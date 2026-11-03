-- KAN-721 (KAN-714 piece B02) test: v_meetup_list / v_meetup_counts read shared columns from public.events.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
--
-- Load order (database must already hold the migration):
--   tests/events_p1/local_harness_kan711.sql, tests/events_p1/local_seed_kan711.sql,
--   tests/events_p2/local_harness_kan712.sql, tests/events_p2_kan713/local_harness_kan713.sql,
--   tests/events_p2_kan714/local_harness_kan714.sql   (fixture: pre-images of both views verbatim + seed),
--   migrations 20261101140000, 20261102110000, 20261102120000,
--     CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();
--   migrations 20261103100000, 20261103110000, 20261104100000, 20261104110000, 20261104110300,
--   migrations/20261104100100 (KAN-720, B01), migrations/20261104100200_kan714_b02_views_meetup_list_counts.sql,
--   then THIS FILE.
--
-- Flow: snapshot NEW -> provenance probes on NEW -> rollback block (verbatim copy of the migration's
-- KAN721-ROLLBACK section) -> snapshot OLD -> the same probes on OLD (they must fail there) -> compare ->
-- re-apply the migration with \ir -> verify round trip and data intact. Leaves the database migrated.
-- Assertions: A signature, B counts / no doubles / no game ids / per-meetup count values, C provenance,
-- D per-viewer row sets, E rollback + data intact, F plan (one events join per legacy meetups read, no events
-- subplan, no new subplans).

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
                  WHERE rw.ev_class = 'public.v_meetup_list'::regclass AND d.refobjid = 'public.events'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_meetup_counts'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'T0 FAIL: migration 20261104100200 not applied (views do not read public.events)';
  END IF;
  IF (SELECT count(*) FROM public.games) = 0 OR (SELECT count(*) FROM public.meetups) = 0
     OR (SELECT count(*) FROM public.meetup_rsvps) = 0 THEN
    RAISE EXCEPTION 'T0 FAIL: harness must hold at least one game, one meetup and one RSVP';
  END IF;
  RAISE NOTICE 'T0 PASS preconditions (games=%, meetups=%, events=%, rsvps=%)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events),
    (SELECT count(*) FROM public.meetup_rsvps);
END
$t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Probe viewers. The creators together see every meetup (hidden is owner-only).
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan721_users;
CREATE TEMP TABLE kan721_users (label text PRIMARY KEY, uid uuid, is_creator boolean DEFAULT false);
INSERT INTO kan721_users VALUES ('anon', NULL), ('stranger', gen_random_uuid());
INSERT INTO kan721_users SELECT 'admin', admin_uid FROM public.harness_admins LIMIT 1;
INSERT INTO kan721_users SELECT 'blocker', blocker_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan721_users SELECT 'blocked', blocked_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan721_users SELECT 'circle_friend', f.peer_user_id FROM public.friendships f
  WHERE f.status = 'accepted' AND f.peer_user_id NOT IN (SELECT uid FROM kan721_users WHERE uid IS NOT NULL)
  ORDER BY f.peer_user_id LIMIT 1;
INSERT INTO kan721_users SELECT 'rsvper', r.user_id FROM public.meetup_rsvps r
  WHERE r.user_id NOT IN (SELECT creator_user_id FROM public.meetups)
  GROUP BY r.user_id ORDER BY count(*) DESC, r.user_id LIMIT 1;
INSERT INTO kan721_users
SELECT 'creator_' || row_number() OVER (ORDER BY c.creator_user_id), c.creator_user_id
  FROM (SELECT DISTINCT creator_user_id FROM public.meetups) c
 WHERE c.creator_user_id NOT IN (SELECT uid FROM kan721_users WHERE uid IS NOT NULL);
UPDATE kan721_users SET is_creator = uid IN (SELECT creator_user_id FROM public.meetups);
SELECT string_agg(label || CASE WHEN is_creator THEN '*' ELSE '' END, ',' ORDER BY label) AS probe_viewers FROM kan721_users;

