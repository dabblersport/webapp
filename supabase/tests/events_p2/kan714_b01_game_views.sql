-- KAN-720 (KAN-714 piece B01) test: v_game_card / v_my_games read shared columns from public.events.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
--
-- Load order (database must already hold the migration):
--   tests/events_p1/local_harness_kan711.sql, tests/events_p1/local_seed_kan711.sql,
--   tests/events_p2/local_harness_kan712.sql, tests/events_p2_kan713/local_harness_kan713.sql,
--   tests/events_p2_kan714/local_harness_kan714.sql   (fixture: pre-images of both views verbatim + seed),
--   migrations 20261101140000, 20261102110000, 20261102120000,
--     CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();
--   migrations 20261103100000, 20261103110000, 20261104100000, 20261104110000, 20261104110300,
--   migrations/20261104100100_kan714_b01_views_game_card_my_games.sql, then THIS FILE.
--
-- Flow: snapshot NEW -> provenance probes on NEW -> rollback block (verbatim copy of the migration's
-- KAN720-ROLLBACK section) -> snapshot OLD -> the same probes on OLD (they must fail there) -> compare ->
-- re-apply the migration with \ir -> verify round trip and data intact. Leaves the database migrated.
-- Assertions: A signature, B counts / no doubles / no meetups, C provenance, D per-viewer row sets,
-- E rollback + data intact, F plan (one events join, no events subplan, no new subplans).

\set ON_ERROR_STOP 1
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------------------
-- T0. Preconditions
-- ---------------------------------------------------------------------------------------------------------
DO $t0$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_game_card'::regclass AND d.refobjid = 'public.events'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_my_games'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'T0 FAIL: migration 20261104100100 not applied (views do not read public.events)';
  END IF;
  IF (SELECT count(*) FROM public.games) = 0 OR (SELECT count(*) FROM public.meetups) = 0 THEN
    RAISE EXCEPTION 'T0 FAIL: harness must hold at least one game and one meetup';
  END IF;
  RAISE NOTICE 'T0 PASS preconditions (games=%, meetups=%, events=%)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);
END
$t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Probe viewers
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan720_users;
CREATE TEMP TABLE kan720_users (label text PRIMARY KEY, uid uuid);
INSERT INTO kan720_users VALUES ('anon', NULL), ('stranger', gen_random_uuid());
INSERT INTO kan720_users SELECT 'admin', admin_uid FROM public.harness_admins LIMIT 1;
INSERT INTO kan720_users SELECT 'blocker', blocker_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan720_users SELECT 'blocked', blocked_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan720_users SELECT 'rostered', user_id FROM public.game_roster WHERE user_id IS NOT NULL
  GROUP BY user_id ORDER BY count(*) DESC, user_id LIMIT 1;
INSERT INTO kan720_users SELECT 'waitlisted', user_id FROM public.game_waitlist ORDER BY user_id LIMIT 1;
INSERT INTO kan720_users SELECT 'follower', p.user_id FROM public.profile_follows pf JOIN public.profiles p ON p.id = pf.follower_profile_id
  WHERE p.user_id IS NOT NULL ORDER BY pf.id LIMIT 1;
INSERT INTO kan720_users SELECT 'private_host', creator_user_id FROM public.events
  WHERE event_type = 'game' AND listing_visibility <> 'public' ORDER BY id LIMIT 1;
SELECT string_agg(label, ',' ORDER BY label) AS probe_viewers FROM kan720_users;

-- ---------------------------------------------------------------------------------------------------------
-- Snapshot helpers
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan720_meta, pg_temp.kan720_rows, pg_temp.kan720_plan, pg_temp.kan720_prov, pg_temp.kan720_data;
CREATE TEMP TABLE kan720_meta (phase text, view text, sig text, owner text, acl text, opts text, def text, reads_events boolean);
CREATE TEMP TABLE kan720_rows (phase text, view text, label text, n bigint, nd bigint, n_meetup_ids bigint, row_md5 text);
CREATE TEMP TABLE kan720_plan (phase text, view text, events_scans int, events_in_subplan int, events_under_join int, subplans int);
CREATE TEMP TABLE kan720_prov (phase text, gc_title text, gc_min_skill text, gc_min_skill_type text, mg_title text, mg_start text,
                               gc_after_flip bigint, mg_after_flip bigint, e_title text, g_title text, e_start text, g_start text);
CREATE TEMP TABLE kan720_data (phase text, games_md5 text, events_md5 text, meetups_md5 text);

