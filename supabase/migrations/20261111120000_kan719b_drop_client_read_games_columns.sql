-- KAN-866 (F11, KAN-719b; Epic KAN-708, Events P4): drop the 22 legacy public.games shared columns that
-- KAN718_D03_OLD_CLIENT_MATRIX.md s1 lists as client-read and that CTO ruling dreq-8ae9bcfa rule 1 (C) kept
-- (KAN718_HANDOFF.md (h); re-scoped into the retained list by F8 / KAN-861, kan718_d06_manifest_check.sql
-- k774_retained why = 'd03'). Their values live on public.events (KAN-710/711), reached through games.event_id.
--
-- AUTHORISATION. CEO written authorisation msg-20261111075244-c8f3f719, 2026-11-11: "I approve for the KAN-866
-- DROP". Recorded by PO in KAN-866 comment 15963: https://dabbler.atlassian.net/browse/KAN-866
-- It stands for the dreq-8ae9bcfa install-share gate and for the destructive step.
--
-- AUTHORED ONLY (needs-ops). Nothing here was applied by the authoring ticket. Memphis applies it (D-043) when it
-- integrates the commit into staging. Local proof: supabase/tests/events_p4/kan866_drop_client_read_games_columns_test.sh
--
-- THE SET (exactly 22, games only; no meetups column, no other games column):
--   creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility, join_policy,
--   is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id, venue_id, min_skill,
--   max_skill, joining_rule, cost_cover, request_id, created_at, updated_at
-- Kept: id, event_id and every other games column. No CASCADE anywhere; DROP COLUMN ... RESTRICT.
--
-- FAIL-CLOSED GATE (block 1). Every unmet precondition is collected and raised once, all listed:
--   P1 every target column exists on public.games with the exact type, NOT NULL flag and default recorded below
--      (the rollback re-creates them from these, so a mismatch means the rollback would be wrong);
--   P2 the caller bypasses RLS (public.games has RLS on; otherwise the backup and the counts are partial);
--   P3 nothing in pg_depend references a target column, apart from that column's own default: no view or rule,
--      policy, trigger column list or WHEN, index, constraint (check, FK, unique, either direction), SQL-standard
--      function body, generated column, statistics object or publication column list;
--   P4 no function body outside pg_catalog / information_schema / extensions names a target column as a whole
--      word AND either names `games` or is the function of a trigger on public.games (plpgsql bodies are not in
--      pg_depend: the KAN-711/712 mirror and guard, games triggers such as a generic NEW.updated_at toucher, and
--      the write RPCs read these columns at run time and would fail on the first games write). Text match, so it can over-report; a false positive is
--      fixed by rewriting that function or by a reviewed change to this gate, never by skipping it;
--   P5 public.games_kan866_dropped_cols_backup does not exist yet.
-- Then block 2 backs the data up (id + the 22 columns), checks the backup row count equals games, and prints one
-- pre-DROP non-null count per column (RAISE NOTICE). Block 3 drops. Block 4 re-checks: none of the 22 left, id
-- and event_id still there, backup count still equals games.
--
-- BACKUP TABLE. public.games_kan866_dropped_cols_backup: RLS on with no policy, and every privilege revoked from
-- PUBLIC, anon and authenticated (T-020: it holds every game's creator and schedule). Service role / postgres only.
-- It is kept after the drop; removing it is a separate, later decision.
--
-- RUN: one transaction (Supabase CLI does this; with psql use --single-transaction). Any failure rolls all back.
-- IDEMPOTENT: no. A second run refuses at P1 (columns gone) and P5 (backup exists). That is the intended answer.
--
-- ROLLBACK (after COMMIT). Run the block between the markers below, uncommented, in one transaction, as a role
-- that bypasses RLS. It re-adds each column with its original type and default, restores every value from the
-- backup by id, then re-applies NOT NULL where the column had it. It does not re-create constraints, indexes,
-- triggers or views: P3/P4 proved none referenced these columns when the drop ran. The test runs this exact block.
-- KAN866-ROLLBACK-BEGIN
-- ALTER TABLE public.games
--   ADD COLUMN title text,
--   ADD COLUMN creator_profile_id uuid,
--   ADD COLUMN creator_user_id uuid,
--   ADD COLUMN start_at timestamp with time zone,
--   ADD COLUMN end_at timestamp with time zone,
--   ADD COLUMN capacity integer,
--   ADD COLUMN listing_visibility text DEFAULT 'public'::text,
--   ADD COLUMN join_policy text DEFAULT 'open'::text,
--   ADD COLUMN min_skill integer,
--   ADD COLUMN max_skill integer,
--   ADD COLUMN is_cancelled boolean DEFAULT false,
--   ADD COLUMN cancelled_at timestamp with time zone,
--   ADD COLUMN cancelled_reason text,
--   ADD COLUMN created_at timestamp with time zone DEFAULT now(),
--   ADD COLUMN updated_at timestamp with time zone DEFAULT now(),
--   ADD COLUMN sport_id uuid,
--   ADD COLUMN geo_location_id uuid,
--   ADD COLUMN area_id uuid,
--   ADD COLUMN venue_id uuid,
--   ADD COLUMN joining_rule text DEFAULT 'free'::text,
--   ADD COLUMN cost_cover text DEFAULT 'free'::text,
--   ADD COLUMN request_id uuid;
-- DO $rt$ BEGIN
--   IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND NOT tgisinternal AND tgenabled = 'D') THEN
--     RAISE EXCEPTION 'KAN-866 rollback: a games trigger is already disabled; re-enabling all would change it. Stop and decide';
--   END IF;
-- END $rt$;
-- ALTER TABLE public.games DISABLE TRIGGER USER;  -- the restore must not fire touch/mirror triggers on the old values
-- UPDATE public.games g SET
--   title = b.title, creator_profile_id = b.creator_profile_id, creator_user_id = b.creator_user_id,
--   start_at = b.start_at, end_at = b.end_at, capacity = b.capacity, listing_visibility = b.listing_visibility,
--   join_policy = b.join_policy, min_skill = b.min_skill, max_skill = b.max_skill, is_cancelled = b.is_cancelled,
--   cancelled_at = b.cancelled_at, cancelled_reason = b.cancelled_reason, created_at = b.created_at,
--   updated_at = b.updated_at, sport_id = b.sport_id, geo_location_id = b.geo_location_id, area_id = b.area_id,
--   venue_id = b.venue_id, joining_rule = b.joining_rule, cost_cover = b.cost_cover, request_id = b.request_id
--   FROM public.games_kan866_dropped_cols_backup b WHERE b.id = g.id;
-- ALTER TABLE public.games ENABLE TRIGGER USER;
-- DO $rb$ BEGIN
--   IF EXISTS (SELECT 1 FROM public.games g WHERE NOT EXISTS
--                (SELECT 1 FROM public.games_kan866_dropped_cols_backup b WHERE b.id = g.id)) THEN
--     RAISE EXCEPTION 'KAN-866 rollback: a games row has no backup row (created after the drop); fill it from public.events first';
--   END IF;
-- END $rb$;
-- ALTER TABLE public.games
--   ALTER COLUMN creator_profile_id SET NOT NULL, ALTER COLUMN creator_user_id SET NOT NULL,
--   ALTER COLUMN start_at SET NOT NULL, ALTER COLUMN end_at SET NOT NULL, ALTER COLUMN capacity SET NOT NULL,
--   ALTER COLUMN listing_visibility SET NOT NULL, ALTER COLUMN join_policy SET NOT NULL,
--   ALTER COLUMN is_cancelled SET NOT NULL, ALTER COLUMN created_at SET NOT NULL, ALTER COLUMN updated_at SET NOT NULL,
--   ALTER COLUMN sport_id SET NOT NULL, ALTER COLUMN geo_location_id SET NOT NULL, ALTER COLUMN area_id SET NOT NULL,
--   ALTER COLUMN joining_rule SET NOT NULL, ALTER COLUMN cost_cover SET NOT NULL;
-- KAN866-ROLLBACK-END

