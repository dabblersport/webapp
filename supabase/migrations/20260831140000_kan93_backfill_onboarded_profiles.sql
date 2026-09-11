-- KAN-93: backfill onboard=true profiles missing their persona-extension row
-- and/or their player sport_profiles row, per docs/DECISIONS.md T-037/T-038.
--
-- What this does:
--   1. Inserts public.player(profile_id) for every onboard=true, persona_type='player'
--      profile with no player row. Pure default insert — no other column required.
--   2. Inserts public.host(profile_id) for every onboard=true, persona_type='host'
--      profile with no host row. Pure default insert.
--   3. Inserts public.organiser(profile_id, sport) for every onboard=true,
--      persona_type='organiser' profile with no organiser row AND a non-NULL
--      preferred_sport (organiser.sport is NOT NULL, so a row with no recoverable
--      sport is deliberately left unrepaired rather than guessed).
--   4. Inserts public.sport_profiles(profile_id, sport, sport_id, skill_level=1) for
--      every onboard=true, persona_type='player' profile with no sport_profiles row
--      AND a non-NULL preferred_sport, mirroring exactly what rpc_onboard_profile
--      (KAN-48) does for a new signup.
--
-- What this does NOT do:
--   - Does not touch any profile with onboard = false (those are legitimately
--     mid-onboarding under the corrected model in T-038, not damaged).
--   - Does not invent a sport for a player with no preferred_sport, or an organiser
--     row for an organiser profile with no preferred_sport (persona_type='organiser'
--     but preferred_sport IS NULL). Both are excluded by the WHERE clauses below and
--     must be resolved by a separate, explicit decision — see verification block.
--   - Does not distinguish seed accounts (email @dabbler.local / @dabbler.internal /
--     dabbler.system@gmail.com) from real users — PO ruled 2026-08-31 that seed/test
--     accounts (dabbler.system@gmail.com, seed_test_001@dabbler.internal) get backfilled
--     the same as everyone else. Nothing in this migration removes seed rows from the
--     backfill; the split is still reported in the verification block below for the
--     record.
--   - Idempotent: every INSERT is guarded by NOT EXISTS / ON CONFLICT DO NOTHING, so
--     running this twice changes nothing on the second run.
--
-- Preconditions measured live, read-only, 2026-08-31 (re-derives T-038's 48/6 census):
--   missing persona-extension rows (onboard=true): 36 player + 9 organiser + 3 host = 48
--   missing sport_profiles rows (onboard=true, persona_type='player'): 6
--   Of those, exactly 1 organiser and 1 player sport row have no recoverable
--   preferred_sport and are excluded from repair by this migration (see guard below).

BEGIN;

DO $$
DECLARE
  v_missing_player int;
  v_missing_organiser int;
  v_missing_host int;
  v_missing_sport int;
BEGIN
  SELECT count(*) INTO v_missing_player
  FROM public.profiles p
  WHERE p.onboard = true AND p.persona_type = 'player'
    AND NOT EXISTS (SELECT 1 FROM public.player pl WHERE pl.profile_id = p.id);

  SELECT count(*) INTO v_missing_organiser
  FROM public.profiles p
  WHERE p.onboard = true AND p.persona_type = 'organiser'
    AND NOT EXISTS (SELECT 1 FROM public.organiser o WHERE o.profile_id = p.id);

  SELECT count(*) INTO v_missing_host
  FROM public.profiles p
  WHERE p.onboard = true AND p.persona_type = 'host'
    AND NOT EXISTS (SELECT 1 FROM public.host h WHERE h.profile_id = p.id);

  SELECT count(*) INTO v_missing_sport
  FROM public.profiles p
  WHERE p.onboard = true AND p.persona_type = 'player'
    AND NOT EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = p.id);

  IF v_missing_player <> 36 OR v_missing_organiser <> 9 OR v_missing_host <> 3 OR v_missing_sport <> 6 THEN
    RAISE EXCEPTION
      'KAN-93 precondition mismatch: player=% (expected 36), organiser=% (expected 9), host=% (expected 3), sport=% (expected 6). Re-measure the census before running — do not adjust these numbers to match and re-run.',
      v_missing_player, v_missing_organiser, v_missing_host, v_missing_sport;
  END IF;
END $$;

-- 1. player persona-extension rows — pure default, no data dependency
INSERT INTO public.player (profile_id)
SELECT p.id
FROM public.profiles p
WHERE p.onboard = true
  AND p.persona_type = 'player'
  AND NOT EXISTS (SELECT 1 FROM public.player pl WHERE pl.profile_id = p.id)
