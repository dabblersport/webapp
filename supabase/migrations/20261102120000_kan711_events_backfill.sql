-- KAN-711 (Events P1) stage 3 of 3: resumable backfill, checkpoint, exception report, parity view,
-- and the conditional link validator.
-- STATUS: authored only, not applied. needs-ops. PEER route (backend-N reviewer).
--
-- THIS MIGRATION DOES NOT RUN THE BACKFILL. It only defines it. Running it writes event_id on every
-- existing games/meetups row, which is a mutation of existing rows of live tables and is reserved to
-- the CEO (019 / CONTRACT.md). The run is a separate, authorised ops step:
--
--     CALL public.kan711_events_backfill_run(500);          -- outside any explicit transaction
--     SELECT * FROM public.kan711_events_parity;            -- expect 0 rows
--     SELECT * FROM public.events_backfill_exceptions WHERE resolved_at IS NULL;  -- expect 0 rows
--     SELECT public.kan711_events_validate_links();         -- validates only if all of the above are 0
--
-- Built on KAN-710 (20261101140000): events, the event_id columns, games/meetups_event_id_fkey
-- (KAN-710:282-285, already VALID) and the deferred link/series/exclusive checks (KAN-710:264-271,
-- 287-295) are KAN-710's. This stage creates no constraint on them except the two NOT NULL checks
-- added by kan711_events_validate_links().
--
-- Order: games first, then meetups; within a table, ascending id. Each batch:
--   1. locks the checkpoint row, then the legacy table in SHARE ROW EXCLUSIVE (blocks concurrent legacy
--      writes; taken first so no lock upgrade can deadlock against a writer),
--   2. selects the next N rows by id FOR UPDATE,
--   3. sets KAN-710's deferred checks for that table IMMEDIATE so each row fails on its own,
--   4. disables, for this transaction only, every enabled non-internal, NON-CONSTRAINT, non-KAN-711
--      trigger that fires on UPDATE, so writing event_id does not bump updated_at, rebuild search_tsv,
--      or touch public_activities / notifications / outbox / msg lines. KAN-710's constraint triggers
--      (trg_*_event_link_check, trg_games_series_occurrence_check) stay ENABLED (tgconstraint <> 0).
--      LOCK: ALTER TABLE ... DISABLE TRIGGER takes SHARE ROW EXCLUSIVE on the legacy table (observed in
--      pg_locks on PostgreSQL 16.15 during a real batch: strongest mode on games = ShareRowExclusiveLock,
--      no AccessExclusiveLock on any relation; see KAN711_CONTRACT.md "Locking"). Step 1 already holds
--      that mode, so the disable adds no stronger lock. It is held until the batch commits: while a batch
--      runs, every INSERT/UPDATE/DELETE of that table (app writes included) waits; plain SELECTs do not.
--      Run small batches (200-500) at a quiet time.
--      The disable is transactional: other sessions never observe the disabled state,
--   5. per row in a subtransaction: upsert events, set event_id = id where NULL; failures go to
--      events_backfill_exceptions and the row is skipped (never half-written),
--   6. restores every trigger to its exact previous mode (O/A/R), restores DEFERRED, advances the
--      checkpoint.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-711: applying role % must be superuser or BYPASSRLS (meetups is FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'games_event_id_fkey' AND conrelid = 'public.games'::regclass) THEN
    RAISE EXCEPTION 'KAN-711: KAN-710 (20261101140000) not applied';
  END IF;
  IF to_regprocedure('public.kan711_events_upsert(public.events)') IS NULL THEN
    RAISE EXCEPTION 'KAN-711: stage 2 (20261102110000) not applied; capture must exist before the backfill';
  END IF;
END $$;

-- 1. Checkpoint and exception report. ---------------------------------------------------------------
CREATE TABLE public.events_backfill_checkpoint (
    kind         text PRIMARY KEY CHECK (kind IN ('games', 'meetups')),
    last_id      uuid,
    rows_done    bigint      NOT NULL DEFAULT 0,
    rows_failed  bigint      NOT NULL DEFAULT 0,
    batches_done integer     NOT NULL DEFAULT 0,
    started_at   timestamptz,
    updated_at   timestamptz,
    finished_at  timestamptz
);
INSERT INTO public.events_backfill_checkpoint (kind) VALUES ('games'), ('meetups');

