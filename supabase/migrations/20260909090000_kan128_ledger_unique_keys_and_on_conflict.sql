-- KAN-128 — T-049 Decision 1 + Decision 2, T-052 amendment, T-055.
-- Authored by senior-backend 2026-09-06. Applied by cto (CONTRACT.md G-002).
--
-- WHAT THIS DOES
-- Installs the natural keys T-049 ruled, and pairs each one with
-- ON CONFLICT DO NOTHING on every writer that can insert into the keyed table.
-- A constraint and its conflict clauses land together, in one migration — a bare
-- constraint turns a tolerable replay into a 500 and a webhook the provider
-- retries forever (T-049 Decision 2), and a bare clause guarantees nothing.
--
--   wallet_ledger      UNIQUE (ref_type, ref_id, direction)
--   financial_ledger   UNIQUE (payment_intent_id, entity_type, entry_type)
--                      WHERE payment_intent_id IS NOT NULL
--
-- `direction` is in the wallet_ledger key deliberately: admin_cancel_payout
-- inserts a SECOND row for the same (ref_type='payout', ref_id) — the reversing
-- credit — and a plain UNIQUE (ref_type, ref_id) would break the one reversal
-- path already doing the right thing (T-049, Invariant 2). `status` is OUT of the
-- key because status is mutated in place (pending -> posted | voided), so
-- including it would let a pending and a posted duplicate coexist.
--
-- WHY NOW
-- wallet_ledger and financial_ledger both hold 0 rows on wtncuzcskpigqpmnxwws
-- (re-measured live 2026-09-06, at authoring time). A UNIQUE index added now is
-- free; after D4 executes it is a backfill, a reconciliation, and a decision
-- about which of two conflicting credits was real. It is free once.
--
-- AUTHORING RULE FOLLOWED (KAN-128 "AC 1 — function attributes and grants")
-- Every function body below was taken from
--   pg_get_functiondef('public.<name>'::regproc)
-- read against the LIVE catalogue of wtncuzcskpigqpmnxwws, never from
-- 20260829080500_baseline_schema.sql. pg_get_functiondef emits each function's
-- own attributes verbatim, which is the only way to avoid the error that stood
-- in this ticket for two days: FOUR of these five are SECURITY DEFINER with
-- SET search_path TO 'public' (no pg_temp); only trgfn_payment_to_ledger is
-- neither SECURITY DEFINER nor without pg_temp. There is no shared attribute
-- string here — each header is restated as that function's own catalogue entry
-- reports it (T-044 / CONVENTIONS.md §6c). CREATE OR REPLACE silently resets
-- prosecdef to false if SECURITY DEFINER is omitted, which would demote four
-- money RPCs to SECURITY INVOKER — the same trap KAN-104 hit on find_slots().
--
-- The live catalogue was compared against the baseline before authoring: no
-- drift. All five definitions match the baseline text, and the attributes match
-- the corrected table in KAN-128.
--
-- OUT OF SCOPE — deliberate absences, so no reviewer reads one as an omission
--   * payment_intents' two partial-unique keys. Ruled out by cto (T-052
--     amendment): zero SQL writers anywhere, so the clause would have nothing to
--     pair with and the constraint would land bare — the exact T-049 Decision 2
--     failure. financial_ledger is the OPPOSITE case: it has three insert
--     statements in this file, so its clause lands paired.
--   * trgfn_payment_to_ledger's `FROM public.bookings` defect (T-055). That
--     table does not exist; the trigger raises before reaching any insert, so
--     the whole payment-to-ledger path is dead code today. Filed as KAN-136,
--     NOT fixed here. Its three ON CONFLICT clauses below are therefore correct
--     and unexercisable in production. That is intentional: the guarantee should
--     already be in the schema the moment KAN-136 revives the path, rather than
--     depending on a future author remembering to add it.
--   * lines that mint a fresh platform uuid (fn_get_wallet('platform',
--     gen_random_uuid(), ...) and the 'platform' insert's entity_id). Those are
--     KAN-131's fn_platform_owner_id() fix (T-052) and are restated here
--     VERBATIM, unchanged. Touching them here would land T-052's change without
--     its function and make KAN-131 untestable standalone.
--   * _wallet_recalc's AED-only balance recompute. Pre-existing narrowness,
--     not this ticket's, not tidied.
--
-- WHAT A GREEN RUN OF THIS MIGRATION DOES *NOT* PROVE
-- T-049's Invariant 4 (webhook replay tolerated end to end) STAYS OPEN after
-- this lands. This migration installs the index that makes the guarantee, but
-- the trigger path that would exercise it cannot run until KAN-136 fixes the
-- public.bookings reference. Mechanism-verified is not observation-verified.
-- Do not close Invariant 4 on this file's green status.
--
-- SEQUENCING (T-052 amendment, cto)
-- KAN-128 ships ALONE and FIRST. KAN-130/KAN-131 ship together in a later
-- migration, and their author must take trgfn_payment_to_ledger's body from
-- pg_get_functiondef read AFTER this migration is applied — never from the
-- baseline — or CREATE OR REPLACE will silently drop the three ON CONFLICT
-- clauses added below.

begin;

-- ---------------------------------------------------------------------------
-- 1. wallet_ledger — ref_id becomes NOT NULL, then the natural key
-- ---------------------------------------------------------------------------
-- admin_wallet_adjust writes ref_type='adjustment', ref_id=NULL today. A UNIQUE
-- index treats NULLs as distinct, so every adjustment row would silently opt out
-- of the guarantee. T-049 ruled: ref_id becomes NOT NULL and the adjustment path
-- supplies a caller-generated uuid. NULLS NOT DISTINCT was considered and
-- EXPLICITLY REJECTED there — it would collapse every adjustment into one row.
--
-- This statement is only safe because the table is empty. It is stated before
-- admin_wallet_adjust is redefined, so a partial application of this file cannot
-- leave a NOT NULL column with a function that writes NULL into it: the whole
-- file is one transaction.

alter table public.wallet_ledger
  alter column ref_id set not null;

comment on column public.wallet_ledger.ref_id is
  'Natural key component, with ref_type and direction. NOT NULL since KAN-128 '
  '(T-049): adjustments supply a caller-generated uuid rather than NULL, because '
  'a UNIQUE index treats NULLs as distinct and NULL rows would opt out of the '
  'idempotency guarantee.';

create unique index wallet_ledger_ref_key_unique
  on public.wallet_ledger (ref_type, ref_id, direction);

comment on index public.wallet_ledger_ref_key_unique is
  'T-049 Invariant 1: every ledger write carries a natural key enforced by a '
  'UNIQUE index, and the write is ON CONFLICT DO NOTHING. direction is in the '
  'key so admin_cancel_payout''s reversing credit for the same (ref_type, '
  'ref_id) still succeeds; status is out of it because status is mutated in '
  'place.';

-- The existing non-unique btree idx_wallet_ledger_ref on (ref_type, ref_id) is
-- left in place. It is not made redundant by the new index — it is a prefix of
-- it, so the new index serves the same lookups, but dropping it is unrelated
-- cleanup and not this ticket's.

-- T-049 Invariant 2, amendment: the table comment is FALSE as written.
-- admin_approve_payout and admin_cancel_payout UPDATE status in place and
-- trg_wallet_ledger_recalc fires on INSERT OR DELETE OR UPDATE, so this is not
-- an append-only journal. It is amount-immutable, which is the property that
-- actually matters and the one the ruling preserves.
comment on table public.wallet_ledger is
  'Amount-immutable journal. amount_aed, direction, user_id, ref_type and ref_id '
  'are immutable after insert and DELETE is forbidden; status moves '
  'pending -> posted | voided by design. Only SECURITY DEFINER engine functions '
  'insert rows. (Corrected by KAN-128 / T-049 Invariant 2: the previous '
  '"Append-only journal" was false as written.)';

-- ---------------------------------------------------------------------------
-- 2. financial_ledger — the natural key, partial
-- ---------------------------------------------------------------------------
-- Partial WHERE payment_intent_id IS NOT NULL, exactly as T-049 ruled: the
-- column is nullable and rows not originating from a payment intent must not be
-- collapsed against one another.
--
-- The existing plain btree idx_ledger_payment on (payment_intent_id) is left in
-- place: it is unconditional where this one is partial, so it still serves
-- lookups this index cannot.

create unique index financial_ledger_payment_entry_unique
  on public.financial_ledger (payment_intent_id, entity_type, entry_type)
  where payment_intent_id is not null;

comment on index public.financial_ledger_payment_entry_unique is
  'T-049 Invariant 1/4: an EXISTS check is not idempotency. '
  'trgfn_payment_to_ledger''s read-then-write guard has no lock and no '
  'supporting constraint, so two concurrent deliveries both read "absent" and '
  'both insert. This index makes the guarantee; the guard may stay as a cheap '
  'early return. NOTE: that trigger path is dead code until KAN-136 (T-055), so '
  'this index is correct and unexercised in production today.';

-- ---------------------------------------------------------------------------
-- 3. admin_cancel_payout — conflict clause on the reversal credit (1 site)
-- ---------------------------------------------------------------------------
-- Header restated from the live catalogue: SECURITY DEFINER, search_path
-- 'public' (no pg_temp). Body verbatim apart from the added conflict clause.

create or replace function public.admin_cancel_payout(p_payout_id uuid, p_reason text default null::text)
 returns payouts
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  me uuid := auth.uid();
  po public.payouts;
  uid uuid;
  amt numeric(12,2);
begin
  if not public.is_admin(me) then raise exception using errcode='P0001', message='forbidden'; end if;

  select user_id, amount_aed into uid, amt from public.payouts where id = p_payout_id;
  if uid is null then raise exception using errcode='P0001', message='not_found'; end if;

  update public.payouts
  set status='cancelled', failure_reason = p_reason
  where id = p_payout_id and status in ('requested','approved','processing')
  returning * into po;

  if po.id is null then raise exception using errcode='P0001', message='invalid_state'; end if;

  -- If a pending hold exists, void it and credit back if needed
  update public.wallet_ledger
  set status='voided'
  where ref_type='payout' and ref_id = p_payout_id and status='pending';

  -- If it was already posted debit, refund via credit
  if exists (select 1 from public.wallet_ledger where ref_type='payout' and ref_id=p_payout_id and status='posted') then
    -- KAN-128: this credit is the compensating reversal T-049 Invariant 2
    -- confirmed. Its (ref_type='payout', ref_id, direction='credit') differs
    -- from the hold's 'debit', so the new unique key permits it and only a
    -- genuine repeat cancellation is absorbed.
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
    values (uid, 'credit', amt, 'posted', 'payout', p_payout_id, 'Payout reversal')
    on conflict do nothing;
  end if;

  return po;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. admin_wallet_adjust — DROP + CREATE, not CREATE OR REPLACE (1 site)
-- ---------------------------------------------------------------------------
-- Adding p_ref_id changes the ARGUMENT LIST. CREATE OR REPLACE would produce an
-- OVERLOAD, leaving the old 5-argument function live and callable and still
-- writing ref_id = NULL — which the NOT NULL above would then reject at runtime
-- rather than at deploy time. The old signature must be dropped.
--
-- p_ref_id carries NO DEFAULT, and deliberately not `default gen_random_uuid()`:
-- a per-call mint is exactly the guarantee T-049 refuses, since every call would
-- then produce a distinct key and no adjustment would ever be deduplicated. The
-- caller supplies the id, which is what makes the call idempotent. Because it is
-- not defaulted it must precede the two defaulted parameters, so it is placed
-- fourth rather than appended.
--
-- Callers: NONE. grep -rnE 'admin_wallet_adjust' over lib/ and
-- supabase/functions/ returns nothing, and the only other repo mention is a
-- comment at supabase/schema/archive/fix_admin_functions_missing_auth_check.sql:9.
-- No client coordination is owed by this signature change.

drop function if exists public.admin_wallet_adjust(uuid, ledger_direction, numeric, text, jsonb);

create or replace function public.admin_wallet_adjust(p_user_id uuid, p_direction ledger_direction, p_amount_aed numeric, p_ref_id uuid, p_memo text default 'Adjustment'::text, p_meta jsonb default '{}'::jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='forbidden'; end if;
  if p_amount_aed is null or p_amount_aed <= 0 then raise exception using errcode='P0001', message='invalid_amount'; end if;
  -- KAN-128 / T-049: the caller supplies the idempotency key. Raised explicitly
  -- rather than left to the NOT NULL, so the failure names the cause.
  if p_ref_id is null then raise exception using errcode='P0001', message='ref_id_required'; end if;

  insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo, meta)
  values (p_user_id, p_direction, p_amount_aed, 'posted', 'adjustment', p_ref_id, p_memo, p_meta)
  on conflict do nothing;
end;
$function$;

-- The DROP removed the old function's whole ACL, and a freshly CREATEd function
-- gets EXECUTE back to PUBLIC by default. Re-granting named roles alone would
-- therefore leave PUBLIC (and so anon, via PUBLIC) still able to execute it.
-- The REVOKE is not optional and must come first.
--
-- REVOKING FROM PUBLIC IS NOT SUFFICIENT ON THIS PROJECT, and the ticket's
-- version of this trap is incomplete. Measured live on wtncuzcskpigqpmnxwws:
-- pg_default_acl carries TWO entries for functions in schema public, granted by
-- supabase_admin and by postgres, and BOTH include anon=X. So a newly created
-- function is granted EXECUTE to anon EXPLICITLY, by name, in addition to the
-- PUBLIC default. Revoking PUBLIC leaves that named anon grant standing.
-- Reproduced: with only the PUBLIC revoke in place, proacl on the new function
-- read {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,
-- service_role=X/postgres} — anon still present, which is exactly what cto
-- ruled against. The explicit REVOKE ... FROM anon below is therefore required,
-- not belt-and-braces.
--
-- Ruled by cto (KAN-128, "AC 1 — function attributes and grants"): re-grant to
-- authenticated and service_role ONLY. This DELIBERATELY DROPS the baseline's
-- GRANT ALL ON FUNCTION ... TO anon (baseline :34693) — flagged here so the diff
-- is not misread as an omission. The function's own is_admin(auth.uid()) guard
-- returns false rather than raising for a null caller, so today's anon grant is
-- harmless; the function has zero callers and no reason to stay anon-executable.
-- This ruling does NOT generalise to the other four functions in this file,
-- whose grants are untouched.

revoke execute on function public.admin_wallet_adjust(uuid, ledger_direction, numeric, uuid, text, jsonb) from public;
revoke execute on function public.admin_wallet_adjust(uuid, ledger_direction, numeric, uuid, text, jsonb) from anon;
grant execute on function public.admin_wallet_adjust(uuid, ledger_direction, numeric, uuid, text, jsonb) to authenticated;
grant execute on function public.admin_wallet_adjust(uuid, ledger_direction, numeric, uuid, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 5. request_payout — conflict clause on the payout hold (1 site)
-- ---------------------------------------------------------------------------

create or replace function public.request_payout(p_amount_aed numeric, p_beneficiary_id uuid default null::uuid)
 returns payouts
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
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
  select balance_aed into bal from public.wallets where user_id = me;
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
$function$;

-- ---------------------------------------------------------------------------
-- 6. settle_game — conflict clause on the settlement credit (1 site)
-- ---------------------------------------------------------------------------
-- This is the one live duplicate this migration actually fixes today. The
-- game_settlements upsert is `on conflict (game_id) do update ... returning *`,
-- so a re-settle returns the SAME gs.id, and the credit insert below is
-- unconditional — a second settle_game(p_finalize := true) for the same game
-- posts a second identical credit. The key + clause makes the second a no-op.

create or replace function public.settle_game(p_game_id uuid, p_organiser_user_id uuid, p_sport text, p_gross_collected numeric, p_finalize boolean default true)
 returns game_settlements
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  me uuid := auth.uid();
  r record;
  fee_rate numeric(5,2);
  min_fee numeric(12,2);
  max_fee numeric(12,2);
  fee numeric(12,2);
  earnings numeric(12,2);
  gs public.game_settlements;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  -- Only admin or organiser can settle
  if not (public.is_admin(me) or me = p_organiser_user_id) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  if p_gross_collected is null or p_gross_collected < 0 then
    raise exception using errcode='P0001', message='invalid_gross';
  end if;

  -- fetch correct commission rule
  select * into r
  from public.resolve_commission(p_organiser_user_id, p_sport, now());

  fee_rate := coalesce(r.rate, 10.00);
  min_fee  := coalesce(r.min_fee, 0);
  max_fee  := coalesce(r.max_fee, null);

  fee := round(p_gross_collected * (fee_rate/100.0), 2);
  if fee < min_fee then fee := min_fee; end if;
  if max_fee is not null and fee > max_fee then fee := max_fee; end if;

  earnings := round(p_gross_collected - fee, 2);

  insert into public.game_settlements(
      game_id,
      organiser_user_id,
      sport,
      gross_collected_aed,
      app_fee_rate,
      app_fee_aed,
      organiser_earnings_aed,
      status,
      meta
  )
  values (
      p_game_id,
      p_organiser_user_id,
      p_sport,
      p_gross_collected,
      fee_rate,
      fee,
      earnings,
      case when p_finalize then 'settled' else 'pending' end,
      jsonb_build_object('resolved_at', now())
  )
  on conflict (game_id) do update
    set gross_collected_aed   = excluded.gross_collected_aed,
        app_fee_rate          = excluded.app_fee_rate,
        app_fee_aed           = excluded.app_fee_aed,
        organiser_earnings_aed = excluded.organiser_earnings_aed,
        status                 = excluded.status,
        meta                   = excluded.meta,
        settled_at             = case when excluded.status='settled' then now() else null end
  returning * into gs;

  -- finalize → post wallet credit
  if p_finalize then
    -- KAN-128: a re-settle returns the same gs.id from the upsert above, so
    -- before this clause a second finalize posted a second identical credit for
    -- ('game_settlement', gs.id, 'credit'). Now it is absorbed.
    insert into public.wallet_ledger(
      user_id,
      direction,
      amount_aed,
      status,
      ref_type,
      ref_id,
      memo,
      meta
    )
    values (
      p_organiser_user_id,
      'credit',
      gs.organiser_earnings_aed,
      'posted',
      'game_settlement',
      gs.id,
      'Game settlement earnings',
      jsonb_build_object(
        'game_id', gs.game_id,
        'sport', gs.sport
      )
    )
    on conflict do nothing;
  end if;

  return gs;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7. trgfn_payment_to_ledger — conflict clauses on all three inserts (3 sites)
-- ---------------------------------------------------------------------------
-- Header restated from the live catalogue and DIFFERENT from the four above:
-- NOT security definer, and search_path 'public', 'pg_temp'. Adding SECURITY
-- DEFINER here, or dropping pg_temp, would both be silent changes to this
-- function's resolution scope and privilege. There is no shared attribute string
-- across these five functions.
--
-- DEAD CODE (T-055): `FROM public.bookings` below references a table that does
-- not exist. The trigger is AFTER UPDATE OF status ON payment_intents, so the
-- exception aborts the update and no payment_intents row can ever reach
-- 'succeeded'. None of these three inserts can execute today. The reference is
-- left EXACTLY AS FOUND — fixing it is KAN-136's, and it is not a rename:
-- venue_bookings has no venue_id column, so resolving a booking's venue routes
-- through venue_spaces and is a design question.
--
-- The two gen_random_uuid() platform lines are likewise restated verbatim.
-- Those are KAN-131's fn_platform_owner_id() fix (T-052) and are out of bounds
-- here.

create or replace function public.trgfn_payment_to_ledger()
 returns trigger
 language plpgsql
 set search_path to 'public', 'pg_temp'
as $function$
DECLARE
  v_platform_pct numeric;
  v_platform_fee numeric;
  v_venue_amount numeric;

  v_user_wallet uuid;
  v_platform_wallet uuid;
  v_venue_wallet uuid;

  v_venue_id uuid;
BEGIN
  -- Only fire on success
  IF NEW.status <> 'succeeded' THEN
    RETURN NEW;
  END IF;

  -- Prevent double processing
  -- KAN-128 / T-049 Invariant 4: this EXISTS check is a read-then-write with no
  -- lock. It is NOT idempotency and is no longer the only thing between a
  -- webhook and a double credit — financial_ledger_payment_entry_unique is. It
  -- stays as a cheap early return that avoids an error round-trip.
  IF EXISTS (
    SELECT 1
    FROM public.financial_ledger
    WHERE payment_intent_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  -- Get booking venue
  -- KAN-136 / T-055: public.bookings does not exist. Left as found.
  SELECT venue_id
  INTO v_venue_id
  FROM public.bookings
  WHERE id = NEW.booking_id;

  -- Get commission
  SELECT percentage
  INTO v_platform_pct
  FROM public.commission_rules
  WHERE applies_to = 'platform'
    AND is_active = true
  LIMIT 1;

  v_platform_fee := round(NEW.amount * (v_platform_pct / 100), 2);
  v_venue_amount := NEW.amount - v_platform_fee;

  -- Resolve wallets
  v_user_wallet := fn_get_wallet('user', NEW.user_id, NEW.currency);
  v_platform_wallet := fn_get_wallet('platform', gen_random_uuid(), NEW.currency);
  v_venue_wallet := fn_get_wallet('venue', v_venue_id, NEW.currency);

  -- USER pays
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'user', NEW.user_id, v_user_wallet,
    NEW.booking_id, NEW.id,
    'debit', NEW.amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  -- PLATFORM commission
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'platform', gen_random_uuid(), v_platform_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_platform_fee, NEW.currency, 'commission'
  )
  ON CONFLICT DO NOTHING;

  -- VENUE revenue
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'venue', v_venue_id, v_venue_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_venue_amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$function$;

commit;

-- ---------------------------------------------------------------------------
-- POST-APPLY ASSERTIONS (run by cto after applying; not part of the transaction)
-- ---------------------------------------------------------------------------
-- A row-count check proves nothing here. Assert the catalogue directly:
--
--   -- both indexes exist, and the financial_ledger one is partial
--   select indexname, indexdef from pg_indexes
--   where schemaname='public'
--     and indexname in ('wallet_ledger_ref_key_unique',
--                       'financial_ledger_payment_entry_unique');
--
--   -- ref_id is NOT NULL
--   select attnotnull from pg_attribute
--   where attrelid='public.wallet_ledger'::regclass and attname='ref_id';
--
--   -- four SECURITY DEFINER with search_path=public, one neither, and NO
--   -- leftover 5-argument admin_wallet_adjust overload (expect 5 rows)
--   select p.proname, pg_get_function_identity_arguments(p.oid) args,
--          p.prosecdef, p.proconfig, p.proacl
--   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--   where n.nspname='public'
--     and p.proname in ('admin_cancel_payout','admin_wallet_adjust',
--                       'request_payout','settle_game','trgfn_payment_to_ledger')
--   order by p.proname;
--   -- admin_wallet_adjust's proacl must show authenticated and service_role
--   -- only: no '=X/' PUBLIC entry and no anon.