-- ---------------------------------------------------------------------------------------------------------
-- Snapshot helpers
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan721_meta, pg_temp.kan721_rows, pg_temp.kan721_cnt, pg_temp.kan721_ids,
                     pg_temp.kan721_plan, pg_temp.kan721_prov, pg_temp.kan721_data;
CREATE TEMP TABLE kan721_meta (phase text, view text, sig text, owner text, acl text, opts text, def text, reads_events boolean);
CREATE TEMP TABLE kan721_rows (phase text, view text, label text, n bigint, nd bigint, n_game_ids bigint, n_non_meetup bigint, row_md5 text);
CREATE TEMP TABLE kan721_cnt  (phase text, label text, meetup_id uuid, going bigint, interested bigint, declined bigint);
CREATE TEMP TABLE kan721_ids  (phase text, label text, id uuid);
CREATE TEMP TABLE kan721_plan (phase text, view text, events_scans int, meetups_scans int, events_in_subplan int, events_under_join int, subplans int);
CREATE TEMP TABLE kan721_prov (phase text, l_title text, l_min_skill text, l_min_skill_type text, l_rsvp_policy text, l_start text,
                               vis_list bigint, vis_counts bigint, type_list bigint, type_counts bigint,
                               e_title text, m_title text, e_start text, m_start text, e_policy text, m_policy text);
CREATE TEMP TABLE kan721_data (phase text, meetups_md5 text, events_md5 text, rsvps_md5 text, games_md5 text);

