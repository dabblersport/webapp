-- KAN-715 (verification fix 1, C1): v_game_card and v_my_games expose the parent identity public.games.event_id.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review.
--
-- Why: getGames / getMyGames (G3/G8) hydrate GameModel from v_game_card / v_my_games. Both views carry games.id
-- as `id` but not the parent events.id, so every card read produced eventId = null. The parent contract carries
-- BOTH identities: `id` stays games.id; the parent is a separate `event_id` column.
--
-- What this does, in ONE transaction:
--   0. Fail-closed precondition: applying role bypasses RLS; both views exist, owned by postgres, owner-run (NOT
--      security_invoker); neither already has an event_id column; games.event_id is NOT NULL + FK validated with no
--      NULL rows; the B01 post-image is in place (the same dependency md5 pins 20261105110000_kan714_events_parent_
--      reads_2.sql:62-63 holds) and the column signature is exactly B01's (54 / 21 columns, `id` first).
--   1. Pre-image (temp, ON COMMIT DROP): column signature, owner, ACL, reloptions.
--   2. CREATE OR REPLACE VIEW for both: the B01 definitions (20261104100100:120 and :205) byte-for-byte, with ONE
--      target appended as the LAST column: `g.event_id`. Every other column, join, WHERE and option is unchanged.
--      Postgres accepts the replace because existing columns keep name, type and position.
--   3. Post-conditions: new signature = pre-image signature + one trailing `event_id uuid`; owner, ACL, reloptions
--      identical; column 1 is still `id` and comes from public.games.id; the trailing event_id comes from
--      public.games.event_id; the dependency md5 is UNCHANGED (games.event_id was already a dependency through the
--      events join), so the KAN-714/2 pins still hold after this file.
--
-- Security: no GRANT, no REVOKE, no policy, no RPC, no DROP, no data mutation. Owner-run as before; event_id is
-- the games row's own FK column, visible to exactly the rows each view already returns.
--
-- Rollback: CREATE OR REPLACE VIEW cannot remove a column. Removing event_id needs DROP VIEW + re-create + re-grant
-- of the B01 definitions, which is destructive and is not scripted here; it is reserved under the DROP rules.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Fail-closed precondition
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
  h text;
  n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-715: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.games'::regclass AND conname IN ('games_event_id_not_null', 'games_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-715: games.event_id NOT NULL / FK not validated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-715: games rows with NULL event_id; a card would carry no parent';
  END IF;

  FOR r IN SELECT * FROM (VALUES
      ('public.v_game_card', 'd7c7c59344e52fff6ace74bec48b048f', 54, 'series_ends_on'),
      ('public.v_my_games',  '3b765364c7aed6faaee98043190936db', 21, 'my_roster_status')) AS t(v, want, ncols, lastcol)
  LOOP
    IF to_regclass(r.v) IS NULL THEN
      RAISE EXCEPTION 'KAN-715: % missing', r.v;
    END IF;
    IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = r.v::regclass) <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-715: % not owned by postgres', r.v;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class c, unnest(coalesce(c.reloptions, '{}')) o
                WHERE c.oid = r.v::regclass AND o ~* '^security_invoker=(true|on|1|yes)$') THEN
      RAISE EXCEPTION 'KAN-715: % is security_invoker; decision_required, stop', r.v;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = r.v::regclass AND attname = 'event_id' AND NOT attisdropped) THEN
      RAISE EXCEPTION 'KAN-715: % already has event_id (already applied?)', r.v;
    END IF;
    SELECT count(*) INTO n FROM pg_attribute WHERE attrelid = r.v::regclass AND attnum > 0 AND NOT attisdropped;
    IF n <> r.ncols
       OR (SELECT attname FROM pg_attribute WHERE attrelid = r.v::regclass AND attnum = 1) <> 'id'
       OR (SELECT attname FROM pg_attribute WHERE attrelid = r.v::regclass AND attnum = r.ncols) <> r.lastcol THEN
      RAISE EXCEPTION 'KAN-715: % column signature is not the B01 post-image (% columns)', r.v, n;
    END IF;
    -- Same dependency md5 as 20261105110000_kan714_events_parent_reads_2.sql:62-63.
    SELECT md5(coalesce(string_agg(x, ',' ORDER BY x), '')) INTO h FROM (
      SELECT DISTINCT format('%I.%I.%I', rn.nspname, rc.relname, a.attname) AS x
        FROM pg_rewrite rw
        JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
        JOIN pg_class rc ON rc.oid = d.refobjid
        JOIN pg_namespace rn ON rn.oid = rc.relnamespace
        JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
       WHERE rw.ev_class = r.v::regclass AND d.refobjid <> r.v::regclass) s;
    IF h IS DISTINCT FROM r.want THEN
      RAISE EXCEPTION 'KAN-715: % is not the B01 post-image (dependency md5 % expected %)', r.v, h, r.want;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan715_pre ON COMMIT DROP AS