-- Block 1: fail-closed gate.
DO $gate$
DECLARE
  fails text[] := '{}';
  x text;
BEGIN
  -- P1. Expected shape: name, format_type, NOT NULL, default (pg_get_expr), from the repo baseline
  -- (20260829080500 public.games) plus request_id; identical on the local tracked chain.
  WITH want(col, typ, nn, def) AS (VALUES
      ('title',              'text',                     false, NULL),
      ('creator_profile_id', 'uuid',                     true,  NULL),
      ('creator_user_id',    'uuid',                     true,  NULL),
      ('start_at',           'timestamp with time zone', true,  NULL),
      ('end_at',             'timestamp with time zone', true,  NULL),
      ('capacity',           'integer',                  true,  NULL),
      ('listing_visibility', 'text',                     true,  '''public''::text'),
      ('join_policy',        'text',                     true,  '''open''::text'),
      ('min_skill',          'integer',                  false, NULL),
      ('max_skill',          'integer',                  false, NULL),
      ('is_cancelled',       'boolean',                  true,  'false'),
      ('cancelled_at',       'timestamp with time zone', false, NULL),
      ('cancelled_reason',   'text',                     false, NULL),
      ('created_at',         'timestamp with time zone', true,  'now()'),
      ('updated_at',         'timestamp with time zone', true,  'now()'),
      ('sport_id',           'uuid',                     true,  NULL),
      ('geo_location_id',    'uuid',                     true,  NULL),
      ('area_id',            'uuid',                     true,  NULL),
      ('venue_id',           'uuid',                     false, NULL),
      ('joining_rule',       'text',                     true,  '''free''::text'),
      ('cost_cover',         'text',                     true,  '''free''::text'),
      ('request_id',         'uuid',                     false, NULL))
  SELECT string_agg(w.col || CASE WHEN a.attnum IS NULL THEN ' (missing)'
                                  ELSE format(' (is %s nn=%s default=%s)', format_type(a.atttypid, a.atttypmod),
                                              a.attnotnull, coalesce(pg_get_expr(ad.adbin, ad.adrelid), 'none')) END,
                    ', ' ORDER BY w.col) INTO x
    FROM want w
    LEFT JOIN pg_attribute a ON a.attrelid = 'public.games'::regclass AND a.attname = w.col
                            AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
   WHERE a.attnum IS NULL
      OR format_type(a.atttypid, a.atttypmod) <> w.typ
      OR a.attnotnull <> w.nn
      OR pg_get_expr(ad.adbin, ad.adrelid) IS DISTINCT FROM w.def
      OR a.attgenerated <> '' OR a.attidentity <> '';
  IF x IS NOT NULL THEN fails := fails || ('P1 target column missing or not the recorded shape: ' || x); END IF;

  -- P2.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    fails := fails || format('P2 role %s does not bypass RLS (backup and counts would be partial)', current_user);
  END IF;

  -- P3. Every pg_depend row that points at a target column, except the column's own default.
  SELECT string_agg(DISTINCT format('%s -> games.%s', pg_describe_object(d.classid, d.objid, d.objsubid), a.attname), '; ') INTO x
    FROM pg_depend d
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE d.refclassid = 'pg_class'::regclass AND d.refobjid = 'public.games'::regclass
     AND a.attname IN ('creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
                       'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id',
                       'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id','created_at','updated_at')
     AND NOT (d.classid = 'pg_attrdef'::regclass
              AND EXISTS (SELECT 1 FROM pg_attrdef ad WHERE ad.oid = d.objid AND ad.adrelid = a.attrelid AND ad.adnum = a.attnum));
  IF x IS NOT NULL THEN fails := fails || ('P3 objects still depend on a target column: ' || x); END IF;

  SELECT string_agg(format('publication %s lists games(%s)', pt.pubname, array_to_string(pt.attnames, ',')), '; ') INTO x
    FROM pg_publication_tables pt
   WHERE pt.schemaname = 'public' AND pt.tablename = 'games'
     AND pt.attnames && ARRAY['creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
                              'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id',
                              'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id','created_at','updated_at']::name[]
     AND EXISTS (SELECT 1 FROM pg_publication_rel pr JOIN pg_publication p ON p.oid = pr.prpubid
                  WHERE p.pubname = pt.pubname AND pr.prrelid = 'public.games'::regclass AND pr.prattrs IS NOT NULL);
  IF x IS NOT NULL THEN fails := fails || ('P3 publication column list names a target column: ' || x); END IF;

  -- P4. Function bodies that name games and a target column.
  SELECT string_agg(p.oid::regprocedure::text, '; ' ORDER BY p.oid::regprocedure::text) INTO x
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
     AND NOT EXISTS (SELECT 1 FROM pg_depend e WHERE e.classid = 'pg_proc'::regclass AND e.objid = p.oid AND e.deptype = 'e')
     AND (p.prosrc ~* '\mgames\M'
          OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.games'::regclass AND t.tgfoid = p.oid))
     AND p.prosrc ~* '\m(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M';
  IF x IS NOT NULL THEN fails := fails || ('P4 function bodies name games and a target column: ' || x); END IF;

  -- P5.
  IF to_regclass('public.games_kan866_dropped_cols_backup') IS NOT NULL THEN
    fails := fails || 'P5 public.games_kan866_dropped_cols_backup already exists (second run, or a stale backup)'::text;
  END IF;

  IF cardinality(fails) > 0 THEN
    RAISE EXCEPTION 'KAN-866 gate refused; nothing was changed. % unmet precondition(s): %', cardinality(fails), array_to_string(fails, ' | ');
  END IF;
  RAISE NOTICE 'KAN-866 gate PASS: P1-P5 hold for the 22 columns';
END
$gate$;

-- Block 2: backup and pre-DROP counts.
CREATE TABLE public.games_kan866_dropped_cols_backup AS
  SELECT id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
         min_skill, max_skill, is_cancelled, cancelled_at, cancelled_reason, created_at, updated_at, sport_id,
         geo_location_id, area_id, venue_id, joining_rule, cost_cover, request_id
    FROM public.games;
ALTER TABLE public.games_kan866_dropped_cols_backup ADD PRIMARY KEY (id);
ALTER TABLE public.games_kan866_dropped_cols_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.games_kan866_dropped_cols_backup FROM PUBLIC;
DO $r$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON TABLE public.games_kan866_dropped_cols_backup FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON TABLE public.games_kan866_dropped_cols_backup FROM authenticated;
  END IF;
END $r$;
COMMENT ON TABLE public.games_kan866_dropped_cols_backup IS
  'KAN-866 (KAN-719b): id + the 22 games columns dropped by 20261111120000, taken in the same transaction. Rollback source. Not client-readable.';

DO $counts$
DECLARE
  n_games bigint;
  n_backup bigint;
  r record;
BEGIN
  SELECT count(*) INTO n_games FROM public.games;
  SELECT count(*) INTO n_backup FROM public.games_kan866_dropped_cols_backup;
  IF n_backup <> n_games THEN
    RAISE EXCEPTION 'KAN-866 backup FAIL: % backup rows, % games rows', n_backup, n_games;
  END IF;
  RAISE NOTICE 'KAN-866 pre-DROP: public.games rows = %, backup rows = %', n_games, n_backup;
  FOR r IN
    SELECT 'title' c, count(title) n FROM public.games UNION ALL
    SELECT 'creator_profile_id', count(creator_profile_id) FROM public.games UNION ALL
    SELECT 'creator_user_id', count(creator_user_id) FROM public.games UNION ALL
    SELECT 'start_at', count(start_at) FROM public.games UNION ALL
    SELECT 'end_at', count(end_at) FROM public.games UNION ALL
    SELECT 'capacity', count(capacity) FROM public.games UNION ALL
    SELECT 'listing_visibility', count(listing_visibility) FROM public.games UNION ALL
    SELECT 'join_policy', count(join_policy) FROM public.games UNION ALL
    SELECT 'min_skill', count(min_skill) FROM public.games UNION ALL
    SELECT 'max_skill', count(max_skill) FROM public.games UNION ALL
    SELECT 'is_cancelled', count(is_cancelled) FROM public.games UNION ALL
    SELECT 'cancelled_at', count(cancelled_at) FROM public.games UNION ALL
    SELECT 'cancelled_reason', count(cancelled_reason) FROM public.games UNION ALL
    SELECT 'created_at', count(created_at) FROM public.games UNION ALL
    SELECT 'updated_at', count(updated_at) FROM public.games UNION ALL
    SELECT 'sport_id', count(sport_id) FROM public.games UNION ALL
    SELECT 'geo_location_id', count(geo_location_id) FROM public.games UNION ALL
    SELECT 'area_id', count(area_id) FROM public.games UNION ALL
    SELECT 'venue_id', count(venue_id) FROM public.games UNION ALL
    SELECT 'joining_rule', count(joining_rule) FROM public.games UNION ALL
    SELECT 'cost_cover', count(cost_cover) FROM public.games UNION ALL
    SELECT 'request_id', count(request_id) FROM public.games
  LOOP
    RAISE NOTICE 'KAN-866 pre-DROP non-null games.% = %', r.c, r.n;
  END LOOP;
END
$counts$;

-- Block 3: the drop. RESTRICT (the default) written out; no CASCADE.
ALTER TABLE public.games
  DROP COLUMN title RESTRICT,
  DROP COLUMN creator_profile_id RESTRICT,
  DROP COLUMN creator_user_id RESTRICT,
  DROP COLUMN start_at RESTRICT,
  DROP COLUMN end_at RESTRICT,
  DROP COLUMN capacity RESTRICT,
  DROP COLUMN listing_visibility RESTRICT,
  DROP COLUMN join_policy RESTRICT,
  DROP COLUMN min_skill RESTRICT,
  DROP COLUMN max_skill RESTRICT,
  DROP COLUMN is_cancelled RESTRICT,
  DROP COLUMN cancelled_at RESTRICT,
  DROP COLUMN cancelled_reason RESTRICT,
  DROP COLUMN created_at RESTRICT,
  DROP COLUMN updated_at RESTRICT,
  DROP COLUMN sport_id RESTRICT,
  DROP COLUMN geo_location_id RESTRICT,
  DROP COLUMN area_id RESTRICT,
  DROP COLUMN venue_id RESTRICT,
  DROP COLUMN joining_rule RESTRICT,
  DROP COLUMN cost_cover RESTRICT,
  DROP COLUMN request_id RESTRICT;

-- Block 4: post-check.
DO $post$
DECLARE
  x text;
BEGIN
  SELECT string_agg(a.attname, ', ') INTO x
    FROM pg_attribute a
   WHERE a.attrelid = 'public.games'::regclass AND a.attnum > 0 AND NOT a.attisdropped
     AND a.attname IN ('creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
                       'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id',
                       'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id','created_at','updated_at');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-866 post-check FAIL: still present: %', x; END IF;
  IF (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname IN ('id', 'event_id')
         AND NOT attisdropped) <> 2 THEN
    RAISE EXCEPTION 'KAN-866 post-check FAIL: games.id or games.event_id is gone';
  END IF;
  IF (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM public.games_kan866_dropped_cols_backup) THEN
    RAISE EXCEPTION 'KAN-866 post-check FAIL: games and backup row counts differ';
  END IF;
  RAISE NOTICE 'KAN-866 post-check PASS: the 22 columns are absent; id, event_id and the backup are intact';
END
$post$;
