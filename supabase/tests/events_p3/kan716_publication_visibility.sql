-- KAN-751 (KAN-716 V03): publication / visibility test. LOCAL THROWAWAY POSTGRES 15+ ONLY (wal_level=logical).
-- NEVER RUN AGAINST SUPABASE. Run from the repo root, on an empty database:
--   psql -v ON_ERROR_STOP=1 -d kan716 -f supabase/tests/events_p3/kan716_publication_visibility.sql
-- Every check is a DO block that RAISEs on failure and a NOTICE 'PASS Tn ...' on success.
--
-- HARNESS ASSUMPTIONS (stand-ins, not the production objects):
--   * public.meetups / public.games carry the baseline column names (meetups: baseline 20260829080500:23084;
--     games: KAN-710/671 mirror columns) plus secret-bearing columns that must NOT be published.
--   * meetups_select_visible is a SIMPLIFIED stand-in of can_view_owner AND kan713_meetup_visible:
--     owner sees own; others see 'public'; nobody sees a blocked owner. games has RLS and NO policy (kan671).
--   * Supabase Realtime's own RLS check is not reproduced; T6 shows what an authenticated subscriber's
--     SELECT RLS allows, which is the check Realtime applies per subscriber.

\set ON_ERROR_STOP on
SET client_min_messages = notice;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

CREATE TABLE public.user_blocks (blocker_user_id uuid NOT NULL, blocked_user_id uuid NOT NULL);
CREATE TABLE public.other_published (id uuid PRIMARY KEY, note text);   -- proves the migration never touches other tables

CREATE TABLE public.meetups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), creator_profile_id uuid NOT NULL, creator_user_id uuid NOT NULL,
  title text NOT NULL, description text, vibe_key text, listing_visibility text NOT NULL DEFAULT 'public',
  rsvp_policy text NOT NULL DEFAULT 'open', capacity integer, start_at timestamptz NOT NULL, end_at timestamptz,
  is_cancelled boolean NOT NULL DEFAULT false, meta jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(), host_actor_id uuid NOT NULL, search_tsv tsvector, geo_location_id uuid,
  sport_id uuid, area_id uuid, venue_id uuid, min_skill integer, max_skill integer, members_only boolean NOT NULL DEFAULT false,
  joining_rule text NOT NULL DEFAULT 'free', cost_cover text NOT NULL DEFAULT 'free', location_name text, event_id uuid);
CREATE TABLE public.games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), creator_profile_id uuid NOT NULL, creator_user_id uuid NOT NULL,
  title text, start_at timestamptz NOT NULL, end_at timestamptz, capacity integer, listing_visibility text NOT NULL DEFAULT 'public',
  join_policy text NOT NULL DEFAULT 'open', is_cancelled boolean NOT NULL DEFAULT false, cancelled_at timestamptz,
  cancelled_reason text, sport_id uuid, area_id uuid, geo_location_id uuid, venue_id uuid, min_skill integer, max_skill integer,
  cost_cover text, request_id uuid, rules jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  event_id uuid);
CREATE TABLE public.events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_type text NOT NULL, creator_user_id uuid NOT NULL, title text);

-- KAN-710/713 posture on events + games, simplified meetups policy.
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY; ALTER TABLE public.events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.events FROM PUBLIC, anon, authenticated;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;                       -- no policy (kan671 header)
GRANT SELECT ON public.games TO authenticated;
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY; ALTER TABLE public.meetups FORCE ROW LEVEL SECURITY;
GRANT SELECT ON public.meetups, public.user_blocks TO authenticated;
CREATE POLICY meetups_select_visible ON public.meetups FOR SELECT TO authenticated USING (
  creator_user_id = auth.uid()
  OR (listing_visibility = 'public'
      AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = creator_user_id AND b.blocked_user_id = auth.uid())));

-- Platform-managed publication, already carrying an unrelated table; NO games / meetups (audit finding).
CREATE PUBLICATION supabase_realtime FOR TABLE public.other_published;

