-- KAN-722 (KAN-714 piece B03) — v_rateable_after_game / v_host_weekly_metrics / v_game_rating read shared facts
-- from public.events. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end: no data survives.
--
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|pass=|fail=, plus #PLAN| and #FINGERPRINT| lines.
--
-- Precondition: 20261104100700_kan714_b07_sport_overview_counts.sql (KAN-726, B07) is applied. B07 owns the
-- v_host_weekly_metrics repoint; B03 does not touch that view. Every v_host_weekly_metrics check below therefore
-- asserts the B03+B07 CHAIN result (reads events, shape unchanged) regardless of :expect.
-- Variable :expect selects which image of v_rateable_after_game is asserted:
--   post (default) — 20261104100300_kan714_b03_views_rating_host_metrics.sql applied.
--   pre            — legacy pre-image (B03 not applied, or after rollback_kan714_b03.sql).
-- RED/GREEN protocol (commands in the KAN-722 report):
--   chain + B07, no B03,      expect=post  -> FAIL lines (D1, X1, P1)               RED
--   chain + B03 + B07,        expect=post  -> 0 FAIL                               GREEN
--   chain + B03 + B07 + rollback, expect=pre -> 0 FAIL, #FINGERPRINT| equal to the pre-migration DB
--
-- Groups: S shape/attributes, D column dependencies (provenance in the catalogue), L legacy parity,
--         E seeded semantics (ended / not ended / cancelled / meetup with NULL end), A access,
--         M compat-mirror path, X EXPLAIN shape, P provenance (events made to disagree with legacy).
\set ON_ERROR_STOP 1
\if :{?expect}
\else
  \set expect post
\endif
BEGIN;
SELECT set_config('kan722.expect', :'expect', true);
CREATE TEMP TABLE res (n serial, id text, ok boolean, detail text);
GRANT INSERT, SELECT ON res TO anon, authenticated;
GRANT USAGE ON SEQUENCE res_n_seq TO anon, authenticated;

CREATE FUNCTION pg_temp.post() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('kan722.expect') = 'post' $$;
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    v := 'ERR ' || s;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, ok, detail)
  VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
CREATE FUNCTION pg_temp.deps(p_view text) RETURNS text LANGUAGE sql AS $$
  SELECT string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname)
    FROM pg_rewrite rw
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
    JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = ('public.' || p_view)::regclass
$$;
CREATE FUNCTION pg_temp.sig(p_view text) RETURNS text LANGUAGE sql AS $$
  SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum))
    FROM pg_attribute a WHERE a.attrelid = ('public.' || p_view)::regclass AND a.attnum > 0 AND NOT a.attisdropped
$$;
CREATE FUNCTION pg_temp.plan(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE l text; o text := '';
BEGIN
  FOR l IN EXECUTE 'EXPLAIN (COSTS OFF) ' || p_sql LOOP o := o || l || E'\n'; END LOOP;
  RETURN o;
END $$;
CREATE FUNCTION pg_temp.cnt(p_hay text, p_re text) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM regexp_matches(p_hay, p_re, 'g')
$$;

-- Data fingerprint of every table the three views read, taken BEFORE this script seeds anything.
-- The runner compares it between the pre-migration DB and the rolled-back DB (data intact).
SELECT '#FINGERPRINT|' || md5(
         (SELECT coalesce(string_agg(g::text, '|' ORDER BY g.id), '') FROM public.games g) ||
         (SELECT coalesce(string_agg(e::text, '|' ORDER BY e.id), '') FROM public.events e) ||
         (SELECT coalesce(string_agg(r::text, '|' ORDER BY r.game_id, r.profile_id), '') FROM public.game_roster r) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.game_id), '') FROM public.game_rating_aggregate x)) AS fingerprint;

