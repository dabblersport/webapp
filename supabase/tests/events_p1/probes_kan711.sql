-- KAN-711 probes. BEGIN ... ROLLBACK: nothing persists.
-- Executed against: local throwaway PostgreSQL 16 built from local_harness_kan711.sql +
-- local_seed_kan711.sql + KAN-710 (20261101140000, unmodified) + the two KAN-711 migrations. NOT executed against Supabase (forbidden to
-- this seat). The ids below are the local seed's; on any other database the probe must be re-seeded.
--
--   psql -h /tmp -p 54399 -U postgres -d kan711 -v ON_ERROR_STOP=1 -f probes_kan711.sql
--
-- Every assertion raises on failure (ON_ERROR_STOP aborts). Key probes are paired with a NEGATIVE
-- CONTROL ("CTRL") that plants the fault inside a savepoint and shows the same probe catching it:
-- a probe nobody has seen fail is not evidence.
--
-- Deferred checks only fire at COMMIT, and this file never commits. pg_temp.flush() reproduces the
-- commit boundary: it sets KAN-710's seven deferred checks IMMEDIATE (firing everything pending) and
-- then DEFERRED again, so statements still run in production mode (deferred) between flushes.
-- NOTE: do not use SET CONSTRAINTS ALL IMMEDIATE *before* a legacy write: the FK's internal RI trigger
-- sorts before trg_kan711_*_mirror and would check before the events row exists (see contract, Risks).

\set ON_ERROR_STOP 1
BEGIN;

CREATE FUNCTION pg_temp.flush() RETURNS void LANGUAGE plpgsql AS $$
-- KAN-710:264-271 (events) and 282-295 (games/meetups). KAN-711 owns no deferred check.
DECLARE l text := 'public.games_event_id_fkey, public.meetups_event_id_fkey, public.trg_games_event_link_check, '
               || 'public.trg_meetups_event_link_check, public.trg_games_series_occurrence_check, '
               || 'public.trg_events_exclusive_check, public.trg_events_series_start_check';
BEGIN
  EXECUTE 'SET CONSTRAINTS ' || l || ' IMMEDIATE';
  EXECUTE 'SET CONSTRAINTS ' || l || ' DEFERRED';
END $$;

CREATE FUNCTION pg_temp.ok(cond boolean, name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF cond IS NOT TRUE THEN RAISE EXCEPTION 'FAIL: %', name; END IF;
  RAISE NOTICE 'PASS: %', name;
END $$;

-- Runs sql (optionally as a role); passes only if it raises with SQLSTATE or message matching want.
CREATE FUNCTION pg_temp.refused(sql text, want text, name text, as_role text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE st text; msg text;
BEGIN
  BEGIN
    IF as_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', as_role); END IF;
    EXECUTE sql;
    PERFORM pg_temp.flush();
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
    PERFORM pg_temp.flush();          -- restore DEFERRED whatever the subtransaction left behind
    IF st = want OR msg = want THEN
      RAISE NOTICE 'PASS: % (refused % %)', name, st, msg;
      RETURN;
    END IF;
    RAISE EXCEPTION 'FAIL: % refused with % % (wanted %)', name, st, msg, want;
  END;
  RAISE EXCEPTION 'FAIL: % was NOT refused', name;
END $$;

CREATE TEMP TABLE sink_snapshot AS
SELECT md5(coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.public_activities t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.activity_events t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.notifications t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.feed_items t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.event_outbox t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.msg_system_lines t), '')) AS h,
       (SELECT count(*) FROM public.public_activities) + (SELECT count(*) FROM public.activity_events)
     + (SELECT count(*) FROM public.notifications) + (SELECT count(*) FROM public.feed_items)
     + (SELECT count(*) FROM public.event_outbox) + (SELECT count(*) FROM public.msg_system_lines) AS n;

CREATE FUNCTION pg_temp.sink_hash() RETURNS text LANGUAGE sql AS $$
SELECT md5(coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.public_activities t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.activity_events t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.notifications t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.feed_items t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.event_outbox t), '')
        || coalesce((SELECT string_agg(t::text, '|' ORDER BY t::text) FROM public.msg_system_lines t), ''))
$$;

CREATE TEMP TABLE legacy_snapshot AS
SELECT 'games' AS kind, id, to_jsonb(g) - 'event_id' AS j FROM public.games g
UNION ALL
SELECT 'meetups', id, to_jsonb(m) - 'event_id' FROM public.meetups m;

-- P0 preconditions ---------------------------------------------------------------------------------
SELECT pg_temp.ok((SELECT count(*) FROM public.events) = 0, 'P0 events empty before backfill');
SELECT pg_temp.ok((SELECT count(*) FROM public.games) = 6 AND (SELECT count(*) FROM public.meetups) = 6, 'P0 12 pre-existing legacy rows');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity WHERE missing_event AND unlinked) = 12,
                  'P0 parity view reports all 12 as missing+unlinked (the probe can see a gap)');

