-- KAN-713 ROLLBACK. One transaction. Undoes 20261104110000 and 20261104100000 together, from the
-- pre-images both migrations saved in public.kan713_preimage. No DROP TABLE, no CASCADE, no data write.
--
-- ORDER: run this BEFORE rollback_kan712.sql. KAN-712's rollback asserts the exact events trigger set and
-- KAN-713 adds trg_kan713_events_location to events, so the reverse order is refused by KAN-712's check.
-- This script refuses to run if KAN-712's stage B markers are already gone.
--
-- What it does (each step asserted at the end):
--   1. gate: KAN-713 fully applied, pre-images complete (5 function, 4 policy, 5 trigger), KAN-712 B present
--   2. functions G-1..G-5 recreated from their saved pg_get_functiondef (CREATE OR REPLACE keeps ACL/owner)
--   3. policies P-1..P-4 restored from their saved USING / WITH CHECK text
--   4. the six KAN-713 triggers dropped; the six KAN-713 trigger functions dropped
--   5. the four kan713_meetup_* helpers dropped (after step 3 removed every policy reference to them)
--   6. the five legacy location triggers returned to their saved tgenabled
--   7. postconditions: md5(pg_get_functiondef) = md5(saved), proacl = saved, owner = saved; policy text =
--      saved; pg_get_triggerdef + tgenabled = saved; no kan713 function or trigger remains
-- Kept on purpose: public.kan713_preimage (the evidence; RLS on, no API grants). Drop it by hand later if wanted.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL search_path = public, pg_catalog;
LOCK TABLE public.events, public.games, public.meetups, public.meetup_attendees IN SHARE ROW EXCLUSIVE MODE;

-- 1. gate ------------------------------------------------------------------------------------------------
DO $$
DECLARE v_missing text;
BEGIN
  IF NOT (SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-713 rollback: run as the migration owner (superuser or BYPASSRLS)';
  END IF;
  IF to_regclass('public.kan713_preimage') IS NULL THEN
    RAISE EXCEPTION 'KAN-713 rollback: public.kan713_preimage missing - nothing to restore from';
  END IF;
  IF (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'function') <> 5
     OR (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'policy') <> 4
     OR (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'trigger') <> 5 THEN
    RAISE EXCEPTION 'KAN-713 rollback: pre-images incomplete (need 5 function / 4 policy / 5 trigger)';
  END IF;
  SELECT string_agg(x, ', ') INTO v_missing FROM unnest(ARRAY[
      'public.kan713_meetup_visible(uuid)', 'public.kan713_meetup_can_read_row(uuid)',
      'public.kan713_meetup_attendee_visible(uuid)', 'public.kan713_meetup_can_write_row(uuid)',
      'public.kan713_games_location()', 'public.kan713_games_joining()', 'public.kan713_games_venue_geo()',
      'public.kan713_meetups_location()', 'public.kan713_meetups_joining()', 'public.kan713_events_location()']) x
   WHERE to_regprocedure(x) IS NULL;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713 rollback: KAN-713 not fully applied, missing: %', v_missing;
  END IF;
  -- KAN-712 stage B markers: the five zz guards / mirror. If KAN-712 was rolled back first, stop.
  IF (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'trg_zz_kan712_%') <> 5 THEN
    RAISE EXCEPTION 'KAN-713 rollback: KAN-712 stage B triggers not all present - roll back KAN-713 before KAN-712';
  END IF;
END $$;

-- 2. functions ---------------------------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT object, definition FROM public.kan713_preimage WHERE kind = 'function' ORDER BY object LOOP
    EXECUTE r.definition;
  END LOOP;
END $$;

-- 3. policies ----------------------------------------------------------------------------------------------
DO $$
DECLARE r record; v_name text;
BEGIN
  FOR r IN SELECT object, pol_table, pol_qual, pol_check FROM public.kan713_preimage WHERE kind = 'policy' ORDER BY object LOOP
    v_name := split_part(r.object, '.', 2);
    IF r.pol_check IS NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', v_name, r.pol_table, r.pol_qual);
    ELSE
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s) WITH CHECK (%s)', v_name, r.pol_table, r.pol_qual, r.pol_check);
    END IF;
  END LOOP;
