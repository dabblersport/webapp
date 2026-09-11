-- KAN-178 AC5 / T-079 Amendment 3 — the two SECURITY INVOKER readers of
-- public.role_grants become SECURITY DEFINER **and** relocate to util,
-- in ONE transaction.
-- Authored and applied by backend-5 (Heka) 2026-09-11.
--
-- APPLIED forward-only via MCP `apply_migration`, never `db push` (T-068).
-- Remote ledger version 20260911081512. The filename IS that version, not a
-- round-hour stamp — see T-068 §B; the same linkage was made on this ticket's
-- first migration, 20260911080427.
--
-- ===========================================================================
-- WHY BOTH CHANGES, AND WHY NEITHER MAY LAND ALONE
-- ===========================================================================
-- KAN-178's first migration (20260911080427) made role_grants admin-only.
-- public.is_moderator(uuid) and public.is_venue_admin(uuid) are SECURITY
-- INVOKER and read that table, so they now answer FALSE for a non-admin caller
-- even when the grant exists — silently, no error.
--
-- Fixing that by flipping them to DEFINER **alone** would be worse, not better:
--
--   * As INVOKER they hold anon EXECUTE but leak nothing, because RLS applies
--     to the caller. That is exactly why the bug is silent.
--   * As DEFINER they bypass RLS, read role_grants in full, AND STILL TAKE A
--     CALLER-SUPPLIED uuid. `POST /rpc/is_venue_admin` as anon with any uuid
--     would then disclose whether an arbitrary user holds that role.
--
-- That is the T-070 identity-parameter oracle, measured answering `200 false`
-- over HTTP and closed for five sibling functions under KAN-188. Definer-only
-- would reopen it on two new functions.
--
-- Revoking EXECUTE instead does not work either (§6d option 2): the three
-- storage.objects policies below call is_venue_admin AS THE CALLER, so a
-- revoke breaks them with 42501 — the same failure KAN-188 measured.
--
--   definer-first  -> opens the oracle
--   relocate-first -> leaves them answering false
--
-- NEITHER INTERMEDIATE STATE MAY EXIST. Both changes are in the single
-- transaction below.
--
-- ===========================================================================
-- THE CONTAINMENT MECHANISM, WHICH IS THE REVERSE OF ORDINARY CONTAINMENT
-- ===========================================================================
-- EXECUTE is deliberately KEPT for anon and authenticated. `util` withholds
-- USAGE from both (verified live: has_schema_privilege('anon','util','USAGE')
-- and the same for authenticated are both FALSE; util.nspacl is NULL, i.e.
-- owner-only defaults).
--
--   * PostgREST resolves an RPC BY NAME -> needs schema USAGE -> denied.
--     The oracle endpoint is closed.
--   * An RLS policy qual stores the function's OID and performs no name
--     resolution at execution time, so no USAGE check occurs; only EXECUTE on
--     the function is checked, and that is retained. Policy execution survives.
--
-- Get this backwards — revoke EXECUTE, or grant util USAGE — and you either
-- reproduce KAN-188's 42501 or reopen the oracle.
--
-- ===========================================================================
-- ALTER, NEVER DROP + CREATE
-- ===========================================================================
-- `ALTER FUNCTION … SET SCHEMA util` preserves the OID, and the OID is what
-- the three storage.objects policy quals are bound to. A DROP + CREATE would
-- mint a new OID, silently orphan those quals, and additionally re-derive
-- grants from pg_default_acl. CREATE OR REPLACE (used below for the security
-- attribute) also preserves the OID and the existing proacl. Both OIDs are
-- asserted unchanged at the end of this file.
--
-- ===========================================================================
-- §6d CALLER SWEEP — RUN ACROSS THE WHOLE DATABASE, AND IT COMES BACK CLEAN
-- ===========================================================================
-- Policy quals are OID-bound and safe. plpgsql callers are NOT: they re-parse
-- by name at runtime and break silently. That is what bit KAN-188, where
-- rpc_my_venue_permissions was a seventh function no sweep had covered. So
-- this sweep covered pg_proc (every schema), pg_policy, views/matviews, and
-- CHECK constraints — not just these two functions' obvious neighbours.
--
-- Callers of the 1-arg is_venue_admin(uuid) — the function being moved:
--   storage.objects / venue_insert_admin   (INSERT)  OID-bound, safe
--   storage.objects / venue_update_admin   (UPDATE)  OID-bound, safe
--   storage.objects / venue_delete_admin   (DELETE)  OID-bound, safe
--
-- Callers of is_moderator(uuid): **NONE**. No policy, no function, no view,
-- no constraint, in any schema. It is a dormant helper.
--
-- THE THREE plpgsql CALLERS ARE NOT AFFECTED, AND THIS IS THE OVERLOAD TRAP
-- FIRING AGAIN — read the body, not the name. rpc_booking_cancel,
-- rpc_booking_hold_for_game and rpc_booking_hold_for_meetup all call
-- `public.is_venue_admin(auth.uid(), vid)` — the **2-arg** overload, and
-- schema-qualified. Measured from prosrc, not assumed from the function name.
--
-- ===========================================================================
-- SCOPE — THE 1-ARG OVERLOAD ONLY. THE 2-ARG IS IMMUNE AND IS NOT TOUCHED.
-- ===========================================================================
--   public.is_venue_admin(p_user uuid)            oid 20147/20148 -> MOVED
--     select exists (select 1 from public.role_grants where …)
--
--   public.is_venue_admin(p_user uuid, p_venue uuid)  oid 22308 -> UNTOUCHED
--     select public.is_admin(p_user)
--        or exists (select 1 from public.venue_members vm where …)
--
-- The 2-arg never reads role_grants — it routes through SECURITY DEFINER
-- is_admin and otherwise reads venue_members — so it cannot exhibit the
-- fail-closed bug and must not be converted. It is what venue_spaces,
-- venue_blackouts and venue_price_rules call. Converting it would be
-- over-reach and would move a function three live policies resolve by name.
--
-- Population is COMPLETE, not a sample: sweeping every function in public and
-- util whose body references role_grants, exactly two are prosecdef = false —
-- these two. Every other reader is already DEFINER.
--
-- ===========================================================================
-- T-058 — BODIES RESTATED VERBATIM FROM LIVE pg_get_functiondef
-- ===========================================================================
-- Read from the live catalogue 2026-09-11, never from a migration file. Only
-- the security attribute changes. LANGUAGE sql, STABLE and
-- `SET search_path TO 'public', 'pg_temp'` are all carried forward unchanged
-- (T-044 / CONVENTIONS §6c: CREATE OR REPLACE silently resets anything not
-- restated). The bodies already fully qualify public.role_grants, so they
-- resolve correctly from util without a search_path change — and changing it
-- would be an unrequested edit to a security function.