CREATE TABLE public.events_backfill_exceptions (
    kind          text        NOT NULL CHECK (kind IN ('games', 'meetups')),
    legacy_id     uuid        NOT NULL,
    sqlstate      text        NOT NULL,
    message       text        NOT NULL,
    detail        text,
    attempts      integer     NOT NULL DEFAULT 1,
    first_seen_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at  timestamptz NOT NULL DEFAULT now(),
    resolved_at   timestamptz,
    PRIMARY KEY (kind, legacy_id)
);

ALTER TABLE public.events_backfill_checkpoint ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events_backfill_exceptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.events_backfill_checkpoint, public.events_backfill_exceptions
  FROM PUBLIC, anon, authenticated, service_role;

-- 2. Parity: one row per legacy/events id that is missing, orphaned, unlinked or differs in any field.
-- Comparison is IS DISTINCT FROM per field (NULL = NULL is parity). Zero rows means full parity.
-- 23 fields: every mapped column except search_tsv (derived by KAN-710:128-137, not copied).
-- updated_at IS compared (KAN-709/02 row 54: the parent carries the exact legacy value). The mirror
-- and the backfill keep it exact through kan711_events_upsert + trg_kan711_events_keep_updated_at
-- (20261102110000 section 2a), so any difference here is a real drift: an events row edited outside
-- the mirror, or a mirror that failed to propagate a subtype-only legacy edit.
CREATE VIEW public.kan711_events_parity WITH (security_invoker = true) AS
WITH src AS (
  SELECT 'games'::text AS kind, g.id, g.event_id, public.kan711_events_map_game(g) AS m FROM public.games g
  UNION ALL
  SELECT 'meetups'::text, mt.id, mt.event_id, public.kan711_events_map_meetup(mt) FROM public.meetups mt
), cmp AS (
  SELECT coalesce(s.kind, 'events') AS kind,
         coalesce(s.id, e.id)       AS id,
         (e.id IS NULL)             AS missing_event,
         (s.id IS NULL)             AS orphan_event,
         (s.id IS NOT NULL AND s.event_id IS DISTINCT FROM s.id) AS unlinked,
         CASE WHEN s.id IS NULL OR e.id IS NULL THEN '{}'::text[] ELSE array_remove(ARRAY[
           CASE WHEN (s.m).event_type         IS DISTINCT FROM e.event_type         THEN 'event_type' END,
           CASE WHEN (s.m).title              IS DISTINCT FROM e.title              THEN 'title' END,
           CASE WHEN (s.m).creator_profile_id IS DISTINCT FROM e.creator_profile_id THEN 'creator_profile_id' END,
           CASE WHEN (s.m).creator_user_id    IS DISTINCT FROM e.creator_user_id    THEN 'creator_user_id' END,
           CASE WHEN (s.m).sport_id           IS DISTINCT FROM e.sport_id           THEN 'sport_id' END,
           CASE WHEN (s.m).start_at           IS DISTINCT FROM e.start_at           THEN 'start_at' END,
           CASE WHEN (s.m).end_at             IS DISTINCT FROM e.end_at             THEN 'end_at' END,
           CASE WHEN (s.m).capacity           IS DISTINCT FROM e.capacity           THEN 'capacity' END,
           CASE WHEN (s.m).venue_id           IS DISTINCT FROM e.venue_id           THEN 'venue_id' END,
           CASE WHEN (s.m).geo_location_id    IS DISTINCT FROM e.geo_location_id    THEN 'geo_location_id' END,
           CASE WHEN (s.m).area_id            IS DISTINCT FROM e.area_id            THEN 'area_id' END,
           CASE WHEN (s.m).listing_visibility IS DISTINCT FROM e.listing_visibility THEN 'listing_visibility' END,
           CASE WHEN (s.m).join_policy        IS DISTINCT FROM e.join_policy        THEN 'join_policy' END,
           CASE WHEN (s.m).min_skill          IS DISTINCT FROM e.min_skill          THEN 'min_skill' END,
           CASE WHEN (s.m).max_skill          IS DISTINCT FROM e.max_skill          THEN 'max_skill' END,
           CASE WHEN (s.m).joining_rule       IS DISTINCT FROM e.joining_rule       THEN 'joining_rule' END,
           CASE WHEN (s.m).cost_cover         IS DISTINCT FROM e.cost_cover         THEN 'cost_cover' END,
           CASE WHEN (s.m).is_cancelled       IS DISTINCT FROM e.is_cancelled       THEN 'is_cancelled' END,
           CASE WHEN (s.m).cancelled_at       IS DISTINCT FROM e.cancelled_at       THEN 'cancelled_at' END,
           CASE WHEN (s.m).cancelled_reason   IS DISTINCT FROM e.cancelled_reason   THEN 'cancelled_reason' END,
           CASE WHEN (s.m).request_id         IS DISTINCT FROM e.request_id         THEN 'request_id' END,
           CASE WHEN (s.m).created_at         IS DISTINCT FROM e.created_at         THEN 'created_at' END,
           CASE WHEN (s.m).updated_at         IS DISTINCT FROM e.updated_at         THEN 'updated_at' END
         ], NULL) END AS mismatched_fields
  FROM src s
  FULL JOIN public.events e ON e.id = s.id
)
SELECT kind, id, missing_event, orphan_event, unlinked, mismatched_fields
FROM cmp
WHERE missing_event OR orphan_event OR unlinked OR cardinality(mismatched_fields) > 0;