-- P1 interrupted run resumes ----------------------------------------------------------------------
SELECT pg_temp.ok(public.kan711_events_backfill_batch('games', 4) = 4, 'P1 games batch 1 processes 4');
SELECT pg_temp.flush();
SELECT pg_temp.ok((SELECT last_id = '10000000-0000-0000-0000-000000000004' AND rows_done = 4 AND finished_at IS NULL
                     FROM public.events_backfill_checkpoint WHERE kind = 'games'), 'P1 checkpoint at 4th id, not finished');
SELECT pg_temp.ok((SELECT count(*) FROM public.events WHERE event_type = 'game') = 4, 'P1 exactly 4 game events after interruption');
-- simulate an interrupted batch: it rolls back entirely and the checkpoint does not move
SAVEPOINT crash;
SELECT public.kan711_events_backfill_batch('games', 4);
ROLLBACK TO SAVEPOINT crash;
SELECT pg_temp.flush();
SELECT pg_temp.ok((SELECT last_id = '10000000-0000-0000-0000-000000000004' FROM public.events_backfill_checkpoint WHERE kind = 'games')
                  AND (SELECT count(*) FROM public.events WHERE event_type = 'game') = 4,
                  'P1 aborted batch left checkpoint and events untouched');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('games', 4) = 2, 'P1 resume picks up the remaining 2');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('games', 4) = 0, 'P1 next batch empty');
SELECT pg_temp.ok((SELECT finished_at IS NOT NULL AND rows_done = 6 AND rows_failed = 0 FROM public.events_backfill_checkpoint WHERE kind = 'games'),
                  'P1 games finished, 6 done, 0 failed');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('meetups', 500) = 6, 'P1 meetups batch processes 6');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('meetups', 500) = 0, 'P1 meetups finished');
SELECT pg_temp.flush();

-- P2 one event per row ----------------------------------------------------------------------------
SELECT pg_temp.ok((SELECT count(*) FROM public.events WHERE event_type = 'game')   = (SELECT count(*) FROM public.games)
              AND (SELECT count(*) FROM public.events WHERE event_type = 'meetup') = (SELECT count(*) FROM public.meetups),
                  'P2 one events row per legacy row, per type');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
              AND NOT EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id),
                  'P2 every legacy row linked, event_id = id');

-- P3 per-field parity, zero mismatches ------------------------------------------------------------
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0, 'P3 parity view: 0 rows (23 fields incl. updated_at, IS DISTINCT FROM)');
SAVEPOINT ctrl;
UPDATE public.events SET title = 'tampered' WHERE id = '10000000-0000-0000-0000-000000000001';
UPDATE public.events SET capacity = 3        WHERE id = '10000000-0000-0000-0000-000000000004';
SELECT pg_temp.ok((SELECT array_agg(mismatched_fields[1] ORDER BY id) FROM public.kan711_events_parity) = ARRAY['title', 'capacity'],
                  'P3 CTRL parity catches a tampered title and a tampered capacity');
ROLLBACK TO SAVEPOINT ctrl;
SELECT pg_temp.flush();
-- mapping spot checks: nulls preserved, nothing inferred, alias applied
SELECT pg_temp.ok((SELECT title IS NULL FROM public.events WHERE id = '10000000-0000-0000-0000-000000000002'), 'P3 null game title preserved');
SELECT pg_temp.ok((SELECT end_at IS NULL AND capacity IS NULL AND cancelled_at IS NULL FROM public.events WHERE id = '30000000-0000-0000-0000-000000000001'),
                  'P3 meetup null end_at/capacity preserved; cancelled_at not invented');
SELECT pg_temp.ok((SELECT is_cancelled AND cancelled_at IS NULL FROM public.events WHERE id = '30000000-0000-0000-0000-000000000003'),
                  'P3 cancelled meetup: is_cancelled copied, cancelled_at NOT inferred');
SELECT pg_temp.ok((SELECT cancelled_at = '2025-12-10 09:00+00' AND cancelled_reason = 'rain' FROM public.events WHERE id = '10000000-0000-0000-0000-000000000003'),
                  'P3 game cancelled_at/reason copied');
SELECT pg_temp.ok((SELECT listing_visibility = 'hidden' AND join_policy = 'closed' FROM public.events WHERE id = '30000000-0000-0000-0000-000000000005'),
                  'P3 meetup-only values kept raw; rsvp_policy -> join_policy');
SELECT pg_temp.ok((SELECT venue_id IS NULL FROM public.events WHERE id = '30000000-0000-0000-0000-000000000002'),
                  'P3 meta.venue_space_id NOT copied into venue_id');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'events'
                               AND column_name IN ('description', 'location_name', 'is_indoor')),
                  'P3 description/location_name/is_indoor are not parent columns (KAN-710); nothing copied or invented');
