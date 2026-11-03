-- KAN-721 (Events P2, KAN-714 piece B02): v_meetup_list and v_meetup_counts read SHARED columns from public.events.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review. Local proof:
-- supabase/tests/events_p2/kan714_b02_meetup_views.sql.
--
-- Pre-images (latest definitions in this repository):
--   v_meetup_counts  20260915120000_meetups_hardening.sql:136 (+ :145 ALTER VIEW ... SET (security_invoker = off))
--   v_meetup_list    20261008140000_game_price_meetup_setting.sql:18 (supersedes 20260915130000:16 and
--                    20261008120000:7; nothing later in migrations/ redefines either view)
--
-- File order: sorts after 20261104100100 (KAN-720, B01) and before 20261104110000 (KAN-713 location triggers).
-- Neither ordering is load-bearing: this file does not read the B01 views, and the location triggers change
-- only how writes derive geo/area — both views read stored values, which the KAN-712 compat mirror keeps
-- identical on meetups and events. The guard therefore requires the KAN-713 access helpers (20261104100000)
-- only, exactly as B01 does.
--
-- What this does, in ONE transaction:
--   0. Stage guard: public.events present (KAN-710) with FORCE RLS; KAN-712 cutover live (compat mirror on
--      events, legacy guard on meetups, meetups.event_id NOT NULL + FK validated, no NULL event_id); KAN-713
--      access helpers live; applying role bypasses RLS; both views exist, are owner-run (NOT
--      security_invoker) and owned by postgres; and NO meetup row disagrees with its events parent on any
--      column this file starts reading from events (so the rewrite cannot change a single value).
--   1. Pre-image capture (temp table, ON COMMIT DROP): column signature, owner, ACL, reloptions.
--   2. CREATE OR REPLACE VIEW for both (v_meetup_counts first: v_meetup_list reads it). Every SHARED column
--      is read from public.events, joined `e.id = m.event_id AND e.event_type = 'meetup'` (INNER:
--      meetups.event_id is NOT NULL and FK-validated since KAN-712 cutover, so no meetup is lost; events.id is
--      the PK, so the join yields at most one parent per meetup and cannot inflate a row or a count; the type
--      filter means a game parent can never surface). meetups.id stays the row id; v_meetup_counts.meetup_id
--      stays meetup_rsvps.meetup_id. Subqueries, predicates, joins and ORDER BY are otherwise the previous
--      definitions with m.<shared> replaced by e.<shared>; no subquery is added. v_meetup_counts keeps
--      WITH (security_invoker = off) explicitly: CREATE OR REPLACE VIEW replaces reloptions, and the
--      pre-image carries that option.
--   3. Post-conditions: column signature, owner, ACL, reloptions identical to the pre-image; neither view
--      references a meetups column that public.events also owns (except id) nor meetups.rsvp_policy; both
--      depend on public.events.
--
-- Security: both views are owner-run (postgres, BYPASSRLS) exactly as before — security_invoker is NOT on for
-- either (asserted). API roles therefore need no grant on public.events, and none is added. No GRANT, no
-- REVOKE, no policy, no RPC, no DROP, no data mutation. No RPC depends on either view's definition.
--
-- Columns (per view) — events (e.) vs meetups (m.):
--   v_meetup_counts  e.: creator_user_id, listing_visibility (WHERE gate only).
--                    r./m.: meetup_id (r.), going/interested/declined counts (r.); m. only as the join key.
--   v_meetup_list    e.: title, start_at, end_at, capacity, listing_visibility, join_policy AS rsvp_policy,
--                        is_cancelled, created_at, updated_at, creator_profile_id, sport_id, area_id, venue_id,
--                        geo_location_id, min_skill::int, max_skill::int, joining_rule, cost_cover; the
--                        profiles/sports/areas/venues joins, both venue_spaces subqueries, the WHERE gate
--                        (e.creator_user_id, e.listing_visibility) and ORDER BY (e.updated_at, e.created_at).
--                    m.: id, description, members_only, vibe_key, location_name, is_indoor (setting_is_indoor
--                        fallback); favorites / meetup_rsvps / v_meetup_counts keyed on m.id.
--
-- Named mappings (value-preserving; the guard proves equality on every row before replacing):
--   rsvp_policy        <- events.join_policy. KAN-711 maps m.rsvp_policy -> join_policy verbatim; both CHECKs
--                         allow exactly ('open','request','invite','link','closed') for meetups.
--   listing_visibility <- events.listing_visibility. Same meetup value set ('public','circle','invite','link',
--                         'hidden') on both CHECKs; copied verbatim.
--   title              <- events.title. Nullable on events, but events_meetup_title_check requires NOT NULL and
--                         3..80 chars for meetups; output column type text either way.
--   capacity / end_at  <- events. NULL is copied, never defaulted or inferred (KAN-711 map).
--   min_skill/max_skill<- events smallint, cast back to integer (view column type unchanged).
--   meta.venue_space_id is not read by either view (it is not copied to events and stays on meetups).

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
  v_drift bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-721: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-721: public.events missing (KAN-710 not applied)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND relrowsecurity AND relforcerowsecurity) THEN
    RAISE EXCEPTION 'KAN-721: public.events is not RLS-enabled + FORCE (KAN-710 security model changed; stop)';
  END IF;

  -- KAN-712 stage B (cutover) markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard')) AS t(tbl, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.tbl::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      RAISE EXCEPTION 'KAN-721: KAN-712 cutover not live (% on % missing or disabled)', r.tg, r.tbl;
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'KAN-721: KAN-712 write contract not applied (public.kan712_wrapped_rpcs missing)';
  END IF;
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.meetups'::regclass AND conname IN ('meetups_event_id_not_null', 'meetups_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-721: meetups.event_id NOT NULL / FK not validated (KAN-711 validate_links)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-721: meetups rows with NULL event_id; the INNER join would drop them';
  END IF;

  -- KAN-713 live: access helpers (20261104100000). See the header for why the location triggers are not required.
  IF to_regprocedure('public._can_view_game(uuid)') IS NULL
     OR to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-721: KAN-713 access helpers not live (20261104100000 not applied)';
  END IF;

  -- Both views exist, owned by postgres, owner-run (security_invoker NOT on). If either became
  -- security_invoker, API roles could not read public.events (FORCE RLS, no grants): decision required, stop.
  FOR r IN SELECT unnest(ARRAY['public.v_meetup_counts', 'public.v_meetup_list']) AS v LOOP
    IF to_regclass(r.v) IS NULL THEN
      RAISE EXCEPTION 'KAN-721: % missing', r.v;
    END IF;
    IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = r.v::regclass) <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-721: % not owned by postgres', r.v;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class c, unnest(coalesce(c.reloptions, '{}')) o
                WHERE c.oid = r.v::regclass AND o ~* '^security_invoker=(true|on|1|yes)$') THEN
      RAISE EXCEPTION 'KAN-721: % is security_invoker; API roles cannot read public.events — decision_required, stop', r.v;
    END IF;
  END LOOP;

  -- Value equivalence: every meetup has exactly one meetup-typed parent and agrees with it on every column
  -- this file moves to events. If any row disagrees, switching the read would change a published value: stop.
  SELECT count(*) INTO v_drift
    FROM public.meetups m
    LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE e.id IS NULL
      OR (m.title, m.start_at, m.end_at, m.capacity, m.listing_visibility, m.rsvp_policy, m.is_cancelled,
          m.created_at, m.updated_at, m.creator_profile_id, m.creator_user_id, m.sport_id, m.area_id, m.venue_id,
          m.geo_location_id, m.min_skill, m.max_skill, m.joining_rule, m.cost_cover)
         IS DISTINCT FROM
         (e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.join_policy, e.is_cancelled,
          e.created_at, e.updated_at, e.creator_profile_id, e.creator_user_id, e.sport_id, e.area_id, e.venue_id,
          e.geo_location_id, e.min_skill::integer, e.max_skill::integer, e.joining_rule, e.cost_cover);
  IF v_drift <> 0 THEN
    RAISE EXCEPTION 'KAN-721: % meetups rows disagree with (or lack) their events parent on shared columns; reconcile first', v_drift;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan721_pre ON COMMIT DROP AS
