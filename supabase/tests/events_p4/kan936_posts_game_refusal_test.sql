-- KAN-936 item 1: a game-tied post from a client that cannot see the games row is refused with
-- P0001 game_not_found by trgfn_posts_set_geo, not a 23502 on geo_lat. The success path (a caller
-- that sees the game: service_role, RLS bypassed) still inherits geo/area from the game's event.
-- Live, BEGIN ... ROLLBACK: nothing persists. One row: string_agg of every check.
BEGIN;

SELECT set_config('t.uid', p.user_id::text, true), set_config('t.pid', p.id::text, true)
  FROM public.profiles p WHERE p.is_active AND p.user_id IS NOT NULL ORDER BY p.created_at LIMIT 1;
SELECT set_config('t.gid', g.id::text, true)
  FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
  JOIN public.geo_locations gl ON gl.id = e.geo_location_id
 ORDER BY e.created_at DESC LIMIT 1;
SELECT set_config('request.jwt.claims',
       json_build_object('sub', current_setting('t.uid'), 'role', 'authenticated')::text, true);

-- 1. authenticated: games has RLS on, so the row is not visible -> expect P0001 game_not_found
SET LOCAL ROLE authenticated;
DO $t$
DECLARE r text;
BEGIN
  INSERT INTO public.posts (author_user_id, author_profile_id, kind, visibility, body, game_id)
  VALUES (current_setting('t.uid')::uuid, current_setting('t.pid')::uuid, 'original', 'public',
          'kan936 probe', current_setting('t.gid')::uuid);
  r := 'auth_refused=FAIL(inserted)';
  PERFORM set_config('t.r1', r, true);
EXCEPTION WHEN OTHERS THEN
  r := CASE WHEN SQLSTATE = 'P0001' AND SQLERRM = 'game_not_found' THEN 'auth_refused=PASS'
            ELSE 'auth_refused=FAIL(' || SQLSTATE || ' ' || SQLERRM || ')' END;
  PERFORM set_config('t.r1', r, true);
END $t$;
RESET ROLE;

-- 2. service_role sees the game -> success path unchanged: geo inherited from the event
SET LOCAL ROLE service_role;
DO $t$
DECLARE v_lat double precision; v_area uuid; v_ev_area uuid;
BEGIN
  INSERT INTO public.posts (author_user_id, author_profile_id, kind, visibility, body, game_id)
  VALUES (current_setting('t.uid')::uuid, current_setting('t.pid')::uuid, 'original', 'public',
          'kan936 probe', current_setting('t.gid')::uuid)
  RETURNING geo_lat, area_id INTO v_lat, v_area;
  SELECT e.area_id INTO v_ev_area FROM public.games g JOIN public.events e ON e.id = g.event_id
   WHERE g.id = current_setting('t.gid')::uuid;
  PERFORM set_config('t.r2', CASE WHEN v_lat IS NOT NULL AND v_area IS NOT DISTINCT FROM v_ev_area
                                  THEN 'svc_success=PASS' ELSE 'svc_success=FAIL' END, true);
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('t.r2', 'svc_success=FAIL(' || SQLSTATE || ' ' || SQLERRM || ')', true);
END $t$;
RESET ROLE;

SELECT string_agg(x, ' | ') AS result
  FROM unnest(ARRAY[current_setting('t.r1', true), current_setting('t.r2', true)]) x;

ROLLBACK;
