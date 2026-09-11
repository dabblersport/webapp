-- KAN-178 / T-079 + Amendment 1 + Amendment 2 — public.role_grants is
-- world-readable. Replace the read policy; scope its sibling to writes.
-- Authored by backend-5 (Heka) 2026-09-11.
--
-- ===========================================================================
-- THE DEFECT, MEASURED LIVE BEFORE AUTHORING (2026-09-11, wtncuzcskpigqpmnxwws)
-- ===========================================================================
--   role_grants_any_read   FOR SELECT, TO PUBLIC (polroles={0}), USING (true)
--   role_grants_no_rw      no FOR clause => FOR ALL, TO PUBLIC,
--                          USING (false) WITH CHECK (false)
--
-- Permissive policies OR within a command, so SELECT today is
-- `true OR false` = true and the table is world-readable. Reproduced as a
-- non-owner role, not inferred from the catalogue:
--
--   SET LOCAL ROLE authenticated + a non-admin sub  -> 1 row visible
--   SET LOCAL ROLE anon                            -> 1 row visible
--
-- That is the T-075 fail-open defect and a T-020 breach: role_grants is a
-- permissions table, and the people it constrains can read it.
--
-- ===========================================================================
-- WHY A BARE DROP IS FORBIDDEN (T-079 Amendment 2 §1) — the ordering is the fix
-- ===========================================================================
-- Dropping role_grants_any_read WITHOUT its successor in the same change
-- leaves SELECT = `false` (role_grants_no_rw is FOR ALL). The table then fails
-- CLOSED — but `is_admin` is SECURITY DEFINER owned by `postgres`, and
-- `relforcerowsecurity` is false, so the owner's RLS exemption keeps is_admin
-- working. The outage would therefore be PARTIAL across the seven T-079 tables
-- (role_grants, venue_submissions, venue_payouts, user_freezes,
-- profile_verifications, game_join_requests, financial_ledger) rather than
-- clean. A partial, confusing failure is worse than a total one. Both
-- statements are in the single transaction below.
--
-- ===========================================================================
-- THE THREE OWNER-EXEMPTION CONDITIONS — READ LIVE, RECORDED AS DIAGNOSTICS
-- ===========================================================================
-- T-079 §2: the exemption is three conditions, not two, and a catalogue read
-- of only two would pass while the property is broken. All three read today:
--   1. is_admin(uuid).prosecdef      = true
--   2. role_grants.relforcerowsecurity = false   (ENABLE, never FORCE)
--   3. is_admin's owner (postgres) IS role_grants's owner (postgres)
-- These are DIAGNOSTICS. The criterion is the behavioural probe pack in
-- supabase/tests/kan178/20_probes.sql, run as a role subject to RLS. Run as
-- `postgres` every probe here passes VACUOUSLY, because the owner is exempt —
-- which is the very property under test.
--
-- The cycle is PROSPECTIVE (Amendment 1 §2): the EXISTING policy is
-- USING (true) and calls nothing. The policy created below is the first to put
-- is_admin on role_grants' own read path, so the recursion risk is introduced
-- HERE and is this migration's to prove absent.
--
-- ===========================================================================
-- !! A CONSEQUENCE T-079 DOES NOT COVER — READ THIS BEFORE GRANTING A ROLE !!
-- ===========================================================================
-- Found by backend-5 at authoring, measured live, and NOT addressed by T-079,
-- Amendment 1 or Amendment 2. It is recorded here because it is latent today
-- and will be invisible at the moment it starts to matter.
--
-- TWO helper functions read role_grants and are SECURITY *INVOKER*, so unlike
-- is_admin they are SUBJECT TO THIS POLICY:
--
--   public.is_moderator(p_user uuid)    prosecdef = FALSE
--     select exists (select 1 from public.role_grants
--                     where user_id = p_user and role = 'moderator')
--   public.is_venue_admin(p_user uuid)  prosecdef = FALSE
--     select exists (select 1 from public.role_grants
--                     where user_id = p_user and role = 'venue_admin')
--
-- After this migration a NON-ADMIN caller sees zero rows in role_grants, so
-- both functions return FALSE for that caller — even when the grant exists.
-- They do not error. They quietly answer "no".
--
-- LIVE BLAST RADIUS: three policies on storage.objects —
--   venue_insert_admin / venue_update_admin / venue_delete_admin, each
--   `bucket_id = 'venue' AND (is_admin(auth.uid()) OR is_venue_admin(auth.uid()))`
-- A user holding venue_admin but NOT admin would lose venue-bucket writes.
-- is_admin is DEFINER and keeps working, so a global admin would not notice —
-- the exact partial-failure shape Amendment 2 warns about, one layer out.
--
-- WHY IT IS SAFE TO LAND TODAY, AND THIS IS THE ONLY REASON:
--   public.role_grants holds ONE row and its role is 'admin'. There are ZERO
--   'venue_admin' grants and ZERO 'moderator' grants. Counted, not assumed.
--   Nothing can regress because nobody holds either role.
--
-- NOT FIXED HERE, DELIBERATELY. The root fix is to make those two helpers
-- SECURITY DEFINER, matching is_admin — a change to the security attributes of
-- two authorization functions used by storage.objects policies. That is a
-- cto ruling and a T-058 body restatement, not a side effect of a policy
-- ticket. Raised to team-lead/cto with this migration.
--
--   >> BEFORE ANY 'venue_admin' OR 'moderator' GRANT IS ISSUED, that ruling
--   >> must land, or the grant will silently not work.
--
-- The alternative considered and REJECTED: widening the read policy to
-- `user_id = auth.uid() OR is_admin(auth.uid())` (self-read). It would keep
-- both helpers working, but it contradicts Amendment 2 §4's criterion — non-
-- admin SELECT returns ZERO rows, "not an error, and not every row" — which is
-- the single test that discriminates recursion, fail-closed and fail-open.
-- Weakening it to "zero or your own" makes that test ambiguous. Not my call to
-- make on a security_sensitive ticket whose shape cto has already ruled.
--
-- ===========================================================================
-- ONE DELIBERATE ADDITION BEYOND CTO'S LITERAL WORDING, FLAGGED FOR REVIEW
-- ===========================================================================
-- The new read policy carries `TO authenticated`. Amendment 2 rules the
-- PREDICATE (replace USING(true) with an admin predicate) and says nothing
-- about role scope. `TO authenticated` means anon matches no permissive SELECT
-- policy at all and gets zero rows without evaluating an admin predicate —
-- strictly tighter, and anon has no business running an authorization check on
-- a permissions table. It does NOT weaken the behavioural test: as
-- `authenticated` the policy still applies and is_admin still sits on
-- role_grants' read path, so the recursion probe remains meaningful.
-- Called out rather than buried so PEER can reject it cheaply.

