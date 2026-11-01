-- KAN-685: convert the one test account Dabbler-Test from Player to Contributor.
-- Scope: profile 5eeb4305-9277-458e-a56f-a5ed77e3f208 / user a3ba3271-3556-4b4e-b15d-bc0851f8a64b ONLY.
-- cto ruling dreq-e2a1e56f: the live guard trgfn_unified_persona_guard refuses a legacy -> unified change while
-- OLD.onboard is true, so the profile is held un-onboarded for the two writes that need it and re-onboarded last.
-- Guard, triggers, RLS, functions and the onboarding RPC are untouched. One DO block = one transaction; the deferred
-- contributor-sports constraint triggers run at commit, with onboard = true again, and abort everything if they fail.
-- There is no rollback after commit (the guard blocks contributor -> player); see the rollback file beside this one.
DO $kan685$
DECLARE
  c_profile constant uuid := '5eeb4305-9277-458e-a56f-a5ed77e3f208';
  c_user    constant uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  c_sport   constant uuid := '4fd36109-12c2-4b17-a8a2-281be2b8649c';
  n bigint;
  p public.profiles%ROWTYPE;
BEGIN
  -- pre-write checks: abort, adding no sport or interest rows, if the sports rule would fail at commit
  SELECT * INTO p FROM public.profiles WHERE id = c_profile AND user_id = c_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'kan685: target profile/user pair not found'; END IF;
  IF p.persona_type <> 'player' OR p.onboard IS NOT TRUE THEN
    RAISE EXCEPTION 'kan685: unexpected before-state persona_type=% onboard=%', p.persona_type, p.onboard;
  END IF;
  IF p.primary_sport IS DISTINCT FROM c_sport THEN RAISE EXCEPTION 'kan685: primary_sport is not the target sport'; END IF;
  IF p.interests IS NULL OR NOT (p.interests @> ARRAY[c_sport]) THEN RAISE EXCEPTION 'kan685: interests missing the primary sport'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = c_profile AND sp.sport_id = c_sport) THEN
    RAISE EXCEPTION 'kan685: no sport_profiles row for the primary sport';
  END IF;
  IF EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = c_profile AND NOT (p.interests @> ARRAY[sp.sport_id])) THEN
    RAISE EXCEPTION 'kan685: a sport_profiles row is not in interests';
  END IF;

  -- 1. un-onboard (own statement)
  UPDATE public.profiles SET onboard = false WHERE id = c_profile AND user_id = c_user;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'kan685: step 1 touched % rows', n; END IF;

  -- 2. persona + intention in one UPDATE
  UPDATE public.profiles SET persona_type = 'contributor', onboarding_intention = 'play_organise'
   WHERE id = c_profile AND user_id = c_user;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'kan685: step 2 touched % rows', n; END IF;

  -- 3. organiser extension for the primary sport, only if absent
  IF NOT EXISTS (SELECT 1 FROM public.organiser WHERE profile_id = c_profile) THEN
    INSERT INTO public.organiser (profile_id, sport)
    SELECT c_profile, s.sport_key FROM public.sports s WHERE s.id = c_sport;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 1 THEN RAISE EXCEPTION 'kan685: step 3 inserted % rows', n; END IF;
  END IF;

  -- 4. re-onboard, last
  UPDATE public.profiles SET onboard = true WHERE id = c_profile AND user_id = c_user;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'kan685: step 4 touched % rows', n; END IF;
END
$kan685$;
