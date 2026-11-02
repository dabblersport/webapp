-- KAN-711 LOCAL SEED. LOCAL THROWAWAY POSTGRES ONLY. Run after local_harness_kan711.sql and BEFORE
-- the three KAN-711 migrations, so these rows are "pre-existing legacy rows" the backfill must cover.
-- Edge cases are deliberate: null game title, null meetup end_at/capacity, meetup meta.venue_space_id,
-- every meetup-only visibility/rsvp value, a cancelled game with cancelled_at/reason, a cancelled
-- meetup (no cancelled_at column exists), request_ids, a series game, old timestamps to prove they
-- are preserved, and a meetup whose creator_user_id differs from its profile's user (legal in legacy).

-- games: 6 rows. trg_games_set_host forces creator_user_id from the profile.
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity,
  listing_visibility, join_policy, min_skill, max_skill, is_cancelled, cancelled_at, cancelled_reason,
  sport_id, geo_location_id, area_id, joining_rule, cost_cover, request_id, series_id, created_at, updated_at)
VALUES
 ('10000000-0000-0000-0000-000000000001', 'Sunday 5s', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  '2026-01-04 18:00+00', '2026-01-04 19:00+00', 10, 'public', 'open', 2, 6, false, NULL, NULL,
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'free', 'free',
  NULL, NULL, '2025-12-01 10:00+00', '2025-12-02 10:00+00'),
 ('10000000-0000-0000-0000-000000000002', NULL, '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  '2026-01-05 18:00+00', '2026-01-05 19:30+00', 2, 'followers', 'request', NULL, NULL, false, NULL, NULL,
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'paid', 'free',
  '20000000-0000-0000-0000-000000000001', NULL, '2025-12-03 10:00+00', '2025-12-03 10:00+00'),
 ('10000000-0000-0000-0000-000000000003', 'Cancelled league', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
  '2026-01-06 18:00+00', '2026-01-06 20:00+00', 64, 'private', 'invite', 1, 10, true, '2025-12-10 09:00+00', 'rain',
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'members_only', 'members_only',
  NULL, NULL, '2025-12-04 10:00+00', '2025-12-10 09:00+00'),
 ('10000000-0000-0000-0000-000000000004', 'Series wk1', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
  '2026-01-07 18:00+00', '2026-01-07 19:00+00', 12, 'public', 'link', NULL, NULL, false, NULL, NULL,
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'paid', 'paid',
  NULL, '00000000-0000-0000-0000-0000000000f1', '2025-12-05 10:00+00', '2025-12-05 10:00+00'),
 ('10000000-0000-0000-0000-000000000005', 'Series wk2', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
  '2026-01-14 18:00+00', '2026-01-14 19:00+00', 12, 'public', 'open', NULL, NULL, false, NULL, NULL,
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'free', 'free',
  NULL, '00000000-0000-0000-0000-0000000000f1', '2025-12-05 10:00+00', '2025-12-05 10:00+00'),
 ('10000000-0000-0000-0000-000000000006', 'Same request other type', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
  '2026-01-08 18:00+00', '2026-01-08 19:00+00', 8, 'public', 'open', NULL, NULL, false, NULL, NULL,
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'free', 'free',
  '20000000-0000-0000-0000-000000000009', NULL, '2025-12-06 10:00+00', '2025-12-06 10:00+00');

-- meetups: 6 rows. Superuser bypasses FORCE RLS here; on live they are created through RPCs.
INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, description, listing_visibility,
  rsvp_policy, capacity, start_at, end_at, is_cancelled, meta, host_actor_id, geo_location_id, sport_id, area_id,
  min_skill, max_skill, joining_rule, cost_cover, location_name, is_indoor, request_id, created_at, updated_at)
VALUES
 ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Morning run', 'Easy pace',
  'public', 'open', NULL, '2026-01-04 06:00+00', NULL, false, '{}', '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
  NULL, NULL, 'free', 'free', 'Corniche', NULL, NULL, '2025-11-01 10:00+00', '2025-11-01 10:00+00'),
 ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Circle padel', NULL,
  'circle', 'request', 4, '2026-01-05 06:00+00', '2026-01-05 07:00+00', false, '{"venue_space_id":"00000000-0000-0000-0000-00000000aaaa"}',
  '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1',
  3, 7, 'paid', 'paid', NULL, true, '20000000-0000-0000-0000-000000000001', '2025-11-02 10:00+00', '2025-11-03 10:00+00'),
 ('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'Invite only', NULL,
  'invite', 'invite', 1, '2026-01-06 06:00+00', NULL, true, '{}', '00000000-0000-0000-0000-0000000000b2', NULL, NULL, NULL,
  NULL, NULL, 'members_only', 'members_only', NULL, false, NULL, '2025-11-04 10:00+00', '2025-11-05 10:00+00'),
 ('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'Link meetup', NULL,
  'link', 'link', 30, '2026-01-07 06:00+00', '2026-01-07 09:00+00', false, '{}', '00000000-0000-0000-0000-0000000000b2', NULL, NULL, NULL,
  NULL, NULL, 'free', 'free', NULL, NULL, NULL, '2025-11-06 10:00+00', '2025-11-06 10:00+00'),
 ('30000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'Hidden closed', NULL,
  'hidden', 'closed', NULL, '2026-01-08 06:00+00', NULL, false, '{}', '00000000-0000-0000-0000-0000000000b2', NULL, NULL, NULL,
  NULL, NULL, 'free', 'free', NULL, NULL, NULL, '2025-11-07 10:00+00', '2025-11-07 10:00+00'),
 ('30000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a2', 'Profile/user drift', NULL,
  'public', 'open', 5, '2026-01-09 06:00+00', NULL, false, '{}', '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
  NULL, NULL, 'free', 'free', NULL, NULL, '20000000-0000-0000-0000-000000000009', '2025-11-08 10:00+00', '2025-11-08 10:00+00');

-- Rows the seed itself caused in side-effect sinks (legacy behaviour, not KAN-711). Probes measure deltas.
