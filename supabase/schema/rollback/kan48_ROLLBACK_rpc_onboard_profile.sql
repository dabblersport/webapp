-- ROLLBACK ARTIFACT for KAN-48. NOT a migration — do not apply in sequence.
--
-- This is the definition of public.rpc_onboard_profile as it stood in production
-- immediately BEFORE cto applied kan48_rpc_onboard_profile_transactional_fold
-- on 2026-08-29. Captured via pg_get_functiondef.
--   pre-apply md5:    4b7c145b740da8dbd3bd92537bb3adb2
--   pre-apply length: 2289 chars
--
-- WHY THIS EXISTS: rpc_onboard_profile is on the critical onboarding path. If the
-- new version breaks onboarding, no new user can sign up. Running this file
-- restores the previous behaviour in one statement. Note that the old version
-- sets onboard = true inline (the bug KAN-48 fixes) and writes NO persona-extension
-- row — restoring it reinstates both of those defects deliberately, as the lesser
-- of two harms while a fix is prepared.

CREATE OR REPLACE FUNCTION public.rpc_onboard_profile(p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_persona_type text, p_preferred_sport uuid DEFAULT NULL::uuid, p_interests uuid[] DEFAULT NULL::uuid[], p_country text DEFAULT NULL::text, p_city text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_profile_id uuid; v_profile_type text; v_persona_type text; v_tier_code text;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: can only onboard your own profile';
  END IF;

  v_persona_type := CASE p_persona_type WHEN 'hoster' THEN 'host' ELSE p_persona_type END;
  v_profile_type := CASE v_persona_type
    WHEN 'player' THEN 'personal' WHEN 'organiser' THEN 'business'
    WHEN 'host' THEN 'venue' WHEN 'socialiser' THEN 'personal' ELSE 'personal' END;
  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id LIMIT 1;
  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles SET
      display_name = p_display_name, username = p_username, age = p_age,
      gender = lower(p_gender), persona_type = v_persona_type,
      preferred_sport = p_preferred_sport, primary_sport = p_preferred_sport,
      interests = p_interests, country = p_country, city = p_city,
      skill_level = 1, onboard = true
    WHERE id = v_profile_id;
  ELSE
    INSERT INTO public.profiles (
      user_id, display_name, username, age, gender,
      profile_type, persona_type, intention,
      preferred_sport, primary_sport, interests,
      country, city, skill_level, onboard, is_player, is_active
    ) VALUES (
      p_user_id, p_display_name, p_username, p_age, lower(p_gender),
      v_profile_type, v_persona_type, v_persona_type,
      p_preferred_sport, p_preferred_sport, p_interests,
      p_country, p_city, 1, true, (v_persona_type = 'player'), true
    ) RETURNING id INTO v_profile_id;
  END IF;
  SELECT code INTO v_tier_code FROM public.tiers WHERE is_default = true LIMIT 1;
  IF v_tier_code IS NOT NULL THEN
    INSERT INTO public.profile_tiers (profile_id, tier_code, is_active)
    VALUES (v_profile_id, v_tier_code, true)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN v_profile_id;
END;
$function$;