CREATE FUNCTION pg_temp.kan720_snapshot(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v text;
  u record;
  r record;
  j json;
  s record;
BEGIN
  INSERT INTO kan720_data
  SELECT p_phase,
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t);

  FOREACH v IN ARRAY ARRAY['v_game_card', 'v_my_games'] LOOP
    INSERT INTO kan720_meta
    SELECT p_phase, v,
           (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
              FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped),
           pg_get_userbyid(c.relowner), c.relacl::text, coalesce(c.reloptions::text, ''), pg_get_viewdef(c.oid),
           EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                    WHERE rw.ev_class = c.oid AND d.refobjid = 'public.events'::regclass)
      FROM pg_class c WHERE c.oid = ('public.' || v)::regclass;

    FOR u IN SELECT * FROM kan720_users ORDER BY label LOOP
      PERFORM set_config('request.jwt.claim.sub', coalesce(u.uid::text, ''), true);
      EXECUTE 'SET LOCAL ROLE ' || CASE WHEN u.uid IS NULL THEN 'anon' ELSE 'authenticated' END;
      EXECUTE format('SELECT count(*) AS n, count(DISTINCT t.id) AS nd, coalesce(array_agg(DISTINCT t.id), %L) AS ids,'
                     ' md5(coalesce(string_agg(t::text, %L ORDER BY t::text), %L)) AS h FROM public.%I t', '{}', '|', '', v)
        INTO r;
      RESET ROLE;
      INSERT INTO kan720_rows VALUES (p_phase, v, u.label, r.n, r.nd,
        (SELECT count(*) FROM public.meetups m WHERE m.id = ANY (r.ids)), r.h);
    END LOOP;

    -- Plan, as the admin viewer (every row visible).
    PERFORM set_config('request.jwt.claim.sub', (SELECT uid::text FROM kan720_users WHERE label = 'admin'), true);
    EXECUTE format('EXPLAIN (FORMAT JSON) SELECT * FROM public.%I', v) INTO j;
    WITH RECURSIVE n(node, in_sub, parent_type) AS (
      SELECT (j::jsonb)->0->'Plan', false, ''::text
      UNION ALL
      SELECT c, n.in_sub OR coalesce(c->>'Parent Relationship', '') IN ('SubPlan', 'InitPlan'), n.node->>'Node Type'
        FROM n, jsonb_array_elements(coalesce(n.node->'Plans', '[]'::jsonb)) c
    )
    SELECT count(*) FILTER (WHERE node->>'Relation Name' = 'events')::int AS es,
           count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND in_sub)::int AS esub,
           count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND parent_type IN ('Hash', 'Hash Join', 'Nested Loop', 'Merge Join', 'Sort', 'Materialize', 'Memoize'))::int AS ejoin,
           count(*) FILTER (WHERE node->>'Parent Relationship' = 'SubPlan')::int AS sp
      INTO s FROM n;
    INSERT INTO kan720_plan VALUES (p_phase, v, s.es, s.esub, s.ejoin, s.sp);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

