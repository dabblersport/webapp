-- KAN-178 AC5 rework / T-079 Amendment 3 — add `row_security=off` to the two
-- relocated helpers. PEER FAIL by backend-6, upheld.
-- Authored and applied by backend-5 (Heka) 2026-09-11.
--
-- APPLIED forward-only via MCP `apply_migration`, never `db push` (T-068).
-- Remote ledger version 20260911105846. Filename is that version deliberately
-- (T-068 §B), matching this ticket's other two migrations.
--
-- ===========================================================================
-- WHAT WAS WRONG
-- ===========================================================================
-- 20260911081512 relocated util.is_moderator(uuid) and util.is_venue_admin(uuid)
-- to `util` and made them SECURITY DEFINER — but carried the invoker-era
-- proconfig through verbatim: {search_path=public, pg_temp}. The ruled value
-- adds `row_security=off`.
--
-- The failure was not just the missing attribute, it was that it was
-- UNDECLARED. That header flagged the `TO authenticated` deviation explicitly
-- and never mentioned row_security at all, so nothing in the artifact told a
-- reviewer whether it had been considered and rejected or simply missed. It
-- was missed. T-058 discipline covers restating what exists; it does not by
-- itself prompt you to add what the ruling requires and the live body lacks.
--
-- CONVENTION CONFIRMED INDEPENDENTLY, not taken on the reviewer's report: all
-- five util.can_* siblings are prosecdef=true with
-- proconfig = {search_path=public,row_security=off}. Before this migration
-- these two were the ONLY SECURITY DEFINER functions in `util` without it.
-- After it, zero remain — the class is closed, asserted not assumed.
--
-- ===========================================================================
-- WHY IT MATTERS — DEMONSTRATED BEHAVIOURALLY, NOT ASSERTED
-- ===========================================================================
-- Measured live as a non-exempt role (`authenticated`), 2026-09-11:
--
--   default (row_security on) -> select from public.role_grants returns FALSE.
--                                RLS SILENTLY FILTERS.
--   SET row_security = off    -> 42501 "query would be affected by row-level
--                                security policy for table role_grants".
--                                IT RAISES.
--
-- That is the whole point, and it is why this is a FAIL rather than a nitpick.
-- These functions answer an authorization question. Today the owner exemption
-- — prosecdef, owner match, no FORCE — makes them correct. T-079 names the
-- dangerous case: `ALTER TABLE role_grants FORCE ROW LEVEL SECURITY` is one
-- line, looks like hardening, and a reviewer seeing that diff has no reason to
-- suspect it. WITHOUT row_security=off, the moment any of those three
-- conditions flips these two quietly answer `false` again — which is EXACTLY
-- the regression AC5 exists to remove, reintroduced silently and from a
-- direction nobody is watching. WITH it they fail loudly instead.
--
-- It is the guard against this ticket's own bug returning.
--
-- ===========================================================================
-- T-058 AND WHAT IS CARRIED FORWARD
-- ===========================================================================
-- Bodies restated verbatim from live pg_get_functiondef read today, AFTER the
-- relocation (so `util.`-qualified, not the pre-move public. definition).
-- LANGUAGE sql, STABLE, SECURITY DEFINER and the existing search_path are all
-- carried forward; only row_security is added. CREATE OR REPLACE preserves the
-- OID and the existing proacl — both asserted below, because the three
-- storage.objects quals are OID-bound and anon's EXECUTE is what keeps them
-- executable.
--
-- ===========================================================================
-- DELIBERATELY NOT CHANGED, AND REPORTED RATHER THAN SILENTLY ALIGNED
-- ===========================================================================
-- The five siblings carry `search_path=public`; these two carry
-- `search_path=public, pg_temp`. That divergence is left alone.
--
-- The PEER FAIL names row_security only. Quietly bundling a second undeclared
-- attribute change into the fix for an undeclared attribute change is the same
-- defect twice, and it would make the diff assert something the review never
-- agreed to. Raised to the reviewer as an observation instead.
--
-- For whoever rules on it: `pg_temp` sits LAST in the search_path and both
-- bodies fully qualify `public.role_grants`, so the temp-object shadowing
-- exposure a SECURITY DEFINER function normally carries is small here. Small
-- is not zero, and it is a judgement for the reviewer, not one to make inside
-- a rework.

begin;

create or replace function util.is_moderator(p_user uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
 set row_security to off
as $function$
  select exists (select 1 from public.role_grants where user_id=p_user and role='moderator')
$function$;

create or replace function util.is_venue_admin(p_user uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
 set row_security to off
as $function$
  select exists (select 1 from public.role_grants where user_id=p_user and role='venue_admin')
$function$;

-- ---------------------------------------------------------------------------
-- Guards — count-shaped against stated expectations, asserting PROPERTIES
-- ---------------------------------------------------------------------------
-- Demonstrated failing before the change: 'expected 2 with row_security=off,
-- found 0'. Every check below is a count against an expectation, never a bare
-- boolean: a blind predicate yields 0, 0 <> expected, and it aborts.
--
-- Four of the six assert things this migration does NOT change. That is the
-- point — CREATE OR REPLACE silently resets whatever is not restated, so the
-- properties the previous migration established are exactly what a careless
-- rework would drop.

do $$
declare
  v_rs int; v_def int; v_sp int; v_acl int; v_2arg int;
  v_oid_mod oid; v_oid_venue oid;
begin
  select count(*) into v_rs
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
     and pg_get_function_identity_arguments(p.oid)='p_user uuid'
     and p.proconfig::text ~ 'row_security=off';
  if v_rs <> 2 then
    raise exception 'KAN-178 AC5: expected 2 with row_security=off, found %', v_rs;
  end if;

  select count(*) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
     and pg_get_function_identity_arguments(p.oid)='p_user uuid' and p.prosecdef;
  if v_def <> 2 then
    raise exception 'KAN-178 AC5: expected 2 SECURITY DEFINER, found %', v_def;
  end if;

  select count(*) into v_sp
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
     and pg_get_function_identity_arguments(p.oid)='p_user uuid'
     and p.proconfig::text ~ 'search_path=public, pg_temp';
  if v_sp <> 2 then
    raise exception 'KAN-178 AC5: search_path not preserved on both, found %', v_sp;
  end if;

  select count(*) into v_acl
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
     and pg_get_function_identity_arguments(p.oid)='p_user uuid'
     and has_function_privilege('anon', p.oid, 'EXECUTE');
  if v_acl <> 2 then
    raise exception 'KAN-178 AC5: anon EXECUTE must be retained, found %', v_acl;
  end if;

  select count(*) into v_2arg
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='is_venue_admin'
     and pg_get_function_identity_arguments(p.oid)='p_user uuid, p_venue uuid'
     and not p.prosecdef;
  if v_2arg <> 1 then
    raise exception 'KAN-178 AC5: 2-arg overload disturbed, found %', v_2arg;
  end if;

  select p.oid into v_oid_mod from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='util' and p.proname='is_moderator';
  select p.oid into v_oid_venue from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='util' and p.proname='is_venue_admin'
     and pg_get_function_identity_arguments(p.oid)='p_user uuid';
  if v_oid_mod <> 20147::oid then
    raise exception 'KAN-178 AC5: is_moderator OID changed (% <> 20147)', v_oid_mod;
  end if;
  if v_oid_venue <> 20148::oid then
    raise exception 'KAN-178 AC5: is_venue_admin OID changed (% <> 20148)', v_oid_venue;
  end if;
end $$;

commit;