-- Seed: ONE game and ONE meetup (plus a private meetup and a blocked-owner meetup for T6).
\set owner  '11111111-1111-1111-1111-111111111111'
\set viewer '22222222-2222-2222-2222-222222222222'
\set victim '33333333-3333-3333-3333-333333333333'
INSERT INTO public.other_published VALUES ('aaaaaaaa-0000-0000-0000-000000000001', 'x');
INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, host_actor_id, title, description, listing_visibility, start_at, capacity, meta, location_name, event_id)
VALUES ('bbbbbbbb-0000-0000-0000-000000000001', :'owner', :'owner', :'owner', 'Meetup A', 'SECRET-MEETUP-DESC', 'public', '2030-01-01T10:00Z', 12, '{"k":"SECRET-MEETUP-META"}', 'SECRET-LOCATION', gen_random_uuid()),
       ('bbbbbbbb-0000-0000-0000-000000000002', :'owner', :'owner', :'owner', 'Private meetup', 'x', 'hidden', '2030-01-02T10:00Z', 5, '{}', null, gen_random_uuid()),
       ('bbbbbbbb-0000-0000-0000-000000000003', :'victim', :'victim', :'victim', 'Blocked owner meetup', 'x', 'public', '2030-01-03T10:00Z', 5, '{}', null, gen_random_uuid());
INSERT INTO public.user_blocks VALUES (:'victim', :'viewer');          -- victim blocked viewer
INSERT INTO public.games (id, creator_profile_id, creator_user_id, title, start_at, end_at, capacity, request_id, rules, event_id)
VALUES ('cccccccc-0000-0000-0000-000000000001', :'owner', :'owner', 'Game A', '2030-02-01T10:00Z', null, 10, gen_random_uuid(), '{"k":"SECRET-GAME-RULES"}', gen_random_uuid());

CREATE TEMP TABLE kan716_before AS
  SELECT (SELECT count(*) FROM public.meetups) AS meetups, (SELECT count(*) FROM public.games) AS games,
         (SELECT count(*) FROM public.events) AS events,
         (SELECT md5(string_agg(m::text, '|' ORDER BY id)) FROM public.meetups m) AS meetups_md5,
         (SELECT md5(string_agg(g::text, '|' ORDER BY id)) FROM public.games g) AS games_md5;

-- T0: precondition reproduces the audit: no games/meetups in the live-shaped publication.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('games','meetups','events')) THEN
    RAISE EXCEPTION 'FAIL T0 games/meetups/events already published'; END IF;
  RAISE NOTICE 'PASS T0 precondition: publication has only other_published';
END $$;

-- ===== APPLY (authored migration, local only) =====
\i supabase/migrations/20261104102000_kan716_events_realtime_publication.sql

-- T1: exact column lists; events not published; other table untouched.
DO $$
DECLARE m text[]; g text[];
BEGIN
  SELECT attnames INTO m FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='meetups';
  SELECT attnames INTO g FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='games';
  IF m IS NULL OR g IS NULL THEN RAISE EXCEPTION 'FAIL T1 meetups/games not published'; END IF;
  IF NOT ('id' = ANY (m) AND 'id' = ANY (g)) THEN RAISE EXCEPTION 'FAIL T1 id missing'; END IF;
  IF m && ARRAY['creator_user_id','creator_profile_id','host_actor_id','description','meta','search_tsv','cost_cover','joining_rule','rsvp_policy','location_name','event_id','min_skill','max_skill','members_only']
     THEN RAISE EXCEPTION 'FAIL T1 meetups publishes a forbidden column: %', m; END IF;
  IF g && ARRAY['creator_user_id','creator_profile_id','request_id','rules','cost_cover','join_policy','event_id','min_skill','max_skill']
     THEN RAISE EXCEPTION 'FAIL T1 games publishes a forbidden column: %', g; END IF;
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='events')
     THEN RAISE EXCEPTION 'FAIL T1 events is published'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='other_published')
     THEN RAISE EXCEPTION 'FAIL T1 unrelated table dropped from publication'; END IF;
  RAISE NOTICE 'PASS T1 meetups=% games=%', m, g;