END $$;

-- 4. KAN-713 triggers and trigger functions ------------------------------------------------------------------
DROP TRIGGER trg_kan713_games_a_location   ON public.games;
DROP TRIGGER trg_kan713_games_b_joining    ON public.games;
DROP TRIGGER trg_kan713_games_c_venue_geo  ON public.games;
DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups;
DROP TRIGGER trg_kan713_meetups_b_joining  ON public.meetups;
DROP TRIGGER trg_kan713_events_location    ON public.events;
DROP FUNCTION public.kan713_games_location();
DROP FUNCTION public.kan713_games_joining();
DROP FUNCTION public.kan713_games_venue_geo();
DROP FUNCTION public.kan713_meetups_location();
DROP FUNCTION public.kan713_meetups_joining();
DROP FUNCTION public.kan713_events_location();

-- 5. policy helpers (no policy references them after step 3; DROP without CASCADE proves it) ---------------
DROP FUNCTION public.kan713_meetup_visible(uuid);
DROP FUNCTION public.kan713_meetup_can_read_row(uuid);
DROP FUNCTION public.kan713_meetup_attendee_visible(uuid);
DROP FUNCTION public.kan713_meetup_can_write_row(uuid);

-- 6. legacy location triggers back to their saved state ---------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT object, pol_table, tg_enabled FROM public.kan713_preimage WHERE kind = 'trigger' ORDER BY object LOOP
    EXECUTE format('ALTER TABLE public.%I %s TRIGGER %I', r.pol_table,
                   CASE r.tg_enabled WHEN 'O' THEN 'ENABLE' WHEN 'D' THEN 'DISABLE'
                                     WHEN 'R' THEN 'ENABLE REPLICA' WHEN 'A' THEN 'ENABLE ALWAYS' END,
                   split_part(r.object, '.', 2));
  END LOOP;
END $$;

-- 7. postconditions -----------------------------------------------------------------------------------------
DO $$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(s.object, ', ') INTO v_bad
    FROM public.kan713_preimage s JOIN pg_proc p ON p.oid = s.object::regprocedure
   WHERE s.kind = 'function'
     AND (md5(pg_get_functiondef(p.oid)) <> md5(s.definition) OR p.proacl IS DISTINCT FROM s.acl
          OR p.proowner::regrole::text <> s.owner);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 rollback: function differs from pre-image: %', v_bad; END IF;

  SELECT string_agg(s.object, ', ') INTO v_bad
    FROM public.kan713_preimage s
    LEFT JOIN pg_policies p ON p.schemaname = 'public' AND p.tablename = s.pol_table AND p.policyname = split_part(s.object, '.', 2)
   WHERE s.kind = 'policy'
     AND (p.policyname IS NULL OR p.qual IS DISTINCT FROM s.pol_qual OR p.with_check IS DISTINCT FROM s.pol_check);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 rollback: policy differs from pre-image: %', v_bad; END IF;

  SELECT string_agg(s.object, ', ') INTO v_bad
    FROM public.kan713_preimage s
    LEFT JOIN pg_class c ON c.relnamespace = 'public'::regnamespace AND c.relname = s.pol_table
    LEFT JOIN pg_trigger t ON t.tgrelid = c.oid AND t.tgname = split_part(s.object, '.', 2)
   WHERE s.kind = 'trigger'
     AND (t.oid IS NULL OR pg_get_triggerdef(t.oid) <> s.definition OR t.tgenabled <> s.tg_enabled);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 rollback: trigger differs from pre-image: %', v_bad; END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname LIKE 'kan713\_%')
     OR EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'trg\_kan713\_%') THEN
    RAISE EXCEPTION 'KAN-713 rollback: a kan713 function or trigger remains';
  END IF;
  IF has_table_privilege('anon', 'public.events', 'SELECT') OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'events') THEN
    RAISE EXCEPTION 'KAN-713 rollback: events is no longer closed';
  END IF;
  RAISE NOTICE 'KAN-713 rollback: OK (5 functions, 4 policies, 5 legacy triggers restored; 10 kan713 functions and 6 triggers removed)';
END $$;
COMMIT;