CREATE FUNCTION pg_temp.kan721_snapshot(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v text;
  u record;
  r record;
  j json;
  jc jsonb;
  s record;
BEGIN
  INSERT INTO kan721_data
  SELECT p_phase,
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t::text)) FROM public.meetup_rsvps t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t);

  FOREACH v IN ARRAY ARRAY['v_meetup_counts', 'v_meetup_list'] LOOP
    INSERT INTO kan721_meta
    SELECT p_phase, v,
           (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
              FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped),
           pg_get_userbyid(c.relowner), c.relacl::text, coalesce(c.reloptions::text, ''), pg_get_viewdef(c.oid),
           EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                    WHERE rw.ev_class = c.oid AND d.refobjid = 'public.events'::regclass)
      FROM pg_class c WHERE c.oid = ('public.' || v)::regclass;

    FOR u IN SELECT * FROM kan721_users ORDER BY label LOOP
      PERFORM set_config('request.jwt.claim.sub', coalesce(u.uid::text, ''), true);
      EXECUTE 'SET LOCAL ROLE ' || CASE WHEN u.uid IS NULL THEN 'anon' ELSE 'authenticated' END;
      BEGIN
        IF v = 'v_meetup_counts' THEN
          EXECUTE format('SELECT count(*) AS n, count(DISTINCT t.meetup_id) AS nd, coalesce(array_agg(DISTINCT t.meetup_id), %L) AS ids,'
                         ' md5(coalesce(string_agg(t::text, %L ORDER BY t::text), %L)) AS h FROM public.v_meetup_counts t', '{}', '|', '')
            INTO r;
          SELECT coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO jc FROM public.v_meetup_counts t;
        ELSE
          EXECUTE format('SELECT count(*) AS n, count(DISTINCT t.id) AS nd, coalesce(array_agg(DISTINCT t.id), %L) AS ids,'
                         ' md5(coalesce(string_agg(t::text, %L ORDER BY t::text), %L)) AS h FROM public.v_meetup_list t', '{}', '|', '')
            INTO r;
        END IF;
        RESET ROLE;
        INSERT INTO kan721_rows VALUES (p_phase, v, u.label, r.n, r.nd,
          (SELECT count(*) FROM public.games g WHERE g.id = ANY (r.ids)),
          (SELECT count(*) FROM unnest(r.ids) x(id) WHERE NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = x.id)),
          r.h);
        IF v = 'v_meetup_list' THEN
          INSERT INTO kan721_ids SELECT p_phase, u.label, x FROM unnest(r.ids) x;
        ELSE
          -- inserted after RESET ROLE: API roles cannot write this temp table
          INSERT INTO kan721_cnt
          SELECT p_phase, u.label, (x->>'meetup_id')::uuid, (x->>'going_count')::bigint,
                 (x->>'interested_count')::bigint, (x->>'declined_count')::bigint
            FROM jsonb_array_elements(jc) x;
        END IF;
      EXCEPTION WHEN insufficient_privilege THEN
        -- v_meetup_counts carries no anon grant (20260915120000:39): recorded, must be identical in both phases.
        RESET ROLE;
        INSERT INTO kan721_rows VALUES (p_phase, v, u.label, -1, -1, 0, 0, 'permission denied');
      END;
    END LOOP;

    -- Plan, as the admin viewer.
    PERFORM set_config('request.jwt.claim.sub', (SELECT uid::text FROM kan721_users WHERE label = 'admin'), true);
    EXECUTE format('EXPLAIN (FORMAT JSON) SELECT * FROM public.%I', v) INTO j;
    WITH RECURSIVE n(node, in_sub, parent_type) AS (
      SELECT (j::jsonb)->0->'Plan', false, ''::text
      UNION ALL
      SELECT c, n.in_sub OR coalesce(c->>'Parent Relationship', '') IN ('SubPlan', 'InitPlan'), n.node->>'Node Type'
        FROM n, jsonb_array_elements(coalesce(n.node->'Plans', '[]'::jsonb)) c
    )
    SELECT count(*) FILTER (WHERE node->>'Relation Name' = 'events')::int AS es,
           count(*) FILTER (WHERE node->>'Relation Name' = 'meetups')::int AS ms,
           count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND in_sub)::int AS esub,
           count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND parent_type IN ('Hash', 'Hash Join', 'Nested Loop', 'Merge Join', 'Sort', 'Materialize', 'Memoize'))::int AS ejoin,
           count(*) FILTER (WHERE node->>'Parent Relationship' = 'SubPlan')::int AS sp
      INTO s FROM n;
    INSERT INTO kan721_plan VALUES (p_phase, v, s.es, s.ms, s.esub, s.ejoin, s.sp);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