-- Provenance probe. Inside a subtransaction that is always rolled back: triggers off (replica), so events and
-- games can be made to DISAGREE on shared columns; read both views; then flip the game's parent to
-- event_type='meetup' and count again. Nothing persists.
CREATE FUNCTION pg_temp.kan720_provenance(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  gid uuid;
  host uuid;
  admin uuid := (SELECT uid FROM kan720_users WHERE label = 'admin');
  p kan720_prov%ROWTYPE;
BEGIN
  SELECT g.id, e.creator_user_id INTO gid, host
    FROM public.games g JOIN public.events e ON e.id = g.event_id
   ORDER BY g.id LIMIT 1;
  p.phase := p_phase;
  BEGIN
    SET LOCAL session_replication_role = replica;
    UPDATE public.events SET title = 'KAN720-FROM-EVENTS', min_skill = 7, start_at = start_at + interval '1 minute',
                             end_at = end_at + interval '1 minute' WHERE id = gid;
    UPDATE public.games  SET title = 'KAN720-FROM-GAMES',  min_skill = 3 WHERE id = gid;
    SELECT e.title, g.title, e.start_at::text, g.start_at::text INTO p.e_title, p.g_title, p.e_start, p.g_start
      FROM public.events e JOIN public.games g ON g.id = e.id WHERE e.id = gid;

    PERFORM set_config('request.jwt.claim.sub', admin::text, true);
    SELECT title, min_skill::text, pg_typeof(min_skill)::text INTO p.gc_title, p.gc_min_skill, p.gc_min_skill_type
      FROM public.v_game_card WHERE id = gid;
    PERFORM set_config('request.jwt.claim.sub', host::text, true);
    SELECT title, start_at::text INTO p.mg_title, p.mg_start FROM public.v_my_games WHERE id = gid LIMIT 1;

    UPDATE public.events SET event_type = 'meetup' WHERE id = gid;
    PERFORM set_config('request.jwt.claim.sub', admin::text, true);
    SELECT count(*) INTO p.gc_after_flip FROM public.v_game_card WHERE id = gid;
    PERFORM set_config('request.jwt.claim.sub', host::text, true);
    SELECT count(*) INTO p.mg_after_flip FROM public.v_my_games WHERE id = gid;
    RAISE EXCEPTION 'kan720_probe_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan720_probe_rollback' THEN RAISE; END IF;
  END;
  INSERT INTO kan720_prov SELECT p.*;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- T1. NEW definitions: snapshot + provenance
-- ---------------------------------------------------------------------------------------------------------
BEGIN; SELECT pg_temp.kan720_snapshot('new'); SELECT pg_temp.kan720_provenance('new'); COMMIT;

DO $c$
DECLARE p kan720_prov%ROWTYPE;
BEGIN
  SELECT * INTO p FROM kan720_prov WHERE phase = 'new';
  IF p.e_title IS DISTINCT FROM 'KAN720-FROM-EVENTS' OR p.g_title IS DISTINCT FROM 'KAN720-FROM-GAMES' OR p.e_start = p.g_start THEN
    RAISE EXCEPTION 'C FAIL: probe could not make events and games disagree (%)', row_to_json(p);
  END IF;
  IF p.gc_title IS DISTINCT FROM 'KAN720-FROM-EVENTS' OR p.gc_min_skill IS DISTINCT FROM '7' OR p.gc_min_skill_type <> 'integer' THEN
    RAISE EXCEPTION 'C FAIL: v_game_card does not follow events (%)', row_to_json(p);
  END IF;
  IF p.mg_title IS DISTINCT FROM 'KAN720-FROM-EVENTS' OR p.mg_start IS DISTINCT FROM p.e_start THEN
    RAISE EXCEPTION 'C FAIL: v_my_games does not follow events (%)', row_to_json(p);
  END IF;
  IF p.gc_after_flip <> 0 OR p.mg_after_flip <> 0 THEN
    RAISE EXCEPTION 'B FAIL: a parent retyped to meetup still surfaces (gc=%, mg=%)', p.gc_after_flip, p.mg_after_flip;
  END IF;
  RAISE NOTICE 'C PASS provenance (new): title/min_skill(integer)/start_at follow public.events, not games';
  RAISE NOTICE 'B PASS type filter (new): a game whose parent is event_type=meetup disappears from both views';
END
$c$;

-- ---------------------------------------------------------------------------------------------------------
-- T2. ROLLBACK — verbatim copy of the migration's KAN720-ROLLBACK block (comment markers stripped).
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    g.capacity + g.bench_slots AS total_slots,
    g.min_skill,
    g.max_skill,
    g.listing_visibility,
    g.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    g.is_cancelled,
    g.rules,
    g.created_at,
    g.updated_at,
    g.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name AS area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    g.joining_rule,
    g.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    g.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM profile_verifications pv
          WHERE pv.profile_id = g.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM organiser o
          WHERE o.profile_id = g.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
    CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
    s2.ends_on AS series_ends_on
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
     LEFT JOIN game_series s2 ON s2.id = g.series_id
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);

