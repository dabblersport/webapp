-- ROLLBACK ARTIFACT for KAN-866. NOT a migration - do not apply in sequence.
--
-- Undoes 20261114123000_kan866_drop_games_shared_columns.sql: re-adds the 22 shared columns to public.games, fills them
-- (from public._kan866_games_backup for the rows that existed at the drop, and from public.events for any game created
-- after it; the two agree, events is authoritative), restores their NOT NULLs, defaults, CHECKs, FKs and indexes, the
-- KAN-947 events->games mirror (kan947_games_from_events / kan947_events_game_mirror, so the events-first writers keep
-- games in parity again) and the old supabase_realtime column list. The four triggers that were already disabled
-- before the drop (trg_game_created, trg_games_inherit_geo, trg_games_inherit_venue_geo, trg_games_sync_joining_rule) are
-- not restored: they did nothing.
--
-- Run as postgres on wtncuzcskpigqpmnxwws in one transaction. It refuses to run if the backup table is missing.

BEGIN;

DO $chk$
BEGIN
  IF to_regclass('public._kan866_games_backup') IS NULL THEN
    RAISE EXCEPTION 'KAN-866 rollback: public._kan866_games_backup is missing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-866 rollback: games.title already exists; nothing to roll back';
  END IF;
END
$chk$;

ALTER TABLE public.games
  ADD COLUMN title text,
  ADD COLUMN creator_profile_id uuid,
  ADD COLUMN creator_user_id uuid,
  ADD COLUMN start_at timestamptz,
  ADD COLUMN end_at timestamptz,
  ADD COLUMN capacity integer,
  ADD COLUMN listing_visibility text DEFAULT 'public'::text,
  ADD COLUMN join_policy text DEFAULT 'open'::text,
  ADD COLUMN min_skill integer,
  ADD COLUMN max_skill integer,
  ADD COLUMN is_cancelled boolean DEFAULT false,
  ADD COLUMN cancelled_at timestamptz,
  ADD COLUMN cancelled_reason text,
  ADD COLUMN created_at timestamptz DEFAULT now(),
  ADD COLUMN updated_at timestamptz DEFAULT now(),
  ADD COLUMN sport_id uuid,
  ADD COLUMN geo_location_id uuid,
  ADD COLUMN area_id uuid,
  ADD COLUMN venue_id uuid,
  ADD COLUMN joining_rule text DEFAULT 'free'::text,
  ADD COLUMN cost_cover text DEFAULT 'free'::text,
  ADD COLUMN request_id uuid;

-- events is authoritative; the backup is the fallback for a game whose parent went missing.
UPDATE public.games g SET
  creator_profile_id = e.creator_profile_id, creator_user_id = e.creator_user_id, title = e.title,
  start_at = e.start_at, end_at = e.end_at, capacity = e.capacity, listing_visibility = e.listing_visibility,
  join_policy = e.join_policy, is_cancelled = e.is_cancelled, cancelled_at = e.cancelled_at,
  cancelled_reason = e.cancelled_reason, sport_id = e.sport_id, area_id = e.area_id,
  geo_location_id = e.geo_location_id, venue_id = e.venue_id, min_skill = e.min_skill, max_skill = e.max_skill,
  joining_rule = e.joining_rule, cost_cover = e.cost_cover, request_id = e.request_id,
  created_at = e.created_at, updated_at = e.updated_at
FROM public.events e
WHERE e.id = g.event_id AND e.event_type = 'game';

UPDATE public.games g SET
  creator_profile_id = b.creator_profile_id, creator_user_id = b.creator_user_id, title = b.title,
  start_at = b.start_at, end_at = b.end_at, capacity = b.capacity, listing_visibility = b.listing_visibility,
  join_policy = b.join_policy, is_cancelled = b.is_cancelled, cancelled_at = b.cancelled_at,
  cancelled_reason = b.cancelled_reason, sport_id = b.sport_id, area_id = b.area_id,
  geo_location_id = b.geo_location_id, venue_id = b.venue_id, min_skill = b.min_skill, max_skill = b.max_skill,
  joining_rule = b.joining_rule, cost_cover = b.cost_cover, request_id = b.request_id,
  created_at = b.created_at, updated_at = b.updated_at