-- Provenance probe. Inside a subtransaction that is always rolled back: triggers off (replica), so events and
-- meetups can be made to DISAGREE on shared columns; read both views. Three public meetups, read as the
-- stranger (a fresh uid in no block pair, so the block check never hides them):
--   m1: events title/min_skill/join_policy/start_at changed, meetups title/min_skill changed differently;
--   m2: events.listing_visibility -> 'hidden' (meetups stays 'public'): must vanish from list AND counts;
--   m3: meetups.event_id repointed at a GAME parent: must vanish from list AND counts (type filter).
-- Nothing persists.
CREATE FUNCTION pg_temp.kan721_provenance(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  ids uuid[];
  game_parent uuid;
  stranger uuid := (SELECT uid FROM kan721_users WHERE label = 'stranger');
  p kan721_prov%ROWTYPE;
BEGIN
  SELECT array_agg(id ORDER BY id) INTO ids FROM (
    SELECT m.id FROM public.meetups m
     WHERE m.listing_visibility = 'public' AND NOT m.is_cancelled AND m.end_at IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.meetup_rsvps r WHERE r.meetup_id = m.id)
     ORDER BY m.id LIMIT 3) x;
  IF coalesce(array_length(ids, 1), 0) <> 3 THEN
    RAISE EXCEPTION 'C FAIL: harness lacks three public meetups with RSVPs for the probe';
  END IF;
  SELECT e.id INTO game_parent FROM public.events e WHERE e.event_type = 'game'
     AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.event_id = e.id) ORDER BY e.id LIMIT 1;
  p.phase := p_phase;
  BEGIN
    SET LOCAL session_replication_role = replica;
    UPDATE public.events SET title = 'KAN721-FROM-EVENTS', min_skill = 7, join_policy = 'request',
                             start_at = start_at + interval '1 minute', end_at = end_at + interval '1 minute'
     WHERE id = ids[1];
    UPDATE public.meetups SET title = 'KAN721-FROM-MEETUPS', min_skill = 3 WHERE id = ids[1];
    UPDATE public.events SET listing_visibility = 'hidden' WHERE id = ids[2];
    UPDATE public.meetups SET event_id = game_parent WHERE id = ids[3];
    SELECT e.title, m.title, e.start_at::text, m.start_at::text, e.join_policy, m.rsvp_policy
      INTO p.e_title, p.m_title, p.e_start, p.m_start, p.e_policy, p.m_policy
      FROM public.events e JOIN public.meetups m ON m.id = e.id WHERE e.id = ids[1];

    PERFORM set_config('request.jwt.claim.sub', stranger::text, true);
    SELECT title, min_skill::text, pg_typeof(min_skill)::text, rsvp_policy, start_at::text
      INTO p.l_title, p.l_min_skill, p.l_min_skill_type, p.l_rsvp_policy, p.l_start
      FROM public.v_meetup_list WHERE id = ids[1];
    SELECT count(*) INTO p.vis_list    FROM public.v_meetup_list   WHERE id = ids[2];
    SELECT count(*) INTO p.vis_counts  FROM public.v_meetup_counts WHERE meetup_id = ids[2];
    SELECT count(*) INTO p.type_list   FROM public.v_meetup_list   WHERE id = ids[3];
    SELECT count(*) INTO p.type_counts FROM public.v_meetup_counts WHERE meetup_id = ids[3];
    RAISE EXCEPTION 'kan721_probe_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan721_probe_rollback' THEN RAISE; END IF;
  END;
  INSERT INTO kan721_prov SELECT p.*;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- T1. NEW definitions: snapshot + provenance
-- ---------------------------------------------------------------------------------------------------------
BEGIN; SELECT pg_temp.kan721_snapshot('new'); SELECT pg_temp.kan721_provenance('new'); COMMIT;

DO $c$
DECLARE p kan721_prov%ROWTYPE;
BEGIN
  SELECT * INTO p FROM kan721_prov WHERE phase = 'new';
  IF p.e_title IS DISTINCT FROM 'KAN721-FROM-EVENTS' OR p.m_title IS DISTINCT FROM 'KAN721-FROM-MEETUPS'
     OR p.e_start = p.m_start OR p.e_policy IS NOT DISTINCT FROM p.m_policy THEN
    RAISE EXCEPTION 'C FAIL: probe could not make events and meetups disagree (%)', row_to_json(p);
  END IF;
  IF p.l_title IS DISTINCT FROM 'KAN721-FROM-EVENTS' OR p.l_min_skill IS DISTINCT FROM '7' OR p.l_min_skill_type <> 'integer'
     OR p.l_rsvp_policy IS DISTINCT FROM 'request' OR p.l_start IS DISTINCT FROM p.e_start THEN
    RAISE EXCEPTION 'C FAIL: v_meetup_list does not follow events (%)', row_to_json(p);
  END IF;
  IF p.vis_list <> 0 OR p.vis_counts <> 0 THEN
    RAISE EXCEPTION 'C FAIL: visibility gate does not read events (list=%, counts=%)', p.vis_list, p.vis_counts;
  END IF;
  IF p.type_list <> 0 OR p.type_counts <> 0 THEN
    RAISE EXCEPTION 'B FAIL: a meetup whose parent is event_type=game still surfaces (list=%, counts=%)', p.type_list, p.type_counts;
  END IF;
  RAISE NOTICE 'C PASS provenance (new): title/min_skill(integer)/rsvp_policy(<-join_policy)/start_at follow public.events, not meetups';
  RAISE NOTICE 'C PASS visibility gate (new): events.listing_visibility=hidden removes the meetup from v_meetup_list and v_meetup_counts';
  RAISE NOTICE 'B PASS type filter (new): a meetup whose parent is event_type=game disappears from both views';
