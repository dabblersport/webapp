-- KAN-171 SITTING 1 — public.charges: table, T-049 invariants, RLS, grants.
-- Rulings: T-063 (shape), T-069 (why settle_game needs it), T-049 (invariants),
--          T-051 (owner_type/owner_id polymorphism), T-074 (can_manage_venue raises 42P01).
-- Author: backend-4 (Min). Route PEER. Landing: apply_migration per T-068 step 1, never db push.
-- Strictly additive: every statement creates a NEW object. Nothing pre-existing is restated,
-- so T-058 does not apply to this sitting.
--
-- AC4 DECISION — purpose addressing. Settled here, not deferred.
--   Shape: purpose_type text + purpose_id uuid, the SAME polymorphism idiom T-051/T-063 ruled
--   for payer identity. T-063 forbids inventing a second idiom, so the parallel is exact:
--   the _type column names WHAT THE _id POINTS AT ('user' -> auth.users, 'venue' -> venues).
--   purpose_id holds a games.id, so the value is 'game' — NOT 'game_settlement', which names a
--   downstream process rather than a referent type and breaks the parallel the ruling exists to
--   preserve. AC4's example says 'game_settlement' and delegates exact naming; this is a
--   deliberate, reviewable deviation.
--   The exact query KAN-169 runs, and AC4's "no others" guarantee:
--       select coalesce(sum(amount), 0), count(*), count(distinct currency)
--       from public.charges
--       where purpose_type = 'game' and purpose_id = <game_id> and status = 'succeeded';
--   charges_purpose_idx (purpose_type, purpose_id) serves exactly that predicate. Rows for any
--   other game, or any future non-game purpose, are excluded by the two equality terms — there
--   is no nullable or overloaded column through which another game's row could leak in.
--
-- CURRENCY — left open for KAN-169, deliberately NOT resolved here.
--   T-063 makes charges multi-currency (amount + currency, never amount_<ccy>), while
--   game_settlements.gross_collected_aed is AED-only by column name, and T-063 bars converting
--   a *_aed column inside a billing ticket. Nothing specifies what a non-AED charge settles to.
--   This migration does not decide it. What it guarantees so KAN-169 CAN decide it:
--   currency is stored PER ROW; nothing here converts, defaults to, or assumes AED; and no CHECK
--   pins currency to 'AED'. So KAN-169 can count(distinct currency) and DETECT a mixed-currency
--   game — failing loudly or settling per-currency — instead of silently summing across
--   currencies into an AED-named column. Pinning it to AED now would foreclose that choice.

create table public.charges (
  id                  uuid        primary key default gen_random_uuid(),
  owner_type          text        not null,
  owner_id            uuid        not null,
  purpose_type        text        not null,
  purpose_id          uuid        not null,
  kind                text        not null,
  amount              numeric     not null,
  currency            text        not null,
  vat_amount          numeric     not null,
  status              text        not null default 'pending',
  provider            text        not null,
  provider_charge_id  text        not null,
  created_at          timestamptz not null default now()
);

comment on table public.charges is
  'KAN-171/T-063. Authoritative money-event object. Amount-immutable after insert (trgfn_charges_immutable); a refund or pro-ration is a compensating row with kind=''refund'' and a negative amount, never an UPDATE. All writes via public.record_charge (SECURITY DEFINER, sitting 2); charges_block_dml forbids client DML entirely.';

comment on column public.charges.amount is
  'GROSS, VAT-inclusive, in `currency`. Deliberately NOT amount_<ccy> (T-063). Negative when kind=''refund'' so sum(amount) is the net collected.';

comment on column public.charges.purpose_id is
  'What the charge is for. When purpose_type=''game'' this is games.id — the column KAN-169 aggregates over, served by charges_purpose_idx. No FK: polymorphic.';

comment on column public.charges.currency is
  'ISO-4217, uppercase. T-063 makes charges multi-currency by design while game_settlements.gross_collected_aed is AED-only by name; T-063 bars resolving that inside a billing ticket and KAN-171 does not resolve it. Guarantee for KAN-169: currency is stored per row and nothing here converts, defaults to, or assumes AED, so a mixed-currency game is DETECTABLE via count(distinct currency) rather than silently summed. No CHECK pins this to AED — that would foreclose KAN-169''s choice.';

alter table public.charges add constraint charges_owner_type_valid
  check (owner_type in ('user','venue','platform'));

alter table public.charges add constraint charges_purpose_type_valid
  check (purpose_type in ('game'));

alter table public.charges add constraint charges_kind_valid
  check (kind in ('charge','refund'));

alter table public.charges add constraint charges_status_valid
  check (status in ('pending','succeeded','failed','cancelled','refunded'));

alter table public.charges add constraint charges_currency_valid
  check (currency = upper(currency) and char_length(currency) = 3);

alter table public.charges add constraint charges_amount_sign_matches_kind
  check ((kind = 'charge' and amount >= 0 and vat_amount >= 0)
      or (kind = 'refund' and amount <= 0 and vat_amount <= 0));

alter table public.charges add constraint charges_vat_within_amount
  check (abs(vat_amount) <= abs(amount));

create unique index charges_natural_key_unique
  on public.charges (provider, provider_charge_id, kind);

create index charges_purpose_idx on public.charges (purpose_type, purpose_id);

create index charges_owner_idx on public.charges (owner_type, owner_id);

create function public.trgfn_charges_immutable()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001',
      message = 'charges rows are immutable: DELETE is forbidden (T-049). Record a compensating refund row instead.';
  end if;
  if new.amount             is distinct from old.amount
  or new.vat_amount         is distinct from old.vat_amount
  or new.currency           is distinct from old.currency
  or new.owner_type         is distinct from old.owner_type
  or new.owner_id           is distinct from old.owner_id
  or new.purpose_type       is distinct from old.purpose_type
  or new.purpose_id         is distinct from old.purpose_id
  or new.kind               is distinct from old.kind
  or new.provider           is distinct from old.provider
  or new.provider_charge_id is distinct from old.provider_charge_id
  or new.id                 is distinct from old.id
  or new.created_at         is distinct from old.created_at then
    raise exception using errcode = 'P0001',
      message = 'charges amounts and identity are immutable after insert (T-049); a refund or pro-ration is a compensating row, never an UPDATE. Only `status` may change.';
  end if;
  return new;
end;
$$;

create trigger trg_charges_immutable
  before update or delete on public.charges
  for each row execute function public.trgfn_charges_immutable();

create function public.charges_is_venue_member(p_venue_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
set row_security to 'off'
as $$
  select exists (
    select 1 from public.venue_members vm
    where vm.venue_id = p_venue_id
      and vm.user_id  = auth.uid()
  );
$$;

alter table public.charges enable row level security;

create policy charges_block_dml on public.charges
  for all using (false) with check (false);

create policy charges_player_read on public.charges
  for select using (owner_type = 'user' and owner_id = auth.uid());

create policy charges_venue_read on public.charges
  for select using (
    owner_type = 'venue'
    and public.charges_is_venue_member(owner_id)
  );

revoke all on public.charges from anon, authenticated;
grant select on public.charges to authenticated;

revoke all on function public.charges_is_venue_member(uuid) from public, anon, authenticated;
grant execute on function public.charges_is_venue_member(uuid) to authenticated, service_role;

revoke all on function public.trgfn_charges_immutable() from public, anon, authenticated;