SELECT c.relname,
       (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
       pg_get_userbyid(c.relowner) AS owner,
       c.relacl::text AS acl,
       coalesce(c.reloptions::text, '') AS opts
  FROM pg_class c
 WHERE c.oid IN ('public.v_meetup_counts'::regclass, 'public.v_meetup_list'::regclass);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Views
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_meetup_counts WITH (security_invoker = off) AS
 SELECT r.meetup_id,
    sum((r.status = 'going'::text)::integer) AS going_count,
    sum((r.status = 'interested'::text)::integer) AS interested_count,
    sum((r.status = 'declined'::text)::integer) AS declined_count
   FROM public.meetup_rsvps r
     JOIN public.meetups m ON m.id = r.meetup_id
     JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'::text
  WHERE public.can_view_owner(e.creator_user_id, e.listing_visibility) = true
  GROUP BY r.meetup_id;

CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    e.title,
    m.description,
    e.start_at,
    e.end_at,
    e.capacity,
    m.members_only,
    e.listing_visibility,
    e.join_policy AS rsvp_policy,
    e.is_cancelled,
    m.vibe_key,
    e.created_at,
    e.updated_at,
    e.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    e.area_id,
    a.name AS area_name,
    e.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    e.geo_location_id,
    e.min_skill::integer AS min_skill,
    e.max_skill::integer AS max_skill,
    e.joining_rule,
    e.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
        CASE
            WHEN auth.uid() IS NULL THEN '[]'::jsonb
            ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
               FROM ( SELECT r2.profile_id,
                        r2.updated_at
                       FROM public.meetup_rsvps r2
                      WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
                      ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
                     LIMIT 5) x
                 JOIN public.profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
        END AS attendee_avatars,
    ( SELECT bool_or(vs.indoor) AS bool_or
           FROM public.venue_spaces vs
          WHERE vs.venue_id = e.venue_id AND vs.is_active = true) AS venue_is_indoor,
    (( SELECT count(*) AS count
           FROM public.favorites f
          WHERE f.meetup_id = m.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM public.favorites f
          WHERE f.meetup_id = m.id AND f.user_id = auth.uid())) AS favourited_by_me,
    COALESCE(( SELECT bool_or(vs2.indoor)
           FROM public.venue_spaces vs2
          WHERE vs2.venue_id = e.venue_id AND vs2.is_active = true), m.is_indoor) AS setting_is_indoor
   FROM public.meetups m
     JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'::text
     LEFT JOIN public.profiles cp ON cp.id = e.creator_profile_id
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venues v ON v.id = e.venue_id
     LEFT JOIN public.v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN public.meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE public.can_view_owner(e.creator_user_id, e.listing_visibility) = true
  ORDER BY (COALESCE(e.updated_at, e.created_at)) DESC;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  r record;
  v_now record;
  v_bad text;
BEGIN
  IF (SELECT count(*) FROM kan721_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-721 post: pre-image incomplete';
  END IF;
  FOR r IN SELECT * FROM kan721_pre LOOP
    SELECT (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
              FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
           pg_get_userbyid(c.relowner) AS owner, c.relacl::text AS acl, coalesce(c.reloptions::text, '') AS opts
      INTO v_now
      FROM pg_class c WHERE c.oid = ('public.' || r.relname)::regclass;
    IF v_now.sig IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-721 post: % column signature changed: % -> %', r.relname, r.sig, v_now.sig;
    END IF;
    IF v_now.owner IS DISTINCT FROM r.owner OR v_now.acl IS DISTINCT FROM r.acl OR v_now.opts IS DISTINCT FROM r.opts THEN
      RAISE EXCEPTION 'KAN-721 post: % owner/ACL/reloptions changed (% % % -> % % %)', r.relname,
        r.owner, r.acl, r.opts, v_now.owner, v_now.acl, v_now.opts;
    END IF;

    -- Depends on public.events.
    IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                    WHERE rw.ev_class = ('public.' || r.relname)::regclass AND d.refobjid = 'public.events'::regclass) THEN
      RAISE EXCEPTION 'KAN-721 post: % does not read public.events', r.relname;
    END IF;

    -- No meetups column that events also owns is referenced (meetups.id, the subtype id, excepted), and not
    -- meetups.rsvp_policy (events.join_policy under another name).
    SELECT string_agg(DISTINCT a.attname, ',') INTO v_bad
      FROM pg_depend d
      JOIN pg_rewrite rw ON rw.oid = d.objid
      JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.relname)::regclass
       AND d.refobjid = 'public.meetups'::regclass
       AND a.attname <> 'id'
       AND (a.attname = 'rsvp_policy'
            OR a.attname IN (SELECT ea.attname FROM pg_attribute ea
                              WHERE ea.attrelid = 'public.events'::regclass AND ea.attnum > 0 AND NOT ea.attisdropped));
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-721 post: % still reads shared meetups columns: %', r.relname, v_bad;
    END IF;
  END LOOP;
  RAISE NOTICE 'KAN-721: v_meetup_counts and v_meetup_list now read shared columns from public.events';
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (manual; NOT executed by this migration). Restores the previous definitions verbatim:
-- v_meetup_counts from 20260915120000_meetups_hardening.sql:136-145 (CREATE + its ALTER VIEW), v_meetup_list
-- from 20261008140000_game_price_meetup_setting.sql:18. CREATE OR REPLACE keeps owner and ACL; the ALTER VIEW
-- restores v_meetup_counts' security_invoker=off reloption. No data is touched. Run as postgres: strip the
-- leading "-- " from the lines between the markers.
-- KAN721-ROLLBACK-BEGIN
-- BEGIN;
-- CREATE OR REPLACE VIEW public.v_meetup_counts AS
--  SELECT r.meetup_id,
--     sum((r.status = 'going')::integer) AS going_count,
--     sum((r.status = 'interested')::integer) AS interested_count,
--     sum((r.status = 'declined')::integer) AS declined_count
--    FROM public.meetup_rsvps r
--      JOIN public.meetups m ON m.id = r.meetup_id
--   WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
--   GROUP BY r.meetup_id;
-- ALTER VIEW public.v_meetup_counts SET (security_invoker = off);
--
-- CREATE OR REPLACE VIEW public.v_meetup_list AS
--  SELECT m.id,
--     m.title,
--     m.description,
--     m.start_at,
--     m.end_at,
--     m.capacity,
--     m.members_only,
--     m.listing_visibility,
--     m.rsvp_policy,
--     m.is_cancelled,
--     m.vibe_key,
--     m.created_at,
--     m.updated_at,
--     m.creator_profile_id,
--     cp.display_name AS creator_display_name,
--     cp.username AS creator_username,
--     cp.avatar_url AS creator_avatar_url,
--     m.sport_id,
--     s.sport_key,
--     s.name_en AS sport_name_en,
--     s.name_ar AS sport_name_ar,
--     s.emoji AS sport_emoji,
--     m.area_id,
--     a.name AS area_name,
--     m.venue_id,
--     v.name_en AS venue_name,
--     m.location_name,
--     m.geo_location_id,
--     m.min_skill,
--     m.max_skill,
--     m.joining_rule,
--     m.cost_cover,
--     COALESCE(c.going_count, 0::bigint) AS going_count,
--     COALESCE(c.interested_count, 0::bigint) AS interested_count,
--     COALESCE(c.declined_count, 0::bigint) AS declined_count,
--     att.status AS my_rsvp_status,
--         CASE
--             WHEN auth.uid() IS NULL THEN '[]'::jsonb
--             ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
--                FROM ( SELECT r2.profile_id,
--                         r2.updated_at
--                        FROM meetup_rsvps r2
--                       WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
--                       ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
--                      LIMIT 5) x
--                  JOIN profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
--         END AS attendee_avatars,
--     ( SELECT bool_or(vs.indoor) AS bool_or
--            FROM venue_spaces vs
--           WHERE vs.venue_id = m.venue_id AND vs.is_active = true) AS venue_is_indoor,
--     (( SELECT count(*) AS count
--            FROM favorites f
--           WHERE f.meetup_id = m.id))::integer AS favorite_count,
--     (EXISTS ( SELECT 1
--            FROM favorites f
--           WHERE f.meetup_id = m.id AND f.user_id = auth.uid())) AS favourited_by_me,
--     COALESCE(( SELECT bool_or(vs2.indoor)
--            FROM venue_spaces vs2
--           WHERE vs2.venue_id = m.venue_id AND vs2.is_active = true), m.is_indoor) AS setting_is_indoor
--    FROM meetups m
--      LEFT JOIN profiles cp ON cp.id = m.creator_profile_id
--      LEFT JOIN sports s ON s.id = m.sport_id
--      LEFT JOIN areas a ON a.id = m.area_id
--      LEFT JOIN venues v ON v.id = m.venue_id
--      LEFT JOIN v_meetup_counts c ON c.meetup_id = m.id
--      LEFT JOIN meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
--   WHERE can_view_owner(m.creator_user_id, m.listing_visibility) = true
--   ORDER BY (COALESCE(m.updated_at, m.created_at)) DESC;
-- COMMIT;
-- KAN721-ROLLBACK-END
