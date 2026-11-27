-- Rollback for KAN-1055. Fails (correctly) if any platform/venue wallet exists: delete those first only
-- after their financial_ledger rows are accounted for. fn_get_wallet body is the pre-migration
-- pg_get_functiondef; ACL {=X,postgres=X,anon=X,authenticated=X,service_role=X} kept by CREATE OR REPLACE.
BEGIN;
ALTER TABLE public.wallets DROP CONSTRAINT wallets_owner_user_consistent;
ALTER TABLE public.wallets DROP CONSTRAINT wallets_user_id_key;
-- financial_ledger_wallet_fkey depends on the pkey index on id: Postgres does not re-bind an FK to another
-- unique index, so the FK is dropped and re-created (same definition) around the key swap.
ALTER TABLE public.financial_ledger DROP CONSTRAINT financial_ledger_wallet_fkey;
ALTER TABLE public.wallets DROP CONSTRAINT wallets_pkey;
CREATE UNIQUE INDEX wallets_id_unique ON public.wallets USING btree (id);
ALTER TABLE public.wallets ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.wallets ADD CONSTRAINT wallets_pkey PRIMARY KEY (user_id);
ALTER TABLE public.financial_ledger ADD CONSTRAINT financial_ledger_wallet_fkey
  FOREIGN KEY (wallet_id) REFERENCES public.wallets(id) ON DELETE SET NULL;
ALTER TABLE public.wallets ALTER COLUMN owner_type DROP NOT NULL;
ALTER TABLE public.wallets ALTER COLUMN id DROP NOT NULL;

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
    INSERT INTO public.wallets (owner_type, owner_id, currency)
    VALUES (p_owner_type, p_owner_id, p_currency)
    RETURNING id INTO v_wallet_id;
  END IF;

  RETURN v_wallet_id;
END;
$function$;
COMMIT;