CREATE OR REPLACE VIEW "public"."v_my_games" AS
 SELECT "g"."id",
    "g"."title",
    "g"."game_type",
    "g"."start_at",
    "g"."end_at",
    "g"."capacity",
    "g"."is_cancelled",
    "g"."listing_visibility",
    "g"."join_policy",
    "g"."created_at",
    "g"."sport_id",
    "s"."sport_key",
    "s"."name_en" AS "sport_name_en",
    "s"."name_ar" AS "sport_name_ar",
    "g"."creator_profile_id",
    "g"."creator_user_id",
    "g"."area_id",
    "a"."name" AS "area_name",
    "g"."venue_id",
    "v"."name_en" AS "venue_name",
    "gr"."status" AS "my_roster_status"
   FROM ((((("public"."games" "g"
     LEFT JOIN "public"."sports" "s" ON (("s"."id" = "g"."sport_id")))
     LEFT JOIN "public"."areas" "a" ON (("a"."id" = "g"."area_id")))
     LEFT JOIN "public"."venue_spaces" "vs" ON (("vs"."id" = "g"."venue_space_id")))
     LEFT JOIN "public"."venues" "v" ON (("v"."id" = COALESCE("vs"."venue_id", "g"."venue_id"))))
     LEFT JOIN "public"."game_roster" "gr" ON ((("gr"."game_id" = "g"."id") AND ("gr"."user_id" = "auth"."uid"()))))
  WHERE (("g"."creator_user_id" = "auth"."uid"()) OR ("gr"."user_id" = "auth"."uid"()));
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- T3. OLD definitions: snapshot + the same provenance probe (it must FAIL here: old views follow games)
-- ---------------------------------------------------------------------------------------------------------
BEGIN; SELECT pg_temp.kan720_snapshot('old'); SELECT pg_temp.kan720_provenance('old'); COMMIT;

DO $c2$
DECLARE p kan720_prov%ROWTYPE;
BEGIN
  SELECT * INTO p FROM kan720_prov WHERE phase = 'old';
  IF p.gc_title IS DISTINCT FROM 'KAN720-FROM-GAMES' OR p.mg_title IS DISTINCT FROM 'KAN720-FROM-GAMES'
     OR p.gc_min_skill IS DISTINCT FROM '3' OR p.mg_start IS DISTINCT FROM p.g_start OR p.gc_after_flip <> 1 THEN
    RAISE EXCEPTION 'C FAIL: probe did not discriminate — old definitions should read games (%)', row_to_json(p);
  END IF;
  IF EXISTS (SELECT 1 FROM kan720_meta WHERE phase = 'old' AND reads_events) THEN
    RAISE EXCEPTION 'E FAIL: rolled-back views still depend on public.events';
  END IF;
  RAISE NOTICE 'C PASS probe proven failing on the old definitions (old views read games: title=%, min_skill=%, flip rows=%)',
    p.gc_title, p.gc_min_skill, p.gc_after_flip;
END
$c2$;

-- ---------------------------------------------------------------------------------------------------------
-- T4. Compare NEW vs OLD
-- ---------------------------------------------------------------------------------------------------------
DO $cmp$
DECLARE
  r record;
  v_games bigint := (SELECT count(*) FROM public.games);
