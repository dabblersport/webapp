-- KAN-128 AC 3 — fixtures. ROWS ONLY. No CREATE of any relation: every object
-- touched below already exists in the deployed schema (cto's "row, never a
-- relation" condition, T-055 addendum).
set client_min_messages to warning;
begin;

-- profiles.country defaults to 'UAE' and carries an FK to ref_countries, which
-- carries one onto ref_regions. Both are reference rows, not relations.
insert into public.ref_regions(key_text, name_en, name_ar) values ('middle_east','Middle East','الشرق الأوسط') on conflict do nothing;
insert into public.ref_countries(code, name_en, name_ar, region) values ('UAE','United Arab Emirates','الإمارات','middle_east') on conflict do nothing;

insert into auth.users(id, email) values
  ('11111111-1111-1111-1111-111111111111','organiser@kan128.test'),
  ('22222222-2222-2222-2222-222222222222','admin@kan128.test')
  on conflict do nothing;

insert into public.sports(id, sport_key, slug, name_en, name_ar, category, default_practitioner_label_en, is_challenge_sport, is_active)
  values ('33333333-3333-3333-3333-333333333333','kan128_sport','kan128-sport','Probe Sport','رياضة','team','player', true, true)
  on conflict do nothing;

insert into public.areas(id, country, city, name, center_lat, center_lng, district)
  values ('44444444-4444-4444-4444-444444444444','AE','Dubai','Probe Area', 25.2, 55.27, 'Probe District')
  on conflict do nothing;

insert into public.geo_locations(id, location, geohash, area_id)
  values ('55555555-5555-5555-5555-555555555555',
          public.st_setsrid(public.st_makepoint(55.27, 25.2), 4326)::public.geography,
          'thrsxxx', '44444444-4444-4444-4444-444444444444')
  on conflict do nothing;

insert into public.profiles(id, user_id, profile_type, username, display_name, age, persona_type, primary_sport)
  values ('66666666-6666-6666-6666-666666666666','11111111-1111-1111-1111-111111111111',
          'personal','kan128org','KAN128 Organiser', 30, 'organiser','33333333-3333-3333-3333-333333333333')
  on conflict do nothing;

insert into public.games(id, creator_profile_id, creator_user_id, start_at, end_at, capacity,
                         sport_id, geo_location_id, area_id)
  values ('77777777-7777-7777-7777-777777777777','66666666-6666-6666-6666-666666666666',
          '11111111-1111-1111-1111-111111111111', now() + interval '1 day', now() + interval '1 day 2 hours',
          10, '33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555',
          '44444444-4444-4444-4444-444444444444')
  on conflict do nothing;

commit;
