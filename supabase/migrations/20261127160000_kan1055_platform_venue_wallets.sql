-- KAN-1055: platform and venue wallets could never be created.
-- wallets already carries owner_type ('user'|'venue'|'platform', CHECK) / owner_id / id and the unique
-- (owner_type, owner_id, currency) index; financial_ledger.wallet_id already references wallets(id).
-- Only the old user-only key was in the way: user_id NOT NULL as PRIMARY KEY. Smallest fit:
--   * PRIMARY KEY moves to id (already unique, referenced by financial_ledger_wallet_fkey);
--   * user_id becomes nullable but stays UNIQUE (one wallet per auth user; _wallet_recalc's
--     ON CONFLICT (user_id) keeps working) and keeps its FK to auth.users;
--   * owner_type NOT NULL, and a CHECK ties user_id to owner_id for 'user' rows and forbids it otherwise.
-- fn_get_wallet sets user_id for 'user' wallets and is race-safe (ON CONFLICT on the owner key).
-- RLS unchanged: wallets_self_read (auth.uid() = user_id) never exposes platform/venue rows.
-- Callers: trgfn_payment_to_ledger (fn_get_wallet x3), _wallet_recalc, request_payout, delete_my_account (cascade),
-- v_wallet_balance, v_wallet_admin_overview. No lib/ or edge-function caller of either. wallets had 0 rows.
BEGIN;

ALTER TABLE public.wallets ALTER COLUMN id SET NOT NULL;
ALTER TABLE public.wallets ALTER COLUMN owner_type SET NOT NULL;
ALTER TABLE public.wallets DROP CONSTRAINT wallets_pkey;
ALTER TABLE public.wallets ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.wallets ADD CONSTRAINT wallets_pkey PRIMARY KEY USING INDEX wallets_id_unique;
ALTER TABLE public.wallets ADD CONSTRAINT wallets_user_id_key UNIQUE (user_id);
ALTER TABLE public.wallets ADD CONSTRAINT wallets_owner_user_consistent CHECK (
  (owner_type = 'user' AND user_id IS NOT NULL AND user_id = owner_id)
  OR (owner_type IN ('platform', 'venue') AND user_id IS NULL)
);

CREATE OR REPLACE FUNCTION public.fn_get_wallet(p_owner_type text, p_owner_id uuid, p_currency text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_wallet_id uuid;
BEGIN
  SELECT id
  INTO v_wallet_id
  FROM public.wallets
  WHERE owner_type = p_owner_type
    AND owner_id = p_owner_id
    AND currency = p_currency;

  IF v_wallet_id IS NULL THEN
    -- KAN-1055: user_id is set only for a 'user' wallet (wallets_owner_user_consistent).
    -- ON CONFLICT on the owner key makes a concurrent first payment safe.
    INSERT INTO public.wallets (user_id, owner_type, owner_id, currency)
    VALUES (CASE WHEN p_owner_type = 'user' THEN p_owner_id END, p_owner_type, p_owner_id, p_currency)
    ON CONFLICT (owner_type, owner_id, currency) DO NOTHING
    RETURNING id INTO v_wallet_id;

    IF v_wallet_id IS NULL THEN
      SELECT id INTO STRICT v_wallet_id
      FROM public.wallets
      WHERE owner_type = p_owner_type AND owner_id = p_owner_id AND currency = p_currency;
    END IF;
  END IF;

  RETURN v_wallet_id;
END;
$function$;

COMMIT;