REVOKE ALL ON TABLE public.kan711_events_parity FROM PUBLIC, anon, authenticated, service_role;

-- 3. One batch. ------------------------------------------------------------------------------------
CREATE FUNCTION public.kan711_events_backfill_batch(p_kind text, p_batch_size integer DEFAULT 500)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_cp      public.events_backfill_checkpoint;
  v_tbl     regclass;
  v_cons    text;
  v_ids     uuid[];
  v_id      uuid;
  v_names   text[] := '{}';
  v_modes   text[] := '{}';
  v_trg     record;
  v_ok      integer := 0;
  v_bad     integer := 0;
  v_state   text;
  v_msg     text;
  v_detail  text;
BEGIN
  IF p_kind NOT IN ('games', 'meetups') OR p_batch_size IS NULL OR p_batch_size < 1 OR p_batch_size > 10000 THEN
    RAISE EXCEPTION 'kan711_backfill: bad arguments (%, %)', p_kind, p_batch_size;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'kan711_backfill: % cannot see every meetup (FORCE RLS); run as owner with BYPASSRLS', current_user;
  END IF;

  SELECT * INTO v_cp FROM public.events_backfill_checkpoint WHERE kind = p_kind FOR UPDATE;
  IF v_cp.finished_at IS NOT NULL THEN
    RETURN 0;
  END IF;

  v_tbl  := pg_catalog.to_regclass('public.' || p_kind);
  -- KAN-710's deferred checks that a batch on this table can queue (KAN-710:264-271, 282-295).
  v_cons := CASE p_kind
    WHEN 'games'   THEN 'public.games_event_id_fkey, public.trg_games_event_link_check, '
                     || 'public.trg_games_series_occurrence_check, public.trg_events_exclusive_check, '
                     || 'public.trg_events_series_start_check'
    ELSE                'public.meetups_event_id_fkey, public.trg_meetups_event_link_check, '
                     || 'public.trg_events_exclusive_check, public.trg_events_series_start_check'
  END;

  -- Fire anything already pending on our checks now (ALTER TABLE refuses while events are pending).
  EXECUTE format('SET CONSTRAINTS %s IMMEDIATE', v_cons);
  EXECUTE format('LOCK TABLE %s IN SHARE ROW EXCLUSIVE MODE', v_tbl);
  EXECUTE format('SELECT array_agg(id ORDER BY id) FROM (SELECT id FROM %s WHERE ($1 IS NULL OR id > $1) ORDER BY id LIMIT $2 FOR UPDATE) s', v_tbl)
     INTO v_ids USING v_cp.last_id, p_batch_size;

  IF v_ids IS NULL THEN
    UPDATE public.events_backfill_checkpoint
       SET finished_at = now(), updated_at = now(), started_at = coalesce(started_at, now())
     WHERE kind = p_kind;
    EXECUTE format('SET CONSTRAINTS %s DEFERRED', v_cons);
    RETURN 0;
  END IF;

  FOR v_trg IN
    SELECT t.tgname, t.tgenabled::text AS mode
      FROM pg_catalog.pg_trigger t
     WHERE t.tgrelid = v_tbl AND NOT t.tgisinternal AND t.tgenabled <> 'D'
       AND t.tgconstraint = 0                            -- KAN-710's constraint triggers stay enabled
       AND t.tgname NOT LIKE 'trg\_kan711\_%'
       AND (t.tgtype::integer & 16) <> 0                 -- TRIGGER_TYPE_UPDATE
     ORDER BY t.tgname
  LOOP
    v_names := v_names || v_trg.tgname::text;
    v_modes := v_modes || v_trg.mode;
    EXECUTE format('ALTER TABLE %s DISABLE TRIGGER %I', v_tbl, v_trg.tgname);
  END LOOP;

  FOREACH v_id IN ARRAY v_ids LOOP
    BEGIN
      IF p_kind = 'games' THEN
        PERFORM public.kan711_events_upsert(public.kan711_events_map_game(g)) FROM public.games g WHERE g.id = v_id;
        UPDATE public.games SET event_id = id WHERE id = v_id AND event_id IS NULL;
      ELSE
        PERFORM public.kan711_events_upsert(public.kan711_events_map_meetup(m)) FROM public.meetups m WHERE m.id = v_id;
        UPDATE public.meetups SET event_id = id WHERE id = v_id AND event_id IS NULL;
      END IF;
      UPDATE public.events_backfill_exceptions SET resolved_at = now()
       WHERE kind = p_kind AND legacy_id = v_id AND resolved_at IS NULL;
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT, v_detail = PG_EXCEPTION_DETAIL;
      INSERT INTO public.events_backfill_exceptions AS x (kind, legacy_id, sqlstate, message, detail)
      VALUES (p_kind, v_id, v_state, v_msg, nullif(v_detail, ''))
      ON CONFLICT (kind, legacy_id) DO UPDATE
         SET attempts = x.attempts + 1, sqlstate = EXCLUDED.sqlstate, message = EXCLUDED.message,
             detail = EXCLUDED.detail, last_seen_at = now(), resolved_at = NULL;
      v_bad := v_bad + 1;
    END;
  END LOOP;

  FOR i IN 1 .. coalesce(array_length(v_names, 1), 0) LOOP
    EXECUTE format('ALTER TABLE %s %s TRIGGER %I', v_tbl,
                   CASE v_modes[i] WHEN 'O' THEN 'ENABLE' WHEN 'A' THEN 'ENABLE ALWAYS' WHEN 'R' THEN 'ENABLE REPLICA' END,
                   v_names[i]);
  END LOOP;
  EXECUTE format('SET CONSTRAINTS %s DEFERRED', v_cons);

  UPDATE public.events_backfill_checkpoint
     SET last_id = v_ids[array_length(v_ids, 1)],
         rows_done = rows_done + v_ok, rows_failed = rows_failed + v_bad,
         batches_done = batches_done + 1,
         started_at = coalesce(started_at, now()), updated_at = now()
   WHERE kind = p_kind;

  RETURN array_length(v_ids, 1);
