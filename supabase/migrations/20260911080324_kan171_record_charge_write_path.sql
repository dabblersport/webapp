-- KAN-171 SITTING 2 — public.record_charge: the single write path.
-- Depends on sitting 1 (version 20260911075539): the table, the natural key, and RLS.
-- Author: backend-4 (Min). Route PEER. Landing: apply_migration per T-068 step 1, never db push.
--
-- Signature and ON CONFLICT target are both DETERMINED by S1's applied objects, not chosen here:
--   * the conflict target (provider, provider_charge_id, kind) is exactly S1's
--     charges_natural_key_unique, verified applied before this migration was authored;
--   * the purpose_type/purpose_id pair is S1's AC4 addressing, so the RPC cannot record a charge
--     that KAN-169's aggregate would fail to find.
--
-- T-049 invariant 1: every charge write carries a natural key enforced by UNIQUE with
-- ON CONFLICT DO NOTHING. A provider retry must be idempotent AND useful — returning the
-- EXISTING row's id rather than null, so a caller cannot mistake an absorbed duplicate for a
-- failure and retry into a second row under a different reference.
--
-- charges_block_dml (USING false / WITH CHECK false) forbids all client DML, so this function is
-- the only way a row reaches the table. It is SECURITY DEFINER and owned by the table owner, so
-- it bypasses RLS by design; trg_charges_immutable is what still binds it, which is why S1 used a
-- trigger rather than grant discipline for the immutability invariant.

create function public.record_charge(
  p_owner_type         text,
  p_owner_id           uuid,
  p_purpose_type       text,
  p_purpose_id         uuid,
  p_kind               text,
  p_amount             numeric,
  p_currency           text,
  p_vat_amount         numeric,
  p_provider           text,
  p_provider_charge_id text,
  p_status             text default 'pending'
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
begin
  insert into public.charges (
    owner_type, owner_id, purpose_type, purpose_id, kind,
    amount, currency, vat_amount, status, provider, provider_charge_id
  ) values (
    p_owner_type, p_owner_id, p_purpose_type, p_purpose_id, p_kind,
    p_amount, p_currency, p_vat_amount, p_status, p_provider, p_provider_charge_id
  )
  on conflict (provider, provider_charge_id, kind) do nothing
  returning id into v_id;

  if v_id is null then
    select c.id into v_id
    from public.charges c
    where c.provider           = p_provider
      and c.provider_charge_id = p_provider_charge_id
      and c.kind               = p_kind;
  end if;

  return v_id;
end;
$$;

comment on function public.record_charge(text,uuid,text,uuid,text,numeric,text,numeric,text,text,text) is
  'KAN-171/T-063/T-049. The ONLY write path to public.charges — charges_block_dml forbids client DML entirely. Idempotent on the natural key (provider, provider_charge_id, kind): a duplicate is absorbed by ON CONFLICT DO NOTHING and the EXISTING row id is returned, never null, so a provider retry cannot be mistaken for a failure. A refund or pro-ration is recorded as a COMPENSATING ROW (kind=''refund'', negative amount), never an UPDATE — trg_charges_immutable enforces that even against this definer path.';

-- pg_default_acl (grantor=postgres) grants anon=X AND authenticated=X on new functions in public
-- BY NAME, measured live. Revoking PUBLIC alone would leave both standing — PUBLIC is named here
-- as well as both roles, and the resulting proacl is asserted after apply rather than assumed.
-- T-069 Q3: service_role is the correct execution tier for a money-moving operation.
revoke all on function public.record_charge(text,uuid,text,uuid,text,numeric,text,numeric,text,text,text)
  from public, anon, authenticated;
grant execute on function public.record_charge(text,uuid,text,uuid,text,numeric,text,numeric,text,text,text)
  to service_role;
