-- KAN-968 (MVP voting) + KAN-969 (wins) — backend half.
--
-- MVP: one vote per voter per event, inside the same 48h rating window and the
-- same eligibility as ratings (ratings_guard / ratings_eligible: finalized,
-- attended, organiser excluded). No self-vote. A second vote replaces the first.
-- Raw votes: the voter reads their own row only; nobody reads others' votes.
-- Aggregates are exposed only as counts (mvp_votes_count, active_stream stats).
--
-- Wins: the existing public.result_wins(user, from, to) is reused — a user wins
-- an event whose event_results.status = 'confirmed' (approved / organiser_final /
-- auto) and whose winning_side equals that user's event_result_submissions.side.
-- Draw (winning_side NULL) = no win. LIMIT: game_roster has no team/side column,
-- so side is known only for players who submitted a result; non-submitters on the
-- winning side are not counted.

CREATE TABLE IF NOT EXISTS public.event_mvp_votes (
  event_id       uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  voter_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  player_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, voter_user_id),
  CONSTRAINT event_mvp_votes_no_self CHECK (voter_user_id <> player_user_id)
);
CREATE INDEX IF NOT EXISTS event_mvp_votes_player_idx ON public.event_mvp_votes (player_user_id, created_at);

ALTER TABLE public.event_mvp_votes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_mvp_votes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.event_mvp_votes TO authenticated;
DROP POLICY IF EXISTS event_mvp_votes_own_read ON public.event_mvp_votes;
CREATE POLICY event_mvp_votes_own_read ON public.event_mvp_votes
  FOR SELECT TO authenticated USING (voter_user_id = (SELECT auth.uid()));
-- Writes only through rpc_mvp_vote (SECURITY DEFINER); no write grant.

-- Cast or change a vote.
CREATE OR REPLACE FUNCTION public.rpc_mvp_vote(p_event_id uuid, p_player_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); g record;
BEGIN
  SELECT * INTO g FROM public.ratings_guard(p_event_id, v_uid);  -- not_authenticated / not_ratable / window_* / not_eligible
  IF p_player_user_id IS NULL THEN RAISE EXCEPTION 'invalid_player'; END IF;
  IF p_player_user_id = v_uid THEN RAISE EXCEPTION 'self_vote'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = p_player_user_id) THEN
    RAISE EXCEPTION 'player_not_eligible';
  END IF;
  INSERT INTO public.event_mvp_votes (event_id, voter_user_id, player_user_id)
  VALUES (p_event_id, v_uid, p_player_user_id)
  ON CONFLICT (event_id, voter_user_id)
  DO UPDATE SET player_user_id = EXCLUDED.player_user_id, updated_at = now();
  RETURN jsonb_build_object('event_id', p_event_id, 'player_user_id', p_player_user_id, 'closes_at', g.closes_at);
END;
$function$;

-- My vote + candidate list.
CREATE OR REPLACE FUNCTION public.rpc_mvp_get(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); g record; v_mine uuid;
BEGIN
  SELECT * INTO g FROM public.ratings_guard(p_event_id, v_uid);
  SELECT player_user_id INTO v_mine FROM public.event_mvp_votes WHERE event_id = p_event_id AND voter_user_id = v_uid;
  RETURN jsonb_build_object(
    'event_id', p_event_id,
    'closes_at', g.closes_at,
    'my_vote', v_mine,
    'candidates', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('user_id', u, 'profile_id', p.id, 'display_name', p.display_name,
                                          'avatar_url', p.avatar_url) ORDER BY p.display_name, u)
        FROM public.ratings_eligible(p_event_id) u
        LEFT JOIN LATERAL (SELECT pp.id, pp.display_name, pp.avatar_url FROM public.profiles pp
                            WHERE pp.user_id = u AND pp.profile_type = 'personal' LIMIT 1) p ON true
       WHERE u <> v_uid AND NOT public.is_blocked(v_uid, u)), '[]'::jsonb));
END;
$function$;

-- Count of MVP votes a user received, votes cast in [p_from, p_to). Counterpart of result_wins.
CREATE OR REPLACE FUNCTION public.mvp_votes_count(p_user_id uuid, p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT count(*)::int FROM public.event_mvp_votes v
   WHERE v.player_user_id = p_user_id
     AND (p_from IS NULL OR v.created_at >= p_from) AND (p_to IS NULL OR v.created_at < p_to);
$function$;

REVOKE ALL ON FUNCTION public.rpc_mvp_vote(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_mvp_get(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mvp_votes_count(uuid, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_mvp_vote(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_mvp_get(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mvp_votes_count(uuid, timestamptz, timestamptz) TO service_role;

-- active_stream: player_week / player_month stats gain mvp_votes and wins (hosted kept).
-- Patched from the live definition so nothing else in it changes.
DO $do$
DECLARE d text; n text;
BEGIN
  d := pg_get_functiondef('public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)'::regprocedure);
  n := replace(d,
    $a$jsonb_build_object('key', 'hosted', 'value', hps.hosted)),$a$,
    $b$jsonb_build_object('key', 'hosted', 'value', hps.hosted),
                             jsonb_build_object('key', 'mvp_votes', 'value', public.mvp_votes_count(hps.user_id, hps.ps_at, hps.pe_at)),
                             jsonb_build_object('key', 'wins', 'value', public.result_wins(hps.user_id, hps.ps_at, hps.pe_at))),$b$);
  n := replace(n,
    $a$SELECT hp.kind, prd.period_start, prd.pe_at, hp.profile_id,$a$,
    $b$SELECT hp.kind, prd.period_start, prd.ps_at, prd.pe_at, hp.profile_id,$b$);
  IF n = d OR position('mvp_votes' in n) = 0 OR position('prd.ps_at, prd.pe_at, hp.profile_id' in n) = 0 THEN
    RAISE EXCEPTION 'kan968: active_stream patch anchors not found';
  END IF;
  EXECUTE n;
END;
$do$;