SELECT pg_temp.ok((SELECT search_tsv = to_tsvector('simple', 'Sunday 5s') FROM public.events WHERE id = '10000000-0000-0000-0000-000000000001')
              AND (SELECT search_tsv = setweight(to_tsvector('simple', 'Morning run'), 'A') FROM public.events WHERE id = '30000000-0000-0000-0000-000000000001'),
                  'P3 search_tsv derived by KAN-710 (title only), not copied from legacy');

-- P4 backfill left every legacy column except event_id untouched (timestamps, tsv) ---------------
SELECT pg_temp.ok(NOT EXISTS (
    SELECT 1 FROM legacy_snapshot s
    LEFT JOIN (SELECT 'games' AS kind, id, to_jsonb(g) - 'event_id' AS j FROM public.games g
               UNION ALL SELECT 'meetups', id, to_jsonb(m) - 'event_id' FROM public.meetups m) c USING (kind, id)
    WHERE c.j IS DISTINCT FROM s.j), 'P4 legacy rows byte-identical apart from event_id (updated_at not bumped)');
SELECT pg_temp.ok((SELECT updated_at = '2025-12-02 10:00+00' FROM public.events WHERE id = '10000000-0000-0000-0000-000000000001'),
                  'P4 events.updated_at = legacy value, not now()');
SELECT pg_temp.ok((SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass)
                     AND tgname = 'trg_game_created' AND tgenabled = 'D') = 1
              AND (SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass)
                     AND NOT tgisinternal AND tgenabled = 'D') = 1,
                  'P4 trigger modes restored exactly (only the baseline-disabled trg_game_created is disabled)');

-- P5 backfill added nothing to notification / feed / outbox / activity / message sinks -----------
SELECT pg_temp.ok(pg_temp.sink_hash() = (SELECT h FROM sink_snapshot), 'P5 side-effect sinks byte-identical after backfill');
SAVEPOINT ctrl;
UPDATE public.games SET is_cancelled = true WHERE id = '10000000-0000-0000-0000-000000000001';   -- a real user action
SELECT pg_temp.ok(pg_temp.sink_hash() <> (SELECT h FROM sink_snapshot), 'P5 CTRL the same probe detects a legacy write''s side effects');
ROLLBACK TO SAVEPOINT ctrl;
SELECT pg_temp.flush();

-- P6 re-run is idempotent -------------------------------------------------------------------------
CREATE TEMP TABLE ev_before AS SELECT id, ctid::text AS c FROM public.events;
SELECT public.kan711_events_backfill_reset('games');
SELECT public.kan711_events_backfill_reset('meetups');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('games', 500) = 6 AND public.kan711_events_backfill_batch('games', 500) = 0
              AND public.kan711_events_backfill_batch('meetups', 500) = 6 AND public.kan711_events_backfill_batch('meetups', 500) = 0,
                  'P6 full re-run scans every row again');
SELECT pg_temp.flush();
SELECT pg_temp.ok((SELECT count(*) FROM public.events) = 12, 'P6 still 12 events');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM ev_before b JOIN public.events e USING (id) WHERE e.ctid::text <> b.c),
                  'P6 no events row rewritten (same tuple, IS DISTINCT FROM guard)');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0 AND pg_temp.sink_hash() = (SELECT h FROM sink_snapshot),
                  'P6 parity still 0, sinks still untouched');

-- P7 create / edit / cancel / delete mirrored in the same transaction -----------------------------
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, sport_id, geo_location_id, area_id)
VALUES ('10000000-0000-0000-0000-0000000000aa', 'New', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2026-02-01 18:00+00', '2026-02-01 19:00+00', 6, '00000000-0000-0000-0000-0000000000e1',
        '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
SELECT pg_temp.ok((SELECT g.event_id = g.id AND e.title = 'New' AND e.event_type = 'game' AND e.created_at = g.created_at
                     FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.id = '10000000-0000-0000-0000-0000000000aa'),
                  'P7 game INSERT mirrored, linked, timestamps copied');
UPDATE public.games SET title = 'Edited', capacity = 8 WHERE id = '10000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.flush();   -- commit boundary: FK + integrity checks pass for the new row
SELECT pg_temp.ok((SELECT title = 'Edited' AND capacity = 8 FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000aa'), 'P7 game edit mirrored');
UPDATE public.games SET is_cancelled = true, cancelled_at = '2026-01-20 12:00+00', cancelled_reason = 'pitch closed'
 WHERE id = '10000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.ok((SELECT is_cancelled AND cancelled_reason = 'pitch closed' FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000aa'), 'P7 game cancel mirrored');
DELETE FROM public.games WHERE id = '10000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000aa'), 'P7 game delete mirrored');
SELECT pg_temp.flush();

INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at, host_actor_id)
VALUES ('30000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
        'New meetup', '2026-02-02 06:00+00', '00000000-0000-0000-0000-0000000000b2');
UPDATE public.meetups SET title = 'New meetup edited', rsvp_policy = 'request' WHERE id = '30000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.ok((SELECT title = 'New meetup edited' AND join_policy = 'request' AND end_at IS NULL
                     FROM public.events WHERE id = '30000000-0000-0000-0000-0000000000aa'), 'P7 meetup insert+edit mirrored, rsvp alias');
