-- APPLIED 2026-09-12 via apply_migration. Ledger version 20260912145504.
--
-- KAN-187: trgfn_organiser_profile_persona_guard's RAISE EXCEPTION message
-- string names organiser_profiles, a table that no longer exists (renamed to
-- public.organiser). Cosmetic/diagnostic only -- the guard logic, FROM
-- clause, and trigger attachment are already correct and are not touched.
-- Body restated verbatim from the live catalogue (pg_get_functiondef) per
-- T-044/CONVENTIONS.md 6c; only the message text differs.
--
-- Verified live post-apply: trigger attachment unchanged (trg_organiser_
-- profile_persona_guard, BEFORE INSERT OR UPDATE, unscoped, on
-- public.organiser); the guard condition was actually fired (a rolled-back
-- probe insert with a profile_id matching no organiser-persona profile) and
-- its message text read verbatim "organiser.profile_id must reference a
-- profiles row with persona_type = organiser" -- no reference to the stale
-- table name. Row count on public.organiser unchanged at 11 (matching the
-- ticket's own baseline), confirming no residual data from the probe.

CREATE OR REPLACE FUNCTION public.trgfn_organiser_profile_persona_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = NEW.profile_id
      AND p.persona_type = 'organiser'
  ) THEN
    RAISE EXCEPTION
      'organiser.profile_id must reference a profiles row with persona_type = organiser';
  END IF;

  RETURN NEW;
END;
$function$;

DO $$
DECLARE
  v_oid oid;
BEGIN
  v_oid := 'public.trgfn_organiser_profile_persona_guard()'::regprocedure;

  IF (SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'organiser_profiles' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: body still references organiser_profiles';
  END IF;
  IF NOT ((SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'organiser\.profile_id') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: corrected message text not present';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: function became SECURITY DEFINER';
  END IF;
  IF NOT ((SELECT proconfig FROM pg_proc WHERE oid = v_oid) @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: search_path changed';
  END IF;
  IF NOT ((SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'FROM public\.profiles p') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: FROM clause changed';
  END IF;
END $$;
