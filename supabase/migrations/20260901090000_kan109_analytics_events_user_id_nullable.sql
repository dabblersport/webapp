-- KAN-109 — analytics_events.user_id fails NOT NULL for pre-auth events,
-- authored by backend-owner (2026-09-01), revised per cto ruling T-043.
--
-- Confirmed live against wtncuzcskpigqpmnxwws:
--
--   SELECT column_name, is_nullable FROM information_schema.columns
--   WHERE table_schema='public' AND table_name='analytics_events' AND column_name='user_id';
--   -- user_id | NO
--
--   SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'rpc_track_event';
--   -- INSERT INTO public.analytics_events (user_id, event_name, properties)
--   -- VALUES (auth.uid(), _event_name, coalesce(_properties, '{}'::jsonb));
--   -- SECURITY DEFINER, EXECUTE granted to anon and authenticated.
--
-- rpc_track_event inserts auth.uid() directly, which is NULL for an
-- unauthenticated caller. This is not a bad call site to fix client-side:
-- main.dart fires flags_snapshot pre-auth by design (feature-flag exposure
-- tracking, before login — confirmed at lib/main.dart:78, app startup),
-- and the RPC is deliberately EXECUTE-granted to anon to support exactly
-- this. A Dart-side gate would also be security theater, not a control:
-- the RPC is callable directly with the publishable key that ships in the
-- web bundle, so gating our own client changes what OUR client sends and
-- nothing about what anyone else can send.
--
-- cto ruling (T-043, 2026-09-01): nullable is correct, but it CANNOT ship
-- alone. rpc_track_event's entire body today is:
--   INSERT INTO public.analytics_events (user_id, event_name, properties)
--   VALUES (auth.uid(), _event_name, coalesce(_properties, '{}'::jsonb));
-- No rate limit, no validation, no cap on _properties. anon holds EXECUTE.
-- The NOT NULL constraint is, right now, the only thing stopping
-- unauthenticated unbounded writes — every anon call fails on it today.
-- Dropping it alone converts "anon writes fail by luck" into "anon writes
-- succeed without limit, arbitrary event names, arbitrary JSONB, at
-- storage cost, forever." That is a control accidentally implemented as
-- an absent nullable column, the same shape as the zero-policy tables in
-- T-012 — this migration replaces it with a real one in the same change.
--
-- Replacement control, decided per cto's recommendation:
--   1. Event-name allowlist for anonymous (auth.uid() IS NULL) callers.
--      Grepped every AnalyticsService.trackEvent/trackScreen/setUser call
--      site in lib/ to find what genuinely fires pre-auth:
--        lib/main.dart:78                                    flags_snapshot   (app startup, pre-auth)
--        lib/features/social/providers/post_providers.dart    post_created     (post-auth feature)
--        lib/.../otp_verification_screen.dart:229              signup           (fires AFTER verifyOtp
--                                                                                 succeeds + session
--                                                                                 refresh — authenticated)
--        lib/.../auth_providers.dart:171,173                  session_started  (post sign-in)
--      Only flags_snapshot is genuinely anonymous today. Allowlist is one
--      row; anything else needs a real caller before it's added, same
--      reasoning as the KAN-75 ruling — don't grant for a consumer that
--      doesn't exist yet.
--   2. A size cap on _properties (4096 bytes) — cheap belt-and-braces
--      against payload stuffing, applies to every caller, authenticated
--      included. A per-caller rate limit is out of scope (hard for
--      anon in Postgres, per cto — not blocking on it).
--
-- Both ship in this one migration; the DROP NOT NULL and its replacement
-- control are one change, not two.

BEGIN;

ALTER TABLE public.analytics_events ALTER COLUMN user_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.rpc_track_event(_event_name text, _properties jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL AND _event_name IS DISTINCT FROM 'flags_snapshot' THEN
    RAISE EXCEPTION 'event "%" is not permitted for unauthenticated callers', _event_name
      USING ERRCODE = '42501';
  END IF;

  IF pg_column_size(_properties) > 4096 THEN
    RAISE EXCEPTION 'properties payload exceeds 4096 bytes'
      USING ERRCODE = '22001';
  END IF;

  INSERT INTO public.analytics_events (user_id, event_name, properties)
  VALUES (v_uid, _event_name, coalesce(_properties, '{}'::jsonb));
END;
$function$;

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply.
-- ============================================================================
--
-- 1. Column is nullable:
--    SELECT is_nullable FROM information_schema.columns
--    WHERE table_schema='public' AND table_name='analytics_events' AND column_name='user_id';
--    -- expect: YES
--
-- 2. anon CAN insert the allowlisted pre-auth event (rolled back):
--    BEGIN; SET LOCAL ROLE anon;
--    SELECT public.rpc_track_event('flags_snapshot', '{"test": true}'::jsonb);
--    -- expect: no error
--    ROLLBACK;
--
-- 3. anon CANNOT insert any other event name (rolled back):
--    BEGIN; SET LOCAL ROLE anon;
--    SELECT public.rpc_track_event('arbitrary_event', '{}'::jsonb);
--    -- expect: ERROR, 42501, "event ... is not permitted for unauthenticated callers"
--    ROLLBACK;
--
-- 4. Oversized properties rejected regardless of caller (rolled back):
--    BEGIN; SET LOCAL ROLE anon;
--    SELECT public.rpc_track_event('flags_snapshot', jsonb_build_object('pad', repeat('x', 5000)));
--    -- expect: ERROR, 22001, "properties payload exceeds 4096 bytes"
--    ROLLBACK;
--
-- 5. Authenticated callers are unrestricted on event name (existing
--    behavior preserved) — rolled back:
--    BEGIN; SET LOCAL ROLE authenticated;
--    PERFORM set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid())::text, true);
--    SELECT public.rpc_track_event('post_created', '{"post_id": "x"}'::jsonb);
--    -- expect: no error
--    ROLLBACK;
--
-- 6. EXECUTE grants unchanged (CREATE OR REPLACE preserves them for an
--    unchanged signature) — confirm anon/authenticated/service_role still
--    hold EXECUTE on rpc_track_event(text, jsonb) after apply.