-- ---------------------------------------------------------------- legacy reference (the pre-image, verbatim, on games)
CREATE TEMP VIEW legacy_rateable AS
 WITH ctx AS (SELECT g.id AS game_id, g.creator_user_id AS host_user_id, g.end_at FROM public.games g)
 SELECT c.game_id, rr.user_id AS you_user_id, r.user_id AS ratee_user_id,
        CASE WHEN r.user_id = (SELECT ctx.host_user_id FROM ctx WHERE ctx.game_id = c.game_id) THEN 'organiser'::text
             ELSE 'player'::text END AS ratee_role
   FROM ctx c
   JOIN public.game_roster rr ON rr.game_id = c.game_id AND rr.status = 'active'::text AND rr.user_id = auth.uid()
   JOIN public.game_roster r ON r.game_id = c.game_id AND r.status = 'active'::text
  WHERE r.user_id <> auth.uid() OR (SELECT ctx.host_user_id FROM ctx WHERE ctx.game_id = c.game_id) <> auth.uid();
CREATE TEMP VIEW legacy_host AS
 WITH g AS (SELECT g.id, g.creator_user_id AS host_user_id, date_trunc('week'::text, g.start_at)::date AS week_start,
                   date_part('isoyear'::text, g.start_at)::integer AS isoy, date_part('week'::text, g.start_at)::integer AS isow,
                   g.capacity, g.is_cancelled FROM public.games g),
      r AS (SELECT game_roster.game_id, count(*) FILTER (WHERE game_roster.status = 'active'::text) AS active_cnt
              FROM public.game_roster GROUP BY game_roster.game_id),
      m AS (SELECT g.host_user_id AS user_id, g.isoy, g.isow, count(*) FILTER (WHERE NOT g.is_cancelled) AS games_hosted,
                   round(avg(GREATEST(0.0, LEAST(1.0, COALESCE(r.active_cnt::numeric, 0::numeric) / NULLIF(g.capacity, 0)::numeric))), 3) AS fill_rate
              FROM g LEFT JOIN r ON r.game_id = g.id GROUP BY g.host_user_id, g.isoy, g.isow)
 SELECT user_id, isoy, isow, games_hosted, fill_rate FROM m;
CREATE TEMP VIEW legacy_rating AS
 SELECT g.id AS game_id, gra.composite_score, gra.event_count, gra.dim_sums, gra.dim_counts, gra.last_event_at
   FROM public.games g LEFT JOIN public.game_rating_aggregate gra ON gra.game_id = g.id;

