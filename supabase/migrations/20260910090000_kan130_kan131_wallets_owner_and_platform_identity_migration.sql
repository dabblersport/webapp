-- KAN-130 / KAN-131 — T-051 (+ T-058 Decision 4) and T-052.
-- Authored by backend-3 (Shed) 2026-09-10, in worktree exec/backend-3/KAN-130.
-- NOT APPLIED by this authorship. See "APPLY GATE" below.
--
-- ===========================================================================
-- THIS FILE IS SHARED BY TWO TICKETS AND ONLY ONE HALF IS PRESENT
-- ===========================================================================
-- T-052 ruled that KAN-130 and KAN-131 ship in a SINGLE migration, and `po`
-- declared this one path as the surface of both tickets. Section A below is
-- KAN-130's half and is complete. Section B is KAN-131's half and is a
-- PLACEHOLDER — fn_platform_owner_id() and its two call sites inside
-- trgfn_payment_to_ledger are a separate ticket with its own peer review, and
-- backend-3 did not author them.
--
-- APPLY GATE. Do NOT apply this file while Section B is a placeholder.
-- Section A is internally coherent and would apply cleanly on its own, but
-- T-052 forbids applying T-051 without T-052: making the wallets constraints
-- correct is precisely what makes fn_get_wallet SUCCEED, and succeeding is how
-- the fresh-platform-uuid bug does its damage. (Today that damage is latent
-- for a second reason — T-055: trgfn_payment_to_ledger selects FROM
-- public.bookings, a table that does not exist, so the payment-to-ledger path
-- raises before it reaches any wallet call. That is KAN-136's, not a licence
-- to split this file.)
--
-- ===========================================================================
-- WHAT SECTION A DOES
-- ===========================================================================
-- Moves public.wallets onto the (owner_type, owner_id) identity it already
-- half-had, and drops user_id.
--
--   wallets.id         -> NOT NULL, and the PRIMARY KEY
--   wallets.owner_type -> NOT NULL
--   wallets.user_id    -> DROPPED (takes wallets_user_id_fkey with it)
--   wallets_self_read  -> owner-keyed
--   _wallet_recalc, request_payout, delete_my_account -> owner-keyed
--
-- WHY user_id CANNOT SURVIVE (T-051, and it is structural, not stylistic)
-- wallets_user_id_fkey points at auth.users. trgfn_payment_to_ledger calls
-- fn_get_wallet('venue', ...) and fn_get_wallet('platform', ...). A venue id is
-- not an auth.users id, so no value of user_id makes those calls legal. The
-- user_id-keyed design can only ever describe one of the three owner types
-- wallets_owner_type_valid admits. Nullable was rejected: two columns holding
-- the same fact is the mechanism that produced this defect.
--
-- WHY owner_type MUST BE NOT NULL
-- It is a member of wallets_unique_idx (owner_type, owner_id, currency). NULLs
-- compare distinct, so a NULL owner_type silently opts a row out of the
-- uniqueness guarantee. Third appearance of that trap (T-049 ref_id, T-051
-- owner_type, T-052's rejected owner_id IS NULL); it is now a standing rule.
--
-- WHY NOW
-- public.wallets holds 0 rows on wtncuzcskpigqpmnxwws — COUNTED live
-- 2026-09-10 by backend-3, not inferred: a targeted `supabase db dump
-- --data-only` restricted to public.wallets emitted no COPY and no INSERT for
-- the table. So SET NOT NULL takes no validation scan, DROP COLUMN rewrites
-- nothing, and there is no backfill and no lock-duration concern. Every one of
-- those becomes a reconciliation once D4 executes. It is free exactly once.
--
-- AUTHORING RULE FOLLOWED (T-058, and it is why this ticket waited)
-- Every function body in Section A was taken from the LIVE catalogue of
-- wtncuzcskpigqpmnxwws read on 2026-09-10 — never from
-- 20260829080500_baseline_schema.sql. The three carry THREE DIFFERENT
-- attribute sets and there is no shared string to restate:
--
--   _wallet_recalc      SECURITY INVOKER  search_path = public, pg_temp
--   request_payout      SECURITY DEFINER  search_path = public
--   delete_my_account   SECURITY DEFINER  search_path = public, auth, extensions
--
-- delete_my_account is the one to get wrong: it needs `auth` on its path to run
-- `delete from auth.users`, and restating any other string fails at RUNTIME on
-- account deletion — the erasure path this migration is modifying — not at
-- apply time. CREATE OR REPLACE silently resets prosecdef to false when
-- SECURITY DEFINER is omitted (CONVENTIONS.md §6c / T-044).
--
-- request_payout's body below is the POST-KAN-128 body (it carries KAN-128's
-- own ON CONFLICT DO NOTHING comment block, restated verbatim). Taking it from
-- the baseline would have silently reverted that clause.
--
-- NO SIGNATURE CHANGES, THEREFORE NO DROP AND NO RE-GRANT
-- All three are CREATE OR REPLACE with identical argument lists, so proacl is
-- preserved and T-058's "revoke from PUBLIC *and* anon by name" rule does not
-- bite here. The probe pack asserts the resulting proacl anyway rather than
-- asserting that no revoke was needed.
--
-- fn_get_wallet IS DELIBERATELY NOT TOUCHED
-- T-051 lists it as a broken writer; cto's own correction (DECISIONS.md,
-- "Corrections to T-051 from senior-backend's sizing pass", item 1) retracts
-- that. Its INSERT already omits user_id, which is exactly what the drop makes
-- legal. Confirmed against the live body. Editing it would be churn.
--
-- OUT OF SCOPE — deliberate absences, so no reviewer reads one as an omission
--   * financial_ledger's right-to-erasure gap. Real, permanently outside this
--     ticket (T-054), filed as KAN-135. delete_my_account below restores a
--     guarantee that exists TODAY via the cascade this file removes; it does
--     not create one that has never existed.
--   * The retention position owed in delete_my_account's comment block. T-051
--     records it as owed pending cpo's KAN-135 ruling, explicitly "not written
--     here". Writing an unruled policy into a dated migration is how the date
--     slips.
--   * _wallet_recalc's AED-only recompute. Pre-existing narrowness, restated
--     unchanged; the ('user', p_user, 'AED') tuple below makes the existing
--     assumption visible rather than introducing it.
--   * _wallet_recalc's EXECUTE grant to anon (live proacl). Pre-existing, and
--     grant surface is KAN-86/KAN-61 territory, not T-051's. Recorded, not
--     changed.
--   * trgfn_payment_to_ledger's FROM public.bookings defect (T-055 / KAN-136).
--
-- WHAT A GREEN RUN OF THIS FILE DOES *NOT* PROVE
-- It does not prove the payment-to-ledger path works. That path is dead until
-- KAN-136 lands (T-055). Every probe in supabase/tests/kan130 therefore drives
-- fn_get_wallet and _wallet_recalc DIRECTLY, and asserts first that the target
-- path can execute at all — a probe that passes because the code under test
-- was never reached is not evidence.

