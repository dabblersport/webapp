-- APPLIED 2026-09-11 via apply_migration. Ledger version 20260911174052.
--
-- KAN-140 / T-061: trgfn_payment_to_ledger's venue-resolution SELECT still
-- references public.bookings, which does not exist (KAN-136/T-055). Replaces
-- it with the ruled two-hop join: venue_bookings -> venue_spaces -> venue_id.
--
-- T-061 (2026-09-06): venue_bookings.venue_space_id is NOT NULL with FK to
-- venue_spaces(id), and venue_spaces.venue_id is NOT NULL with FK to
-- venues(id) -- re-verified live immediately above this migration. Given a
-- venue_bookings row exists, venue_id cannot be NULL, so no NULL-handling
-- branch is written. The only failure mode is booking_id pointing at a
-- booking that does not exist, which KAN-145's already-live FK
-- (payment_intents_booking_id_fkey -> venue_bookings(id) ON DELETE RESTRICT,
-- re-verified live immediately above) prevents; INTO STRICT only asserts
-- that guarantee (CONVENTIONS.md 12d), it does not establish it.
--
-- Body restated verbatim from pg_get_functiondef on the LIVE catalogue
-- (T-044/CONVENTIONS.md 6c) -- this is the CURRENT live body, already
-- carrying KAN-128's three ON CONFLICT DO NOTHING clauses and KAN-131's
-- fn_platform_owner_id() at both platform-identity call sites, re-verified
-- live immediately before authoring this migration. Only the venue-
-- resolution SELECT and its comment change; everything else -- including
-- both fn_platform_owner_id() call sites, all three ON CONFLICT DO NOTHING
-- clauses, the double-processing EXISTS guard, wallet resolution via
-- fn_get_wallet, and all three financial_ledger inserts -- is byte-for-byte
-- unchanged. No SECURITY DEFINER, no search_path change.
--
-- AC2/AC3 simulated in a disposable container loaded from the full migration
-- history (supabase/tests/kan140/run.sh), never against production. Two
-- separate, pre-existing, unrelated defects were found during that
-- simulation, neither fixed here (out of this ticket's scope) and each
-- bypassed only in the disposable harness (see 10_fixtures.sql for both
-- declared deviations), never in production:
--   1. live public.commission_rules has no applies_to/percentage columns,
--      though the commission-lookup SELECT immediately after this fix's
--      venue-resolution block already assumes both.
--   2. live public.wallets.user_id is the table's PRIMARY KEY, FK'd to
--      auth.users(id) -- a legacy user-only wallet model. fn_get_wallet
--      (unmodified by KAN-140, explicitly out of scope per cto's T-072
--      Decision 3) never populates it, and no auth.users row exists for the
--      platform-sentinel or venue identities either -- so this INSERT fails
--      in PRODUCTION TODAY too, for every owner_type, independent of
--      anything KAN-140 touches. The same "wallets holds 0 rows" defect
--      KAN-131's own ticket already documented. KAN-130's territory.

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
  -- KAN-140 / T-061: two-hop join through venue_bookings -> venue_spaces.
  -- Both venue_bookings.venue_space_id and venue_spaces.venue_id are NOT NULL
  -- with FKs enforcing referential integrity, so given a venue_bookings row
  -- venue_id cannot be NULL -- no NULL-handling branch is written. INTO
  -- STRICT asserts (does not establish) that booking_id resolves to exactly
  -- one row, a guarantee KAN-145's payment_intents_booking_id_fkey holds.
  SELECT vs.venue_id
  INTO STRICT v_venue_id
  FROM public.venue_bookings vb
  JOIN public.venue_spaces vs ON vs.id = vb.venue_space_id
  WHERE vb.id = NEW.booking_id;

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
$function$;

DO $$
DECLARE
  v_oid oid;
BEGIN
  v_oid := 'public.trgfn_payment_to_ledger()'::regprocedure;

  IF (SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'public\.bookings' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: body still references public.bookings';
  END IF;
  IF NOT ((SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'public\.venue_bookings') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: body does not reference public.venue_bookings';
  END IF;
  IF NOT ((SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'public\.venue_spaces') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: body does not reference public.venue_spaces';
  END IF;
  IF NOT ((SELECT prosrc FROM pg_proc WHERE oid = v_oid) ~ 'INTO STRICT v_venue_id') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: INTO STRICT two-hop join not present';
  END IF;
  IF (SELECT count(*) FROM regexp_matches((SELECT prosrc FROM pg_proc WHERE oid = v_oid), 'ON CONFLICT DO NOTHING', 'g')) <> 3 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: expected exactly 3 ON CONFLICT DO NOTHING clauses, found %',
      (SELECT count(*) FROM regexp_matches((SELECT prosrc FROM pg_proc WHERE oid = v_oid), 'ON CONFLICT DO NOTHING', 'g'));
  END IF;
  IF (SELECT count(*) FROM regexp_matches((SELECT prosrc FROM pg_proc WHERE oid = v_oid), 'fn_platform_owner_id\(\)', 'g')) <> 2 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: expected exactly 2 fn_platform_owner_id() call sites, found %',
      (SELECT count(*) FROM regexp_matches((SELECT prosrc FROM pg_proc WHERE oid = v_oid), 'fn_platform_owner_id\(\)', 'g'));
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: function became SECURITY DEFINER';
  END IF;
  IF NOT ((SELECT proconfig FROM pg_proc WHERE oid = v_oid) @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: search_path is %', (SELECT proconfig::text FROM pg_proc WHERE oid = v_oid);
  END IF;
END $$;