END $$;

-- T2: replica identity unchanged (DEFAULT) on all three.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE oid IN ('public.meetups'::regclass,'public.games'::regclass,'public.events'::regclass) AND relreplident <> 'd')
    THEN RAISE EXCEPTION 'FAIL T2 replica identity changed'; END IF;
  RAISE NOTICE 'PASS T2 replica identity DEFAULT on meetups, games, events';
END $$;

-- T3: wire-level check. Decode with pgoutput through the publication: the changes for the seeded rows carry
-- the title but none of the SECRET markers or owner ids.
SELECT pg_create_logical_replication_slot('kan716_slot', 'pgoutput');
UPDATE public.meetups SET title = 'Meetup A v2', description = 'SECRET-MEETUP-DESC-2', updated_at = now() WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001';
UPDATE public.games   SET title = 'Game A v2',   rules = '{"k":"SECRET-GAME-RULES-2"}', updated_at = now()   WHERE id = 'cccccccc-0000-0000-0000-000000000001';
DO $$
DECLARE blob text; n int;
BEGIN
  SELECT string_agg(encode(data, 'escape'), ' '), count(*) INTO blob, n
    FROM pg_logical_slot_get_binary_changes('kan716_slot', NULL, NULL, 'proto_version', '1', 'publication_names', 'supabase_realtime');
  IF blob IS NULL OR n = 0 THEN RAISE EXCEPTION 'FAIL T3 no changes decoded'; END IF;
  IF blob NOT LIKE '%Meetup A v2%' OR blob NOT LIKE '%Game A v2%' THEN RAISE EXCEPTION 'FAIL T3 published columns missing from stream'; END IF;
  IF blob LIKE '%SECRET%' THEN RAISE EXCEPTION 'FAIL T3 a SECRET column leaked into the replication stream'; END IF;
  IF blob LIKE '%11111111-1111-1111-1111-111111111111%' THEN RAISE EXCEPTION 'FAIL T3 owner id leaked into the replication stream'; END IF;
  RAISE NOTICE 'PASS T3 stream carries title, no SECRET column, no owner id (% messages)', n;
END $$;
SELECT pg_drop_replication_slot('kan716_slot');

-- T4: rows not doubled, data untouched by the migration (compare to pre-migration snapshot; the two UPDATEs in
-- T3 changed title/description/rules/updated_at on one row each, so counts and ids are compared, not content).
DO $$
DECLARE b record;
BEGIN
  SELECT * INTO b FROM kan716_before;
  IF (SELECT count(*) FROM public.meetups) <> b.meetups OR (SELECT count(*) FROM public.games) <> b.games
     OR (SELECT count(*) FROM public.events) <> b.events THEN RAISE EXCEPTION 'FAIL T4 row counts changed'; END IF;
  IF (SELECT count(DISTINCT id) FROM public.meetups) <> b.meetups OR (SELECT count(DISTINCT id) FROM public.games) <> b.games
     THEN RAISE EXCEPTION 'FAIL T4 duplicate ids'; END IF;
  RAISE NOTICE 'PASS T4 counts unchanged: meetups=% games=% events=%, no duplicate ids', b.meetups, b.games, b.events;
END $$;

-- T5: events stays closed (no grant, no policy) and no policy/grant was added anywhere by the migration.
DO $$ BEGIN
  IF has_table_privilege('authenticated', 'public.events', 'SELECT') OR has_table_privilege('anon', 'public.events', 'SELECT')
    THEN RAISE EXCEPTION 'FAIL T5 events readable by API roles'; END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename IN ('events','games'))
    THEN RAISE EXCEPTION 'FAIL T5 policy appeared on events/games'; END IF;
  IF (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='meetups') <> 1
    THEN RAISE EXCEPTION 'FAIL T5 meetups policy set changed'; END IF;
  RAISE NOTICE 'PASS T5 events closed; no policy added; meetups keeps its single SELECT policy';