begin;

-- ===========================================================================
-- SECTION A — KAN-130 (T-051 + T-058 Decision 4)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A.1  wallets.id becomes NOT NULL
-- ---------------------------------------------------------------------------
-- id already has DEFAULT gen_random_uuid() and already carries a UNIQUE index,
-- and it is already the FK target of financial_ledger_wallet_fkey. The only
-- thing missing is that it is nullable — which makes an inbound foreign key
-- reference a column that can hold NULL. Free on 0 rows: no validation scan.

alter table public.wallets
  alter column id set not null;

-- ---------------------------------------------------------------------------
-- A.2  drop the user_id primary key
-- ---------------------------------------------------------------------------
-- wallets_pkey is PRIMARY KEY (user_id) today. Dropped explicitly rather than
-- letting A.6's DROP COLUMN take it silently, so the intent is stated where a
-- reader looks for it.

alter table public.wallets
  drop constraint wallets_pkey;

-- ---------------------------------------------------------------------------
-- A.3  the primary key becomes id
-- ---------------------------------------------------------------------------
-- USING INDEX rather than a bare PRIMARY KEY (id) on purpose. wallets_id_unique
-- is already a plain UNIQUE btree index on exactly (id), owned by no
-- constraint. Promoting it consumes it — the index object survives, is renamed
-- to wallets_pkey, and financial_ledger_wallet_fkey keeps depending on the same
-- index throughout. A bare PRIMARY KEY (id) would instead build a SECOND
-- identical unique index and leave wallets_id_unique standing beside it
-- forever, which is a defect that costs nothing on 0 rows and real write
-- amplification on a live money table.

alter table public.wallets
  add constraint wallets_pkey primary key using index wallets_id_unique;

-- ---------------------------------------------------------------------------
-- A.4  wallets.owner_type becomes NOT NULL
-- ---------------------------------------------------------------------------

alter table public.wallets
  alter column owner_type set not null;

