-- KAN-188: contain the venue-authority authorisation oracle by relocating the five
-- functions out of the PostgREST-exposed schema. CONVENTIONS.md §6d option 3.
--
-- Applied via apply_migration; filename carries the exact version the ledger returned
-- (20260911080000), so `supabase migration list` matches repo-to-remote by name.
--
-- WHY NOT A REVOKE. The obvious fix -- REVOKE EXECUTE FROM PUBLIC, anon -- was authored,
-- dry-run in a rolled-back transaction, and rejected on measurement. These functions are
-- not reached only through PostgREST: SEVEN RLS POLICIES call them, every one with
-- roles = {public}, which includes anon, and anon holds table SELECT on venues,
-- venue_spaces, venue_members and venue_bookings. A policy qual is evaluated as the
-- INVOKING role, so revoking EXECUTE denies anon the policy itself: venues (379 rows) and
-- venue_spaces (679 rows) both returned 42501. Revoking authenticated as well broke all
-- eight paths, signed-in users included. This is CONVENTIONS.md §6d's known hazard --
-- "Option 2 is unsafe when a security_invoker view calls the function" (measured on
-- circle_member_count, KAN-77) -- arriving through RLS policies instead of views. Both
-- evaluate as the caller. Option 1 is impossible here because these functions ARE the
-- authorization, hence option 3.
--
-- THE MECHANISM, WHICH IS COUNTERINTUITIVE. A stored RLS policy qual holds the function
-- OID. Schema USAGE is checked at NAME RESOLUTION, which for a stored policy already
-- happened; EXECUTE is checked at RUN TIME, by OID. So the containment is:
--
--     revoke schema USAGE  --  KEEP EXECUTE for anon and authenticated
--
-- which is the reverse of what a grant-revoke instinct suggests. Keeping EXECUTE is what
-- preserves every venue RLS policy; withholding USAGE on util is what removes the
-- by-name/RPC reachability. ALTER ... SET SCHEMA, never DROP+CREATE: only ALTER preserves
-- the OID, and the OID is the entire mechanism.

ALTER FUNCTION public.can_manage_venue(uuid, uuid)         SET SCHEMA util;
ALTER FUNCTION public.can_manage_venue_members(uuid, uuid) SET SCHEMA util;
ALTER FUNCTION public.can_view_venue_bookings(uuid, uuid)  SET SCHEMA util;
ALTER FUNCTION public.can_create_venue_booking(uuid, uuid) SET SCHEMA util;
ALTER FUNCTION public.can_edit_venue_details(uuid, uuid)   SET SCHEMA util;

