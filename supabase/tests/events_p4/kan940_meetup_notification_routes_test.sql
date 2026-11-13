-- KAN-940 live test: every meetup notification path carries action_route, and a first join and a re-join send the
-- same kind. Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Each client step runs as role authenticated with request.jwt.claims for the caller; notifications are read back as
-- postgres after each step.
--   host  a3ba3271-3556-4b4e-b15d-bc0851f8a64b (two of the host's meetups are un-cancelled inside the transaction:
--         O = e77e39be (open policy), R = ae2d9647 (request policy))
--   p1    18e15813-52bc-4f03-9a30-25dc6441223d     p2    47d57ad9-76e3-4145-93f5-9e3d233ab137
-- Expected (GREEN after 20261113224654_kan940_meetup_notification_routes.sql):
--   T1 first join (p1 going on O)          host  meetup.player_joined     /meetups/O
--   T2 re-join after un-RSVP (p1 on O)     host  meetup.player_joined     /meetups/O   (RED before: rsvp_received)
--   T3 request (p1 on R)                   host  meetup.request_received  /meetups/R/manage
--   T4 host approves p1 on R               p1    meetup.request_approved  /meetups/R
--   T5 request + host declines (p2 on R)   p2    meetup.request_declined  /meetups/R
--   T6 host invites p2 to O                p2    meetup.invited           /meetups/O
--   T7 host cancels O                      p1    meetup.cancelled         /meetups/O
--   T8 other kinds unchanged: game.player_joined -> /sports/games/<id>, game.join_request -> ?focus=requests,
--      friend.requested -> null (no aggregation rule, so it reaches notifications)
--   T9 every step ran (no step raised)
-- RED before apply: T1..T7 fail on action_route null, T2 also on kind.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k940_cap (step int, to_user uuid, kind text, route text) ON COMMIT DROP;
CREATE TEMP TABLE k940_err (step int, err text) ON COMMIT DROP;
CREATE TEMP TABLE k940_seen (id uuid PRIMARY KEY) ON COMMIT DROP;
CREATE TEMP TABLE k940_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;

INSERT INTO k940_seen SELECT id FROM public.notifications WHERE created_at = now();

-- Fixture: two of the host's meetups made live again (only inside this transaction); p1/p2 have no RSVP on them.
UPDATE public.events SET is_cancelled = false
 WHERE id IN ('e77e39be-8a0b-4879-bf7e-6686da621f70', 'ae2d9647-c896-45e1-80b9-1da177085a38') AND event_type = 'meetup';