-- ---------------------------------------------------------------------------
-- A.5  wallets_self_read becomes owner-keyed
-- ---------------------------------------------------------------------------
-- This MUST precede A.6. The policy expression references user_id, so Postgres
-- records a dependency on the column and DROP COLUMN ... RESTRICT (the default)
-- refuses while the old policy stands. Ordering it here is load-bearing, not
-- cosmetic.
--
-- wallets_block_dml (USING false WITH CHECK false) is untouched and still
-- blocks every INSERT/UPDATE/DELETE from anon and authenticated. Writes reach
-- this table only through SECURITY DEFINER functions and service_role.

drop policy wallets_self_read on public.wallets;

create policy wallets_self_read on public.wallets
  for select
  using (owner_type = 'user' and owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- A.6  wallets.user_id is DROPPED
-- ---------------------------------------------------------------------------
-- This takes wallets_user_id_fkey (REFERENCES auth.users(id) ON DELETE CASCADE)
-- with it. Losing that cascade is what obliges A.9's change to
-- delete_my_account — see there.
--
-- RESTRICT is deliberate (it is the default; stated so nobody "fixes" this to
-- CASCADE). Exactly two policies and zero views referenced user_id, and the
-- policy is already replaced above; if anything else has grown a dependency
-- since authoring, this statement must FAIL loudly rather than silently drop
-- the dependent object.

alter table public.wallets
  drop column user_id restrict;

-- ---------------------------------------------------------------------------
-- A.7  state, in the schema itself, that owner_id is not a foreign key
-- ---------------------------------------------------------------------------
-- T-051 requires this in the table comment specifically, because the absence of
-- an FK on owner_id looks exactly like an oversight to the next reader and the
-- obvious "fix" is impossible.

comment on table public.wallets is
  'One wallet per (owner_type, owner_id, currency) — see wallets_unique_idx. '
  'The primary key is the surrogate id, which is what financial_ledger.wallet_id '
  'references. owner_id is DELIBERATELY NOT A FOREIGN KEY: it points at three '
  'different tables selected by owner_type (auth.users, venues, and the platform '
  'singleton, per wallets_owner_type_valid), so no single REFERENCES clause can '
  'express it. Do not "fix" this by adding one. user_id was dropped in KAN-130 '
  '(T-051, 2026-09-10) rather than made nullable: it could only ever describe '
  'owner_type = ''user'', and two columns holding the same fact is the defect '
  'that ruling exists to remove.';

-- ---------------------------------------------------------------------------
-- A.8  _wallet_recalc — owner-keyed insert AND conflict target
-- ---------------------------------------------------------------------------
-- Body from the live catalogue. NOT SECURITY DEFINER; search_path is
-- 'public', 'pg_temp' — its own string, shared with nothing else in this file.
--
-- T-058 Decision 4 is the reason the INSERT column list changes and not just
-- the ON CONFLICT target. owner_id is NOT NULL with no default, and the NOT
-- NULL check runs BEFORE the ON CONFLICT arbiter is ever consulted — so an
-- insert that named only the conflict target would still fail 23502 on every
-- ledger write, on a schema this very file just made correct. Both owner_type
-- and owner_id are supplied explicitly on the one and only insert branch.
--
-- The conflict target (owner_type, owner_id, currency) infers wallets_unique_idx.
-- All three columns are NOT NULL after A.4/A.6, so the arbiter is total: there
-- is no NULL-distinct row that can slip past it into a duplicate.
--
-- The recompute-never-increment shape is T-049 Invariant 3 and is UNCHANGED:
-- balance_aed and held_aed are still assigned from a full re-aggregation of
-- wallet_ledger, never incremented. `where user_id = p_user` in the SELECT is
-- wallet_ledger.user_id, a different table and a different column from the one
-- being dropped — it is correct and stays.
--
-- 'AED' is the pre-existing narrowness, not a new assumption: the aggregate
-- above has always been currency-blind and wallets.currency has always
-- defaulted to 'AED'. Naming it makes the assumption visible.

create or replace function public._wallet_recalc(p_user uuid) returns void
    language plpgsql
    set search_path to 'public', 'pg_temp'
    as $$
declare
  avail numeric(12,2);
  held  numeric(12,2);
begin
  select
    coalesce(sum(case when status='posted' and direction='credit' then amount_aed
                      when status='posted' and direction='debit'  then -amount_aed
                      else 0 end),0),
    coalesce(sum(case when status='pending' and direction='credit' then amount_aed
                      when status='pending' and direction='debit'  then -amount_aed
                      else 0 end),0)
  into avail, held
  from public.wallet_ledger
  where user_id = p_user;

  insert into public.wallets(owner_type, owner_id, currency, balance_aed, held_aed)
  values ('user', p_user, 'AED', avail, held)
  on conflict (owner_type, owner_id, currency)
  do update set balance_aed = excluded.balance_aed,
                held_aed    = excluded.held_aed,
                updated_at  = now();
end;
$$;

-- ---------------------------------------------------------------------------
-- A.9  delete_my_account — replace the cascade A.6 removed
-- ---------------------------------------------------------------------------
-- Body from the live catalogue. SECURITY DEFINER; search_path is
-- 'public', 'auth', 'extensions' — the only function in KAN-128/130/131
-- carrying auth on its path, and it is load-bearing for `delete from
-- auth.users`.
--
-- This function's own closing comment names wallets in the list of tables
-- "ON DELETE CASCADE now handles". A.6 makes that sentence false. Without the
-- delete added below, account deletion silently orphans the user's wallet row —
-- an erasure obligation broken by this migration, not a tidiness point. The
-- comment is corrected in place so it does not become a second lie.
--
-- Placed with the other pre-auth.users deletes, before the final delete, and
-- keyed the same way the new wallets_self_read policy is keyed.
--
-- OWED, NOT WRITTEN HERE: cpo's financial_ledger retention ruling (KAN-135)
-- belongs in this comment block once it exists (T-051). financial_ledger is
-- absent from the cascade list below and always has been; that is KAN-135's
-- question, not this migration's.

create or replace function public.delete_my_account() returns void
    language plpgsql security definer
    set search_path to 'public', 'auth', 'extensions'
    as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove storage objects owned by this user (avatars, post media, etc.)
  -- so no orphaned metadata rows remain after the account is gone.
  -- storage.objects has a BEFORE DELETE guard (storage.protect_delete) that
  -- rejects direct DML unless the transaction-local flag below is set — the
  -- same flag Supabase's Storage API sets internally before deleting rows.
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where owner = v_uid;

  -- Null out nullable audit/reference columns that don't cascade
  -- (ON DELETE SET NULL semantics applied manually, in-place).
  update public.role_grants set granted_by = null where granted_by = v_uid;
  update public.profile_verifications set verified_by = null where verified_by = v_uid;
  update public.point_ledger set created_by = null where created_by = v_uid;
  update public.venue_submissions set revoked_by = null where revoked_by = v_uid;
  update public.venue_submissions set rejected_by = null where rejected_by = v_uid;
  update public.venue_submissions set approved_by = null where approved_by = v_uid;
  update public.venue_submissions set returned_by = null where returned_by = v_uid;

  -- Delete rows with NOT NULL / restrictive FKs to auth.users that would
  -- otherwise block the account deletion outright. These are all
  -- user-owned artifacts (invite/link tokens, bookings, freezes the user
  -- issued), so deleting them is the correct "erase associated data"
  -- behaviour, not just a workaround.
  delete from public.meetup_invites where created_by = v_uid;
  delete from public.meetup_link_tokens where created_by = v_uid;
  delete from public.squad_link_tokens where created_by = v_uid;
  delete from public.game_link_tokens where created_by = v_uid;
  delete from public.user_freezes where created_by = v_uid;
  delete from public.blackouts where created_by = v_uid;
  delete from public.venue_bookings where created_by = v_uid;

  -- KAN-130 (T-051): wallets is NO LONGER covered by ON DELETE CASCADE. That
  -- migration dropped wallets.user_id and with it wallets_user_id_fkey
  -- (REFERENCES auth.users ON DELETE CASCADE), because user_id could never
  -- describe a venue or platform wallet. The cascade is replaced by this
  -- explicit delete, keyed the way the table is now keyed. It must stay ahead
  -- of the auth.users delete: afterwards there is no v_uid to match on and the
  -- row is unreachable.
  delete from public.wallets where owner_type = 'user' and owner_id = v_uid;

  -- Finally remove the auth user. ON DELETE CASCADE now handles the rest:
  -- profiles, posts, comments, likes, notifications, user_blocks,
  -- moderation_reports, consent_records, fcm_tokens, etc. NOTE: `wallets` was
  -- removed from this list by KAN-130 and is handled explicitly above.
  -- financial_ledger is NOT in this list and never was — its retention position
  -- is KAN-135 (T-054), deliberately unruled here.
  delete from auth.users where id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- A.10  request_payout — owner-keyed balance lookup
-- ---------------------------------------------------------------------------
-- Body from the live catalogue, POST-KAN-128 (the ON CONFLICT DO NOTHING clause
-- and its comment are KAN-128's and are restated verbatim; taking this body
-- from the baseline would have reverted them). SECURITY DEFINER; search_path is
-- 'public' — no pg_temp, its own string.
--
-- One line changes. `where user_id = me` was a primary-key lookup and returned
-- exactly one row. The owner-keyed replacement adds currency = 'AED' because
-- (owner_type, owner_id) alone is NOT unique — wallets_unique_idx is
-- (owner_type, owner_id, currency), so a user with a second currency would make
-- a bare owner lookup return an arbitrary row and pay out against the wrong
-- balance. 'AED' is the currency this function already deals in throughout
-- (p_amount_aed, balance_aed, payouts.amount_aed); naming it preserves the
-- one-row guarantee the primary key used to provide.
--
-- The `if bal is null then bal := 0` branch below still does the work it always
-- did: a user with no wallet row yet gets 0 and 'insufficient_funds', rather
-- than a NULL comparison that silently falls through.

create or replace function public.request_payout(p_amount_aed numeric, p_beneficiary_id uuid default null::uuid) returns public.payouts
    language plpgsql security definer
    set search_path to 'public'
    as $$
declare
  me uuid := auth.uid();
  ben uuid;
  bal numeric(12,2);
  po public.payouts;
begin
  if me is null then raise exception using errcode='P0001', message='auth_required'; end if;
  if p_amount_aed is null or p_amount_aed <= 0 then raise exception using errcode='P0001', message='invalid_amount'; end if;

  -- Beneficiary: explicit or default
  if p_beneficiary_id is not null then
    select id into ben from public.payout_beneficiaries where id = p_beneficiary_id and user_id = me;
    if ben is null then raise exception using errcode='P0001', message='beneficiary_not_found'; end if;
  else
    select id into ben from public.payout_beneficiaries where user_id = me and is_default = true limit 1;
    if ben is null then raise exception using errcode='P0001', message='no_default_beneficiary'; end if;
  end if;

  -- Check available balance
  -- KAN-130 (T-051): owner-keyed. currency is part of the lookup because
  -- wallets_unique_idx is (owner_type, owner_id, currency) — without it this
  -- select is not single-row.
  select balance_aed into bal
    from public.wallets
   where owner_type = 'user' and owner_id = me and currency = 'AED';
  if bal is null then bal := 0; end if;
  if p_amount_aed > bal then raise exception using errcode='P0001', message='insufficient_funds'; end if;

  -- Create payout row
  insert into public.payouts(user_id, beneficiary_id, amount_aed, status)
  values (me, ben, p_amount_aed, 'requested')
  returning * into po;

  -- Move funds to held: ledger pending debit (hold)
  -- KAN-128: po.id is freshly generated on the line above, so this conflict
  -- clause absorbs nothing today. It is the guarantee for the writer, not a fix
  -- for an observed duplicate — it holds if a future caller ever re-drives this
  -- path against an existing payout id.
  insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
  values (me, 'debit', p_amount_aed, 'pending', 'payout', po.id, 'Payout hold')
  on conflict do nothing;

  return po;
end;
$$;

-- ===========================================================================
-- SECTION B — KAN-131 (T-052) — NOT AUTHORED HERE
-- ===========================================================================
-- PLACEHOLDER. KAN-131 is a separate ticket, dependency-blocked behind KAN-130
-- and unowned at the time this file was written. backend-3 did not author it:
-- doing so would land T-052's change without its own peer review, and
-- queue.contends(KAN-130, KAN-131) is True precisely so that does not happen by
-- accident.
--
-- What belongs here, per T-052, for whoever owns KAN-131:
--   1. create function public.fn_platform_owner_id() returns uuid
--        language sql immutable
--        returning '00000000-0000-0000-0000-000000000000'::uuid
--   2. create or replace function public.trgfn_payment_to_ledger() — body taken
--      from pg_get_functiondef on the LIVE catalogue AFTER KAN-128 was applied,
--      never from the baseline, or its three ON CONFLICT DO NOTHING clauses are
--      silently reverted. Two call sites change:
--        :19211  fn_get_wallet('platform', gen_random_uuid(), NEW.currency)
--                  -> fn_get_wallet('platform', fn_platform_owner_id(), NEW.currency)
--        :19231  entity_id = gen_random_uuid()  (the platform ledger row)
--                  -> entity_id = fn_platform_owner_id()
--      Its attributes are its own third string: NOT SECURITY DEFINER,
--      search_path = public, pg_temp. It is the only one of these five carrying
--      pg_temp alongside a non-definer body.
--
-- Until Section B is written, the APPLY GATE at the top of this file stands.

commit;