SELECT pg_temp.flush();   -- commit boundary between create and delete; see the FINDING probe below
UPDATE public.meetups SET is_cancelled = true WHERE id = '30000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.ok((SELECT is_cancelled AND cancelled_at IS NULL FROM public.events WHERE id = '30000000-0000-0000-0000-0000000000aa'), 'P7 meetup cancel mirrored');
DELETE FROM public.meetups WHERE id = '30000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.events WHERE id = '30000000-0000-0000-0000-0000000000aa'), 'P7 meetup delete mirrored');
SELECT pg_temp.flush();
SELECT pg_temp.ok(true, 'P7 KAN-710 deferred FK + link checks passed at the simulated commit boundary for create/edit/cancel/delete');
-- FINDING (KAN-710 x KAN-711): a subtype row created AND deleted in one transaction fails at COMMIT.
-- KAN-711's assign trigger sets event_id on INSERT, queueing KAN-710's deferred link check; the
-- delete removes the row and (via the mirror) its events row; the queued check then runs against the
-- stale NEW tuple and raises 'orphan' (KAN-710:172-176 never re-checks that the subtype row exists).
-- Recorded, not fixed: the fix is in KAN-710's events_check_subtype_link().
SELECT pg_temp.refused($q$
  INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at, host_actor_id)
  VALUES ('30000000-0000-0000-0000-0000000000ab', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
          'Short lived', '2026-02-03 06:00+00', '00000000-0000-0000-0000-0000000000b2');
  DELETE FROM public.meetups WHERE id = '30000000-0000-0000-0000-0000000000ab';
$q$, '23503', 'P7 FINDING create+delete of one meetup in one transaction is refused at commit (orphan)');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.meetups WHERE id = '30000000-0000-0000-0000-0000000000ab')
                  AND NOT EXISTS (SELECT 1 FROM public.events WHERE id = '30000000-0000-0000-0000-0000000000ab'),
                  'P7 FINDING refused transaction left nothing behind');

SAVEPOINT atom;
UPDATE public.games SET title = 'rolled back' WHERE id = '10000000-0000-0000-0000-000000000001';
ROLLBACK TO SAVEPOINT atom;
SELECT pg_temp.ok((SELECT title = 'Sunday 5s' FROM public.events WHERE id = '10000000-0000-0000-0000-000000000001'),
                  'P7 a rolled-back legacy write takes its mirror with it (same transaction)');

SAVEPOINT direct;
UPDATE public.events SET title = 'direct edit' WHERE id = '10000000-0000-0000-0000-000000000005';
UPDATE public.games SET title = 'legacy wins' WHERE id = '10000000-0000-0000-0000-000000000005';
SELECT pg_temp.ok((SELECT title = 'legacy wins' AND updated_at = (SELECT updated_at FROM public.games WHERE id = '10000000-0000-0000-0000-000000000005')
                     FROM public.events WHERE id = '10000000-0000-0000-0000-000000000005'),
                  'P7 legacy is authoritative: the next legacy write overwrites a direct events edit; both touch triggers agree on updated_at');
ROLLBACK TO SAVEPOINT direct;
SELECT pg_temp.flush();

SAVEPOINT api;
GRANT SELECT ON public.profiles TO authenticated;
CREATE POLICY kan711_probe_insert ON public.games FOR INSERT TO authenticated WITH CHECK (true);
SET LOCAL ROLE authenticated;
INSERT INTO public.games (id, creator_profile_id, creator_user_id, start_at, end_at, capacity, sport_id, geo_location_id, area_id)
VALUES ('10000000-0000-0000-0000-0000000000bb', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2026-02-03 18:00+00', '2026-02-03 19:00+00', 4, '00000000-0000-0000-0000-0000000000e1',
        '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
RESET ROLE;
SELECT pg_temp.flush();
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000bb'),
                  'P7 an authenticated write still mirrors although the trigger functions are revoked from it');
ROLLBACK TO SAVEPOINT api;
SELECT pg_temp.flush();

-- P8 mismatched event_type refused ----------------------------------------------------------------
SELECT pg_temp.refused($$UPDATE public.games SET event_id = '30000000-0000-0000-0000-000000000001' WHERE id = '10000000-0000-0000-0000-000000000001'$$,
                       'games.event_id must equal the row id (30000000-0000-0000-0000-000000000001 vs 10000000-0000-0000-0000-000000000001)',
                       'P8 game pointed at a meetup event refused (KAN-710 link check)');
SELECT pg_temp.refused($$INSERT INTO public.games (id, creator_profile_id, creator_user_id, start_at, end_at, capacity, sport_id, geo_location_id, area_id)
                         VALUES ('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
                                 '2026-02-03 18:00+00', '2026-02-03 19:00+00', 4, '00000000-0000-0000-0000-0000000000e1',
                                 '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1')$$,
                       'kan711_event_type_mismatch', 'P8 game reusing a meetup''s id refused by the mirror');