SELECT c.relname,
       (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
       (SELECT count(*) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped)::int AS ncols,
       pg_get_userbyid(c.relowner) AS owner,
       c.relacl::text AS acl,
       coalesce(c.reloptions::text, '') AS opts
  FROM pg_class c
 WHERE c.oid IN ('public.v_game_card'::regclass, 'public.v_my_games'::regclass);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Views (B01 definitions verbatim; `g.event_id` appended as the last column)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    e.title,
    g.game_type,
    e.start_at,
    e.end_at,
    e.capacity,
    g.bench_slots,
    e.capacity + g.bench_slots AS total_slots,
    e.min_skill::integer AS min_skill,
    e.max_skill::integer AS max_skill,
    e.listing_visibility,
    e.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    e.is_cancelled,
    g.rules,
    e.created_at,
    e.updated_at,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    e.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    e.geo_location_id,
    e.area_id,
    a.name AS area_name,
    g.venue_space_id,
    e.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    e.joining_rule,
    e.cost_cover,
    ( SELECT count(*) AS count
           FROM public.game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    e.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM public.game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM public.profile_verifications pv
          WHERE pv.profile_id = e.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM public.organiser o
          WHERE o.profile_id = e.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM public.likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM public.favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM public.favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
    CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
    s2.ends_on AS series_ends_on,
    g.event_id
   FROM public.games g
     JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'::text
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN public.profiles cp ON cp.id = e.creator_profile_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN public.venues v ON v.id = COALESCE(vs.venue_id, e.venue_id)
     LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
     LEFT JOIN public.game_series s2 ON s2.id = g.series_id
  WHERE e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM public.game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR public.can_view_with_scope(auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id);

CREATE OR REPLACE VIEW public.v_my_games AS
 SELECT g.id,
    e.title,
    g.game_type,
    e.start_at,
    e.end_at,
    e.capacity,
    e.is_cancelled,
    e.listing_visibility,
    e.join_policy,
    e.created_at,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    e.creator_profile_id,
    e.creator_user_id,
    e.area_id,
    a.name AS area_name,
    e.venue_id,
    v.name_en AS venue_name,
    gr.status AS my_roster_status,
    g.event_id
   FROM public.games g
     JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'::text
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN public.venues v ON v.id = COALESCE(vs.venue_id, e.venue_id)
     LEFT JOIN public.game_roster gr ON gr.game_id = g.id AND gr.user_id = auth.uid()
  WHERE e.creator_user_id = auth.uid() OR gr.user_id = auth.uid();


-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  r record;
  v_now record;
  h text;
BEGIN
  IF (SELECT count(*) FROM kan715_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-715 post: pre-image incomplete';
  END IF;
  FOR r IN SELECT p.*, w.want FROM kan715_pre p
             JOIN (VALUES ('v_game_card', 'd7c7c59344e52fff6ace74bec48b048f'),
                          ('v_my_games',  '3b765364c7aed6faaee98043190936db')) AS w(relname, want) USING (relname)
  LOOP
    SELECT (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
              FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
           pg_get_userbyid(c.relowner) AS owner, c.relacl::text AS acl, coalesce(c.reloptions::text, '') AS opts
      INTO v_now
      FROM pg_class c WHERE c.oid = ('public.' || r.relname)::regclass;
    IF v_now.sig IS DISTINCT FROM r.sig || ',' || (r.ncols + 1) || ':event_id:uuid' THEN
      RAISE EXCEPTION 'KAN-715 post: % signature is not pre-image + trailing event_id: %', r.relname, v_now.sig;
    END IF;
    IF v_now.owner IS DISTINCT FROM r.owner OR v_now.acl IS DISTINCT FROM r.acl OR v_now.opts IS DISTINCT FROM r.opts THEN
      RAISE EXCEPTION 'KAN-715 post: % owner/ACL/reloptions changed', r.relname;
    END IF;

    -- Column provenance from the stored definition: first target g.id, last target g.event_id, FROM games g.
    IF pg_get_viewdef(('public.' || r.relname)::regclass) !~ '^\s*SELECT g\.id,'
       OR pg_get_viewdef(('public.' || r.relname)::regclass) !~ ',\s*g\.event_id\s+FROM \(*\s*(public\.)?games g\s' THEN
      RAISE EXCEPTION 'KAN-715 post: % target list is not (g.id, ..., g.event_id): %', r.relname,
        pg_get_viewdef(('public.' || r.relname)::regclass);
    END IF;

    -- Dependency md5 unchanged: games.event_id was already referenced by the events join.
    SELECT md5(coalesce(string_agg(x, ',' ORDER BY x), '')) INTO h FROM (
      SELECT DISTINCT format('%I.%I.%I', rn.nspname, rc.relname, a.attname) AS x
        FROM pg_rewrite rw
        JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
        JOIN pg_class rc ON rc.oid = d.refobjid
        JOIN pg_namespace rn ON rn.oid = rc.relnamespace
        JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
       WHERE rw.ev_class = ('public.' || r.relname)::regclass AND d.refobjid <> ('public.' || r.relname)::regclass) s;
    IF h IS DISTINCT FROM r.want THEN
      RAISE EXCEPTION 'KAN-715 post: % dependency md5 changed: % (KAN-714/2 pin %)', r.relname, h, r.want;
    END IF;
  END LOOP;
  RAISE NOTICE 'KAN-715: v_game_card and v_my_games expose event_id (last column); id stays games.id';
END
$post$;

COMMIT;