-- One client step as role authenticated, then capture the new notification rows as postgres.
CREATE FUNCTION pg_temp.k940_step(p_step int, p_uid uuid, p_sql text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE p_sql;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    INSERT INTO k940_err VALUES (p_step, SQLSTATE || ' ' || SQLERRM);
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO k940_cap SELECT p_step, n.to_user_id, n.kind_key, n.action_route
    FROM public.notifications n WHERE n.created_at = now() AND n.id NOT IN (SELECT id FROM k940_seen);
  INSERT INTO k940_seen SELECT n.id FROM public.notifications n WHERE n.created_at = now() ON CONFLICT DO NOTHING;
END $f$;

DO $run$
DECLARE
  h  uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  p1 uuid := '18e15813-52bc-4f03-9a30-25dc6441223d';
  p2 uuid := '47d57ad9-76e3-4145-93f5-9e3d233ab137';
  o  uuid := 'e77e39be-8a0b-4879-bf7e-6686da621f70';
  r  uuid := 'ae2d9647-c896-45e1-80b9-1da177085a38';
BEGIN
  PERFORM pg_temp.k940_step(1, p1, format('SELECT public.rpc_meetup_rsvp(%L, ''going'')', o));
  PERFORM pg_temp.k940_step(0, p1, format('SELECT public.rpc_meetup_rsvp(%L, ''cancel'')', o));
  PERFORM pg_temp.k940_step(2, p1, format('SELECT public.rpc_meetup_rsvp(%L, ''going'')', o));
  PERFORM pg_temp.k940_step(3, p1, format('SELECT public.rpc_meetup_rsvp(%L, ''request'')', r));
  PERFORM pg_temp.k940_step(4, h,  format('SELECT public.rpc_meetup_decide_request(%L, %L, ''approve'')', r, p1));
  PERFORM pg_temp.k940_step(50, p2, format('SELECT public.rpc_meetup_rsvp(%L, ''request'')', r));
  PERFORM pg_temp.k940_step(5, h,  format('SELECT public.rpc_meetup_decide_request(%L, %L, ''decline'')', r, p2));
  PERFORM pg_temp.k940_step(6, h,  format('SELECT public.rpc_meetup_invite_user(%L, %L)', o, p2));
  PERFORM pg_temp.k940_step(7, h,  format('SELECT public.rpc_meetup_cancel(%L)', o));
  -- T8: other kinds, called directly (as postgres, the owner) with synthetic entity ids.
  PERFORM public.process_notification_event(p1, 'game.player_joined', 'game', '94000000-0000-4000-8000-000000000001', p2);
  PERFORM public.process_notification_event(p1, 'game.join_request', 'game', '94000000-0000-4000-8000-000000000002', p2);
  PERFORM public.process_notification_event(p1, 'friend.requested', 'profile', '94000000-0000-4000-8000-000000000003', p2);
  INSERT INTO k940_cap SELECT 8, n.to_user_id, n.kind_key, n.action_route
    FROM public.notifications n WHERE n.created_at = now() AND n.id NOT IN (SELECT id FROM k940_seen);
END
$run$;

INSERT INTO k940_tap
SELECT x.step, EXISTS (SELECT 1 FROM k940_cap c WHERE c.step = x.step AND c.to_user = x.to_user AND c.kind = x.kind
                         AND c.route IS NOT DISTINCT FROM x.route)
            AND NOT EXISTS (SELECT 1 FROM k940_cap c WHERE c.step = x.step AND c.kind LIKE 'meetup.%'
                              AND (c.route IS DISTINCT FROM x.route OR c.kind <> x.kind)),
       x.label || ': ' || x.kind || ' ' || coalesce(x.route, 'null'),
       'got: ' || coalesce((SELECT string_agg(c.to_user || ' ' || c.kind || ' ' || coalesce(c.route, 'null'), '; ')
                              FROM k940_cap c WHERE c.step = x.step), 'nothing')
FROM (VALUES
  (1, 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b'::uuid, 'meetup.player_joined',    '/meetups/e77e39be-8a0b-4879-bf7e-6686da621f70',        'first join -> host'),
  (2, 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b'::uuid, 'meetup.player_joined',    '/meetups/e77e39be-8a0b-4879-bf7e-6686da621f70',        're-join after un-RSVP -> host, same kind as a first join'),
  (3, 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b'::uuid, 'meetup.request_received', '/meetups/ae2d9647-c896-45e1-80b9-1da177085a38/manage', 'request -> host'),
  (4, '18e15813-52bc-4f03-9a30-25dc6441223d'::uuid, 'meetup.request_approved', '/meetups/ae2d9647-c896-45e1-80b9-1da177085a38',        'approve -> attendee'),
  (5, '47d57ad9-76e3-4145-93f5-9e3d233ab137'::uuid, 'meetup.request_declined', '/meetups/ae2d9647-c896-45e1-80b9-1da177085a38',        'decline -> attendee'),
  (6, '47d57ad9-76e3-4145-93f5-9e3d233ab137'::uuid, 'meetup.invited',          '/meetups/e77e39be-8a0b-4879-bf7e-6686da621f70',        'invite -> invitee'),
  (7, '18e15813-52bc-4f03-9a30-25dc6441223d'::uuid, 'meetup.cancelled',        '/meetups/e77e39be-8a0b-4879-bf7e-6686da621f70',        'cancel -> attendee')
) x(step, to_user, kind, route, label);

INSERT INTO k940_tap SELECT 8,
  count(*) = 3
  AND bool_and(CASE kind WHEN 'game.player_joined' THEN route = '/sports/games/94000000-0000-4000-8000-000000000001'
                         WHEN 'game.join_request'  THEN route = '/sports/games/94000000-0000-4000-8000-000000000002?focus=requests'
                         WHEN 'friend.requested'   THEN route IS NULL END),
  'other kinds unchanged (game routes, friend.requested null)', string_agg(kind || ' ' || coalesce(route, 'null'), '; ')
  FROM k940_cap WHERE step = 8;

INSERT INTO k940_tap SELECT 9, NOT EXISTS (SELECT 1 FROM k940_err), 'every step ran',
  coalesce((SELECT string_agg(step || ': ' || err, '; ') FROM k940_err), 'no errors');

SELECT (SELECT count(*) FILTER (WHERE ok) || '/' || count(*) FROM k940_tap) || E'\n'
    || string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || ' [' || left(detail, 400) || ']', E'\n' ORDER BY n) AS tap
  FROM k940_tap;
ROLLBACK;