SELECT pg_temp.refused($$UPDATE public.events SET event_type = 'meetup' WHERE id = '10000000-0000-0000-0000-000000000001'$$,
                       'events.event_type is immutable (game -> meetup)', 'P8 retyping an events row refused (KAN-710 guard)');
SAVEPOINT bypass;
ALTER TABLE public.games DISABLE TRIGGER trg_kan711_games_mirror;        -- simulate a path that skips the mirror
-- Parent first (outside the refused subtransaction) so no outer deferred FK event outlives it.
INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at)
VALUES ('10000000-0000-0000-0000-0000000000cc', 'meetup', '00000000-0000-0000-0000-0000000000b1',
        '00000000-0000-0000-0000-0000000000a1', 'Mistyped', '2026-02-03 18:00+00');
SELECT pg_temp.refused($$INSERT INTO public.games (id, creator_profile_id, creator_user_id, start_at, end_at, capacity, sport_id, geo_location_id, area_id)
                         VALUES ('10000000-0000-0000-0000-0000000000cc', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
                                 '2026-02-03 18:00+00', '2026-02-03 19:00+00', 4, '00000000-0000-0000-0000-0000000000e1',
                                 '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1')$$,
                       'wrong subtype: meetup event 10000000-0000-0000-0000-0000000000cc has a games row',
                       'P8 a game linked to a meetup-typed parent refused at the boundary (KAN-710 parent-children check, 197-208)');
ROLLBACK TO SAVEPOINT bypass;
SELECT pg_temp.flush();

-- P9 orphan / duplicate event_id ----------------------------------------------------------------
SELECT pg_temp.refused($$UPDATE public.games SET event_id = '10000000-0000-0000-0000-000000000002' WHERE id = '10000000-0000-0000-0000-000000000001'$$,
                       '23505', 'P9 duplicate event_id (pointing at another game) refused (games_event_id_key, KAN-710:279)');
SAVEPOINT cascade;
DELETE FROM public.events WHERE id = '10000000-0000-0000-0000-000000000001';
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.games WHERE id = '10000000-0000-0000-0000-000000000001'),
                  'P9 FINDING: KAN-710 FK is ON DELETE CASCADE (KAN-710:282-285): deleting a parent DELETES its legacy game');
ROLLBACK TO SAVEPOINT cascade;
SELECT pg_temp.flush();
SAVEPOINT bypass;
ALTER TABLE public.meetups DISABLE TRIGGER trg_kan711_meetups_mirror;     -- simulate a path that skips the mirror
DELETE FROM public.meetups WHERE id = '30000000-0000-0000-0000-000000000004';
SELECT pg_temp.flush();                                                  -- not refused: KAN-710 phase 1 allows a childless parent
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity WHERE orphan_event) = 1,
                  'P9 a legacy delete that skips the mirror is NOT refused (KAN-710 handoff limitation 3); parity reports the orphan');
ROLLBACK TO SAVEPOINT bypass;
SELECT pg_temp.flush();
SAVEPOINT ctrl;
DELETE FROM public.meetups WHERE id = '30000000-0000-0000-0000-000000000004';
SELECT pg_temp.flush();
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM public.events WHERE id = '30000000-0000-0000-0000-000000000004')
              AND (SELECT count(*) FROM public.kan711_events_parity) = 0,
                  'P9 CTRL with the mirror in place the same delete removes the parent and parity stays 0');
ROLLBACK TO SAVEPOINT ctrl;
SELECT pg_temp.flush();

