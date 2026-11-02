-- KAN-722 rollback: restores the pre-image of v_rateable_after_game and v_host_weekly_metrics
-- (baseline 20260829080500_baseline_schema.sql:25639 / :25665, verbatim) after
-- 20261104100300_kan714_b03_views_rating_host_metrics.sql. v_game_rating was never changed.
-- Single transaction; no DROP, no CASCADE, no data mutation, no grant change.
-- CREATE OR REPLACE VIEW keeps owner, ACL and reloptions; asserted below.

BEGIN;

DO $guard$
DECLARE v text;
BEGIN
  SELECT string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname) INTO v
    FROM pg_rewrite rw
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
    JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class IN ('public.v_rateable_after_game'::regclass, 'public.v_host_weekly_metrics'::regclass)
     AND t.relname = 'events';
  IF v IS NULL THEN
    RAISE EXCEPTION 'KAN-722 rollback: post-image not present (views do not read events) — nothing to roll back';
  END IF;
END
$guard$;

CREATE TEMP TABLE kan722_rb_pre ON COMMIT DROP AS
  SELECT c.oid, c.relowner, c.relacl::text AS acl, c.reloptions FROM pg_class c
   WHERE c.oid IN ('public.v_rateable_after_game'::regclass, 'public.v_host_weekly_metrics'::regclass);

SET LOCAL search_path TO public, extensions;

CREATE OR REPLACE VIEW public.v_rateable_after_game AS
 WITH ctx AS (
         SELECT g.id AS game_id,
            g.creator_user_id AS host_user_id,
            g.end_at
           FROM public.games g
        )
 SELECT c.game_id,
    rr.user_id AS you_user_id,
    r.user_id AS ratee_user_id,
        CASE
            WHEN r.user_id = (( SELECT ctx.host_user_id
               FROM ctx
              WHERE ctx.game_id = c.game_id)) THEN 'organiser'::text
            ELSE 'player'::text
        END AS ratee_role
   FROM ctx c
     JOIN public.game_roster rr ON rr.game_id = c.game_id AND rr.status = 'active'::text AND rr.user_id = auth.uid()
     JOIN public.game_roster r ON r.game_id = c.game_id AND r.status = 'active'::text
  WHERE r.user_id <> auth.uid() OR (( SELECT ctx.host_user_id
           FROM ctx
          WHERE ctx.game_id = c.game_id)) <> auth.uid();

CREATE OR REPLACE VIEW public.v_host_weekly_metrics AS
 WITH g AS (
         SELECT g_1.id,
            g_1.creator_user_id AS host_user_id,
            date_trunc('week'::text, g_1.start_at)::date AS week_start,
            date_part('isoyear'::text, g_1.start_at)::integer AS isoy,
            date_part('week'::text, g_1.start_at)::integer AS isow,
            g_1.capacity,
            g_1.is_cancelled
           FROM public.games g_1
        ), r AS (
         SELECT game_roster.game_id,
            count(*) FILTER (WHERE game_roster.status = 'active'::text) AS active_cnt
           FROM public.game_roster
          GROUP BY game_roster.game_id
        ), m AS (
         SELECT g.host_user_id AS user_id,
            g.isoy,
            g.isow,
            count(*) FILTER (WHERE NOT g.is_cancelled) AS games_hosted,
            round(avg(GREATEST(0.0, LEAST(1.0, COALESCE(r.active_cnt::numeric, 0::numeric) / NULLIF(g.capacity, 0)::numeric))), 3) AS fill_rate
           FROM g
             LEFT JOIN r ON r.game_id = g.id
          GROUP BY g.host_user_id, g.isoy, g.isow
        )
 SELECT user_id,
    isoy,
    isow,
    games_hosted,
    fill_rate
   FROM m;

DO $post$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('v_rateable_after_game', '43f0f35181fd741e2f1cb6ac5e8e8c03'),
      ('v_host_weekly_metrics', '49ec8ddfcaac7104c744305dc6cdc1c4')) AS t(vw, dep)
  LOOP
    -- same hash method as the 20261105100000 pins: games/meetups/events column deps only
    SELECT md5(string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname)) INTO v
      FROM pg_rewrite rw
      JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
      JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
                     AND t.relname IN ('games', 'meetups', 'events')
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.vw)::regclass;
    IF v IS DISTINCT FROM r.dep THEN
      RAISE EXCEPTION 'KAN-722 rollback post: public.% dependency md5 % expected %', r.vw, v, r.dep;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_temp.kan722_rb_pre p JOIN pg_class c ON c.oid = p.oid
              WHERE c.relowner <> p.relowner OR c.relacl::text IS DISTINCT FROM p.acl
                 OR c.reloptions IS DISTINCT FROM p.reloptions) THEN
    RAISE EXCEPTION 'KAN-722 rollback post: owner / ACL / reloptions changed';
  END IF;
END
$post$;

COMMIT;