begin;

-- ---------------------------------------------------------------------------
-- A.1  replace the world-readable read policy
-- ---------------------------------------------------------------------------
-- REPLACE, not narrow (Amendment 2 §2): USING (true) cannot be narrowed into
-- an admin predicate, so it is rewritten wholesale. The drop and the create
-- are adjacent and inside one transaction — see the APPLY note above.

drop policy role_grants_any_read on public.role_grants;

create policy role_grants_admin_read on public.role_grants
  for select
  to authenticated
  using (public.is_admin(auth.uid()));

comment on policy role_grants_admin_read on public.role_grants is
  'KAN-178 / T-079 Amendment 2. Replaced role_grants_any_read, which was '
  'FOR SELECT USING (true) TO PUBLIC and made this permissions table '
  'world-readable (T-020 breach, T-075 fail-open). is_admin is SECURITY '
  'DEFINER owned by postgres and role_grants is owned by postgres with '
  'relforcerowsecurity false, so the owner exemption breaks what would '
  'otherwise be a policy->helper->same-table cycle. THAT EXEMPTION IS THREE '
  'CONDITIONS (T-079): prosecdef, NOT FORCE, and the two owners matching. '
  'Any change to one of them must re-run supabase/tests/kan178/20_probes.sql '
  'as a non-owner role. NOTE: is_moderator() and is_venue_admin() are SECURITY '
  'INVOKER and read this table, so they answer false for non-admins; see the '
  'migration header before granting either role.';

-- ---------------------------------------------------------------------------
-- A.2  scope the no_rw sibling to writes (Amendment 2 §3, first branch)
-- ---------------------------------------------------------------------------
-- role_grants_no_rw had no FOR clause, so it was FOR ALL and silently
-- participated in SELECT. It was harmless only because a sibling happened to
-- grant reads — the §12a shape cto named. It is also a latent hazard: made
-- RESTRICTIVE it would turn SELECT into `<admin predicate> AND false` and fail
-- closed permanently.
--
-- cto offered two branches — scope it to writes, or justify FOR ALL in the
-- migration. Taking the FIRST, because this ticket exists to remove ambiguity
-- from this table's security and leaving the trap documented still leaves the
-- trap. Three explicit policies replace it; none can touch SELECT.
--
-- These remain belt-and-braces: with RLS enabled and no permissive policy for
-- a command, that command is denied anyway. Stated so nobody removes them as
-- redundant without re-reading that sentence.

drop policy role_grants_no_rw on public.role_grants;

create policy role_grants_no_insert on public.role_grants
  for insert to public
  with check (false);

create policy role_grants_no_update on public.role_grants
  for update to public
  using (false)
  with check (false);

create policy role_grants_no_delete on public.role_grants
  for delete to public
  using (false);

comment on policy role_grants_no_insert on public.role_grants is
  'KAN-178: write-scoped replacement for role_grants_no_rw, which was FOR ALL '
  'and therefore also participated in SELECT. Writes reach this table only '
  'through SECURITY DEFINER functions and roles with rolbypassrls '
  '(postgres, service_role).';

-- ---------------------------------------------------------------------------
-- A.3  in-transaction guard: the policy set must be exactly what is intended
-- ---------------------------------------------------------------------------
-- Not a substitute for the behavioural probes — it cannot be, because it runs
-- as the migration role, which is exempt. It catches a mis-applied policy set
-- (a leftover role_grants_any_read, a missing successor) BEFORE commit, which
-- is the failure the "never drop without the successor" rule is about.

do $$
declare
  v_read   int;
  v_forall int;
  v_legacy int;
begin
  select count(*) into v_read from pg_policy
   where polrelid = 'public.role_grants'::regclass and polcmd = 'r';
  select count(*) into v_forall from pg_policy
   where polrelid = 'public.role_grants'::regclass and polcmd = '*';
  select count(*) into v_legacy from pg_policy
   where polrelid = 'public.role_grants'::regclass
     and polname in ('role_grants_any_read','role_grants_no_rw');

  if v_legacy <> 0 then
    raise exception 'KAN-178: % legacy policy/policies still present', v_legacy;
  end if;
  if v_read <> 1 then
    raise exception 'KAN-178: expected exactly 1 SELECT policy, found %', v_read;
  end if;
  if v_forall <> 0 then
    raise exception 'KAN-178: expected 0 FOR ALL policies, found %', v_forall;
  end if;
end $$;

commit;
