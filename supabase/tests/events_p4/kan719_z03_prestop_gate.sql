-- KAN-780 (KAN-719 Z03, Epic KAN-708), re-pinned by KAN-862 (serial finish, 2026-11-13) to the regenerated Z01:
--   supabase/migrations/20261113202013_kan862_z01_remove_replaced_columns.sql
--   manifest md5 254f6202893607899592380ee724a79b (64 statements; md5 of the statements joined by newline, seq order).
-- The pre-KAN-862 version (47 slated columns, D06 manifest 614c1f8d29cd017126bca92588e96d9f, for the superseded
-- 20261105100000 file) is in git history.
--
-- Immediate pre-application dependency re-scan gate for the phase-4 removal.
-- READ-ONLY. It writes nothing and is safe on production. It is NOT a migration. Run it immediately before the
-- Z01 apply (on hosted Supabase: execute_sql inside BEGIN READ ONLY ... ROLLBACK, then apply_migration of the file).
-- Z01 itself re-runs the same S1 (as its G6) and S2/S3 (as its G7) inside the apply transaction, so a dependency
-- created between this scan and the apply still stops it.
--
-- What it re-scans, for the 22 slated columns (games.search_tsv; meetups: every column except id, event_id, vibe_key,
-- meta, host_actor_id, members_only, description, location_name, is_indoor):
--   S1  every object with a column-level pg_depend on a slated column (view, policy on any table, index, constraint,
--       trigger, publication, extended statistics, anything else)
--   S2  every non-internal trigger on games/meetups whose function reads a slated NEW./OLD. column
--   S3  every public function body that reads a slated column of public.games/public.meetups (the KAN-862 P2 lexical
--       scanner, PEER-reviewed in KAN-862 comments 16226/16229: alias.col, unqualified select/where, update set, insert
--       column list). Function bodies carry no pg_depend, so this is the only way they are seen
--   S4  pg_cron jobs whose command names games/meetups and a slated column
-- Each dependency found is one of:
--   REMOVED   the Z01 manifest drops or rewrites it (embedded below)
--   KNOWN     reviewed, harmless after Z01: column defaults (they go with their column); the dead kan711 tooling
--   NEW       anything else = STOP: the gate raises and the apply must not run. Clearing it needs a review and a new
--             Z01 revision, never an edit of these lists in the apply session.
-- On PASS it sets kan719.z03_pass = the manifest md5 (transaction-local).
DO $z03$
DECLARE
  manifest_md5 constant text := '254f6202893607899592380ee724a79b';
  sl_t text[]; sl_c text[];
  removed text[] := ARRAY[
    'policy:meetups_select_visible', 'policy:meetup_attendees_select', 'policy:meetup_attendees_select_visible', 'policy:meetup_attendees_write',
    'publication:meetups',
    'trigger:trg_kan711_meetups_mirror', 'trigger:trg_zz_kan712_meetups_guard', 'trigger:trg_kan713_meetups_a_location', 'trigger:trg_kan713_meetups_b_joining',
    'trigger:trg_games_search_tsv', 'trigger:trg_meetups_search_tsv', 'trigger:trg_meetups_touch', 'trigger:trg_meetups_updated',
    'trigger:trg_meetups_inherit_geo', 'trigger:tr_meetups_activity_sync', 'trigger:trg_meetups_cancel_notify', 'trigger:trg_meetups_outbox',
    'trigger:trg_meetups_stamp_request_id', 'trigger:trg_meetups_enforce_solo_sport', 'trigger:trg_meetups_sync_joining_rule', 'trigger:trg_meetups_sync_geo',
    'index:meetups_creator_request_id_key', 'index:idx_games_search_tsv', 'index:idx_meetups_owner', 'index:idx_meetups_owner_time', 'index:idx_meetups_search_tsv',
    'constraint:chk_meetups_title_len', 'constraint:meetups_area_id_fkey', 'constraint:meetups_capacity_check', 'constraint:meetups_cost_cover_check',
    'constraint:meetups_cost_cover_logic', 'constraint:meetups_owner_profile_id_fkey', 'constraint:meetups_geo_location_id_fkey', 'constraint:meetups_joining_rule_check',
    'constraint:meetups_listing_visibility_check', 'constraint:meetups_rsvp_policy_check', 'constraint:meetups_sport_id_fkey', 'constraint:meetups_title_check',
    'constraint:meetups_venue_id_fkey',
    'function:getnearbygames', 'function:rpc_create_meetup_legacy_v1'
  ];
  known text[] := ARRAY[
    'default',
    'function:kan711_events_map_meetup', 'function:kan711_events_backfill_batch', 'function:kan711_meetups_mirror',
    'function:kan711_events_backfill_run', 'function:kan711_events_validate_links'
  ];
  found text[] := '{}';
  x text[];
  nnew text[];