END
$c$;

-- ---------------------------------------------------------------------------------------------------------
-- T2. ROLLBACK — verbatim copy of the migration's KAN721-ROLLBACK block (comment markers stripped).
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
CREATE OR REPLACE VIEW public.v_meetup_counts AS
 SELECT r.meetup_id,
    sum((r.status = 'going')::integer) AS going_count,
    sum((r.status = 'interested')::integer) AS interested_count,
    sum((r.status = 'declined')::integer) AS declined_count
   FROM public.meetup_rsvps r
     JOIN public.meetups m ON m.id = r.meetup_id
  WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
  GROUP BY r.meetup_id;
ALTER VIEW public.v_meetup_counts SET (security_invoker = off);

CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    m.title,
    m.description,
    m.start_at,
    m.end_at,
    m.capacity,
    m.members_only,
    m.listing_visibility,
    m.rsvp_policy,
    m.is_cancelled,
    m.vibe_key,
    m.created_at,
    m.updated_at,
    m.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    m.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    m.area_id,
    a.name AS area_name,
    m.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    m.geo_location_id,
    m.min_skill,
    m.max_skill,
    m.joining_rule,
    m.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
        CASE
            WHEN auth.uid() IS NULL THEN '[]'::jsonb
            ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
               FROM ( SELECT r2.profile_id,
                        r2.updated_at
                       FROM meetup_rsvps r2
                      WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
                      ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
                     LIMIT 5) x
                 JOIN profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
        END AS attendee_avatars,
    ( SELECT bool_or(vs.indoor) AS bool_or
           FROM venue_spaces vs
          WHERE vs.venue_id = m.venue_id AND vs.is_active = true) AS venue_is_indoor,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.meetup_id = m.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.meetup_id = m.id AND f.user_id = auth.uid())) AS favourited_by_me,
    COALESCE(( SELECT bool_or(vs2.indoor)
           FROM venue_spaces vs2
          WHERE vs2.venue_id = m.venue_id AND vs2.is_active = true), m.is_indoor) AS setting_is_indoor
   FROM meetups m
     LEFT JOIN profiles cp ON cp.id = m.creator_profile_id
     LEFT JOIN sports s ON s.id = m.sport_id
     LEFT JOIN areas a ON a.id = m.area_id
     LEFT JOIN venues v ON v.id = m.venue_id
     LEFT JOIN v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE can_view_owner(m.creator_user_id, m.listing_visibility) = true
  ORDER BY (COALESCE(m.updated_at, m.created_at)) DESC;
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- T3. OLD definitions: snapshot + the same provenance probe (it must FAIL here: old views follow meetups)
-- ---------------------------------------------------------------------------------------------------------
BEGIN; SELECT pg_temp.kan721_snapshot('old'); SELECT pg_temp.kan721_provenance('old'); COMMIT;

