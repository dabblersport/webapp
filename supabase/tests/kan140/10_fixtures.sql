-- KAN-140 AC2/AC3 probe pack -- fixtures. ROWS ONLY, fabricated from nothing
-- (venues, venue_spaces, venue_bookings, payment_intents are all 0 rows live,
-- per backend-3's own Preflight measurement), same "row, never a relation"
-- discipline as supabase/tests/kan128/10_fixtures.sql.
--
-- FK chain: venue -> venue_space -> venue_booking -> payment_intent. This is
-- the exact chain KAN-140's fix joins across (venue_bookings.venue_space_id
-- -> venue_spaces.id -> venue_spaces.venue_id), so the fixture has to be
-- FK-valid all the way through or the join under test would be exercising
-- nothing.
set client_min_messages to warning;
begin;

insert into auth.users(id, email) values
  ('11111111-1111-1111-1111-111111111111','payer@kan140.test'),
  ('22222222-2222-2222-2222-222222222222','venuestaff@kan140.test')
  on conflict do nothing;

insert into public.sports(id, sport_key, slug, name_en, name_ar, category, default_practitioner_label_en, is_challenge_sport, is_active)
  values ('33333333-3333-3333-3333-333333333333','kan140_sport','kan140-sport','Probe Sport','رياضة','team','player', true, true)
  on conflict do nothing;

insert into public.areas(id, country, city, name, center_lat, center_lng, district)
  values ('44444444-4444-4444-4444-444444444444','AE','Dubai','Probe Area', 25.2, 55.27, 'Probe District')
  on conflict do nothing;

insert into public.geo_locations(id, location, geohash, area_id)
  values ('55555555-5555-5555-5555-555555555555',
          public.st_setsrid(public.st_makepoint(55.27, 25.2), 4326)::public.geography,
          'thrsxxx', '44444444-4444-4444-4444-444444444444')
  on conflict do nothing;

insert into public.venues(id, name_en, geo_location_id, area_id)
  values ('66666666-6666-6666-6666-666666666666','Probe Venue',
          '55555555-5555-5555-5555-555555555555','44444444-4444-4444-4444-444444444444')
  on conflict do nothing;

insert into public.venue_spaces(id, venue_id, sport_id)
  values ('77777777-7777-7777-7777-777777777777',
          '66666666-6666-6666-6666-666666666666','33333333-3333-3333-3333-333333333333')
  on conflict do nothing;

insert into public.venue_bookings(id, venue_space_id, starts_at, ends_at, source_type, created_by)
  values ('88888888-8888-8888-8888-888888888888','77777777-7777-7777-7777-777777777777',
          now() + interval '1 day', now() + interval '1 day 2 hours', 'manual',
          '22222222-2222-2222-2222-222222222222')
  on conflict do nothing;

-- DECLARED HARNESS DEVIATION (T-058 Decision 3 precedent, KAN-128): live
-- public.commission_rules has NO applies_to or percentage column
-- (information_schema, measured live 2026-09-11) -- yet
-- trgfn_payment_to_ledger's commission-lookup SELECT, immediately AFTER the
-- venue-resolution block this ticket fixes, already assumes both. That is a
-- separate, pre-existing defect, entirely unrelated to KAN-140's scope (the
-- venue-resolution join), and this ticket does not fix it -- fixing it would
-- be exactly the adjacent-defect scope creep the brief forbids. Patched HERE,
-- in the disposable harness only, never in production, solely so the
-- simulation can reach past that unrelated blocker to KAN-140's own
-- assertions (AC2/AC3). Evidence for anything downstream of this patched
-- table is reported at reduced strength, same discipline as KAN-128's
-- disabled-trigger deviation.
alter table public.commission_rules add column if not exists applies_to text;
alter table public.commission_rules add column if not exists percentage numeric;

insert into public.commission_rules(commission_rate, applies_to, percentage, is_active)
  values (10.00, 'platform', 10.00, true)
  on conflict do nothing;

-- SECOND DECLARED HARNESS DEVIATION (T-058 Decision 3 precedent, KAN-128),
-- refined after actually running this pack twice. public.wallets.user_id is
-- the table's PRIMARY KEY (measured live 2026-09-11: PRIMARY KEY (user_id),
-- FK to auth.users(id)) -- so it cannot merely be relaxed to nullable; a
-- PRIMARY KEY column can never be NULL regardless of a NOT NULL constraint.
-- fn_get_wallet (unmodified by KAN-140, and explicitly out of scope: cto's
-- T-072 Decision 3 says this ticket is authored NOT against wallets.user_id
-- being dropped and NOT against fn_get_wallet working) inserts only
-- (owner_type, owner_id, currency) and never user_id -- meaning this INSERT
-- fails in PRODUCTION TODAY too, for every owner_type, independent of
-- anything KAN-140 touches. That is KAN-130's unfinished owner-model
-- migration (the same "wallets holds 0 rows, no row can be written" defect
-- KAN-131's own ticket already documented), not a KAN-140 defect, and fixing
-- the real function would be exactly the adjacent-defect scope creep the
-- brief forbids.
--
-- Bypassed here by redefining fn_get_wallet IN THE DISPOSABLE HARNESS ONLY,
-- to additionally set user_id = owner_id so its own PK constraint is
-- satisfied -- never touching the real fn_get_wallet, never touching
-- production, and never touching anything KAN-140's own migration changes.
-- Evidence downstream of this patched function is reported at reduced
-- strength, same discipline as KAN-128's disabled-trigger deviation.
CREATE OR REPLACE FUNCTION public.fn_get_wallet(p_owner_type text, p_owner_id uuid, p_currency text)
RETURNS uuid LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $wallet$
DECLARE
  v_wallet_id uuid;
BEGIN
  SELECT id INTO v_wallet_id FROM public.wallets
   WHERE owner_type = p_owner_type AND owner_id = p_owner_id AND currency = p_currency;

  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (user_id, owner_type, owner_id, currency)
    VALUES (p_owner_id, p_owner_type, p_owner_id, p_currency)
    ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
    RETURNING id INTO v_wallet_id;
  END IF;

  RETURN v_wallet_id;
END;
$wallet$;

-- Same deviation, continued: wallets_user_id_fkey references auth.users(id)
-- -- another artefact of the legacy user-only wallet model, since a platform
-- or venue "wallet" has no natural auth.users row. This FK would reject the
-- platform-sentinel and venue owner_ids in PRODUCTION TODAY too, for the same
-- reason as the PK issue above. Seeding placeholder auth.users rows for those
-- two synthetic identities so the harness-patched fn_get_wallet's INSERT can
-- satisfy the FK -- this does not touch KAN-140's own scope, it only lets the
-- simulation reach the financial_ledger assertions.
insert into auth.users(id, email) values
  ('00000000-0000-0000-0000-000000000000','platform-sentinel@kan140.test'),
  ('66666666-6666-6666-6666-666666666666','venue-placeholder@kan140.test')
  on conflict do nothing;

insert into public.payment_intents(id, booking_id, user_id, amount, currency, provider, status)
  values ('99999999-9999-9999-9999-999999999999','88888888-8888-8888-8888-888888888888',
          '11111111-1111-1111-1111-111111111111', 100.00, 'AED', 'kan140_probe', 'pending')
  on conflict do nothing;

commit;
