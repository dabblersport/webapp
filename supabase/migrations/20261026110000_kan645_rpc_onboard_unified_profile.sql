-- KAN-645 (Personas S2): atomic intention-based onboarding for the unified personas.
-- Depends on KAN-644 (20261026100000): persona CHECK, onboarding_intention, extension guards,
-- the one-profile guard and the completed-Contributor sports rule. AUTHORED, NOT APPLIED (story 6).
--
-- New function only. The legacy public.rpc_onboard_profile is deliberately NOT edited: its signature,
-- grants and body stay as they are. KAN-644's triggers already protect unified accounts from it
-- (UPDATE persona_type on a unified row -> persona_conversion_blocked, whole call rolled back) and its
-- own vocabulary check rejects 'contributor'/'partner'. Probes P-L1..P-L3 prove both.
--
-- Error codes are the exception message (stable, no free text):
--   access_denied, invalid_onboarding_intention, invalid_display_name, invalid_username, invalid_age,
--   invalid_gender, invalid_country, primary_sport_required, invalid_sport, invalid_interests,
--   username_taken, profile_migration_required, legacy_profile_requires_existing_flow,
--   persona_change_not_supported, onboarding_incomplete (+ KAN-644: single_profile_required,
--   contributor_sports_incomplete).

CREATE OR REPLACE FUNCTION public.rpc_onboard_unified_profile(
  p_user_id uuid,
  p_display_name text,
  p_username text,
  p_age integer,
  p_gender text,
  p_onboarding_intention text,
  p_preferred_sport uuid DEFAULT NULL::uuid,
  p_interests uuid[] DEFAULT NULL::uuid[],
  p_country text DEFAULT NULL::text,
  p_city text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_persona   text;
  v_name      text;
  v_username  text;
  v_gender    text;
  v_sport_key text;
  v_follow    uuid[];
  v_count     integer;
  v_row       public.profiles%ROWTYPE;
  v_pid       uuid;
  v_tier_code text;
BEGIN
  -- 1. Caller must be the owner. IS DISTINCT FROM so a NULL p_user_id cannot slip through.
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'access_denied';
  END IF;

  -- 2. Intention -> persona. Missing or unknown is an error; never a default persona.
  v_persona := CASE p_onboarding_intention
    WHEN 'connect_play'  THEN 'contributor'
    WHEN 'play_organise' THEN 'contributor'
    WHEN 'organise'      THEN 'contributor'
    WHEN 'host_games'    THEN 'partner'
  END;
  IF v_persona IS NULL THEN
    RAISE EXCEPTION 'invalid_onboarding_intention';
  END IF;

  -- 3. Input validation (before any write).
  v_name := btrim(p_display_name);
  IF v_name IS NULL OR char_length(v_name) < 2 OR char_length(v_name) > 50 THEN
    RAISE EXCEPTION 'invalid_display_name';
  END IF;
  v_username := btrim(p_username);
  IF v_username IS NULL OR v_username !~ '^[a-zA-Z0-9_]+$' THEN
    RAISE EXCEPTION 'invalid_username';
  END IF;
  IF p_age IS NULL OR p_age < 13 OR p_age > 120 THEN
    RAISE EXCEPTION 'invalid_age';
  END IF;
  v_gender := lower(btrim(p_gender));
  IF p_gender IS NOT NULL AND v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'invalid_gender';
  END IF;
  IF p_country IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.ref_countries c WHERE c.code = p_country) THEN
    RAISE EXCEPTION 'invalid_country';
  END IF;

  -- Primary is required for both personas (profiles_primary_sport_required_for_sport_personas).
  IF p_preferred_sport IS NULL THEN
    RAISE EXCEPTION 'primary_sport_required';
  END IF;
  SELECT s.sport_key INTO v_sport_key FROM public.sports s WHERE s.id = p_preferred_sport AND s.is_active;
  IF v_sport_key IS NULL THEN
    RAISE EXCEPTION 'invalid_sport';
  END IF;
  IF p_interests IS NOT NULL THEN
    IF array_position(p_interests, NULL) IS NOT NULL THEN
      RAISE EXCEPTION 'invalid_interests';
    END IF;
    IF EXISTS (SELECT 1 FROM unnest(p_interests) AS i(id)
               WHERE NOT EXISTS (SELECT 1 FROM public.sports s WHERE s.id = i.id AND s.is_active)) THEN
      RAISE EXCEPTION 'invalid_sport';
    END IF;
  END IF;

  -- Contributor Following = distinct p_interests UNION Primary (Primary first, no count cap).
  -- Partner keeps the caller's list as given.
  IF v_persona = 'contributor' THEN
    SELECT array_agg(d.x ORDER BY d.ord) INTO v_follow
    FROM (SELECT DISTINCT ON (t.x) t.x, t.ord
          FROM unnest(ARRAY[p_preferred_sport] || COALESCE(p_interests, '{}'::uuid[])) WITH ORDINALITY AS t(x, ord)
          ORDER BY t.x, t.ord) d;
  ELSE
    v_follow := p_interests;
  END IF;

  -- 4. Serialize by user (KAN-644's one lock discipline), then look at ALL of the user's rows.
  PERFORM pg_advisory_xact_lock(hashtextextended('profiles:user:' || p_user_id::text, 0));

  SELECT count(*) INTO v_count FROM public.profiles WHERE user_id = p_user_id;
  IF v_count > 1 THEN
    RAISE EXCEPTION 'profile_migration_required';
  ELSIF v_count = 1 THEN
    SELECT * INTO v_row FROM public.profiles WHERE user_id = p_user_id FOR UPDATE;
    IF v_row.persona_type NOT IN ('contributor', 'partner') THEN
      RAISE EXCEPTION 'legacy_profile_requires_existing_flow';
    ELSIF v_row.persona_type IS DISTINCT FROM v_persona THEN
      RAISE EXCEPTION 'persona_change_not_supported';
    ELSIF v_row.onboard IS TRUE THEN
      RETURN v_row.id;      -- completed, compatible retry: nothing is reset or overwritten
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = v_username::citext AND id IS DISTINCT FROM v_row.id) THEN
    RAISE EXCEPTION 'username_taken';
  END IF;

  IF v_count = 1 THEN
    -- Resume an incomplete unified row. Persona is never touched; the first-three intention may change.
    v_pid := v_row.id;
    UPDATE public.profiles SET
      display_name = v_name, username = v_username, age = p_age, gender = v_gender,
      onboarding_intention = p_onboarding_intention,
      preferred_sport = p_preferred_sport, primary_sport = p_preferred_sport,
      interests = v_follow, country = p_country, city = p_city
    WHERE id = v_pid;
  ELSE
    -- Legacy carriers on INSERT only: Contributor personal/true/player, Partner venue/false/host.
    INSERT INTO public.profiles (
      user_id, display_name, username, age, gender,
      profile_type, persona_type, intention, onboarding_intention,
      preferred_sport, primary_sport, interests,
      country, city, skill_level, onboard, is_player, is_active
    ) VALUES (
      p_user_id, v_name, v_username, p_age, v_gender,
      CASE v_persona WHEN 'contributor' THEN 'personal' ELSE 'venue' END,
      v_persona,
      CASE v_persona WHEN 'contributor' THEN 'player' ELSE 'host' END,
      p_onboarding_intention,
      p_preferred_sport, p_preferred_sport, v_follow,
      p_country, p_city, 1, false, (v_persona = 'contributor'), true
    ) RETURNING id INTO v_pid;
  END IF;

  -- 5. Required record set. Plain IFs, no ELSIF between Player and Organizer. Existing rows are kept
  --    (DO NOTHING): earned skill/xp is never reset.
  IF v_persona = 'contributor' THEN
    INSERT INTO public.player (profile_id) VALUES (v_pid)
      ON CONFLICT (profile_id) DO NOTHING;
    INSERT INTO public.organiser (profile_id, sport) VALUES (v_pid, v_sport_key)
      ON CONFLICT (profile_id, sport) DO NOTHING;
    INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
      VALUES (v_pid, v_sport_key, p_preferred_sport, 1)
      ON CONFLICT (profile_id, sport) DO NOTHING;
    -- Following-only sports get no sport_profiles row.
  ELSE
    -- Partner: existing Host defaults (pending status, unverified, no venues/wallet/payout/commission).
    INSERT INTO public.host (profile_id) VALUES (v_pid)
      ON CONFLICT (profile_id) DO NOTHING;
  END IF;

  -- 6. Existing default tier only; nothing elevated.
  SELECT t.code INTO v_tier_code FROM public.tiers t WHERE t.is_default = true LIMIT 1;
  IF v_tier_code IS NOT NULL THEN
    INSERT INTO public.profile_tiers (profile_id, tier_code, is_active)
    SELECT v_pid, v_tier_code, true
    WHERE NOT EXISTS (SELECT 1 FROM public.profile_tiers pt WHERE pt.profile_id = v_pid AND pt.tier_code = v_tier_code);
  END IF;

  -- 7. Invariants, then onboard = true LAST. Any RAISE above or here rolls the whole call back.
  IF v_persona = 'contributor' THEN
    IF NOT EXISTS (SELECT 1 FROM public.player WHERE profile_id = v_pid)
       OR NOT EXISTS (SELECT 1 FROM public.organiser WHERE profile_id = v_pid AND sport = v_sport_key)
       OR NOT EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = v_pid AND sport_id = p_preferred_sport) THEN
      RAISE EXCEPTION 'onboarding_incomplete';
    END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.host WHERE profile_id = v_pid) THEN
    RAISE EXCEPTION 'onboarding_incomplete';
  END IF;

  UPDATE public.profiles SET onboard = true WHERE id = v_pid;

  RETURN v_pid;
END;
$function$;

ALTER FUNCTION public.rpc_onboard_unified_profile(uuid, text, text, integer, text, text, uuid, uuid[], text, text) OWNER TO postgres;

-- Grants: signed-in clients and service_role only. No PUBLIC, no anon (auth.uid() is required anyway).
REVOKE ALL ON FUNCTION public.rpc_onboard_unified_profile(uuid, text, text, integer, text, text, uuid, uuid[], text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_onboard_unified_profile(uuid, text, text, integer, text, text, uuid, uuid[], text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.rpc_onboard_unified_profile(uuid, text, text, integer, text, text, uuid, uuid[], text, text)
  IS 'KAN-645: atomic unified onboarding. Persona derived from p_onboarding_intention (connect_play/play_organise/organise -> contributor, host_games -> partner). One profile, full record set, onboard=true last.';