begin;

-- ---------------------------------------------------------------------------
-- 1. is_moderator(uuid) -> SECURITY DEFINER
-- ---------------------------------------------------------------------------
create or replace function public.is_moderator(p_user uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select exists (select 1 from public.role_grants where user_id=p_user and role='moderator')
$function$;

-- ---------------------------------------------------------------------------
-- 2. is_venue_admin(uuid) -> SECURITY DEFINER   (1-ARG ONLY)
-- ---------------------------------------------------------------------------
create or replace function public.is_venue_admin(p_user uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select exists (select 1 from public.role_grants where user_id=p_user and role='venue_admin')
$function$;

-- ---------------------------------------------------------------------------
-- 3. relocate both to util — same transaction, so the oracle never exists
-- ---------------------------------------------------------------------------
-- Argument types disambiguate the overload: (uuid) is the 1-arg.
-- (uuid, uuid) is NOT named here and stays in public.

alter function public.is_moderator(uuid)   set schema util;
alter function public.is_venue_admin(uuid) set schema util;

-- ---------------------------------------------------------------------------
-- 4. guards — count-shaped against stated expectations, and they assert
--    PROPERTIES, not existence
-- ---------------------------------------------------------------------------
-- Shape matters independently of care: `RAISE IF n <> expected` on a blind
-- predicate yields 0 <> expected and aborts (fails closed), where a bare
-- boolean testing NULL would raise nothing and read as success. Every check
-- below is a count against an expectation.
--
-- They assert the PROPERTY, not the name — an object of the right name with
-- the wrong shape must not satisfy them. The OID assertions are the strongest:
-- they prove ALTER preserved identity rather than a DROP + CREATE having
-- silently orphaned the three storage.objects policy quals.

do $$
declare
  v_in_util    int;
  v_definer    int;
  v_2arg       int;
  v_anon_exec  int;
  v_oid_mod    oid;
  v_oid_venue  oid;
begin
  select count(*) into v_in_util
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'util' and p.proname in ('is_moderator','is_venue_admin')
     and pg_get_function_identity_arguments(p.oid) = 'p_user uuid';
  if v_in_util <> 2 then
    raise exception 'KAN-178 AC5: expected 2 relocated functions in util, found %', v_in_util;
  end if;

  select count(*) into v_definer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'util' and p.proname in ('is_moderator','is_venue_admin')
     and p.prosecdef = true;
  if v_definer <> 2 then
    raise exception 'KAN-178 AC5: expected 2 SECURITY DEFINER, found %', v_definer;
  end if;

  -- the 2-arg overload must be untouched: still public, still INVOKER
  select count(*) into v_2arg
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'is_venue_admin'
     and pg_get_function_identity_arguments(p.oid) = 'p_user uuid, p_venue uuid'
     and p.prosecdef = false;
  if v_2arg <> 1 then
    raise exception 'KAN-178 AC5: 2-arg is_venue_admin must remain public+INVOKER, found %', v_2arg;
  end if;

  -- EXECUTE for anon must be RETAINED: it is what keeps the storage.objects
  -- policies working. Containment is util's withheld USAGE, not this grant.
  select count(*) into v_anon_exec
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'util' and p.proname in ('is_moderator','is_venue_admin')
     and has_function_privilege('anon', p.oid, 'EXECUTE');
  if v_anon_exec <> 2 then
    raise exception 'KAN-178 AC5: anon EXECUTE must be retained on both, found %', v_anon_exec;
  end if;

  -- identity preserved: ALTER, not DROP+CREATE
  select p.oid into v_oid_mod from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname='is_moderator';
  select p.oid into v_oid_venue from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname='is_venue_admin'
     and pg_get_function_identity_arguments(p.oid) = 'p_user uuid';
  if v_oid_mod <> 20147::oid then
    raise exception 'KAN-178 AC5: is_moderator OID changed (% <> 20147) - policy quals orphaned', v_oid_mod;
  end if;
  if v_oid_venue <> 20148::oid then
    raise exception 'KAN-178 AC5: is_venue_admin OID changed (% <> 20148) - policy quals orphaned', v_oid_venue;
  end if;
end $$;

commit;
