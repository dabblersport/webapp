-- KAN-980 [W1-B2] aggregation: live test pack.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117100750_kan980_aggregation.sql.
-- Everything runs inside BEGIN ... ROLLBACK: no notification, aggregate, follow, rsvp or hook persists, and the
-- pg_net requests queued by trg_push_on_notification_insert are rolled back with it (nothing is sent).
-- Recipient A = dabbler.pro@proton.me. Actors X1..X4 = four other users with an active profile, picked at run time.
-- Time: notification_aggregate_add and flush_notification_aggregates take p_now, so the G-01 timeline (t0, +10m,
-- +15m, +20m, +25m, +30m, +61m) runs in one transaction. "push" = a row queued in net.http_request_queue for
-- send-push-notification (the insert push of KAN-979's trigger); "re-push" = a call to the KAN-979 hook
-- notification_repush(uuid), replaced here by a recorder created inside the transaction.
--
--  G1  t0 first like: one row, group_key set, title "<X1> liked your post", one push
--  G2  +10m second person: same row, count 2, "<X2> and 1 other liked your post", no push, flush re-pushes nothing
--  G3  +15m: flush re-pushes once (hook called with the row id); a second flush at +16m does nothing
--  G4  row read, +20m third person: unread again, created_at = +20m, first in A's list, "<X3> and 2 others"
--  G5  the same person again (X3 like) and X1's reaction on the same post: count stays 3 (counted once)
--  G6  cap: pending since +20m; flush at +25m re-pushes nothing (last push +15m), flush at +30m re-pushes once
--  G7  +61m, a like after the 1-hour window: a NEW row; flush at +62m closes the old group
--  F1  follows through the real producer (2 profile_follows inserts): one grouped social.followed row, count 2
--  C1  comment likes through notify_v2: one grouped row, count 2
--  R1  Interested RSVP through the real trigger (2 members): one grouped meetup.rsvp_interested row for the
--      organiser, no push, flush never re-pushes it
--  NC1 negative control: two comments and a mention in the same window each make their own row and push at once,
--      and no aggregate group exists for them
--  NC2 negative control: a Going join (rsvp cancelled -> going by the member) still notifies the organiser
--      (meetup.player_joined, as before) and makes no rsvp_interested row
--  P1  grants: anon and authenticated cannot execute flush_notification_aggregates (42501)
--  K1  catalogue: cron job every minute; the four producers call notify_v2 only
--
-- Run history: 2026-11-17 backend-2, one full run after 20261117100750: 36/36 PASS. Cron runs at 10:09, 10:10, 10:11
-- UTC succeeded. Evidence comment on KAN-980.

BEGIN;

CREATE TEMP TABLE kan980_results (n int GENERATED ALWAYS AS IDENTITY, name text, expected text, actual text) ON COMMIT DROP;
CREATE TEMP TABLE kan980_repush (notification_id uuid, at timestamptz DEFAULT clock_timestamp()) ON COMMIT DROP;
GRANT ALL ON kan980_results, kan980_repush TO anon, authenticated;

CREATE FUNCTION pg_temp.r(p_name text, p_expected text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO pg_temp.kan980_results (name, expected, actual) VALUES (p_name, p_expected, p_actual);
$$;
GRANT EXECUTE ON FUNCTION pg_temp.r(text, text, text) TO anon, authenticated;
CREATE FUNCTION pg_temp.pushes() RETURNS bigint LANGUAGE sql AS $$
  SELECT count(*) FROM net.http_request_queue WHERE url LIKE '%send-push-notification%';
$$;

-- the KAN-979 hook, as a recorder (rolled back with everything else)
CREATE FUNCTION public.notification_repush(p_notification_id uuid) RETURNS void LANGUAGE sql AS $$
  INSERT INTO pg_temp.kan980_repush (notification_id) VALUES (p_notification_id);
$$;

CREATE TEMP TABLE kan980_ids ON COMMIT DROP AS
WITH a AS (SELECT u.id FROM auth.users u WHERE u.email = 'dabbler.pro@proton.me'),
     actors AS (
       SELECT p.user_id, min(p.id::text)::uuid AS profile_id, row_number() OVER (ORDER BY p.user_id) AS k
         FROM public.profiles p
        WHERE p.is_active AND p.display_name IS NOT NULL AND p.user_id <> (SELECT id FROM a)
          AND NOT EXISTS (SELECT 1 FROM public.user_blocks b
                           WHERE (b.blocker_user_id = p.user_id AND b.blocked_user_id = (SELECT id FROM a))
                              OR (b.blocked_user_id = p.user_id AND b.blocker_user_id = (SELECT id FROM a)))
        GROUP BY p.user_id
        LIMIT 4)
SELECT (SELECT id FROM a) AS a,
       (SELECT min(p.id::text)::uuid FROM public.profiles p WHERE p.user_id = (SELECT id FROM a) AND p.is_active) AS a_profile,
       (SELECT user_id FROM actors WHERE k = 1) AS x1, (SELECT user_id FROM actors WHERE k = 2) AS x2,
       (SELECT user_id FROM actors WHERE k = 3) AS x3, (SELECT user_id FROM actors WHERE k = 4) AS x4,
       (SELECT profile_id FROM actors WHERE k = 1) AS x1_profile, (SELECT profile_id FROM actors WHERE k = 2) AS x2_profile,
       gen_random_uuid() AS post, gen_random_uuid() AS post2, gen_random_uuid() AS comment_id,
       now() AS t0;

CREATE FUNCTION pg_temp.name(p uuid) RETURNS text LANGUAGE sql AS $$
  SELECT display_name FROM public.profiles WHERE user_id = p AND is_active ORDER BY updated_at DESC NULLS LAST LIMIT 1;
$$;
CREATE FUNCTION pg_temp.add(p_kind text, p_entity uuid, p_actor uuid, p_min int) RETURNS uuid LANGUAGE sql AS $$
  SELECT public.notification_aggregate_add((SELECT a FROM pg_temp.kan980_ids), p_kind, 'post', p_entity, p_actor,
           '{}'::jsonb, 'en', NULL, 'kan980-test', (SELECT t0 FROM pg_temp.kan980_ids) + make_interval(mins => p_min));
$$;
CREATE FUNCTION pg_temp.flush(p_min int) RETURNS integer LANGUAGE sql AS $$
  SELECT public.flush_notification_aggregates((SELECT t0 FROM pg_temp.kan980_ids) + make_interval(mins => p_min));
$$;
CREATE TEMP TABLE kan980_s (k text PRIMARY KEY, v text) ON COMMIT DROP;

SELECT pg_temp.r('fixture: A and 4 actors found', 'true',
  (SELECT (a IS NOT NULL AND x4 IS NOT NULL AND x1_profile IS NOT NULL AND a_profile IS NOT NULL)::text FROM kan980_ids));

-- G1 t0 -------------------------------------------------------------------------------------------------------------
SELECT pg_temp.r('precondition: no other open aggregate group (flush counts are global)', '0',
  (SELECT count(*)::text FROM public.notification_aggregates WHERE notification_id IS NOT NULL AND NOT is_flushed));
INSERT INTO kan980_s VALUES ('p0', pg_temp.pushes()::text);
INSERT INTO kan980_s VALUES ('row1', pg_temp.add('social.post_liked', (SELECT post FROM kan980_ids), (SELECT x1 FROM kan980_ids), 0)::text);
SELECT pg_temp.r('G1 one row for the group', '1',
  (SELECT count(*)::text FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids)
      AND group_key = 'post:post:' || (SELECT post FROM kan980_ids)));
SELECT pg_temp.r('G1 title', pg_temp.name((SELECT x1 FROM kan980_ids)) || ' liked your post',
  (SELECT title FROM public.notifications WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1')));
SELECT pg_temp.r('G1 one push at t0', '1', (pg_temp.pushes() - (SELECT v::bigint FROM kan980_s WHERE k = 'p0'))::text);

-- G2 +10m -----------------------------------------------------------------------------------------------------------
INSERT INTO kan980_s VALUES ('p1', pg_temp.pushes()::text);
SELECT pg_temp.r('G2 same row', 'true',
  (pg_temp.add('social.post_liked', (SELECT post FROM kan980_ids), (SELECT x2 FROM kan980_ids), 10)
     = (SELECT v::uuid FROM kan980_s WHERE k = 'row1'))::text);
SELECT pg_temp.r('G2 count and title', '2|' || pg_temp.name((SELECT x2 FROM kan980_ids)) || ' and 1 other liked your post',
  (SELECT (context ->> 'total_count') || '|' || title FROM public.notifications WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1')));
SELECT pg_temp.r('G2 no push on growth', '0', (pg_temp.pushes() - (SELECT v::bigint FROM kan980_s WHERE k = 'p1'))::text);
SELECT pg_temp.r('G2 flush at +10m re-pushes nothing', '0', pg_temp.flush(10)::text);

-- G3 +15m -----------------------------------------------------------------------------------------------------------
SELECT pg_temp.r('G3 flush at +15m re-pushes once', '1', pg_temp.flush(15)::text);
SELECT pg_temp.r('G3 hook called with the row', '1|true',
  (SELECT count(*)::text || '|' || bool_and(notification_id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1'))::text FROM kan980_repush));
SELECT pg_temp.r('G3 flush at +16m does nothing', '0', pg_temp.flush(16)::text);

-- G4 read, then +20m ------------------------------------------------------------------------------------------------
UPDATE public.notifications SET is_read = true, read_at = now() WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1');
SELECT pg_temp.add('social.post_liked', (SELECT post FROM kan980_ids), (SELECT x3 FROM kan980_ids), 20);
SELECT pg_temp.r('G4 unread again, moved to +20m', 'false|true',
  (SELECT is_read::text || '|' || (created_at = (SELECT t0 FROM kan980_ids) + interval '20 minutes')::text
     FROM public.notifications WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1')));
SELECT pg_temp.r('G4 first in A''s list', 'true',
  ((SELECT id FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids) ORDER BY created_at DESC LIMIT 1)
     = (SELECT v::uuid FROM kan980_s WHERE k = 'row1'))::text);
SELECT pg_temp.r('G4 title', pg_temp.name((SELECT x3 FROM kan980_ids)) || ' and 2 others liked your post',
  (SELECT title FROM public.notifications WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1')));

-- G5 counted once -----------------------------------------------------------------------------------------------------
SELECT pg_temp.add('social.post_liked', (SELECT post FROM kan980_ids), (SELECT x3 FROM kan980_ids), 21);
SELECT pg_temp.add('social.post_reacted', (SELECT post FROM kan980_ids), (SELECT x1 FROM kan980_ids), 22);
SELECT pg_temp.r('G5 like again + reaction by a liker: count stays 3, one row', '3|1',
  (SELECT (context ->> 'total_count') || '|' ||
          (SELECT count(*) FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids)
              AND group_key = 'post:post:' || (SELECT post FROM kan980_ids))::text
     FROM public.notifications WHERE id = (SELECT v::uuid FROM kan980_s WHERE k = 'row1')));

-- G6 cap ------------------------------------------------------------------------------------------------------------
SELECT pg_temp.r('G6 flush at +25m (10m after last push) re-pushes nothing', '0', pg_temp.flush(25)::text);
SELECT pg_temp.r('G6 flush at +30m re-pushes once', '1', pg_temp.flush(30)::text);
SELECT pg_temp.r('G6 hook calls so far', '2', (SELECT count(*)::text FROM kan980_repush));

-- G7 after the window -------------------------------------------------------------------------------------------------
INSERT INTO kan980_s VALUES ('p2', pg_temp.pushes()::text);
INSERT INTO kan980_s VALUES ('row2', pg_temp.add('social.post_liked', (SELECT post FROM kan980_ids), (SELECT x4 FROM kan980_ids), 61)::text);
SELECT pg_temp.r('G7 a new row after 1 hour', 'true|2',
  (((SELECT v FROM kan980_s WHERE k = 'row2') <> (SELECT v FROM kan980_s WHERE k = 'row1'))::text || '|' ||
   (SELECT count(*) FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids)
       AND group_key = 'post:post:' || (SELECT post FROM kan980_ids))::text));
SELECT pg_temp.r('G7 new row pushes at once', '1', (pg_temp.pushes() - (SELECT v::bigint FROM kan980_s WHERE k = 'p2'))::text);
SELECT pg_temp.flush(62);
SELECT pg_temp.r('G7 old group closed at +62m, new one open', 'true|false',
  (SELECT string_agg(is_flushed::text, '|' ORDER BY window_started_at) FROM public.notification_aggregates
    WHERE to_user_id = (SELECT a FROM kan980_ids) AND group_key = 'post:post:' || (SELECT post FROM kan980_ids)));

-- F1 follows through the real producer -------------------------------------------------------------------------------
INSERT INTO public.profile_follows (follower_profile_id, following_profile_id)
SELECT x1_profile, a_profile FROM kan980_ids
 WHERE NOT EXISTS (SELECT 1 FROM public.profile_follows f, kan980_ids i
                    WHERE f.follower_profile_id = i.x1_profile AND f.following_profile_id = i.a_profile);
INSERT INTO public.profile_follows (follower_profile_id, following_profile_id)
SELECT x2_profile, a_profile FROM kan980_ids
 WHERE NOT EXISTS (SELECT 1 FROM public.profile_follows f, kan980_ids i
                    WHERE f.follower_profile_id = i.x2_profile AND f.following_profile_id = i.a_profile);
SELECT pg_temp.r('F1 follows: one grouped row, count 2', '1|2|social.followed',
  (SELECT count(*)::text || '|' || max(context ->> 'total_count') || '|' || max(kind_key)
     FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids)
      AND group_key = 'follow:profile:' || (SELECT a_profile FROM kan980_ids)));

-- C1 comment likes through notify_v2 ----------------------------------------------------------------------------------
SELECT public.notify_v2((SELECT a FROM kan980_ids), 'social.comment_liked', '{}'::jsonb, 'comment',
                        (SELECT comment_id FROM kan980_ids), (SELECT x1 FROM kan980_ids), 'kan980-test', 'kan980:cl1');
SELECT public.notify_v2((SELECT a FROM kan980_ids), 'social.comment_liked', '{}'::jsonb, 'comment',
                        (SELECT comment_id FROM kan980_ids), (SELECT x2 FROM kan980_ids), 'kan980-test', 'kan980:cl2');
SELECT pg_temp.r('C1 comment likes: one grouped row, count 2', '1|2',
  (SELECT count(*)::text || '|' || max(context ->> 'total_count') FROM public.notifications
    WHERE to_user_id = (SELECT a FROM kan980_ids) AND group_key = 'comment:comment:' || (SELECT comment_id FROM kan980_ids)));

-- R1 Interested RSVP through the real trigger -------------------------------------------------------------------------
CREATE TEMP TABLE kan980_m ON COMMIT DROP AS
SELECT m.id AS meetup_id, e.creator_user_id AS host
  FROM public.kan714_meetups_read m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE e.creator_user_id IS NOT NULL
   AND e.creator_user_id NOT IN (SELECT x1 FROM kan980_ids UNION SELECT x2 FROM kan980_ids UNION SELECT x3 FROM kan980_ids)
   AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r WHERE r.meetup_id = m.id
                    AND r.user_id IN (SELECT x1 FROM kan980_ids UNION SELECT x2 FROM kan980_ids UNION SELECT x3 FROM kan980_ids))
 ORDER BY e.created_at DESC LIMIT 1;
INSERT INTO kan980_s VALUES ('p3', pg_temp.pushes()::text);
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT x1 FROM kan980_ids), 'role', 'authenticated')::text, true);
INSERT INTO public.meetup_rsvps (meetup_id, user_id, status) SELECT meetup_id, (SELECT x1 FROM kan980_ids), 'interested' FROM kan980_m;
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT x2 FROM kan980_ids), 'role', 'authenticated')::text, true);
INSERT INTO public.meetup_rsvps (meetup_id, user_id, status) SELECT meetup_id, (SELECT x2 FROM kan980_ids), 'interested' FROM kan980_m;
SELECT pg_temp.r('R1 one grouped in-app row for the organiser, count 2', '1|2|meetup.rsvp_interested',
  (SELECT count(*)::text || '|' || max(context ->> 'total_count') || '|' || max(kind_key) FROM public.notifications
    WHERE to_user_id = (SELECT host FROM kan980_m) AND group_key = 'meetup_interested:meetup:' || (SELECT meetup_id FROM kan980_m)));
SELECT pg_temp.r('R1 no push', '0', (pg_temp.pushes() - (SELECT v::bigint FROM kan980_s WHERE k = 'p3'))::text);
SELECT pg_temp.r('R1 group has push disabled', 'false|0',
  (SELECT push_enabled::text || '|' || push_count FROM public.notification_aggregates
    WHERE to_user_id = (SELECT host FROM kan980_m) AND group_key = 'meetup_interested:meetup:' || (SELECT meetup_id FROM kan980_m)));

-- NC2 a Going join still notifies the organiser as before ------------------------------------------------------------
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT x3 FROM kan980_ids), 'role', 'authenticated')::text, true);
INSERT INTO public.meetup_rsvps (meetup_id, user_id, status) SELECT meetup_id, (SELECT x3 FROM kan980_ids), 'cancelled' FROM kan980_m;
UPDATE public.meetup_rsvps SET status = 'going'
 WHERE meetup_id = (SELECT meetup_id FROM kan980_m) AND user_id = (SELECT x3 FROM kan980_ids);
