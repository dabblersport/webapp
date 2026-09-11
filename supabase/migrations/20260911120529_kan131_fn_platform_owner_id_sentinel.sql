-- KAN-131 / T-052 (cto, sequencing overturned 2026-09-10): fixed platform owner
-- sentinel replaces gen_random_uuid() at both platform call sites in
-- trgfn_payment_to_ledger. Body restated verbatim from the live catalogue
-- (pg_get_functiondef) per T-044 / CONVENTIONS.md 6c -- CREATE OR REPLACE drops
-- anything not restated. Exactly two tokens differ from the pre-apply body.
-- Scope: this makes a dead path correct; it does not make it live.
--
-- APPLIED 2026-09-11 via apply_migration. Ledger version 20260911120529.
-- Denied four times (2026-09-10/11) by the Claude Code auto mode classifier
-- (harness permission refusal, not a database error) before landing; the
-- migration body was re-verified byte-identical against live before every
-- attempt (pre-apply pg_get_functiondef md5 486f525a7be9436a24ce5386bd7a32ff,
-- unchanged since first authored) and needed no rework. Post-apply, both
-- fn_platform_owner_id() call sites verified returning the identical
-- all-zero UUID, 0 remaining gen_random_uuid() calls, both load-bearing
-- comment blocks and all 3 ON CONFLICT DO NOTHING clauses intact,
-- prosecdef=false, search_path=public, pg_temp unchanged.

create or replace function public.fn_platform_owner_id()
returns uuid language sql immutable
set search_path = public, pg_temp
as $$ select '00000000-0000-0000-0000-000000000000'::uuid $$;

CREATE OR REPLACE FUNCTION public.trgfn_payment_to_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  -- webhook and a double credit -- financial_ledger_payment_entry_unique is. It
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
  v_platform_wallet := fn_get_wallet('platform', fn_platform_owner_id(), NEW.currency);
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
    'platform', fn_platform_owner_id(), v_platform_wallet,
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
$function$
;
