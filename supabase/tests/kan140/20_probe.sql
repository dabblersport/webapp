-- KAN-140 AC2/AC3 probe. Read-only assertion of the pack's own fixture; run
-- once BEFORE the migration (must fail on public.bookings) and once AFTER
-- (must succeed and produce all three financial_ledger rows). Same
-- OBSERVED/CONSEQUENCE reporting shape as supabase/tests/kan128/20_probes.sql.
DO $$
DECLARE
  v_pi_id uuid := '99999999-9999-9999-9999-999999999999';
  v_user_rows int;
  v_platform_rows int;
  v_venue_rows int;
  v_errcode text;
  v_errmsg text;
BEGIN
  -- Reset to pending so this probe is re-runnable (pre and post).
  UPDATE public.payment_intents SET status = 'pending' WHERE id = v_pi_id;
  DELETE FROM public.financial_ledger WHERE payment_intent_id = v_pi_id;

  BEGIN
    UPDATE public.payment_intents SET status = 'succeeded' WHERE id = v_pi_id;
    RAISE NOTICE 'OBSERVED: UPDATE to succeeded raised NO error.';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_errcode = RETURNED_SQLSTATE, v_errmsg = MESSAGE_TEXT;
    RAISE NOTICE 'OBSERVED: UPDATE to succeeded raised % : %', v_errcode, v_errmsg;
    RAISE NOTICE 'CONSEQUENCE: no financial_ledger rows were written (trigger aborted).';
    RETURN;
  END;

  SELECT count(*) INTO v_user_rows FROM public.financial_ledger
   WHERE payment_intent_id = v_pi_id AND entity_type = 'user' AND entry_type = 'debit';
  SELECT count(*) INTO v_platform_rows FROM public.financial_ledger
   WHERE payment_intent_id = v_pi_id AND entity_type = 'platform' AND entry_type = 'credit';
  SELECT count(*) INTO v_venue_rows FROM public.financial_ledger
   WHERE payment_intent_id = v_pi_id AND entity_type = 'venue' AND entry_type = 'credit';

  RAISE NOTICE 'OBSERVED: financial_ledger rows -- user/debit=%, platform/credit=%, venue/credit=%',
    v_user_rows, v_platform_rows, v_venue_rows;

  IF v_user_rows = 1 AND v_platform_rows = 1 AND v_venue_rows = 1 THEN
    RAISE NOTICE 'CONSEQUENCE: all three financial_ledger writes present and correctly typed.';
  ELSE
    RAISE NOTICE 'CONSEQUENCE: FAILED -- expected exactly one row of each type, got user=%, platform=%, venue=%',
      v_user_rows, v_platform_rows, v_venue_rows;
  END IF;
END $$;