SELECT pg_temp.r('NC2 Going join: organiser gets meetup.player_joined, no interested row for X3', '1|0',
  (SELECT count(*) FILTER (WHERE kind_key = 'meetup.player_joined' AND context ->> 'actor_user_id' = (SELECT x3 FROM kan980_ids)::text)::text
          || '|' ||
          count(*) FILTER (WHERE kind_key = 'meetup.rsvp_interested' AND context -> 'actor_user_ids' ? (SELECT x3 FROM kan980_ids)::text)::text
     FROM public.notifications WHERE to_user_id = (SELECT host FROM kan980_m)
      AND context ->> 'entity_id' = (SELECT meetup_id FROM kan980_m)::text));
SELECT set_config('request.jwt.claims', '', true);

-- NC1 comments and mentions are immediate and never grouped ----------------------------------------------------------
INSERT INTO kan980_s VALUES ('p4', pg_temp.pushes()::text);
SELECT public.process_notification_event((SELECT a FROM kan980_ids), 'social.post_commented', 'post', (SELECT post2 FROM kan980_ids), (SELECT x1 FROM kan980_ids));
SELECT public.process_notification_event((SELECT a FROM kan980_ids), 'social.post_commented', 'post', (SELECT post2 FROM kan980_ids), (SELECT x2 FROM kan980_ids));
SELECT public.process_notification_event((SELECT a FROM kan980_ids), 'social.mentioned_in_post', 'post', (SELECT post2 FROM kan980_ids), (SELECT x3 FROM kan980_ids));
SELECT pg_temp.r('NC1 two comments + one mention: three rows at once', '2|1',
  (SELECT count(*) FILTER (WHERE kind_key = 'social.post_commented')::text || '|' ||
          count(*) FILTER (WHERE kind_key = 'social.mentioned_in_post')::text
     FROM public.notifications WHERE to_user_id = (SELECT a FROM kan980_ids)
      AND context ->> 'entity_id' = (SELECT post2 FROM kan980_ids)::text));