-- P10 anon / authenticated cannot touch events or execute KAN-711 functions ----------------------
SELECT pg_temp.refused('SELECT * FROM public.events', '42501', 'P10 anon SELECT events', 'anon');
SELECT pg_temp.refused($$INSERT INTO public.events (id, event_type) VALUES (gen_random_uuid(), 'game')$$, '42501', 'P10 anon INSERT events', 'anon');
SELECT pg_temp.refused($$UPDATE public.events SET title = 'x'$$, '42501', 'P10 anon UPDATE events', 'anon');
SELECT pg_temp.refused('DELETE FROM public.events', '42501', 'P10 anon DELETE events', 'anon');
SELECT pg_temp.refused('SELECT * FROM public.events', '42501', 'P10 authenticated SELECT events', 'authenticated');
SELECT pg_temp.refused($$INSERT INTO public.events (id, event_type) VALUES (gen_random_uuid(), 'game')$$, '42501', 'P10 authenticated INSERT events', 'authenticated');
SELECT pg_temp.refused($$UPDATE public.events SET title = 'x'$$, '42501', 'P10 authenticated UPDATE events', 'authenticated');
SELECT pg_temp.refused('DELETE FROM public.events', '42501', 'P10 authenticated DELETE events', 'authenticated');
SELECT pg_temp.refused('SELECT * FROM public.events_backfill_checkpoint', '42501', 'P10 authenticated reads checkpoint', 'authenticated');
SELECT pg_temp.refused('SELECT * FROM public.events_backfill_exceptions', '42501', 'P10 authenticated reads exceptions', 'authenticated');
SELECT pg_temp.refused('SELECT * FROM public.kan711_events_parity', '42501', 'P10 authenticated reads parity view', 'authenticated');
SELECT pg_temp.refused($$SELECT public.kan711_events_backfill_batch('games', 1)$$, '42501', 'P10 anon executes backfill batch', 'anon');
SELECT pg_temp.refused($$SELECT public.kan711_events_backfill_batch('games', 1)$$, '42501', 'P10 authenticated executes backfill batch', 'authenticated');
SELECT pg_temp.refused($$SELECT public.kan711_events_validate_links()$$, '42501', 'P10 authenticated executes validate_links', 'authenticated');
SELECT pg_temp.refused($$SELECT public.kan711_events_backfill_reset('games')$$, '42501', 'P10 authenticated executes reset', 'authenticated');
SELECT pg_temp.refused($$CALL public.kan711_events_backfill_run(1, 1)$$, '42501', 'P10 authenticated calls backfill_run', 'authenticated');
SELECT pg_temp.refused($$SELECT public.kan711_events_upsert(NULL::public.events)$$, '42501', 'P10 authenticated executes upsert', 'authenticated');
SELECT pg_temp.ok(NOT EXISTS (
    SELECT 1 FROM pg_proc p CROSS JOIN unnest(ARRAY['anon', 'authenticated']) r(role)
     WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%'
       AND has_function_privilege(r.role, p.oid, 'EXECUTE')),
                  'P10 no kan711 function (incl. the 3 trigger functions) executable by anon/authenticated (proacl asserted)');
SAVEPOINT ctrl;
GRANT EXECUTE ON FUNCTION public.kan711_games_mirror() TO anon;
GRANT SELECT ON public.events TO anon;
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%'
                            AND has_function_privilege('anon', p.oid, 'EXECUTE'))
              AND has_table_privilege('anon', 'public.events', 'SELECT'),
                  'P10 CTRL a planted grant is detected by the same checks');
SET LOCAL ROLE anon;
SELECT pg_temp.ok((SELECT count(*) FROM public.events) = 0, 'P10 CTRL even with a stray grant, RLS (no policy) returns 0 rows');
RESET ROLE;
ROLLBACK TO SAVEPOINT ctrl;

-- P11 exception path: a row the mirror cannot take is reported and NOT NULL is not added -----------
SELECT pg_temp.flush();
SAVEPOINT exc;
ALTER TABLE public.meetups DISABLE TRIGGER trg_kan711_meetups_assign_event_id;
ALTER TABLE public.meetups DISABLE TRIGGER trg_kan711_meetups_mirror;
-- legal in legacy (different creator_user_id), illegal in events (same type+profile+request_id as meetup ...02)
INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at, host_actor_id, request_id)
VALUES ('30000000-0000-0000-0000-0000000000ff', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a2',
        'Pre-existing conflict', '2026-02-04 06:00+00', '00000000-0000-0000-0000-0000000000b1', '20000000-0000-0000-0000-000000000001');
SELECT pg_temp.flush();   -- the deferred FK check queued by this INSERT (event_id NULL, passes)
ALTER TABLE public.meetups ENABLE TRIGGER trg_kan711_meetups_assign_event_id;
ALTER TABLE public.meetups ENABLE TRIGGER trg_kan711_meetups_mirror;
SELECT public.kan711_events_backfill_reset('meetups');
SELECT pg_temp.ok(public.kan711_events_backfill_batch('meetups', 500) = 7 AND public.kan711_events_backfill_batch('meetups', 500) = 0,
                  'P11 batch completes despite a bad row');
SELECT pg_temp.flush();
SELECT pg_temp.ok((SELECT sqlstate = '23505' AND resolved_at IS NULL FROM public.events_backfill_exceptions
                    WHERE legacy_id = '30000000-0000-0000-0000-0000000000ff'), 'P11 bad row captured in exceptions (23505)');
SELECT pg_temp.ok((SELECT event_id IS NULL FROM public.meetups WHERE id = '30000000-0000-0000-0000-0000000000ff')
              AND NOT EXISTS (SELECT 1 FROM public.events WHERE id = '30000000-0000-0000-0000-0000000000ff'),
                  'P11 bad row not half-written (no event, no link)');
SELECT pg_temp.ok((public.kan711_events_validate_links() ->> 'validated')::boolean = false
              AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname IN ('games_event_id_not_null', 'meetups_event_id_not_null')),
                  'P11 validate_links refuses and adds no NOT NULL check');
ROLLBACK TO SAVEPOINT exc;
SELECT pg_temp.flush();