BEGIN
  SELECT array_agg(t ORDER BY t, c), array_agg(c ORDER BY t, c) INTO sl_t, sl_c FROM (VALUES
    ('games', 'search_tsv'),
    ('meetups', 'creator_profile_id'), ('meetups', 'creator_user_id'), ('meetups', 'title'), ('meetups', 'listing_visibility'), ('meetups', 'rsvp_policy'),
    ('meetups', 'capacity'), ('meetups', 'start_at'), ('meetups', 'end_at'), ('meetups', 'is_cancelled'), ('meetups', 'created_at'), ('meetups', 'updated_at'),
    ('meetups', 'search_tsv'), ('meetups', 'geo_location_id'), ('meetups', 'sport_id'), ('meetups', 'area_id'), ('meetups', 'venue_id'),
    ('meetups', 'min_skill'), ('meetups', 'max_skill'), ('meetups', 'joining_rule'), ('meetups', 'cost_cover'), ('meetups', 'request_id')
  ) v(t, c);

  -- S1 column-level pg_depend
  SELECT array_agg(DISTINCT k) INTO x FROM (
    SELECT CASE
             WHEN d.classid = 'pg_attrdef'::regclass THEN 'default'
             WHEN d.classid = 'pg_constraint'::regclass THEN 'constraint:' || (SELECT conname FROM pg_constraint WHERE oid = d.objid)
             WHEN d.classid = 'pg_class'::regclass THEN
               CASE WHEN (SELECT relkind FROM pg_class WHERE oid = d.objid) IN ('i', 'I') THEN 'index:' ELSE 'relation:' END
               || (SELECT relname FROM pg_class WHERE oid = d.objid)
             WHEN d.classid = 'pg_trigger'::regclass THEN 'trigger:' || (SELECT tgname FROM pg_trigger WHERE oid = d.objid)
             WHEN d.classid = 'pg_policy'::regclass THEN 'policy:' || (SELECT polname FROM pg_policy WHERE oid = d.objid)
             WHEN d.classid = 'pg_rewrite'::regclass THEN 'view:' || (SELECT ev_class::regclass::text FROM pg_rewrite WHERE oid = d.objid)
             WHEN d.classid = 'pg_publication_rel'::regclass THEN 'publication:' || s.tbl
             WHEN d.classid = 'pg_statistic_ext'::regclass THEN 'statistics:' || (SELECT stxname FROM pg_statistic_ext WHERE oid = d.objid)
             ELSE 'other:' || pg_describe_object(d.classid, d.objid, d.objsubid) END AS k
      FROM pg_depend d
      JOIN unnest(sl_t, sl_c) s(tbl, col) ON d.refclassid = 'pg_class'::regclass AND d.refobjid = ('public.' || s.tbl)::regclass
      JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid AND a.attname = s.col
     WHERE NOT (d.classid = 'pg_class'::regclass AND d.objid = d.refobjid)) q;
  found := found || coalesce(x, '{}');

  -- S2 + S3 (KAN-862 P2 lexical scanner, per table)
  WITH sl AS (SELECT s.tbl, '(' || string_agg(s.col, '|') || ')' r FROM unnest(sl_t, sl_c) s(tbl, col) GROUP BY s.tbl),
  f AS (SELECT p.oid, p.proname::text fn, p.prosrc src, sl.tbl, sl.r FROM pg_proc p JOIN sl ON p.prosrc ~* ('\m' || sl.tbl || '\M')
         WHERE p.pronamespace = 'public'::regnamespace AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_)'),
  al AS (SELECT f.oid, f.tbl, lower(rm[1]) a FROM f, regexp_matches(f.src, 'public\.' || f.tbl || '\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') rm
          WHERE lower(rm[1]) NOT IN ('where','on','join','set','for','left','inner','order','group','limit','using','values','returning','select','and','or')
         UNION SELECT f.oid, f.tbl, lower(rm[1]) FROM f, regexp_matches(f.src, '([a-z_][a-z0-9_]*)\s+public\.' || f.tbl || '%rowtype', 'gi') rm),
  hits AS (
    SELECT 'function:' || f.fn k FROM f JOIN al ON al.oid = f.oid AND al.tbl = f.tbl, regexp_matches(f.src, '\m' || al.a || '\.' || f.r || '\M', 'gi') h
    UNION SELECT 'function:' || f.fn FROM f, regexp_matches(f.src, 'select\s+(?:[a-z_]+\.)?' || f.r || '\s+from\s+public\.' || f.tbl || '\s+where', 'gi') h
    UNION SELECT 'function:' || f.fn FROM f, regexp_matches(f.src, 'from\s+public\.' || f.tbl || '\s+where\s+' || f.r || '\M', 'gi') h
    UNION SELECT 'function:' || f.fn FROM f, regexp_matches(f.src, 'update\s+public\.' || f.tbl || '\s+set[^;]*?\m' || f.r || '\s*=', 'gi') h
    UNION SELECT 'function:' || f.fn FROM f, regexp_matches(f.src, 'insert\s+into\s+public\.' || f.tbl || '\s*\([^)]*\m' || f.r || '\M', 'gi') h
    UNION SELECT 'trigger:' || t.tgname
      FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid JOIN sl ON t.tgrelid = ('public.' || sl.tbl)::regclass
     WHERE NOT t.tgisinternal AND p.proname !~ '^harness_' AND p.prosrc ~* ('\m(new|old)\.' || sl.r || '\M'))
  SELECT array_agg(DISTINCT k) INTO x FROM hits;
  found := found || coalesce(x, '{}');

  -- S4 pg_cron
  IF to_regclass('cron.job') IS NOT NULL THEN
    EXECUTE $q$SELECT array_agg(DISTINCT 'cron:' || coalesce(jobname, jobid::text)) FROM cron.job
                WHERE command ~* '\m(public\.)?(games|meetups)\M' AND EXISTS (SELECT 1 FROM unnest($1) c WHERE command ~* ('\m' || c || '\M'))$q$
      INTO x USING sl_c;
    found := found || coalesce(x, '{}');
  END IF;

  SELECT array_agg(k ORDER BY k) INTO nnew FROM (SELECT DISTINCT unnest(found) k) u WHERE k <> ALL (removed) AND k <> ALL (known);
  IF cardinality(nnew) > 0 THEN
    RAISE EXCEPTION 'KAN-780 STOP: % NEW dependenc(ies) on slated games/meetups columns since the Z01 review (manifest %); the destructive step must not run: %',
      cardinality(nnew), manifest_md5, array_to_string(nnew, ', ')
      USING HINT = 'Review each one; a new Z01 revision is needed before phase 4. Do not edit the gate lists in the apply session.';
  END IF;
  PERFORM set_config('kan719.z03_pass', manifest_md5, true);
  PERFORM set_config('kan719.z03_summary', format('%s deps, %s removed, %s known: %s', (SELECT count(DISTINCT k) FROM unnest(found) k),
    (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (removed)), (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (known)),
    (SELECT string_agg(DISTINCT k, ', ') FROM unnest(found) k WHERE k = ANY (known))), true);   -- readable where NOTICEs are not (execute_sql)
  RAISE NOTICE 'KAN-780 GATE PASS at % for manifest %: % dependencies on % slated columns, 0 NEW; % removed by Z01, % KNOWN (%)',
    clock_timestamp(), manifest_md5, (SELECT count(DISTINCT k) FROM unnest(found) k), cardinality(sl_c),
    (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (removed)),
    (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (known)),
    (SELECT string_agg(DISTINCT k, ', ') FROM unnest(found) k WHERE k = ANY (known));
END $z03$;