END $$;

-- 4. Driver: COMMIT per batch so an interruption loses at most one batch and resumes from last_id.
-- A procedure that COMMITs may not be SECURITY DEFINER or carry SET search_path (PostgreSQL rule), so
-- it is SECURITY INVOKER, schema-qualifies every reference, and is executable by its owner only.
CREATE PROCEDURE public.kan711_events_backfill_run(p_batch_size integer DEFAULT 500, p_max_batches integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
  v_kind    text;
  v_n       integer;
  v_batches integer := 0;
BEGIN
  FOREACH v_kind IN ARRAY ARRAY['games', 'meetups'] LOOP
    LOOP
      v_n := public.kan711_events_backfill_batch(v_kind, p_batch_size);
      COMMIT;
      v_batches := v_batches + 1;
      RAISE NOTICE 'kan711 backfill % batch %: % rows', v_kind, v_batches, v_n;
      EXIT WHEN v_n = 0;
      IF p_max_batches IS NOT NULL AND v_batches >= p_max_batches THEN
        RAISE NOTICE 'kan711 backfill stopped at p_max_batches=%; re-CALL to resume', p_max_batches;
        RETURN;
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- 5. Re-open a kind for a fresh pass (re-run after fixing exceptions). Idempotent: rows already in
-- parity are skipped by the upsert's IS DISTINCT FROM guard.
CREATE FUNCTION public.kan711_events_backfill_reset(p_kind text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.events_backfill_checkpoint
     SET last_id = NULL, finished_at = NULL, updated_at = now()
   WHERE kind = p_kind;
  IF NOT FOUND THEN RAISE EXCEPTION 'kan711_backfill_reset: unknown kind %', p_kind; END IF;
END $$;

-- 6. Add and validate the NOT NULL checks ONLY on verified parity with no exceptions; otherwise leave
-- them absent and report. KAN-710's FKs are created VALID (KAN-710:282-285); this function does not
-- touch them, it only reports their convalidated state.
CREATE FUNCTION public.kan711_events_validate_links()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_parity     bigint;
  v_exceptions bigint;
  v_unfinished bigint;
  v_fk         jsonb;
BEGIN
  SELECT jsonb_object_agg(conname, convalidated) INTO v_fk FROM pg_catalog.pg_constraint
   WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey')
     AND conrelid IN ('public.games'::regclass, 'public.meetups'::regclass);
  SELECT count(*) INTO v_parity     FROM public.kan711_events_parity;
  SELECT count(*) INTO v_exceptions FROM public.events_backfill_exceptions WHERE resolved_at IS NULL;
  SELECT count(*) INTO v_unfinished FROM public.events_backfill_checkpoint WHERE finished_at IS NULL;

  IF v_parity > 0 OR v_exceptions > 0 OR v_unfinished > 0 THEN
    RETURN jsonb_build_object('validated', false, 'parity_rows', v_parity,
      'unresolved_exceptions', v_exceptions, 'unfinished_kinds', v_unfinished, 'fk_valid', v_fk,
      'note', 'NOT NULL checks not added; resolve the report and re-run');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'games_event_id_not_null'
                  AND conrelid = 'public.games'::regclass) THEN
    ALTER TABLE public.games ADD CONSTRAINT games_event_id_not_null CHECK (event_id IS NOT NULL) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'meetups_event_id_not_null'
                  AND conrelid = 'public.meetups'::regclass) THEN
    ALTER TABLE public.meetups ADD CONSTRAINT meetups_event_id_not_null CHECK (event_id IS NOT NULL) NOT VALID;
  END IF;
  ALTER TABLE public.games   VALIDATE CONSTRAINT games_event_id_not_null;
  ALTER TABLE public.meetups VALIDATE CONSTRAINT meetups_event_id_not_null;

  RETURN jsonb_build_object('validated', true, 'parity_rows', 0, 'unresolved_exceptions', 0,
    'unfinished_kinds', 0, 'fk_valid', v_fk,
    'not_null_valid', (SELECT jsonb_object_agg(conname, convalidated) FROM pg_catalog.pg_constraint
                        WHERE conname IN ('games_event_id_not_null', 'meetups_event_id_not_null')));