-- P12 validate_links on verified parity ----------------------------------------------------------
SELECT pg_temp.ok((public.kan711_events_validate_links() ->> 'validated')::boolean, 'P12 validate_links validates on parity');
SELECT pg_temp.ok((SELECT count(*) FROM pg_constraint WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey',
                     'games_event_id_not_null', 'meetups_event_id_not_null') AND convalidated) = 4, 'P12 FKs and NOT NULL checks VALID');
INSERT INTO public.games (id, creator_profile_id, creator_user_id, start_at, end_at, capacity, sport_id, geo_location_id, area_id)
VALUES ('10000000-0000-0000-0000-0000000000dd', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2026-02-05 18:00+00', '2026-02-05 19:00+00', 4, '00000000-0000-0000-0000-0000000000e1',
        '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
SELECT pg_temp.flush();
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000dd'), 'P12 inserts still work under the validated constraints');

-- P13 series occurrence uniqueness stays with the legacy index -----------------------------------
SELECT pg_temp.refused($$UPDATE public.games SET start_at = '2026-01-07 18:00+00' WHERE id = '10000000-0000-0000-0000-000000000005'$$,
                       '23505', 'P13 duplicate (series_id, start_at) still refused by games_series_id_start_at_key');

-- P14 events carries KAN-710's five triggers plus KAN-711's one updated_at keeper, sorted after touch --
SELECT pg_temp.ok((SELECT array_agg(tgname::text ORDER BY tgname) FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal)
                  = ARRAY['trg_events_exclusive_check', 'trg_events_search_tsv', 'trg_events_series_start_check',
                          'trg_events_touch', 'trg_events_type_immutable', 'trg_kan711_events_keep_updated_at'],
                  'P14 events triggers are KAN-710''s five (KAN-710:260-271) + trg_kan711_events_keep_updated_at, keeper last');
SELECT pg_temp.ok((SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_kan711\_%') = 5
              AND (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_games_event_link_check', 'trg_meetups_event_link_check',
                     'trg_games_series_occurrence_check') AND tgenabled = 'O') = 3,
                  'P14 5 kan711 triggers; KAN-710''s 3 subtype constraint triggers enabled after every backfill batch');

-- P15 updated_at is the exact legacy value on every mirror/backfill write (KAN-709/02 row 54) ------
-- Inside one transaction now() is constant, so a legacy UPDATE through trg_games_touch and an events
-- UPDATE through trg_events_touch both yield the same now(): a probe that compares them proves
-- nothing about copying. P15a/b therefore pin the legacy updated_at to a distinctive past value
-- (legacy touch disabled inside a savepoint) so only an exact copy can match it.
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0, 'P15 precondition: parity 0 before the updated_at probes');

-- P15a reviewer counterexample 1, verbatim: a subtype-only edit (games.rules) after a full backfill.
-- Pre-fix result (reviewer, SHA b2903455): parent kept 2025-12-03 14:00+04, legacy advanced, parity 0.
SAVEPOINT p15a;
UPDATE public.games SET rules = jsonb_build_object('qa', 'changed retained subtype field') WHERE id = '10000000-0000-0000-0000-000000000002';
SELECT pg_temp.ok((SELECT g.updated_at = e.updated_at AND g.updated_at <> '2025-12-03 10:00+00'
                     FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '10000000-0000-0000-0000-000000000002'),
                  'P15a reviewer repro 1: rules-only edit advances legacy updated_at and the parent carries the same value');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0, 'P15a parity 0 after the rules-only edit');
SELECT pg_temp.ok(coalesce(current_setting('kan711.src_updated_at', true), '') = '', 'P15a hand-off setting is cleared after the mirror write');
ROLLBACK TO SAVEPOINT p15a;
SELECT pg_temp.flush();

-- P15b exact copy: legacy updated_at pinned to a value no clock can produce in this transaction.
SAVEPOINT p15b;
ALTER TABLE public.games DISABLE TRIGGER trg_games_touch;
UPDATE public.games SET rules = jsonb_build_object('qa', 'p15b'), updated_at = '2024-01-02 03:04:05.678901+00'
 WHERE id = '10000000-0000-0000-0000-000000000002';
SELECT pg_temp.ok((SELECT e.updated_at = '2024-01-02 03:04:05.678901+00' FROM public.events e WHERE e.id = '10000000-0000-0000-0000-000000000002'),
                  'P15b parent.updated_at = exact legacy value to the microsecond (not now(), not touched)');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0, 'P15b parity 0 when the timestamps match');
-- P15b CTRL: the same edit with the keeper disabled -> KAN-710 touch wins -> parity and validate_links must see it.
SAVEPOINT p15b_ctrl;
SELECT pg_temp.flush();                                    -- no pending trigger events before ALTER
ALTER TABLE public.events DISABLE TRIGGER trg_kan711_events_keep_updated_at;
UPDATE public.games SET rules = jsonb_build_object('qa', 'p15b ctrl'), updated_at = '2023-05-06 07:08:09.101112+00'
 WHERE id = '10000000-0000-0000-0000-000000000002';