DO $c2$
DECLARE p kan721_prov%ROWTYPE;
BEGIN
  SELECT * INTO p FROM kan721_prov WHERE phase = 'old';
  IF p.l_title IS DISTINCT FROM 'KAN721-FROM-MEETUPS' OR p.l_min_skill IS DISTINCT FROM '3'
     OR p.l_rsvp_policy IS DISTINCT FROM p.m_policy OR p.l_start IS DISTINCT FROM p.m_start
     OR p.vis_list <> 1 OR p.vis_counts <> 1 OR p.type_list <> 1 OR p.type_counts <> 1 THEN
    RAISE EXCEPTION 'C FAIL: probe did not discriminate — old definitions should read meetups (%)', row_to_json(p);
  END IF;
  IF EXISTS (SELECT 1 FROM kan721_meta WHERE phase = 'old' AND reads_events) THEN
    RAISE EXCEPTION 'E FAIL: rolled-back views still depend on public.events';
  END IF;
  IF (SELECT opts FROM kan721_meta WHERE phase = 'old' AND view = 'v_meetup_counts') <> '{security_invoker=off}' THEN
    RAISE EXCEPTION 'E FAIL: rollback did not restore v_meetup_counts reloptions';
  END IF;
  RAISE NOTICE 'C PASS probe proven failing on the old definitions (old views read meetups: title=%, min_skill=%, rsvp_policy=%, hidden-on-events rows list/counts=%/%, game-parent rows list/counts=%/%)',
    p.l_title, p.l_min_skill, p.l_rsvp_policy, p.vis_list, p.vis_counts, p.type_list, p.type_counts;
  RAISE NOTICE 'E  old v_meetup_list def md5=% ; old v_meetup_counts def md5=% opts=%',
    (SELECT md5(def) FROM kan721_meta WHERE phase = 'old' AND view = 'v_meetup_list'),
    (SELECT md5(def) FROM kan721_meta WHERE phase = 'old' AND view = 'v_meetup_counts'),
    (SELECT opts FROM kan721_meta WHERE phase = 'old' AND view = 'v_meetup_counts');
END
$c2$;

-- ---------------------------------------------------------------------------------------------------------
-- T4. Compare NEW vs OLD
-- ---------------------------------------------------------------------------------------------------------
DO $cmp$
DECLARE
  r record;
  v_meetups bigint := (SELECT count(*) FROM public.meetups);
  v_cmp bigint;
  v_bad bigint;
  v_union bigint;