SELECT pg_temp.r('NC1 three pushes at once', '3', (pg_temp.pushes() - (SELECT v::bigint FROM kan980_s WHERE k = 'p4'))::text);
SELECT pg_temp.r('NC1 no aggregate group for them', '0',
  (SELECT count(*)::text FROM public.notification_aggregates WHERE to_user_id = (SELECT a FROM kan980_ids)
      AND entity_id = (SELECT post2 FROM kan980_ids)));

-- P1 grants -----------------------------------------------------------------------------------------------------------
SET LOCAL ROLE anon;
DO $p$ DECLARE v text; BEGIN
  BEGIN PERFORM public.flush_notification_aggregates(); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('P1 anon executes flush', '42501', v);
END $p$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $p$ DECLARE v text; BEGIN
  BEGIN PERFORM public.flush_notification_aggregates(); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('P1 authenticated executes flush', '42501', v);
  BEGIN PERFORM 1 FROM public.notification_aggregates LIMIT 1; v := 'select ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('P1 authenticated can still read its own groups (RLS)', 'select ok', v);
END $p$;
RESET ROLE;

-- K1 catalogue ------------------------------------------------------------------------------------------------------
SELECT pg_temp.r('K1 cron', 'flush_notification_aggregates_every_minute|* * * * *|true',
  (SELECT string_agg(jobname || '|' || schedule || '|' || active, ',') FROM cron.job WHERE command ILIKE '%flush_notification_aggregates%'));
SELECT pg_temp.r('K1 producers call notify_v2 only', '4',
  (SELECT count(*)::text FROM pg_proc WHERE oid IN ('public.fn_likes_notify()'::regprocedure, 'public.trg_post_reaction_notify()'::regprocedure,
      'public.trg_profile_follow_notify()'::regprocedure, 'public.trg_circle_join_notify()'::regprocedure)
     AND pg_get_functiondef(oid) ~ 'notify_v2\(' AND pg_get_functiondef(oid) !~ 'process_notification_event'));

SELECT n, CASE WHEN expected IS NOT DISTINCT FROM actual THEN 'PASS' ELSE 'FAIL' END AS verdict, name, expected, actual
  FROM kan980_results ORDER BY n;

ROLLBACK;
