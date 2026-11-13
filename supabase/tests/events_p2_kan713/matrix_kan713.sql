-- KAN-713 PERMISSION MATRIX. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
--
-- Prints one sorted line per cell:  actor|event|cell|value
-- Run it on the database BEFORE KAN-713, AFTER KAN-713, and AFTER rollback_kan713.sql; `diff` of the three
-- outputs must be empty (KAN713_CONTRACT.md "Permission matrix"). Errors are captured as ERR <sqlstate>.
--
-- Events: games G-pub (public/open), G-fol (followers/request), G-pri (private/invite), G-link (public/link)
--         meetups M-pub (public/open), M-cir (circle/request), M-inv (invite/invite), M-lnk (link/link),
--         M-hid (hidden/closed) -- every listing_visibility value each type allows.
-- Adversarial events: X-none (no such row), X-mtg-as-game (a meetup id through every game cell),
--         X-game-as-mtg (a game id through every meetup cell).
-- Actors: anon; authenticated as a1 owner, a2 non-member (pending join request on G-fol), a3 admin,
--         a4 member (roster / going everywhere), a5 follower + friend, a6 follower but BLOCKED by a1,
--         a7 invitee + link-holder + waitlisted, a9 (uid with no profile at all);
--         service_role (BYPASSRLS: the only API role whose invoker reads reach games and events) with no uid and as a1-a7.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
CREATE TEMP TABLE mx (actor text, ev text, cell text, val text);

CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_matrix_undo';   -- undo any write the cell made
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    IF NOT (s = 'P0001' AND SQLERRM = 'kan713_matrix_undo') THEN v := 'ERR ' || s; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;