FROM public._kan866_games_backup b
WHERE b.id = g.id AND g.creator_profile_id IS NULL;

ALTER TABLE public.games
  ALTER COLUMN creator_profile_id SET NOT NULL, ALTER COLUMN creator_user_id SET NOT NULL,
  ALTER COLUMN start_at SET NOT NULL, ALTER COLUMN end_at SET NOT NULL, ALTER COLUMN capacity SET NOT NULL,
  ALTER COLUMN listing_visibility SET NOT NULL, ALTER COLUMN join_policy SET NOT NULL,
  ALTER COLUMN is_cancelled SET NOT NULL, ALTER COLUMN created_at SET NOT NULL, ALTER COLUMN updated_at SET NOT NULL,
  ALTER COLUMN sport_id SET NOT NULL, ALTER COLUMN geo_location_id SET NOT NULL, ALTER COLUMN area_id SET NOT NULL,
  ALTER COLUMN joining_rule SET NOT NULL, ALTER COLUMN cost_cover SET NOT NULL;

ALTER TABLE public.games
  ADD CONSTRAINT fk_games_geo FOREIGN KEY (geo_location_id) REFERENCES public.geo_locations(id) ON DELETE SET NULL,
  ADD CONSTRAINT games_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id),
  ADD CONSTRAINT games_creator_profile_id_fkey FOREIGN KEY (creator_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT,
  ADD CONSTRAINT games_creator_user_id_fkey FOREIGN KEY (creator_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD CONSTRAINT games_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES public.sports(id),
  ADD CONSTRAINT games_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE SET NULL,
  ADD CONSTRAINT games_capacity_check CHECK (((capacity >= 2) AND (capacity <= 64))),
  ADD CONSTRAINT games_cost_cover_check CHECK ((cost_cover = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
  ADD CONSTRAINT games_cost_cover_logic CHECK ((((joining_rule = 'free'::text) AND (cost_cover = 'free'::text)) OR ((joining_rule = 'members_only'::text) AND (cost_cover = 'members_only'::text)) OR ((joining_rule = 'paid'::text) AND (cost_cover = ANY (ARRAY['paid'::text, 'free'::text]))))),
  ADD CONSTRAINT games_join_policy_check CHECK ((join_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text, 'link'::text]))),
  ADD CONSTRAINT games_join_policy_chk CHECK ((join_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text, 'link'::text, 'circle'::text, 'squad'::text, 'closed'::text]))),
  ADD CONSTRAINT games_joining_rule_check CHECK ((joining_rule = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
  ADD CONSTRAINT games_listing_visibility_check CHECK ((listing_visibility = ANY (ARRAY['public'::text, 'followers'::text, 'private'::text]))),
  ADD CONSTRAINT games_location_required CHECK (((geo_location_id IS NOT NULL) AND (area_id IS NOT NULL))),
  ADD CONSTRAINT games_max_skill_check CHECK (((max_skill >= 1) AND (max_skill <= 10))),
  ADD CONSTRAINT games_min_skill_check CHECK (((min_skill >= 1) AND (min_skill <= 10)));

CREATE INDEX idx_games_time ON public.games USING btree (start_at, end_at);
CREATE INDEX idx_games_host ON public.games USING btree (creator_user_id, creator_profile_id);
CREATE INDEX idx_games_visibility ON public.games USING btree (listing_visibility, join_policy);
CREATE INDEX idx_games_cancelled ON public.games USING btree (is_cancelled);
CREATE INDEX idx_games_is_cancelled ON public.games USING btree (is_cancelled);
CREATE INDEX idx_games_start_at ON public.games USING btree (start_at);
CREATE INDEX idx_games_title_prefix ON public.games USING btree (lower(public.unaccent_immutable(title)) text_pattern_ops) WHERE (title IS NOT NULL);
CREATE INDEX idx_games_geo ON public.games USING btree (geo_location_id);
CREATE INDEX idx_games_area ON public.games USING btree (area_id);
CREATE UNIQUE INDEX games_creator_request_id_key ON public.games USING btree (creator_profile_id, request_id) WHERE (request_id IS NOT NULL);
CREATE UNIQUE INDEX games_series_id_start_at_key ON public.games USING btree (series_id, start_at) WHERE (series_id IS NOT NULL);

-- the KAN-947 mirror, as it stood before the drop (20261114114127 + 20261114120447)
CREATE FUNCTION public.kan947_games_from_events()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  e public.events;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF pg_trigger_depth() < 2 OR coalesce(current_setting('kan947.mirror', true), '') <> NEW.id::text THEN
      RETURN NEW;     -- not inside kan947_events_game_mirror: a retained-column write, leave its row alone
    END IF;
  END IF;
  SELECT * INTO e FROM public.events WHERE id = coalesce(NEW.event_id, NEW.id) AND event_type = 'game';
  IF NOT FOUND THEN
    RETURN NEW;       -- INSERT with no events parent: refused at commit by trg_games_event_link_check
  END IF;
  NEW.creator_profile_id := e.creator_profile_id; NEW.creator_user_id := e.creator_user_id;
  NEW.title := e.title; NEW.start_at := e.start_at; NEW.end_at := e.end_at; NEW.capacity := e.capacity;
  NEW.listing_visibility := e.listing_visibility; NEW.join_policy := e.join_policy;
  NEW.is_cancelled := e.is_cancelled; NEW.cancelled_at := e.cancelled_at; NEW.cancelled_reason := e.cancelled_reason;
  NEW.sport_id := e.sport_id; NEW.area_id := e.area_id; NEW.geo_location_id := e.geo_location_id;
  NEW.venue_id := e.venue_id; NEW.min_skill := e.min_skill; NEW.max_skill := e.max_skill;
  NEW.joining_rule := e.joining_rule; NEW.cost_cover := e.cost_cover; NEW.request_id := e.request_id;
  NEW.created_at := e.created_at; NEW.updated_at := e.updated_at;
  RETURN NEW;
END
$function$;

CREATE FUNCTION public.kan947_events_game_mirror()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  PERFORM set_config('kan947.mirror', NEW.id::text, true);
  UPDATE public.games g SET bench_slots = g.bench_slots
   WHERE g.event_id = NEW.id
     AND ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
             g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
             g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill, g.max_skill,
             g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
         IS DISTINCT FROM
         ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
             NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled, NEW.cancelled_at, NEW.cancelled_reason,
             NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer, NEW.max_skill::integer,
             NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at, NEW.updated_at);
  PERFORM set_config('kan947.mirror', '', true);
  RETURN NULL;
END
$function$;

REVOKE ALL ON FUNCTION public.kan947_games_from_events() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan947_events_game_mirror() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_00_kan947_games_from_events BEFORE INSERT ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan947_games_from_events();
CREATE TRIGGER trg_zz_kan947_games_from_events BEFORE UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan947_games_from_events();
CREATE TRIGGER trg_zz_kan947_events_game_mirror AFTER UPDATE ON public.events
  FOR EACH ROW WHEN (NEW.event_type = 'game') EXECUTE FUNCTION public.kan947_events_game_mirror();

ALTER PUBLICATION supabase_realtime DROP TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.games
  (id, title, start_at, end_at, capacity, is_cancelled, cancelled_at, cancelled_reason, updated_at, sport_id,
   geo_location_id, area_id, venue_id, event_changed_at);

DO $post$
BEGIN
  IF EXISTS (SELECT 1 FROM public.games WHERE creator_profile_id IS NULL OR start_at IS NULL) THEN
    RAISE EXCEPTION 'KAN-866 rollback: a game could not be restored';
  END IF;
END
$post$;

COMMIT;