BEGIN
  -- A. column names / types / order, owner, ACL, reloptions
  FOR r IN SELECT n.view, n.sig = o.sig AS sig_eq, n.owner = o.owner AND n.acl = o.acl AND n.opts = o.opts AS attrs_eq, n.opts
             FROM kan720_meta n JOIN kan720_meta o ON o.view = n.view AND o.phase = 'old' WHERE n.phase = 'new' LOOP
    IF NOT r.sig_eq THEN RAISE EXCEPTION 'A FAIL: % column signature differs new vs old', r.view; END IF;
    IF NOT r.attrs_eq THEN RAISE EXCEPTION 'A FAIL: % owner/ACL/reloptions differ new vs old', r.view; END IF;
    IF r.opts ~* 'security_invoker' THEN RAISE EXCEPTION 'A FAIL: % carries security_invoker', r.view; END IF;
  END LOOP;
  IF (SELECT count(*) FROM kan720_meta WHERE phase = 'new' AND reads_events) <> 2 THEN
    RAISE EXCEPTION 'A FAIL: new definitions do not both read public.events';
  END IF;
  RAISE NOTICE 'A PASS column names/types/order, owner, ACL and reloptions identical new vs old (both views)';

  -- B. counts equal to legacy, no doubles, no meetup ids, admin sees every game exactly once
  IF EXISTS (SELECT 1 FROM kan720_rows n JOIN kan720_rows o ON o.phase = 'old' AND o.view = n.view AND o.label = n.label
              WHERE n.phase = 'new' AND (n.n <> o.n OR n.nd <> o.nd)) THEN
    RAISE EXCEPTION 'B FAIL: row counts differ new vs old';
  END IF;
  IF EXISTS (SELECT 1 FROM kan720_rows WHERE phase = 'new' AND (n_meetup_ids <> 0 OR (view = 'v_game_card' AND n <> nd))) THEN
    RAISE EXCEPTION 'B FAIL: meetup ids or doubled v_game_card rows present';
  END IF;
  IF (SELECT n FROM kan720_rows WHERE phase = 'new' AND view = 'v_game_card' AND label = 'admin') <> v_games
     OR (SELECT nd FROM kan720_rows WHERE phase = 'new' AND view = 'v_game_card' AND label = 'admin') <> v_games THEN
    RAISE EXCEPTION 'B FAIL: admin v_game_card rows <> games (%)', v_games;
  END IF;
  RAISE NOTICE 'B PASS counts equal legacy for every viewer; admin v_game_card = % rows = % games, each once; 0 meetup ids',
    (SELECT n FROM kan720_rows WHERE phase = 'new' AND view = 'v_game_card' AND label = 'admin'), v_games;

  -- D. per-viewer row SET (full row text incl. viewer flags and nulls) identical, API roles
  FOR r IN SELECT n.view, n.label, n.n, n.row_md5 = o.row_md5 AS eq
             FROM kan720_rows n JOIN kan720_rows o ON o.phase = 'old' AND o.view = n.view AND o.label = n.label
            WHERE n.phase = 'new' ORDER BY n.view, n.label LOOP
    IF NOT r.eq THEN RAISE EXCEPTION 'D FAIL: % rows for viewer % differ new vs old', r.view, r.label; END IF;
    RAISE NOTICE 'D  ok % viewer=% rows=%', r.view, r.label, r.n;
  END LOOP;
  IF (SELECT count(*) FROM kan720_rows WHERE phase = 'new') <> 2 * (SELECT count(*) FROM kan720_users) THEN
    RAISE EXCEPTION 'D FAIL: missing viewer snapshots';
  END IF;
  RAISE NOTICE 'D PASS every viewer (anon, stranger, blocked, blocker, follower, rostered, waitlisted, private host, admin) sees the identical row set, as anon/authenticated';

  -- F. plan: events scanned once, inside a join, never in a subplan; no new subplans
  FOR r IN SELECT n.view, n.events_scans, n.events_in_subplan, n.events_under_join, n.subplans AS sp_new, o.subplans AS sp_old
             FROM kan720_plan n JOIN kan720_plan o ON o.phase = 'old' AND o.view = n.view WHERE n.phase = 'new' LOOP
    IF r.events_scans <> 1 OR r.events_in_subplan <> 0 OR r.events_under_join <> 1 OR r.sp_new <> r.sp_old THEN
      RAISE EXCEPTION 'F FAIL: % plan events_scans=% in_subplan=% under_join=% subplans new=% old=%',
        r.view, r.events_scans, r.events_in_subplan, r.events_under_join, r.sp_new, r.sp_old;
    END IF;
    RAISE NOTICE 'F  ok % events scans=1 (join), in subplan=0, subplans new=% old=%', r.view, r.sp_new, r.sp_old;
  END LOOP;
  RAISE NOTICE 'F PASS one join to public.events per view, no per-row events lookup, no added subplans';
END
$cmp$;

-- ---------------------------------------------------------------------------------------------------------
-- T5. Re-apply the migration (round trip), then verify E
-- ---------------------------------------------------------------------------------------------------------
\ir ../../migrations/20261104100100_kan714_b01_views_game_card_my_games.sql

BEGIN; SELECT pg_temp.kan720_snapshot('reapplied'); COMMIT;

DO $e$
BEGIN
  IF EXISTS (SELECT 1 FROM kan720_meta n JOIN kan720_meta r ON r.phase = 'reapplied' AND r.view = n.view
              WHERE n.phase = 'new' AND (n.def <> r.def OR n.sig <> r.sig OR n.acl <> r.acl OR n.opts <> r.opts OR NOT r.reads_events)) THEN
    RAISE EXCEPTION 'E FAIL: re-applied definitions differ from the first application';
  END IF;
  IF (SELECT count(DISTINCT (games_md5, events_md5, meetups_md5)) FROM kan720_data) <> 1 THEN
    RAISE EXCEPTION 'E FAIL: table data changed across apply/rollback/re-apply/probes';
  END IF;
  IF EXISTS (SELECT 1 FROM kan720_rows n JOIN kan720_rows r ON r.phase = 'reapplied' AND r.view = n.view AND r.label = n.label
              WHERE n.phase = 'new' AND n.row_md5 <> r.row_md5) THEN
    RAISE EXCEPTION 'E FAIL: re-applied view rows differ';
  END IF;
  RAISE NOTICE 'E PASS rollback restored the old definitions (reads games, same signature/ACL), games/events/meetups data identical across all phases, re-apply round-trips';
  RAISE NOTICE 'KAN-720 ALL PASS';
END
$e$;