SELECT pg_temp.ok((SELECT e.updated_at = now() FROM public.events e WHERE e.id = '10000000-0000-0000-0000-000000000002'),
                  'P15b CTRL without the keeper the parent gets touch''s now()');
SELECT pg_temp.ok((SELECT array_agg(id::text || ':' || array_to_string(mismatched_fields, ',')) FROM public.kan711_events_parity)
                  = ARRAY['10000000-0000-0000-0000-000000000002:updated_at'],
                  'P15b CTRL parity > 0: exactly one row, mismatched_fields = {updated_at}');
SELECT pg_temp.ok((public.kan711_events_validate_links() ->> 'validated')::boolean = false
              AND (public.kan711_events_validate_links() ->> 'parity_rows')::int = 1,
                  'P15b CTRL validate_links refuses on the updated_at drift (validated:false, parity_rows:1)');
ROLLBACK TO SAVEPOINT p15b_ctrl;
ROLLBACK TO SAVEPOINT p15b;
SELECT pg_temp.flush();

-- P15c forced drift: an events row edited outside the mirror is reported, and validate_links refuses.
SAVEPOINT p15c;
UPDATE public.events SET updated_at = '2020-01-01 00:00+00' WHERE id = '30000000-0000-0000-0000-000000000001';
SELECT pg_temp.ok((SELECT e.updated_at = now() FROM public.events e WHERE e.id = '30000000-0000-0000-0000-000000000001'),
                  'P15c a direct events UPDATE (no KAN-711 hand-off) still gets KAN-710 touch now(): the keeper is inert');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity WHERE 'updated_at' = ANY (mismatched_fields)) = 1,
                  'P15c parity > 0 on a forced updated_at drift');
SELECT pg_temp.ok((public.kan711_events_validate_links() ->> 'validated')::boolean = false, 'P15c validate_links false on the forced drift');
ROLLBACK TO SAVEPOINT p15c;

-- P15d reviewer counterexample 2 (repair): a stale parent whose updated_at has been touched to now()
-- is repaired by a re-backfill and gets the SOURCE updated_at back, not now().
-- (The reviewer's verbatim sequence starts before any backfill and CALLs the COMMIT-ing procedure;
-- it is run as-is by reviewer_repro_kan711.sql on a fresh database. This is the in-transaction form.)
SAVEPOINT p15d;
UPDATE public.events SET title = 'stale parent title' WHERE id = '10000000-0000-0000-0000-000000000001';
SELECT pg_temp.ok((SELECT updated_at = now() FROM public.events WHERE id = '10000000-0000-0000-0000-000000000001')
              AND (SELECT array_agg(f ORDER BY f) FROM public.kan711_events_parity, unnest(mismatched_fields) f
                    WHERE id = '10000000-0000-0000-0000-000000000001') = ARRAY['title', 'updated_at'],
                  'P15d stale parent: parity reports title AND updated_at');
SELECT public.kan711_events_backfill_reset('games');
SELECT count(*) AS p15d_games FROM public.games \gset
-- (the count is taken first: referencing games in the same statement blocks the batch's ALTER TABLE)
SELECT pg_temp.ok(public.kan711_events_backfill_batch('games', 500) = :p15d_games, 'P15d re-backfill of games processes every row');
SELECT pg_temp.ok((SELECT e.title = 'Sunday 5s' AND e.updated_at = '2025-12-02 10:00+00' AND e.updated_at = g.updated_at
                     FROM public.events e JOIN public.games g ON g.id = e.id WHERE e.id = '10000000-0000-0000-0000-000000000001'),
                  'P15d repair restores the title and copies the source updated_at (2025-12-02 10:00+00), not now()');
SELECT pg_temp.ok((SELECT count(*) FROM public.kan711_events_parity) = 0, 'P15d parity 0 after the repair');
ROLLBACK TO SAVEPOINT p15d;
SELECT pg_temp.flush();

-- P15e the hand-off cannot leak: a refused upsert (type mismatch) leaves no setting behind.
DO $p15e$
DECLARE r public.events;
BEGIN
  SELECT (public.kan711_events_map_meetup(m)).* INTO r FROM public.meetups m WHERE m.id = '30000000-0000-0000-0000-000000000001';
  r.id := '10000000-0000-0000-0000-000000000001';          -- a game's id: must be refused
  BEGIN
    PERFORM public.kan711_events_upsert(r);
    RAISE EXCEPTION 'FAIL: P15e mismatched upsert was not refused';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF coalesce(current_setting('kan711.src_updated_at', true), '') <> '' THEN
    RAISE EXCEPTION 'FAIL: P15e kan711.src_updated_at leaked past a refused upsert';
  END IF;
  RAISE NOTICE 'PASS: P15e refused upsert leaves kan711.src_updated_at empty';
END $p15e$;

SELECT 'ALL KAN-711 PROBES PASSED' AS result;
ROLLBACK;