ON CONFLICT (profile_id) DO NOTHING;

-- 2. host persona-extension rows — pure default, no data dependency
INSERT INTO public.host (profile_id)
SELECT p.id
FROM public.profiles p
WHERE p.onboard = true
  AND p.persona_type = 'host'
  AND NOT EXISTS (SELECT 1 FROM public.host h WHERE h.profile_id = p.id)
ON CONFLICT (profile_id) DO NOTHING;

-- 3. organiser persona-extension rows — sport is NOT NULL, so only where recoverable
INSERT INTO public.organiser (profile_id, sport)
SELECT p.id, s.sport_key
FROM public.profiles p
JOIN public.sports s ON s.id = p.preferred_sport
WHERE p.onboard = true
  AND p.persona_type = 'organiser'
  AND p.preferred_sport IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.organiser o WHERE o.profile_id = p.id)
ON CONFLICT (profile_id, sport) DO NOTHING;

-- 4. player sport_profiles rows — mirrors rpc_onboard_profile's own insert exactly
INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
SELECT p.id, s.sport_key, p.preferred_sport, 1
FROM public.profiles p
JOIN public.sports s ON s.id = p.preferred_sport
WHERE p.onboard = true
  AND p.persona_type = 'player'
  AND p.preferred_sport IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = p.id)
ON CONFLICT (profile_id, sport) DO NOTHING;

COMMIT;

-- ============================================================================
-- PRE-APPLY SNAPSHOT — run this BEFORE the migration above and save the output;
-- it is the only way to get the seed/real split, since the rows it selects no
-- longer meet the WHERE clause once the migration has inserted them.
-- ============================================================================

-- select
--   case when u.email ~ '@dabbler\.(local|internal)$' or u.email = 'dabbler.system@gmail.com'
--        then 'seed' else 'real' end as origin,
--   count(*) filter (where p.persona_type = 'player'
--     and not exists (select 1 from public.player pl where pl.profile_id = p.id)) as missing_player,
--   count(*) filter (where p.persona_type = 'organiser'
--     and not exists (select 1 from public.organiser o where o.profile_id = p.id)) as missing_organiser,
--   count(*) filter (where p.persona_type = 'host'
--     and not exists (select 1 from public.host h where h.profile_id = p.id)) as missing_host,
--   count(*) filter (where p.persona_type = 'player'
--     and not exists (select 1 from public.sport_profiles sp where sp.profile_id = p.id)) as missing_sport
-- from public.profiles p
-- join auth.users u on u.id = p.user_id
-- where p.onboard = true
-- group by 1;

-- ============================================================================
-- VERIFICATION BLOCK — run immediately after applying, results go in the ticket
-- comment per G-002 condition 4.
-- ============================================================================

-- 1. Remaining gaps after backfill (expect: 0 player, 0 host, 1 organiser, 1 sport)
select
  (select count(*) from public.profiles p where p.onboard and p.persona_type='player'
     and not exists (select 1 from public.player pl where pl.profile_id=p.id)) as still_missing_player,
  (select count(*) from public.profiles p where p.onboard and p.persona_type='organiser'
     and not exists (select 1 from public.organiser o where o.profile_id=p.id)) as still_missing_organiser,
  (select count(*) from public.profiles p where p.onboard and p.persona_type='host'
     and not exists (select 1 from public.host h where h.profile_id=p.id)) as still_missing_host,
  (select count(*) from public.profiles p where p.onboard and p.persona_type='player'
     and not exists (select 1 from public.sport_profiles sp where sp.profile_id=p.id)) as still_missing_sport;

-- 2. The 2 rows this migration deliberately did not touch, for a follow-up decision
select p.id, p.persona_type, p.preferred_sport, p.primary_sport, u.email
from public.profiles p
join auth.users u on u.id = p.user_id
where p.onboard = true
  and p.preferred_sport is null
  and (
    (p.persona_type = 'organiser' and not exists (select 1 from public.organiser o where o.profile_id = p.id))
    or (p.persona_type = 'player' and not exists (select 1 from public.sport_profiles sp where sp.profile_id = p.id))
  );

-- 3. Seed vs. real split (informational — PO ruled 2026-08-31 both groups are
--    backfilled identically, no exclusion applied) — see the pre-apply snapshot
--    query above; it must be run and its output saved *before* this migration,
--    since the rows it counts no longer match "missing" once this migration has
--    inserted them.