END $$;

REVOKE ALL ON FUNCTION public.kan711_events_backfill_batch(text, integer)        FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON PROCEDURE public.kan711_events_backfill_run(integer, integer)      FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_backfill_reset(text)                 FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_validate_links()                     FROM PUBLIC, anon, authenticated, service_role;

-- 7. Post-conditions. ------------------------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS f FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%' LOOP
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE')
       OR has_function_privilege('service_role', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-711 post: % is executable by an API role', r.f;
    END IF;
  END LOOP;
  -- Every function except the COMMIT-ing procedure pins search_path (see note at section 4).
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%'
              AND p.prokind = 'f' AND NOT ('search_path=""' = ANY (coalesce(p.proconfig, '{}')))) THEN
    RAISE EXCEPTION 'KAN-711 post: a kan711 function lacks a pinned empty search_path';
  END IF;
  FOR r IN SELECT unnest(ARRAY['public.events_backfill_checkpoint', 'public.events_backfill_exceptions',
                               'public.kan711_events_parity']) AS t LOOP
    IF has_table_privilege('anon', r.t, 'SELECT,INSERT,UPDATE,DELETE')
       OR has_table_privilege('authenticated', r.t, 'SELECT,INSERT,UPDATE,DELETE')
       OR has_table_privilege('service_role', r.t, 'SELECT,INSERT,UPDATE,DELETE') THEN
      RAISE EXCEPTION 'KAN-711 post: an API role holds a privilege on %', r.t;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.events_backfill_checkpoint WHERE last_id IS NULL AND finished_at IS NULL) <> 2 THEN
    RAISE EXCEPTION 'KAN-711 post: checkpoint not initialised';
  END IF;
END $$;

COMMIT;
