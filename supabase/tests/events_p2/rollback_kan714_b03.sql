-- KAN-722 rollback: restores the pre-image of v_rateable_after_game (baseline
-- 20260829080500_baseline_schema.sql:25639, verbatim) after 20261104100300_kan714_b03_views_rating_host_metrics.sql.
-- v_game_rating was never changed. v_host_weekly_metrics is NOT B03's (B07 / KAN-726 owns its repoint and its
-- rollback) and is deliberately left as it is.
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
   WHERE rw.ev_class = 'public.v_rateable_after_game'::regclass
     AND t.relname = 'events';
  IF v IS NULL THEN
    RAISE EXCEPTION 'KAN-722 rollback: post-image not present (views do not read events) — nothing to roll back';
  END IF;
END
$guard$;

CREATE TEMP TABLE kan722_rb_pre ON COMMIT DROP AS
  SELECT c.oid, c.relowner, c.relacl::text AS acl, c.reloptions FROM pg_class c
   WHERE c.oid = 'public.v_rateable_after_game'::regclass;

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

DO $post$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('v_rateable_after_game', '43f0f35181fd741e2f1cb6ac5e8e8c03')) AS t(vw, dep)
  LOOP
    -- md5 of the games/meetups/events column deps of the pre-image
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
