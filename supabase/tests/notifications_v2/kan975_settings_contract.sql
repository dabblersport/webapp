-- KAN-975 [W0-2] settings contract: live test pack.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117045159_kan975_notification_settings_contract.sql,
-- 20261117053604_kan975b_category_keys_follow_registry.sql and 20261117054010_kan975c_quiet_hours_default_off.sql. Security kind used: security.new_signin (KAN-974, can_mute false).
-- Everything runs inside BEGIN ... ROLLBACK: no row, kind or setting persists.
-- Users: the two CEO-approved staging accounts, looked up by email (A = dabbler.pro@proton.me,
-- B = jidep35093@iconcubic.com). Client calls run as role authenticated with request.jwt.claims.sub set.
--
-- Each check writes one row to pg_temp.kan975_results (name, expected, actual). PASS = expected IS NOT DISTINCT FROM actual.
-- Expected outcome: every row PASS. The negative controls (NC*) are checks whose expected value is the
-- *old* behaviour and that must now read differently; NC rows that PASS prove the probe can see a change.
--
--  D1  rpc_get_my_notification_settings creates A's row with the defaults (quiet NULL/NULL = off until KAN-979,
--      sender_and_message, every rung true for going and interested, every category in_app+push true)
--  D2  a user with no row is not quiet at 01:00 or 12:00 Asia/Dubai (default off)
--  D3  the current client's direct upsert creates a row with quiet NULL/NULL, not quiet at 01:00
--  NC3 negative control for D3: the same row switched on by the user (rpc) is 0/480 and quiet at 01:00
--  Q1  A switches quiet hours on (tz Asia/Dubai, 00:00-08:00): 01:00 local quiet, 12:00 and 08:00 not quiet
--  Q2  window across midnight 23:00-07:00, tz America/New_York: 23:30 NY quiet, 06:59 NY quiet, 07:00 NY not, 12:00 NY not
--  Q3  same instant, two timezones: 2026-11-17 21:00 UTC = 01:00 Dubai (quiet) and 16:00 New York (not quiet)
--  Q4  quiet hours off (rpc quiet_hours_enabled false) -> never quiet; quiet_hours_enabled column false
--  Q5  start = end rejected (rpc: 22023; direct table write: 23514 notification_settings_quiet_span_chk)
--  T1  rpc_set_my_notification_timezone('Mars/Olympus') rejected 22023; 'Europe/London' accepted
--  R1  each rung stored separately: going.2h false, interested.09:00 false, the other six still true
--  R2  a reminder_rungs value with a missing rung is rejected (23514)
--  M1  muting a security kind is rejected (22023), via rpc and via direct table write
--  M2  muting a mutable kind (social.post_liked) is accepted and notification_channel_enabled says false for it
--  S1  security kind: notification_channel_enabled is true for push and in_app even with push_enabled false,
--      every category off and the kind in no list (guard prevents the list)
--  L1  RLS: B cannot read A's row (0 rows), cannot update it (0 rows), cannot insert a row for A (42501)
--  L2  anon cannot read the table (42501) and cannot execute is_quiet_hour (42501)
--  NC1 negative control: writing user_settings quiet_start/quiet_end/timezone no longer changes is_quiet_hour
--      (old reader would have flipped the 12:00 result to quiet; it stays false)
--  NC2 negative control on a mutable kind: same settings that cannot silence a security kind do silence
--      social.post_liked (push false)
--  E1  catalogue: no function body reads email_enabled or sms_enabled; none reads user_settings quiet/timezone
--
-- Run history: 2026-11-17 after 20261117053604, 48 checks, 44 PASS + 4 probe defects (concat_ws renders booleans
-- t/f; E1 matched notify_v2's locale read), fixed. Full end-to-end re-run after 20261117054010: see the Jira
-- evidence comment on KAN-975.

BEGIN;

CREATE TEMP TABLE kan975_results (n int GENERATED ALWAYS AS IDENTITY, name text, expected text, actual text)
  ON COMMIT DROP;
GRANT ALL ON kan975_results TO authenticated, anon;

CREATE TEMP TABLE kan975_ids ON COMMIT DROP AS
SELECT (SELECT id FROM auth.users WHERE email = 'dabbler.pro@proton.me') AS a,
       (SELECT id FROM auth.users WHERE email = 'jidep35093@iconcubic.com') AS b,
       gen_random_uuid() AS nobody;
GRANT SELECT ON kan975_ids TO authenticated, anon;

-- Precondition (no DELETE: the pack must run without a destructive statement).
DO $pre$ BEGIN
  IF EXISTS (SELECT 1 FROM public.notification_settings WHERE user_id IN (SELECT a FROM kan975_ids UNION SELECT b FROM kan975_ids)) THEN
    RAISE EXCEPTION 'precondition: A and B must have no notification_settings row (they had none on 2026-11-17)';
  END IF;
END $pre$;

CREATE FUNCTION pg_temp.as_user(p uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
CREATE FUNCTION pg_temp.r(p_name text, p_expected text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO pg_temp.kan975_results (name, expected, actual) VALUES (p_name, p_expected, p_actual);
$$;
GRANT EXECUTE ON FUNCTION pg_temp.as_user(uuid), pg_temp.r(text, text, text) TO authenticated, anon;

-- D2 first, while A and B have no row (as postgres: is_quiet_hour is service-side only).
-- Since 20261117054010 (kan975c) a user with no row has quiet hours OFF.
SELECT pg_temp.r('D2 no row, 01:00 Dubai not quiet (default off)', 'false',
                 public.is_quiet_hour((SELECT nobody FROM kan975_ids), '2026-11-17 01:00 Asia/Dubai')::text);
SELECT pg_temp.r('D2 no row, 12:00 Dubai not quiet', 'false',
                 public.is_quiet_hour((SELECT nobody FROM kan975_ids), '2026-11-17 12:00 Asia/Dubai')::text);

-- D1 ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.as_user((SELECT a FROM kan975_ids));
SET LOCAL ROLE authenticated;
SELECT pg_temp.r('D1 defaults',
  'NULL|NULL|f|sender_and_message|{"going": {"2h": true, "24h": true, "30m": true, "09:00": true}, "interested": {"2h": true, "24h": true, "30m": true, "09:00": true}}|6 categories all on|{}|Asia/Dubai',
  (SELECT concat_ws('|', coalesce(s.quiet_start_min::text, 'NULL'), coalesce(s.quiet_end_min::text, 'NULL'),
                    s.quiet_hours_enabled, s.message_preview, s.reminder_rungs::text,
                    (SELECT count(*) || ' categories all on' FROM jsonb_each(s.category_prefs) e(k, v)
                      WHERE v = '{"in_app": true, "push": true}'::jsonb), s.muted_kinds::text, s.tz)
     FROM public.rpc_get_my_notification_settings() s));
SELECT pg_temp.r('D1 row now exists for A', '1',
  (SELECT count(*)::text FROM public.notification_settings WHERE user_id = (SELECT a FROM kan975_ids)));
RESET ROLE;
SELECT pg_temp.r('D1 A fresh row, 01:00 Dubai not quiet (default off)', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 01:00 Asia/Dubai')::text);

-- D3 the current client's write path (direct upsert under RLS, no quiet columns sent) gets NULL quiet hours.
SELECT pg_temp.as_user((SELECT b FROM kan975_ids));
SET LOCAL ROLE authenticated;
INSERT INTO public.notification_settings (user_id, tz, push_enabled, muted_kinds)
VALUES ((SELECT b FROM kan975_ids), 'Asia/Dubai', true, '{}')
ON CONFLICT (user_id) DO UPDATE SET push_enabled = EXCLUDED.push_enabled;
RESET ROLE;
SELECT pg_temp.r('D3 direct client upsert: quiet NULL/NULL, enabled f', 'NULL|NULL|f',
  (SELECT concat_ws('|', coalesce(quiet_start_min::text, 'NULL'), coalesce(quiet_end_min::text, 'NULL'), quiet_hours_enabled)
     FROM public.notification_settings WHERE user_id = (SELECT b FROM kan975_ids)));
SELECT pg_temp.r('D3 direct client row, 01:00 Dubai not quiet', 'false',
  public.is_quiet_hour((SELECT b FROM kan975_ids), '2026-11-17 01:00 Asia/Dubai')::text);
-- NC3 negative control for D3: the same row with quiet hours switched on by the user IS quiet at 01:00, so the
-- D3 probe can see quiet when it is there.
SELECT pg_temp.as_user((SELECT b FROM kan975_ids));
SET LOCAL ROLE authenticated;
SELECT public.rpc_update_my_notification_settings('{"quiet_hours_enabled": true}');
RESET ROLE;
SELECT pg_temp.r('NC3 B switched on: window 0/480', '0|480|t',
  (SELECT concat_ws('|', quiet_start_min, quiet_end_min, quiet_hours_enabled)
     FROM public.notification_settings WHERE user_id = (SELECT b FROM kan975_ids)));
SELECT pg_temp.r('NC3 B switched on: 01:00 Dubai quiet', 'true',
  public.is_quiet_hour((SELECT b FROM kan975_ids), '2026-11-17 01:00 Asia/Dubai')::text);

-- Q1 (A switches quiet hours on: 00:00-08:00 Dubai) ----------------------------------------------------------------
SELECT pg_temp.as_user((SELECT a FROM kan975_ids));
SET LOCAL ROLE authenticated;
SELECT public.rpc_update_my_notification_settings('{"quiet_hours_enabled": true}');
RESET ROLE;
SELECT pg_temp.r('Q1 01:00 Dubai quiet', 'true',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 01:00 Asia/Dubai')::text);
SELECT pg_temp.r('Q1 12:00 Dubai not quiet', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 12:00 Asia/Dubai')::text);
SELECT pg_temp.r('Q1 08:00 Dubai not quiet (end exclusive)', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 08:00 Asia/Dubai')::text);

-- NC1: write the legacy store as A would have; the result must not move. ------------------------------------------
INSERT INTO public.user_settings (user_id, timezone, quiet_start, quiet_end)
VALUES ((SELECT a FROM kan975_ids), 'Asia/Dubai', '11:00', '13:00')
ON CONFLICT (user_id) DO UPDATE SET timezone = EXCLUDED.timezone, quiet_start = EXCLUDED.quiet_start,
                                    quiet_end = EXCLUDED.quiet_end;
SELECT pg_temp.r('NC1 user_settings says 11:00-13:00; 12:00 still not quiet', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 12:00 Asia/Dubai')::text);
SELECT pg_temp.r('NC1 the old predicate on the same user_settings row would say quiet', 'true',
  (SELECT (('2026-11-17 12:00 Asia/Dubai'::timestamptz AT TIME ZONE us.timezone)::time >= us.quiet_start
           AND ('2026-11-17 12:00 Asia/Dubai'::timestamptz AT TIME ZONE us.timezone)::time < us.quiet_end)::text
     FROM public.user_settings us WHERE us.user_id = (SELECT a FROM kan975_ids)));

-- Q2 / Q3 (A: across midnight, New York; B: 00:00-08:00 Dubai from NC3) ---------------------------------------------
SELECT pg_temp.as_user((SELECT a FROM kan975_ids));
SET LOCAL ROLE authenticated;
SELECT public.rpc_update_my_notification_settings(
  '{"tz": "America/New_York", "quiet_start_min": 1380, "quiet_end_min": 420}'::jsonb);
RESET ROLE;
SELECT pg_temp.r('Q2 23:30 NY quiet', 'true',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 23:30 America/New_York')::text);
SELECT pg_temp.r('Q2 06:59 NY quiet', 'true',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-18 06:59 America/New_York')::text);
SELECT pg_temp.r('Q2 07:00 NY not quiet', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-18 07:00 America/New_York')::text);
SELECT pg_temp.r('Q2 12:00 NY not quiet', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-18 12:00 America/New_York')::text);
SELECT pg_temp.r('Q3 21:00 UTC: B (Dubai 01:00) quiet', 'true',
  public.is_quiet_hour((SELECT b FROM kan975_ids), '2026-11-17 21:00 UTC')::text);
SELECT pg_temp.r('Q3 21:00 UTC: A (New York 16:00) not quiet', 'false',
  public.is_quiet_hour((SELECT a FROM kan975_ids), '2026-11-17 21:00 UTC')::text);
SELECT pg_temp.r('Q3 is_in_quiet_hours agrees with is_quiet_hour(now)', 'true',
  (public.is_in_quiet_hours((SELECT a FROM kan975_ids)) = public.is_quiet_hour((SELECT a FROM kan975_ids), now()))::text);

-- Q4 / Q5 / T1 / R1 / R2 / M1 / M2 (as A) ---------------------------------------------------------------------------
SELECT pg_temp.as_user((SELECT a FROM kan975_ids));
SET LOCAL ROLE authenticated;

DO $t$
DECLARE s public.notification_settings; v text;
BEGIN
  s := public.rpc_update_my_notification_settings('{"quiet_hours_enabled": false}');
  PERFORM pg_temp.r('Q4 off: window cleared, enabled false', '||f', concat_ws('|', coalesce(s.quiet_start_min::text, ''),
                    coalesce(s.quiet_end_min::text, ''), s.quiet_hours_enabled));
  s := public.rpc_update_my_notification_settings('{"quiet_hours_enabled": true}');
  PERFORM pg_temp.r('Q4 back on: default window', '0|480|t',
                    concat_ws('|', s.quiet_start_min, s.quiet_end_min, s.quiet_hours_enabled));
  PERFORM public.rpc_update_my_notification_settings('{"quiet_hours_enabled": false}');

  BEGIN
    PERFORM public.rpc_update_my_notification_settings('{"quiet_start_min": 600, "quiet_end_min": 600}');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('Q5 start=end via rpc rejected', '22023', v);
  BEGIN
    UPDATE public.notification_settings SET quiet_start_min = 600, quiet_end_min = 600
     WHERE user_id = (SELECT a FROM pg_temp.kan975_ids);
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('Q5 start=end via table rejected', '23514', v);

  BEGIN
    PERFORM public.rpc_set_my_notification_timezone('Mars/Olympus');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('T1 bad timezone rejected', '22023', v);
  s := public.rpc_set_my_notification_timezone('Europe/London');
  PERFORM pg_temp.r('T1 device timezone stored', 'Europe/London', s.tz);

  s := public.rpc_update_my_notification_settings(
         '{"reminder_rungs": {"going": {"2h": false}, "interested": {"09:00": false}}}');
  PERFORM pg_temp.r('R1 rungs stored separately',
    'going:24h=true,09:00=true,2h=false,30m=true interested:24h=true,09:00=false,2h=true,30m=true',
    format('going:24h=%s,09:00=%s,2h=%s,30m=%s interested:24h=%s,09:00=%s,2h=%s,30m=%s',
      s.reminder_rungs->'going'->>'24h', s.reminder_rungs->'going'->>'09:00', s.reminder_rungs->'going'->>'2h',
      s.reminder_rungs->'going'->>'30m', s.reminder_rungs->'interested'->>'24h',
      s.reminder_rungs->'interested'->>'09:00', s.reminder_rungs->'interested'->>'2h',
      s.reminder_rungs->'interested'->>'30m'));
  BEGIN
    UPDATE public.notification_settings SET reminder_rungs = '{"going": {"24h": true}, "interested": {}}'
     WHERE user_id = (SELECT a FROM pg_temp.kan975_ids);
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('R2 incomplete rungs rejected', '23514', v);
  BEGIN
    PERFORM public.rpc_update_my_notification_settings('{"reminder_rungs": {"going": {"1h": true}}}');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('R2 unknown rung rejected', '23514', v);

  BEGIN
    PERFORM public.rpc_update_my_notification_settings('{"muted_kinds": ["security.new_signin"]}');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('M1 mute security kind via rpc rejected', '22023', v);
  BEGIN
    UPDATE public.notification_settings SET muted_kinds = ARRAY['security.new_signin']
     WHERE user_id = (SELECT a FROM pg_temp.kan975_ids);
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('M1 mute security kind via table rejected', '22023', v);
  BEGIN
    PERFORM public.rpc_update_my_notification_settings('{"category_prefs": {"security": {"in_app": false, "push": false}}}');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('M1 no security category switch', '23514', v);
  BEGIN
    PERFORM public.rpc_update_my_notification_settings('{"email_enabled": true}');
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('F-15 email flag not settable through the rpc', '22023', v);

  s := public.rpc_update_my_notification_settings(
         '{"muted_kinds": ["social.post_liked"], "push_enabled": false, "message_preview": "sender_only",
           "category_prefs": {"social": {"in_app": false, "push": false}, "messages": {"in_app": false, "push": false},
                              "games": {"in_app": false, "push": false}, "meetups": {"in_app": false, "push": false},
                              "system": {"in_app": false, "push": false},
                              "booking": {"in_app": false, "push": false}}}');
  PERFORM pg_temp.r('M2 mutable kind muted, preview sender_only', '{social.post_liked}|sender_only',
                    s.muted_kinds::text || '|' || s.message_preview);
END
$t$;
RESET ROLE;

-- S1 / NC2 (service side) --------------------------------------------------------------------------------------------
SELECT pg_temp.r('S1 security kind push still on', 'true',
  public.notification_channel_enabled((SELECT a FROM kan975_ids), 'security.new_signin', 'push')::text);
SELECT pg_temp.r('S1 security kind in_app still on', 'true',
  public.notification_channel_enabled((SELECT a FROM kan975_ids), 'security.new_signin', 'in_app')::text);
SELECT pg_temp.r('NC2 same settings silence a mutable kind (push)', 'false',
  public.notification_channel_enabled((SELECT a FROM kan975_ids), 'social.post_liked', 'push')::text);
SELECT pg_temp.r('NC2 same settings silence a mutable kind (in_app, muted)', 'false',
  public.notification_channel_enabled((SELECT a FROM kan975_ids), 'social.post_liked', 'in_app')::text);
SELECT pg_temp.r('S1 B (default category prefs) gets a mutable kind', 'true',
  public.notification_channel_enabled((SELECT b FROM kan975_ids), 'social.post_liked', 'push')::text);

-- L1 RLS (as B) ------------------------------------------------------------------------------------------------------
SELECT pg_temp.as_user((SELECT b FROM kan975_ids));
SET LOCAL ROLE authenticated;
SELECT pg_temp.r('L1 B reads A row', '0',
  (SELECT count(*)::text FROM public.notification_settings WHERE user_id = (SELECT a FROM kan975_ids)));
SELECT pg_temp.r('L1 B sees only its own row', '1|true',
  (SELECT count(*)::text || '|' || bool_and(user_id = (SELECT b FROM kan975_ids))::text FROM public.notification_settings));
WITH u AS (UPDATE public.notification_settings SET message_preview = 'sender_and_message', push_enabled = true
            WHERE user_id = (SELECT a FROM kan975_ids) RETURNING 1)
SELECT pg_temp.r('L1 B updates A row', '0', (SELECT count(*)::text FROM u));
DO $l$
DECLARE v text;
BEGIN
  BEGIN
    INSERT INTO public.notification_settings (user_id) VALUES ((SELECT a FROM pg_temp.kan975_ids));
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('L1 B inserts a row for A', '42501', v);
  BEGIN
    PERFORM public.is_quiet_hour((SELECT a FROM pg_temp.kan975_ids), now());
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('L1 authenticated cannot call is_quiet_hour', '42501', v);
END
$l$;
SELECT pg_temp.r('L1 B own rpc read returns B', 'true',
  ((SELECT user_id FROM public.rpc_get_my_notification_settings()) = (SELECT b FROM kan975_ids))::text);
RESET ROLE;
SELECT pg_temp.r('L1 A row unchanged by B', 'sender_only|false',
  (SELECT message_preview || '|' || push_enabled FROM public.notification_settings
    WHERE user_id = (SELECT a FROM kan975_ids)));

-- L2 anon ------------------------------------------------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"role": "anon"}', true);
SET LOCAL ROLE anon;
DO $n$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM count(*) FROM public.notification_settings;
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('L2 anon reads table', '42501', v);
  BEGIN
    PERFORM public.is_quiet_hour(gen_random_uuid(), now());
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('L2 anon executes is_quiet_hour', '42501', v);
  BEGIN
    PERFORM public.rpc_get_my_notification_settings();
    v := 'accepted';
  EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('L2 anon executes rpc_get', '42501', v);
END
$n$;
RESET ROLE;

-- E1 catalogue -------------------------------------------------------------------------------------------------------
SELECT pg_temp.r('E1 functions reading email_enabled/sms_enabled', '',
  coalesce((SELECT string_agg(p.oid::regprocedure::text, ', ') FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p')
               AND pg_get_functiondef(p.oid) ~* '(email_enabled|sms_enabled)'), ''));
-- (user_settings.locale is still read by render_notification and KAN-974's notify_v2: locale is not a
--  notification setting. The check is on the quiet-hours and timezone fields only.)
SELECT pg_temp.r('E1 functions reading user_settings quiet hours or timezone', '',
  coalesce((SELECT string_agg(p.oid::regprocedure::text, ', ') FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p')
               AND pg_get_functiondef(p.oid) ~* 'user_settings'
               AND pg_get_functiondef(p.oid) ~* '(quiet_start|quiet_end|timezone)'), ''));
SELECT pg_temp.r('E1 is_quiet_hour proacl', '{postgres=X/postgres,service_role=X/postgres}',
  (SELECT proacl::text FROM pg_proc WHERE oid = 'public.is_quiet_hour(uuid,timestamptz)'::regprocedure));

SELECT n, CASE WHEN expected IS NOT DISTINCT FROM actual THEN 'PASS' ELSE 'FAIL' END AS verdict, name, expected, actual
  FROM kan975_results ORDER BY n;

ROLLBACK;