BEGIN
  -- A. column names / types / order, owner, ACL, reloptions
  FOR r IN SELECT n.view, n.sig = o.sig AS sig_eq, n.owner = o.owner AND n.acl = o.acl AND n.opts = o.opts AS attrs_eq, n.opts
             FROM kan721_meta n JOIN kan721_meta o ON o.view = n.view AND o.phase = 'old' WHERE n.phase = 'new' LOOP
    IF NOT r.sig_eq THEN RAISE EXCEPTION 'A FAIL: % column signature differs new vs old', r.view; END IF;
    IF NOT r.attrs_eq THEN RAISE EXCEPTION 'A FAIL: % owner/ACL/reloptions differ new vs old', r.view; END IF;
    IF r.opts ~* 'security_invoker=(true|on|1|yes)' THEN RAISE EXCEPTION 'A FAIL: % is security_invoker', r.view; END IF;
  END LOOP;
  IF (SELECT count(*) FROM kan721_meta WHERE phase = 'new' AND reads_events) <> 2 THEN
    RAISE EXCEPTION 'A FAIL: new definitions do not both read public.events';
  END IF;
  RAISE NOTICE 'A PASS column names/types/order, owner, ACL and reloptions identical new vs old (v_meetup_list %, v_meetup_counts % incl. %)',
    (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.v_meetup_list'::regclass AND attnum > 0) || ' cols',
    (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.v_meetup_counts'::regclass AND attnum > 0) || ' cols',
    (SELECT opts FROM kan721_meta WHERE phase = 'new' AND view = 'v_meetup_counts');

  -- B. counts equal to legacy, no doubles, no game ids, the creators together see every meetup exactly once
  IF EXISTS (SELECT 1 FROM kan721_rows n JOIN kan721_rows o ON o.phase = 'old' AND o.view = n.view AND o.label = n.label
              WHERE n.phase = 'new' AND (n.n <> o.n OR n.nd <> o.nd)) THEN
    RAISE EXCEPTION 'B FAIL: row counts differ new vs old';
  END IF;
  IF EXISTS (SELECT 1 FROM kan721_rows WHERE phase = 'new' AND (n_game_ids <> 0 OR n_non_meetup <> 0 OR n <> nd)) THEN
    RAISE EXCEPTION 'B FAIL: game ids, non-meetup ids or doubled rows present';
  END IF;
  -- Every viewer's id SET equals legacy; the union over all viewers equals the legacy union. (Not "all meetups":
  -- legacy can_view_with_scope hides a creator's own 'circle' meetup — are_synced(self, self) is false.)
  IF EXISTS (SELECT label, id FROM kan721_ids WHERE phase = 'new' EXCEPT SELECT label, id FROM kan721_ids WHERE phase = 'old')
     OR EXISTS (SELECT label, id FROM kan721_ids WHERE phase = 'old' EXCEPT SELECT label, id FROM kan721_ids WHERE phase = 'new') THEN
    RAISE EXCEPTION 'B FAIL: v_meetup_list id sets differ new vs old';
  END IF;
  v_union := (SELECT count(DISTINCT id) FROM kan721_ids WHERE phase = 'new');
  IF v_union = 0 OR v_union <> (SELECT count(DISTINCT id) FROM kan721_ids WHERE phase = 'old') THEN
    RAISE EXCEPTION 'B FAIL: union of visible meetups differs new % vs old', v_union;
  END IF;
  -- B. v_meetup_counts values equal legacy, per meetup, per viewer.
  SELECT count(*), count(*) FILTER (WHERE n.meetup_id IS NULL OR o.meetup_id IS NULL
                                       OR (n.going, n.interested, n.declined) IS DISTINCT FROM (o.going, o.interested, o.declined))
    INTO v_cmp, v_bad
    FROM (SELECT * FROM kan721_cnt WHERE phase = 'new') n
    FULL JOIN (SELECT * FROM kan721_cnt WHERE phase = 'old') o ON o.label = n.label AND o.meetup_id = n.meetup_id;
  IF v_bad <> 0 OR v_cmp = 0 THEN
    RAISE EXCEPTION 'B FAIL: v_meetup_counts values differ new vs old on % of % (viewer, meetup) pairs', v_bad, v_cmp;
  END IF;
  -- B. counts are not inflated: they equal a direct aggregate over meetup_rsvps.
  SELECT count(*) INTO v_bad
    FROM kan721_cnt c
    JOIN (SELECT meetup_id, sum((status = 'going')::int) g, sum((status = 'interested')::int) i, sum((status = 'declined')::int) d
            FROM public.meetup_rsvps GROUP BY meetup_id) x ON x.meetup_id = c.meetup_id
   WHERE c.phase = 'new' AND (c.going, c.interested, c.declined) IS DISTINCT FROM (x.g, x.i, x.d);
  IF v_bad <> 0 THEN
    RAISE EXCEPTION 'B FAIL: % v_meetup_counts rows differ from a direct meetup_rsvps aggregate (inflation)', v_bad;
  END IF;
  RAISE NOTICE 'B PASS counts and id sets equal legacy for every viewer (union % of % meetups, each once per viewer); 0 game ids; v_meetup_counts equal legacy on % (viewer, meetup) pairs and equal a direct meetup_rsvps aggregate (no inflation)',
    v_union, v_meetups, v_cmp;

  -- D. per-viewer row SET (full row text incl. viewer flags and nulls) identical, API roles
  FOR r IN SELECT n.view, n.label, n.n, n.row_md5 = o.row_md5 AS eq
             FROM kan721_rows n JOIN kan721_rows o ON o.phase = 'old' AND o.view = n.view AND o.label = n.label
            WHERE n.phase = 'new' ORDER BY n.view, n.label LOOP
    IF NOT r.eq THEN RAISE EXCEPTION 'D FAIL: % rows for viewer % differ new vs old', r.view, r.label; END IF;
    RAISE NOTICE 'D  ok % viewer=% rows=%', r.view, r.label, CASE WHEN r.n < 0 THEN 'permission denied (both phases)' ELSE r.n::text END;
  END LOOP;
  IF (SELECT count(*) FROM kan721_rows WHERE phase = 'new') <> 2 * (SELECT count(*) FROM kan721_users) THEN
    RAISE EXCEPTION 'D FAIL: missing viewer snapshots';
  END IF;
  RAISE NOTICE 'D PASS every viewer (anon, stranger, admin, blocker, blocked, circle friend, rsvper, every creator) sees the identical row set, as anon/authenticated';

  -- F. plan: one events join per legacy meetups read, never in a subplan; no new subplans
  FOR r IN SELECT n.view, n.events_scans, n.meetups_scans AS ms_new, o.meetups_scans AS ms_old, n.events_in_subplan,
                  n.events_under_join, n.subplans AS sp_new, o.subplans AS sp_old, o.events_scans AS es_old
             FROM kan721_plan n JOIN kan721_plan o ON o.phase = 'old' AND o.view = n.view WHERE n.phase = 'new' LOOP
    IF r.es_old <> 0 OR r.ms_new <> r.ms_old OR r.events_scans <> r.ms_old OR r.events_in_subplan <> 0
       OR r.events_under_join <> r.events_scans OR r.sp_new <> r.sp_old THEN
      RAISE EXCEPTION 'F FAIL: % plan events_scans=% (old 0? %) meetups new=% old=% in_subplan=% under_join=% subplans new=% old=%',
        r.view, r.events_scans, r.es_old, r.ms_new, r.ms_old, r.events_in_subplan, r.events_under_join, r.sp_new, r.sp_old;
    END IF;
    RAISE NOTICE 'F  ok % events scans=% (= legacy meetups scans %, each a join), in subplan=0, subplans new=% old=%',
      r.view, r.events_scans, r.ms_old, r.sp_new, r.sp_old;
  END LOOP;
  RAISE NOTICE 'F PASS one join to public.events per meetups read (v_meetup_list: its own + the one inside v_meetup_counts), no per-row events lookup, no added subplans';
END
$cmp$;

-- ---------------------------------------------------------------------------------------------------------
-- T5. Re-apply the migration (round trip), then verify E
-- ---------------------------------------------------------------------------------------------------------
\ir ../../migrations/20261104100200_kan714_b02_views_meetup_list_counts.sql

BEGIN; SELECT pg_temp.kan721_snapshot('reapplied'); COMMIT;

DO $e$
BEGIN
  IF EXISTS (SELECT 1 FROM kan721_meta n JOIN kan721_meta r ON r.phase = 'reapplied' AND r.view = n.view
              WHERE n.phase = 'new' AND (n.def <> r.def OR n.sig <> r.sig OR n.acl <> r.acl OR n.opts <> r.opts OR NOT r.reads_events)) THEN
    RAISE EXCEPTION 'E FAIL: re-applied definitions differ from the first application';
  END IF;
  IF (SELECT count(DISTINCT (meetups_md5, events_md5, rsvps_md5, games_md5)) FROM kan721_data) <> 1 THEN
    RAISE EXCEPTION 'E FAIL: table data changed across apply/rollback/re-apply/probes';
  END IF;
  IF EXISTS (SELECT 1 FROM kan721_rows n JOIN kan721_rows r ON r.phase = 'reapplied' AND r.view = n.view AND r.label = n.label
              WHERE n.phase = 'new' AND n.row_md5 <> r.row_md5) THEN
    RAISE EXCEPTION 'E FAIL: re-applied view rows differ';
  END IF;
  RAISE NOTICE 'E PASS rollback restored the old definitions (read meetups, same signature/ACL/reloptions), meetups/events/meetup_rsvps/games data identical across all phases, re-apply round-trips';
  RAISE NOTICE 'KAN-721 ALL PASS';
END
$e$;
