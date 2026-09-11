-- KAN-130 probe pack — fixtures. ROWS ONLY. No probe or fixture creates a
-- relation (cto's "row, never a relation" condition, T-055 addendum).
--
-- Deliberately minimal: NO wallets rows are seeded. Every wallet in this pack is
-- created by the code under test (fn_get_wallet, or _wallet_recalc via the
-- trigger). Seeding one would hide the exact failure T-051 exists to fix — on
-- the deployed schema wallets.user_id is NOT NULL, so neither writer can create
-- a wallet at all, and a fixture that pre-creates one lets probes pass by
-- stepping over the defect. KAN-128's pack had to seed one for precisely that
-- reason and recorded it as a finding; this ticket is where it stops being
-- necessary.
--
-- owner_id is deliberately NOT a foreign key (T-051), so the venue and platform
-- ids below need no parent row and none is created.
set client_min_messages to warning;
begin;

insert into auth.users(id, email) values
  ('a1111111-1111-1111-1111-111111111111','usera@kan130.test'),
  ('b2222222-2222-2222-2222-222222222222','userb@kan130.test')
  on conflict do nothing;

commit;
