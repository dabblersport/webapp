-- KAN-1018: duplicate organiser notices from the KAN-982 roster sender.
--  1. game.full went out once per filling row (key per roster row), so a leave refilled from the waitlist sent it
--     again. It is now sent once per fill episode: public.game_fill_episodes holds full_since / episode per game.
--     A join that leaves the game with no slot starts an episode only when none is open; the key is
--     game.full:<game>:<episode>. A leave ends the episode only if a place is still open after the waitlist
--     promotion step, so a refill from the waitlist is the same episode.
--  2. A join that accepts a pending invite sent game.invite_accepted (invite trigger) and game.player_joined. It now
--     sends only invite_accepted: player_joined is skipped when the join accepted an invite.
-- Known edge (KAN-976 owns event edits): a capacity change that opens or fills a game without a roster change does
-- not move the episode; the next roster change corrects it.
-- New table: RLS on, no policies, no client grants (server state only). CREATE OR REPLACE only. No DROP, no DELETE.
-- No backfill: there were 0 full upcoming games on 2026-11-17, so no open episode to seed.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.kan982_roster_after()'::regprocedure)) <> '30e1bcfde73e12ee182aaeebe0908487' THEN
    RAISE EXCEPTION 'KAN-1018 guard: kan982_roster_after changed since it was read';
  END IF;
  IF to_regclass('public.game_fill_episodes') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-1018 guard: game_fill_episodes already exists';
  END IF;
END
$guard$;

CREATE TABLE public.game_fill_episodes (
  game_id    uuid PRIMARY KEY REFERENCES public.games(id) ON DELETE CASCADE,
  full_since timestamptz,
  episode    integer NOT NULL DEFAULT 0 CHECK (episode >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.game_fill_episodes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.game_fill_episodes FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.game_fill_episodes IS
  'KAN-1018: one row per game. full_since is set while the roster is full; episode counts fills. Written only by '
  'kan982_roster_after; game.full is deduped on (game, episode).';

CREATE OR REPLACE FUNCTION public.kan982_roster_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  c          record;
  v_key      text;
  v_invited  integer := 0;
  v_episode  integer;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NULL;
  END IF;
  SELECT * INTO c FROM public.kan982_game_ctx(NEW.game_id);

  IF NEW.status = 'active' AND (TG_OP = 'INSERT' OR OLD.status <> 'active') THEN
    -- One key per join: the first join, or the re-join after the recorded leave.
    v_key := NEW.id || ':' || CASE WHEN TG_OP = 'INSERT' THEN 'first'
                                  ELSE 'rejoin:' || COALESCE(public.kan982_tkey(OLD.left_at), 'unknown') END;

    -- A pending invite to this player for this game is now accepted (game.invite_accepted, via its trigger).
    UPDATE public.game_invites SET status = 'accepted', responded_at = now()
     WHERE game_id = NEW.game_id AND to_user_id = NEW.user_id AND status = 'pending';
    GET DIAGNOSTICS v_invited = ROW_COUNT;

    -- Tell the host, unless the host is the one joining, the host made it happen (approval), or (KAN-1018) the
    -- join accepted an invite, which the host already hears about as game.invite_accepted.
    IF NEW.role <> 'host' AND c.host_user_id IS NOT NULL AND NEW.user_id <> c.host_user_id
       AND auth.uid() IS DISTINCT FROM c.host_user_id AND v_invited = 0 THEN
      PERFORM public.kan982_notify(c.host_user_id, 'game.player_joined', jsonb_build_object('title', c.title),
        'game', NEW.game_id, NEW.user_id, 'game.player_joined:' || v_key);
    END IF;

    -- KAN-1018: game.full once per fill episode.
    IF c.capacity IS NOT NULL AND c.host_user_id IS NOT NULL AND public.game_slots_left(NEW.game_id) = 0 THEN
      INSERT INTO public.game_fill_episodes AS f (game_id, full_since, episode, updated_at)
      VALUES (NEW.game_id, now(), 1, now())
      ON CONFLICT (game_id) DO UPDATE
         SET full_since = now(), episode = f.episode + 1, updated_at = now()
       WHERE f.full_since IS NULL
      RETURNING f.episode INTO v_episode;
      IF v_episode IS NOT NULL THEN   -- NULL: an episode was already open, nothing to send
        PERFORM public.kan982_notify(c.host_user_id, 'game.full', jsonb_build_object('title', c.title),
          'game', NEW.game_id, NULL, 'game.full:' || NEW.game_id || ':episode:' || v_episode);
      END IF;
    END IF;

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status IN ('left', 'kicked') THEN
    IF NEW.status = 'left' AND NEW.role <> 'host' AND c.host_user_id IS NOT NULL
       AND NEW.user_id <> c.host_user_id THEN
      PERFORM public.kan982_notify(c.host_user_id, 'game.player_left', jsonb_build_object('title', c.title),
        'game', NEW.game_id, NEW.user_id,
        'game.player_left:' || NEW.id || ':' || public.kan982_tkey(COALESCE(NEW.left_at, now())));
    END IF;
    IF OLD.role <> 'host' THEN
      PERFORM public.kan982_promote_waitlist(NEW.game_id);
    END IF;
    -- KAN-1018: the fill episode ends only if a place is still open after the waitlist step.
    IF public.game_slots_left(NEW.game_id) > 0 THEN
      UPDATE public.game_fill_episodes SET full_since = NULL, updated_at = now()
       WHERE game_id = NEW.game_id AND full_since IS NOT NULL;
    END IF;
  END IF;

  RETURN NULL;
END;
$function$;