-- ---------------------------------------------------------------- seed (normal write path: KAN-712 guard writes events first)
-- Users a1..a5 (profiles b1..b5). Week of 2031-03-03 (Mon). G1 ended, G2 not ended, G3 ended+cancelled, G4 host off roster.
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled)
VALUES
 ('72200000-0000-0000-0000-000000000001', 'B03 G1 ended',     '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  now() - interval '3 hours', now() - interval '1 hour', 4, 'public', 'open', '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 1, 10, 'pickup', false),
 ('72200000-0000-0000-0000-000000000002', 'B03 G2 not ended', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  now() + interval '2 days', now() + interval '2 days 2 hours', 4, 'public', 'open', '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 1, 10, 'pickup', false),
 ('72200000-0000-0000-0000-000000000003', 'B03 G3 cancelled', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  now() - interval '5 hours', now() - interval '4 hours', 4, 'public', 'open', '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 1, 10, 'pickup', true),
 ('72200000-0000-0000-0000-000000000004', 'B03 G4 host off roster', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  timestamptz '2031-03-04 10:00+00', timestamptz '2031-03-04 11:00+00', 10, 'public', 'open', '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 1, 10, 'pickup', false);
INSERT INTO public.game_roster (game_id, user_id, profile_id, status) VALUES
 ('72200000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'active'),
 ('72200000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'active'),
 ('72200000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'active'),
 ('72200000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000b5', 'left'),
 ('72200000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'active'),
 ('72200000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'active'),
 ('72200000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'active'),
 ('72200000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'active'),
 ('72200000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'active'),
 ('72200000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'active');
-- A meetup by a1 with a NULL end_at: none of the three views covers meetups, so it must appear nowhere.
INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at, listing_visibility,
                            rsvp_policy, sport_id, geo_location_id, area_id, capacity, is_cancelled, location_name, is_indoor)
VALUES ('72200000-0000-0000-0001-000000000001', 'B03 meetup null end', 'd', '00000000-0000-0000-0000-0000000000b1',
        '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', timestamptz '2031-03-05 10:00+00', NULL,
        'public', 'open', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1',
        '00000000-0000-0000-0000-0000000000c1', 10, false, 'Here', false);

-- ---------------------------------------------------------------- S: shape and attributes (both images)
SELECT pg_temp.chk('S1 column signatures (rateable, host, rating)',
  pg_temp.sig('v_rateable_after_game') || ',' || pg_temp.sig('v_host_weekly_metrics') || ',' || pg_temp.sig('v_game_rating'),
  '1e6a11420e215a3f621928c055996116,1d76ace9f1cfce7fda0d9ec3ad7c065f,98e6f13a1a9a3f74467e722395688334');
SELECT pg_temp.chk('S2 owner / reloptions / ACL unchanged',
  (SELECT string_agg(c.relname || ':' || pg_get_userbyid(c.relowner) || ':' || coalesce(array_to_string(c.reloptions, ';'), '-')
                     || ':' || coalesce(c.relacl::text, '-'), ' ' ORDER BY c.relname)
     FROM pg_class c WHERE c.oid IN ('public.v_rateable_after_game'::regclass, 'public.v_host_weekly_metrics'::regclass,
                                    'public.v_game_rating'::regclass)),
  'v_game_rating:postgres:-:{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres,anon=xt/postgres,authenticated=xt/postgres} '
  || 'v_host_weekly_metrics:postgres:-:{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres,anon=xt/postgres,authenticated=xt/postgres} '
  || 'v_rateable_after_game:postgres:-:{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres,anon=rxt/postgres,authenticated=rxt/postgres}');

-- ---------------------------------------------------------------- D: catalogue provenance
SELECT pg_temp.chk('D1 v_rateable_after_game column dependencies', pg_temp.deps('v_rateable_after_game'),
  CASE WHEN pg_temp.post()
       THEN 'events.creator_user_id,events.end_at,events.event_type,events.id,game_roster.game_id,game_roster.status,game_roster.user_id,games.event_id,games.id'
       ELSE 'game_roster.game_id,game_roster.status,game_roster.user_id,games.creator_user_id,games.end_at,games.id' END);
SELECT pg_temp.chk('D2 v_host_weekly_metrics column dependencies after B03+B07 (B07 owns the repoint)', pg_temp.deps('v_host_weekly_metrics'),
  'events.capacity,events.creator_user_id,events.event_type,events.id,events.is_cancelled,events.start_at,game_roster.game_id,game_roster.status,games.event_id,games.id');
SELECT pg_temp.chk('D3 v_game_rating reads only games.id + aggregate (UNCHANGED by design)', pg_temp.deps('v_game_rating'),
  'game_rating_aggregate.composite_score,game_rating_aggregate.dim_counts,game_rating_aggregate.dim_sums,game_rating_aggregate.event_count,game_rating_aggregate.game_id,game_rating_aggregate.last_event_at,games.id');

SELECT pg_temp.chk('D4 v_game_rating has no shared-fact column to move (no start/end/cancel/creator output)',
  (SELECT count(*)::text FROM pg_attribute a WHERE a.attrelid = 'public.v_game_rating'::regclass AND a.attnum > 0
      AND NOT a.attisdropped AND a.attname ~ '(start|end|cancel|creator)'), '0');

-- ---------------------------------------------------------------- L: legacy parity (whole population, as the owner, per rater)
-- Raters: every user on any active roster + an outsider + NULL (anon). Diff must be empty both ways, counts equal.
DO $l1$
DECLARE u uuid; d int := 0; nv bigint; nl bigint; tv bigint := 0; tl bigint := 0;
BEGIN
  FOR u IN SELECT DISTINCT user_id FROM public.game_roster UNION SELECT '00000000-0000-0000-0000-0000000000a4'::uuid LOOP
    PERFORM set_config('request.jwt.claim.sub', u::text, true);
    SELECT count(*) INTO nv FROM public.v_rateable_after_game;
    SELECT count(*) INTO nl FROM legacy_rateable;
    tv := tv + nv; tl := tl + nl;
    d := d + (SELECT count(*) FROM ((SELECT * FROM public.v_rateable_after_game EXCEPT ALL SELECT * FROM legacy_rateable)
                              UNION ALL (SELECT * FROM legacy_rateable EXCEPT ALL SELECT * FROM public.v_rateable_after_game)) x);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO res (id, ok, detail) VALUES ('L1 v_rateable_after_game == legacy for every rater', d = 0 AND tv = tl AND tv > 0,
    format('diff=%s view_rows=%s legacy_rows=%s', d, tv, tl));
END $l1$;
SELECT pg_temp.chk('L2 v_host_weekly_metrics == legacy (diff both ways, count)',
  (SELECT count(*) FROM ((SELECT * FROM public.v_host_weekly_metrics EXCEPT ALL SELECT * FROM legacy_host)
                    UNION ALL (SELECT * FROM legacy_host EXCEPT ALL SELECT * FROM public.v_host_weekly_metrics)) x)::text
   || ':' || ((SELECT count(*) FROM public.v_host_weekly_metrics) = (SELECT count(*) FROM legacy_host))::text, '0:true');
SELECT pg_temp.chk('L3 v_game_rating == legacy (diff both ways, count)',
  (SELECT count(*) FROM ((SELECT * FROM public.v_game_rating EXCEPT ALL SELECT * FROM legacy_rating)
                    UNION ALL (SELECT * FROM legacy_rating EXCEPT ALL SELECT * FROM public.v_game_rating)) x)::text
   || ':' || ((SELECT count(*) FROM public.v_game_rating) = (SELECT count(*) FROM public.games))::text, '0:true');
SELECT pg_temp.chk('L4 no doubled rows (host key unique; rating one row per game)',
  ((SELECT count(*) FROM public.v_host_weekly_metrics)
     = (SELECT count(*) FROM (SELECT DISTINCT user_id, isoy, isow FROM public.v_host_weekly_metrics) k))::text || ':' ||
  ((SELECT count(*) FROM public.v_game_rating) = (SELECT count(DISTINCT game_id) FROM public.v_game_rating))::text, 'true:true');

-- ---------------------------------------------------------------- E: seeded semantics (literal expectations, not recomputed)
-- The view carries NO end/cancel filter in the pre-image; ended, not-ended and cancelled games all list identically.
-- Pre-image quirk, preserved: a NON-host rater also gets a self-row (WHERE r.user_id <> uid OR host <> uid).
SELECT pg_temp.chk('E1 a2 rateables: G1 ended, G2 not ended, G3 cancelled, G4 host off roster',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$SELECT string_agg(right(game_id::text, 1) || ':' || right(ratee_user_id::text, 2) || ':' || ratee_role, ' '
                         ORDER BY game_id, ratee_user_id)
         FROM public.v_rateable_after_game WHERE game_id::text LIKE '72200000-%'$q$),
  '1:a1:organiser 1:a2:player 1:a3:player 2:a1:organiser 2:a2:player 3:a1:organiser 3:a2:player 4:a2:player 4:a3:player');
SELECT pg_temp.chk('E2 host a1 rates own players, never self (G1..G3)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$SELECT string_agg(right(game_id::text, 1) || ':' || right(ratee_user_id::text, 2) || ':' || ratee_role, ' '
                         ORDER BY game_id, ratee_user_id)
         FROM public.v_rateable_after_game WHERE game_id::text LIKE '72200000-%'$q$),
  '1:a2:player 1:a3:player 2:a2:player 3:a2:player');
SELECT pg_temp.chk('E3 left roster member a5 sees nothing and is never a ratee',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a5',
    $q$SELECT count(*)::text FROM public.v_rateable_after_game WHERE game_id::text LIKE '72200000-%'$q$) || ':' ||
  (SELECT count(*) FILTER (WHERE ratee_user_id = '00000000-0000-0000-0000-0000000000a5')::text FROM (
     SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true)) s,
     LATERAL (SELECT * FROM public.v_rateable_after_game WHERE game_id::text LIKE '72200000-%') v), '0:0');
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT pg_temp.chk('E4 host week 2031-W10: G4 only (1 hosted, fill 2/10)',
  (SELECT games_hosted || ':' || fill_rate FROM public.v_host_weekly_metrics
    WHERE user_id = '00000000-0000-0000-0000-0000000000a1' AND isoy = 2031 AND isow = 10), '1:0.200');
SELECT pg_temp.chk('E5 meetup (NULL end_at) appears in no view',
  ((SELECT count(*) FROM public.v_game_rating WHERE game_id = '72200000-0000-0000-0001-000000000001')
   + (SELECT count(*) FROM (SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true)) s,
        LATERAL (SELECT 1 FROM public.v_rateable_after_game WHERE game_id = '72200000-0000-0000-0001-000000000001') v))::text, '0');
SELECT set_config('request.jwt.claim.sub', '', true);

-- ---------------------------------------------------------------- A: access parity
SELECT pg_temp.chk('A1 outsider a4 sees nothing extra on seeded games',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a4',
    $q$SELECT count(*)::text FROM public.v_rateable_after_game WHERE game_id::text LIKE '72200000-%'$q$), '0');
SELECT pg_temp.chk('A2 anon sees zero rateable rows', pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.v_rateable_after_game'), '0');
SELECT pg_temp.chk('A3 authenticated row count == owner row count for a2 (owner view still readable)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a2', 'SELECT count(*)::text FROM public.v_rateable_after_game'),
  (SELECT count(*)::text FROM (SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true)) s,
     LATERAL (SELECT 1 FROM public.v_rateable_after_game) v));
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT pg_temp.chk('A4 API roles still denied v_host_weekly_metrics / v_game_rating / events',
  pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.v_host_weekly_metrics') || ','
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.v_host_weekly_metrics') || ','
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.v_game_rating') || ','
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.events'),
  'ERR 42501,ERR 42501,ERR 42501,ERR 42501');
SELECT pg_temp.chk('A5 events posture unchanged (ACL, FORCE RLS, zero policies)',
  (SELECT coalesce(relacl::text, '-') || ':' || relrowsecurity || ':' || relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
  || ':' || (SELECT count(*) FROM pg_policy WHERE polrelid = 'public.events'::regclass),
  '{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres}:true:true:0');

-- ---------------------------------------------------------------- X: EXPLAIN shape
-- One events scan per view, joined (no per-row lookup into events). The rateable view keeps exactly the pre-image's
-- two scalar SubPlans over the materialised ctx CTE (pre-existing, not added here).
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true);
SELECT '#PLAN|v_rateable_after_game|' || replace(pg_temp.plan('SELECT * FROM public.v_rateable_after_game'), E'\n', E'\n#PLAN|  ');
SELECT '#PLAN|v_host_weekly_metrics|' || replace(pg_temp.plan('SELECT * FROM public.v_host_weekly_metrics'), E'\n', E'\n#PLAN|  ');
SELECT pg_temp.chk('X1 rateable plan: events scans, SubPlans, CTE scans of ctx',
  (WITH p AS (SELECT pg_temp.plan('SELECT * FROM public.v_rateable_after_game') t)
   SELECT pg_temp.cnt(t, ' on events\s') || ':' || pg_temp.cnt(t, '\n\s*SubPlan \d') || ':' || pg_temp.cnt(t, 'CTE Scan on ctx') FROM p),
  CASE WHEN pg_temp.post() THEN '1:2:3' ELSE '0:2:3' END);
-- X3: the single events scan sits inside the CTE ctx node (evaluated once), and no SubPlan NODE header (a line that
-- starts with "SubPlan n"; references like "(SubPlan 3)" inside a filter are not nodes) lies between them.
SELECT pg_temp.chk('X3 rateable: the events scan is in CTE ctx, not under a SubPlan',
  (WITH p AS (SELECT pg_temp.plan('SELECT * FROM public.v_rateable_after_game') t),
        q AS (SELECT t, position(E'CTE ctx\n' IN t) AS c, position(' on events ' IN t) AS e FROM p)
   SELECT CASE WHEN e = 0 THEN 'no-events-scan'
               WHEN c = 0 OR c > e THEN 'not-in-cte'
               WHEN substr(t, c, e - c) ~ '\n\s*SubPlan \d' THEN 'under-subplan'
               ELSE 'ok' END FROM q),
  CASE WHEN pg_temp.post() THEN 'ok' ELSE 'no-events-scan' END);
SELECT pg_temp.chk('X2 host plan: events scans, SubPlans',
  (WITH p AS (SELECT pg_temp.plan('SELECT * FROM public.v_host_weekly_metrics') t)
   SELECT pg_temp.cnt(t, ' on events\s') || ':' || pg_temp.cnt(t, '\n\s*SubPlan \d') FROM p),
  '1:0');
SELECT set_config('request.jwt.claim.sub', '', true);

-- ---------------------------------------------------------------- M: compat-mirror path (normal write through events)
-- Write events the supported way; the KAN-712 mirror copies it to games; both images must still equal legacy.
UPDATE public.events SET capacity = 5 WHERE id = (SELECT event_id FROM public.games WHERE id = '72200000-0000-0000-0000-000000000004');
SELECT pg_temp.chk('M1 mirror wrote games.capacity; host view follows (fill 2/5)',
  (SELECT capacity::text FROM public.games WHERE id = '72200000-0000-0000-0000-000000000004') || ':' ||
  (SELECT fill_rate::text FROM public.v_host_weekly_metrics
    WHERE user_id = '00000000-0000-0000-0000-0000000000a1' AND isoy = 2031 AND isow = 10), '5:0.400');

-- ---------------------------------------------------------------- P: provenance — events DISAGREES with legacy
-- Triggers off for this transaction only (session_replication_role = replica) so the mirror cannot reconcile.
SET LOCAL session_replication_role = replica;
-- P1: events says G1's host is a3; games still says a1.
UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a3'
 WHERE id = (SELECT event_id FROM public.games WHERE id = '72200000-0000-0000-0000-000000000001');
-- P2: events moves G4 to 2032-W20; games keeps 2031-W10.
UPDATE public.events SET start_at = timestamptz '2032-05-12 10:00+00', end_at = timestamptz '2032-05-12 11:00+00'
 WHERE id = (SELECT event_id FROM public.games WHERE id = '72200000-0000-0000-0000-000000000004');
-- P3/P4: events moves G2 to 2033-W02 (a week nobody else hosts), cancels it and sets capacity 2 (2 active on roster);
--        games keeps it live, capacity 4, in its original week.
UPDATE public.events SET start_at = timestamptz '2033-01-12 10:00+00', end_at = timestamptz '2033-01-12 11:00+00',
                         is_cancelled = true, capacity = 2
 WHERE id = (SELECT event_id FROM public.games WHERE id = '72200000-0000-0000-0000-000000000002');
SET LOCAL session_replication_role = origin;

SELECT pg_temp.chk('P1 rateable host role follows events.creator_user_id',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$SELECT string_agg(right(ratee_user_id::text, 2) || ':' || ratee_role, ' ' ORDER BY ratee_user_id)
         FROM public.v_rateable_after_game WHERE game_id = '72200000-0000-0000-0000-000000000001'$q$),
  CASE WHEN pg_temp.post() THEN 'a1:player a2:player a3:organiser' ELSE 'a1:organiser a2:player a3:player' END);
SELECT pg_temp.chk('P2 host week follows events.start_at (2032-W20 row exists, 2031-W10 gone)',
  (SELECT count(*) FROM public.v_host_weekly_metrics WHERE user_id = '00000000-0000-0000-0000-0000000000a1' AND isoy = 2032 AND isow = 20)::text
  || ':' || (SELECT count(*) FROM public.v_host_weekly_metrics WHERE user_id = '00000000-0000-0000-0000-0000000000a1' AND isoy = 2031 AND isow = 10)::text,
  '1:0');
SELECT pg_temp.chk('P3/P4 2033-W02 row follows events.is_cancelled (0 hosted) and events.capacity (fill 2/2)',
  (SELECT games_hosted || ':' || fill_rate FROM public.v_host_weekly_metrics
    WHERE user_id = '00000000-0000-0000-0000-0000000000a1' AND isoy = 2033 AND isow = 2),
  '0:1.000');

SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY n;
SELECT '#SUMMARY|expect=' || current_setting('kan722.expect') || '|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;