-- REQUIRED by the relocation, not an unrelated change. rpc_my_venue_permissions is a
-- plpgsql SECURITY DEFINER function whose body calls all five by public.-QUALIFIED name.
-- plpgsql bodies are stored as TEXT and re-parsed at run time (prosqlbody IS NULL, and
-- pg_depend records no function->function edge), so the move alone leaves it raising
-- 42883. Verified: post-move it fails, and so does a fresh-plan clone of the same body,
-- which rules out plan caching. A first probe of this appeared to PASS and was wrong --
-- with no JWT the function takes an early return and never reaches the five calls at all.
-- Body taken from pg_get_functiondef on the live catalogue (CONVENTIONS.md 6g) with only
-- the five schema qualifiers changed public. -> util. CREATE OR REPLACE (not DROP+CREATE)
-- preserves proacl.
-- It runs as its owner, which holds USAGE on util, so anon/authenticated callers still
-- reach it; and it derives the subject from request.jwt.claims rather than from an
-- argument, so it answers only about the caller. That is precisely why it is a safe
-- public interface while the raw five are not -- the five take an arbitrary p_user_id.
CREATE OR REPLACE FUNCTION public.rpc_my_venue_permissions(p_venue_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare
  v_user_id uuid;
  v_claims jsonb;
begin
  -- Extract JWT safely
  v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_user_id := (v_claims ->> 'sub')::uuid;

  if v_user_id is null then
    return jsonb_build_object(
      'can_manage', false,
      'can_edit_details', false,
      'can_view_bookings', false,
      'can_create_booking', false,
      'can_manage_members', false
    );
  end if;

  return jsonb_build_object(
    'can_manage',
      util.can_manage_venue(v_user_id, p_venue_id),

    'can_edit_details',
      util.can_edit_venue_details(v_user_id, p_venue_id),

    'can_view_bookings',
      util.can_view_venue_bookings(v_user_id, p_venue_id),

    'can_create_booking',
      util.can_create_venue_booking(v_user_id, p_venue_id),

    'can_manage_members',
      util.can_manage_venue_members(v_user_id, p_venue_id)
  );
end;
$function$;

-- Post-conditions. Assert the resulting catalogue state, never that the statements ran.
-- Resolution is via to_regprocedure(): do NOT compare
-- pg_get_function_identity_arguments = 'uuid, uuid', because that emits PARAMETER NAMES
-- ('p_user_id uuid, p_venue_id uuid'), so the comparison never matches, every IF tests
-- NULL, and the assertion passes blind. That exact defect was written here first and
-- caught only by running the assertion with no change in place and watching it fail to
-- fail.
DO $assert$
DECLARE
  fn   text;
  oid_ regprocedure;
  bad  text := '';
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'can_manage_venue',
    'can_manage_venue_members',
    'can_view_venue_bookings',
    'can_create_venue_booking',
    'can_edit_venue_details'
  ] LOOP
    IF to_regprocedure(format('public.%I(uuid,uuid)', fn)) IS NOT NULL THEN
      bad := bad || format(E'\n  %s: still resolvable in public - RPC surface not removed', fn);
    END IF;

    oid_ := to_regprocedure(format('util.%I(uuid,uuid)', fn));
    IF oid_ IS NULL THEN
      bad := bad || format(E'\n  %s: did not arrive in util', fn);
      CONTINUE;
    END IF;

    -- EXECUTE must be RETAINED, or every venue RLS policy raises 42501
    IF NOT has_function_privilege('anon', oid_, 'EXECUTE') THEN
      bad := bad || format(E'\n  %s: anon LOST EXECUTE - anon venue reads are now dead', fn);
    END IF;
    IF NOT has_function_privilege('authenticated', oid_, 'EXECUTE') THEN
      bad := bad || format(E'\n  %s: authenticated LOST EXECUTE - venue RLS is now dead', fn);
    END IF;
  END LOOP;

  -- Containment boundary, and the substitute for the docs/SCHEMA.md §2g gate cover these
  -- five lose by leaving public. util must remain unreachable by name to both API roles.
  -- NOTE: the true boundary is PostgREST's exposed-schema config, which is API
  -- configuration and NOT visible in the catalogue. Verified out of band against the live
  -- API, which reports: "Only the following schemas are exposed: public, graphql_public".
  IF has_schema_privilege('anon', 'util', 'USAGE') THEN
    bad := bad || E'\n  anon holds USAGE on util - containment boundary is open';
  END IF;
  IF has_schema_privilege('authenticated', 'util', 'USAGE') THEN
    bad := bad || E'\n  authenticated holds USAGE on util - containment boundary is open';
  END IF;

  -- is_venue_admin stays in public DELIBERATELY: both overloads are SECURITY INVOKER, so
  -- they are bounded by the caller's own RLS and are not an oracle. Asserted at 2 so that
  -- a later move, or the loss of an overload, is a decision rather than an accident --
  -- a by-name enumeration sees only one of the two.
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'is_venue_admin') <> 2 THEN
    bad := bad || E'\n  expected exactly 2 public.is_venue_admin overloads to remain in public';
  END IF;

  IF bad <> '' THEN
    RAISE EXCEPTION 'KAN-188 post-condition failed:%', bad;
  END IF;
END
$assert$;