CREATE TEMP TABLE actors (actor text, role text, uid uuid);
INSERT INTO actors VALUES
  ('anon',            'anon',          NULL),
  ('auth:a1-owner',   'authenticated', '00000000-0000-0000-0000-0000000000a1'),
  ('auth:a2-nonmember','authenticated','00000000-0000-0000-0000-0000000000a2'),
  ('auth:a3-admin',   'authenticated', '00000000-0000-0000-0000-0000000000a3'),
  ('auth:a4-member',  'authenticated', '00000000-0000-0000-0000-0000000000a4'),
  ('auth:a5-follower','authenticated', '00000000-0000-0000-0000-0000000000a5'),
  ('auth:a6-blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('auth:a7-invitee-linkholder','authenticated','00000000-0000-0000-0000-0000000000a7'),
  ('auth:a9-noprofile','authenticated','00000000-0000-0000-0000-0000000000a9'),
  ('service_role',    'service_role',  NULL),
  ('service_role:a1', 'service_role',  '00000000-0000-0000-0000-0000000000a1'),
  ('service_role:a2', 'service_role',  '00000000-0000-0000-0000-0000000000a2'),
  ('service_role:a3', 'service_role',  '00000000-0000-0000-0000-0000000000a3'),
  ('service_role:a4', 'service_role',  '00000000-0000-0000-0000-0000000000a4'),
  ('service_role:a5', 'service_role',  '00000000-0000-0000-0000-0000000000a5'),
  ('service_role:a6', 'service_role',  '00000000-0000-0000-0000-0000000000a6'),
  ('service_role:a7', 'service_role',  '00000000-0000-0000-0000-0000000000a7');

CREATE TEMP TABLE gev (ev text, id uuid);
INSERT INTO gev VALUES
  ('G-pub',  '71300000-0000-0000-0000-000000000001'), ('G-fol', '71300000-0000-0000-0000-000000000002'),
  ('G-pri',  '71300000-0000-0000-0000-000000000003'), ('G-link','71300000-0000-0000-0000-000000000004'),
  ('X-none', '71300000-0000-0000-0000-0000000009ff'), ('X-mtg-as-game', '71300000-0000-0000-0000-000000000101');
CREATE TEMP TABLE mev (ev text, id uuid);
INSERT INTO mev VALUES
  ('M-pub', '71300000-0000-0000-0000-000000000101'), ('M-cir', '71300000-0000-0000-0000-000000000102'),
  ('M-inv', '71300000-0000-0000-0000-000000000103'), ('M-lnk', '71300000-0000-0000-0000-000000000104'),
  ('M-hid', '71300000-0000-0000-0000-000000000105'),
  ('X-none', '71300000-0000-0000-0000-0000000009ff'), ('X-game-as-mtg', '71300000-0000-0000-0000-000000000001');

CREATE TEMP TABLE gcell (cell text, sql text);
INSERT INTO gcell VALUES
  ('fn:_can_view_game',          $q$SELECT public._can_view_game('%s')::text$q$),
  ('fn:_can_view_game_for_join', $q$SELECT public._can_view_game_for_join('%s')::text$q$),
  ('fn:_is_game_host',           $q$SELECT public._is_game_host('%s')::text$q$),
  ('fn:join(no token)',          $q$SELECT public.can_current_user_join_game('%s','player',NULL)::text$q$),
  ('fn:join(token f1)',          $q$SELECT public.can_current_user_join_game('%s','player','71300000-0000-0000-0000-0000000000f1')::text$q$),
  ('fn:join(wrong token)',       $q$SELECT public.can_current_user_join_game('%s','player','71300000-0000-0000-0000-0000000000f2')::text$q$),
  ('rows:games',                 $q$SELECT count(*)::text FROM public.games WHERE id = '%s'$q$),
  ('rows:game_roster',           $q$SELECT count(*)::text FROM public.game_roster WHERE game_id = '%s'$q$),
  ('rows:game_waitlist',         $q$SELECT count(*)::text FROM public.game_waitlist WHERE game_id = '%s'$q$),
  ('rows:game_join_requests',    $q$SELECT count(*)::text FROM public.game_join_requests WHERE game_id = '%s'$q$),
  ('rows:events',                $q$SELECT count(*)::text FROM public.events WHERE id = '%s'$q$);
CREATE TEMP TABLE mcell (cell text, sql text);
INSERT INTO mcell VALUES
  ('fn:rsvp(no token)',          $q$SELECT public.can_current_user_rsvp_meetup('%s', NULL)::text$q$),
  ('fn:rsvp(token f2)',          $q$SELECT public.can_current_user_rsvp_meetup('%s', '71300000-0000-0000-0000-0000000000f2')::text$q$),
  ('fn:rsvp(wrong token)',       $q$SELECT public.can_current_user_rsvp_meetup('%s', '71300000-0000-0000-0000-0000000000f1')::text$q$),
  ('rows:meetups',               $q$SELECT count(*)::text FROM public.meetups WHERE id = '%s'$q$),
  ('rows:meetup_attendees',      $q$SELECT count(*)::text FROM public.meetup_attendees WHERE meetup_id = '%s'$q$),
  ('write:meetup_attendees',     $q$WITH u AS (UPDATE public.meetup_attendees SET status = status WHERE meetup_id = '%s' RETURNING 1) SELECT count(*)::text FROM u$q$),
  ('rows:events',                $q$SELECT count(*)::text FROM public.events WHERE id = '%s'$q$);

INSERT INTO mx SELECT a.actor, g.ev, c.cell, pg_temp.as_(a.role, a.uid, replace(c.sql, '%s', g.id::text))
  FROM actors a CROSS JOIN gev g CROSS JOIN gcell c;
INSERT INTO mx SELECT a.actor, m.ev, c.cell, pg_temp.as_(a.role, a.uid, replace(c.sql, '%s', m.id::text))
  FROM actors a CROSS JOIN mev m CROSS JOIN mcell c;

SELECT actor || '|' || ev || '|' || cell || '|' || val FROM mx ORDER BY actor, ev, cell;
SELECT '#CELLS|' || count(*) FROM mx;
ROLLBACK;