END $$;

-- T6: what a subscriber may receive is bounded by its own SELECT RLS (Realtime applies it per subscriber).
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);     -- viewer: non-owner, blocked by victim
DO $$
DECLARE seen uuid[]; gseen int; eseen text;
BEGIN
  SELECT array_agg(id ORDER BY id) INTO seen FROM public.meetups;
  IF seen <> ARRAY['bbbbbbbb-0000-0000-0000-000000000001']::uuid[]
    THEN RAISE EXCEPTION 'FAIL T6 non-owner/blocked viewer sees %', seen; END IF;
  SELECT count(*) INTO gseen FROM public.games;
  IF gseen <> 0 THEN RAISE EXCEPTION 'FAIL T6 viewer sees % games rows', gseen; END IF;
  BEGIN PERFORM 1 FROM public.events; eseen := 'readable';
  EXCEPTION WHEN insufficient_privilege THEN eseen := 'denied'; END;
  IF eseen <> 'denied' THEN RAISE EXCEPTION 'FAIL T6 events %', eseen; END IF;
  RAISE NOTICE 'PASS T6 non-owner sees only the public meetup (not private, not blocked owner), 0 games, events denied';
END $$;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);     -- owner
DO $$ BEGIN
  IF (SELECT count(*) FROM public.meetups) <> 3 THEN RAISE EXCEPTION 'FAIL T6 owner should see own 2 + the public one'; END IF;
  RAISE NOTICE 'PASS T6 owner sees own 2 meetups + the other public one (3)';
END $$;
RESET ROLE;

-- T7: idempotent re-run leaves the same lists.
CREATE TEMP TABLE kan716_lists AS SELECT tablename, attnames FROM pg_publication_tables WHERE pubname='supabase_realtime';
\i supabase/migrations/20261104102000_kan716_events_realtime_publication.sql
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM kan716_lists l FULL JOIN (SELECT tablename, attnames FROM pg_publication_tables WHERE pubname='supabase_realtime') p
               USING (tablename) WHERE l.attnames IS DISTINCT FROM p.attnames)
    THEN RAISE EXCEPTION 'FAIL T7 re-run changed the lists'; END IF;
  RAISE NOTICE 'PASS T7 idempotent re-run';
END $$;

-- T8: ROLLBACK leaves data intact and restores the pre-state publication.
ALTER PUBLICATION supabase_realtime DROP TABLE public.meetups, public.games;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('meetups','games'))
    THEN RAISE EXCEPTION 'FAIL T8 rollback incomplete'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='other_published')
    THEN RAISE EXCEPTION 'FAIL T8 rollback touched other_published'; END IF;
  IF (SELECT count(*) FROM public.meetups) <> (SELECT meetups FROM kan716_before)
     OR (SELECT count(*) FROM public.games) <> (SELECT games FROM kan716_before)
    THEN RAISE EXCEPTION 'FAIL T8 data changed by rollback'; END IF;
  RAISE NOTICE 'PASS T8 rollback: publication back to other_published only; row counts intact';
END $$;

-- T9: with the platform publication missing, the REAL migration refuses (expected ERROR below) and creates nothing.
ALTER PUBLICATION supabase_realtime RENAME TO supabase_realtime_x;
\set ON_ERROR_STOP off
\i supabase/migrations/20261104102000_kan716_events_realtime_publication.sql
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     OR EXISTS (SELECT 1 FROM pg_publication_tables WHERE tablename IN ('meetups','games'))
    THEN RAISE EXCEPTION 'FAIL T9 migration created or altered a publication'; END IF;
  RAISE NOTICE 'PASS T9 missing publication refused (see ERROR above), nothing created';
END $$;
ALTER PUBLICATION supabase_realtime_x RENAME TO supabase_realtime;
