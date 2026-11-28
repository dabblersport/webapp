-- Rollback for KAN-1059 (20261128120000_kan1059_sports_model.sql).
-- Every body below is pg_get_functiondef output captured 2026-11-28 before the migration.
-- CREATE OR REPLACE keeps each function's ACL; rpc_sport_overview and the view are dropped/recreated with their captured ACL.
-- register_dubai_gym_seed_profile was not changed by the migration, so it is not restored here.
BEGIN;
SET LOCAL check_function_bodies = off;

DROP FUNCTION IF EXISTS public.rpc_follow_sport(uuid,uuid);
DROP FUNCTION IF EXISTS public.rpc_unfollow_sport(uuid,uuid);
DROP FUNCTION IF EXISTS public.rpc_add_my_sport(uuid,uuid,integer);
DROP FUNCTION IF EXISTS public.rpc_remove_my_sport(uuid,uuid);
DROP FUNCTION IF EXISTS public.rpc_set_sport_level(uuid,uuid,integer);
DROP FUNCTION IF EXISTS public._kan1059_sport_owner_kind(uuid);

DROP FUNCTION IF EXISTS public.rpc_sport_overview(uuid, text);

-- _get_skill_level(uuid,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._get_skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select spm.skill_level
    into lvl
  from public.sport_profiles spm
  join public.profiles pr on pr.id = spm.profile_id
  where pr.user_id = $1
    and spm.sport = $2
  limit 1;

  return lvl;
end;
$function$
;

-- _skill_level(uuid,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select sp.skill_level
    into lvl
  from public.sport_profiles sp
  join public.profiles pr on pr.id = sp.profile_id
  where pr.user_id = $1
    and sp.sport = $2
  limit 1;

  return lvl;
end;
$function$
;

-- recompute_sport_user_counts()  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.recompute_sport_user_counts()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.sports
  SET primary_user_count = 0, interested_user_count = 0
  WHERE true;

  -- primary sport count — explicit uuid::text cast avoids btrim(uuid) error
  UPDATE public.sports s
  SET primary_user_count = sub.cnt
  FROM (
    SELECT
      lower(trim(primary_sport::text)) AS sport_key,
      COUNT(*) AS cnt
    FROM public.profiles
    WHERE primary_sport IS NOT NULL
      AND is_active = true
    GROUP BY lower(trim(primary_sport::text))
  ) sub
  WHERE s.sport_key = sub.sport_key;

  -- interested sport count — sport_id is uuid vs uuid, no citext involved
  UPDATE public.sports s
  SET interested_user_count = sub.cnt
  FROM (
    SELECT sp.sport_id, COUNT(DISTINCT sp.profile_id) AS cnt
    FROM public.sport_profiles sp
    JOIN public.profiles p ON p.id = sp.profile_id
    WHERE p.is_active = true
    GROUP BY sp.sport_id
  ) sub
  WHERE s.id = sub.sport_id;
END;
$function$
;

-- rpc_create_sport_profile(uuid,uuid,text,integer)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_create_sport_profile(p_profile_id uuid, p_sport_id uuid, p_sport_key text, p_skill_level integer DEFAULT 1)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_profile_id AND persona_type = 'player' AND user_id = auth.uid())
     AND NOT EXISTS (SELECT 1 FROM public.profiles pc
                     WHERE pc.id = p_profile_id AND pc.persona_type = 'contributor' AND pc.is_active = true
                       AND pc.user_id = public.effective_actor_uid()
                       AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pc.id)) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'sport_profile requires owned player profile';
  END IF;
  INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
  VALUES (p_profile_id, p_sport_key, p_sport_id, p_skill_level)
  ON CONFLICT (profile_id, sport) DO UPDATE SET skill_level = EXCLUDED.skill_level;
END;
$function$
;

-- rpc_onboard_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_onboard_profile(p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_persona_type text, p_preferred_sport uuid DEFAULT NULL::uuid, p_interests uuid[] DEFAULT NULL::uuid[], p_country text DEFAULT NULL::text, p_city text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_profile_id uuid;
  v_profile_type text;
  v_persona_type text;
  v_tier_code text;
  v_sport_key text;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: can only onboard your own profile';
  END IF;

  v_persona_type := CASE p_persona_type WHEN 'hoster' THEN 'host' ELSE p_persona_type END;

  IF v_persona_type NOT IN ('player', 'organiser', 'host', 'socialiser') THEN
    RAISE EXCEPTION 'Unrecognised persona_type: %', v_persona_type;
  END IF;

  v_profile_type := CASE v_persona_type
    WHEN 'player' THEN 'personal'
    WHEN 'organiser' THEN 'business'
    WHEN 'host' THEN 'venue'
    WHEN 'socialiser' THEN 'personal'
    ELSE 'personal'
  END;

  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles SET
      display_name = p_display_name,
      username = p_username,
      age = p_age,
      gender = lower(p_gender),
      persona_type = v_persona_type,
      preferred_sport = p_preferred_sport,
      primary_sport = p_preferred_sport,
      interests = p_interests,
      country = p_country,
      city = p_city,
      skill_level = 1
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
      p_country, p_city, 1, false, (v_persona_type = 'player'), true
    ) RETURNING id INTO v_profile_id;
  END IF;

  IF v_persona_type = 'player' THEN
    INSERT INTO public.player (profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;

  ELSIF v_persona_type = 'organiser' THEN
    IF p_preferred_sport IS NULL THEN
      RAISE EXCEPTION 'organiser persona requires p_preferred_sport (organiser.sport is NOT NULL)';
    END IF;
    SELECT sport_key INTO v_sport_key FROM public.sports WHERE id = p_preferred_sport;
    IF v_sport_key IS NULL THEN
      RAISE EXCEPTION 'Sport % not found', p_preferred_sport;
    END IF;
    INSERT INTO public.organiser (profile_id, sport)
    VALUES (v_profile_id, v_sport_key)
    ON CONFLICT (profile_id, sport) DO NOTHING;

  ELSIF v_persona_type = 'host' THEN
    INSERT INTO public.host (profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;

  IF v_persona_type = 'player' AND p_preferred_sport IS NOT NULL THEN
    SELECT sport_key INTO v_sport_key FROM public.sports WHERE id = p_preferred_sport;
    IF v_sport_key IS NULL THEN
      RAISE EXCEPTION 'Sport % not found', p_preferred_sport;
    END IF;
    INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
    VALUES (v_profile_id, v_sport_key, p_preferred_sport, 1)
    ON CONFLICT (profile_id, sport) DO UPDATE SET skill_level = EXCLUDED.skill_level;
  END IF;

  SELECT code INTO v_tier_code FROM public.tiers WHERE is_default = true LIMIT 1;
  IF v_tier_code IS NOT NULL THEN
    INSERT INTO public.profile_tiers (profile_id, tier_code, is_active)
    VALUES (v_profile_id, v_tier_code, true)
    ON CONFLICT DO NOTHING;
  END IF;

  UPDATE public.profiles SET onboard = true WHERE id = v_profile_id;

  RETURN v_profile_id;
END;
$function$
;

-- rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_onboard_unified_profile(p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_onboarding_intention text, p_preferred_sport uuid DEFAULT NULL::uuid, p_interests uuid[] DEFAULT NULL::uuid[], p_country text DEFAULT NULL::text, p_city text DEFAULT NULL::text)
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
$function$
;

-- rpc_sport_overview(uuid,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL::text)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint, posts bigint, news bigint, mutual_followers jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_window interval := interval '7 days';
  v_key    text;
  v_city   text := p_city_code;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'permission denied for function rpc_sport_overview' USING ERRCODE = '42501';
  END IF;

  SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id;

  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT p.id) FROM public.profiles p
      WHERE p.interests @> ARRAY[p_sport_id]
        AND NOT public.is_blocked(v_uid, p.user_id)),

    (SELECT count(DISTINCT g.id) FROM public.games g
       JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       LEFT JOIN public.areas a ON a.id = e.area_id
      WHERE e.sport_id = p_sport_id AND e.is_cancelled = false
        AND e.listing_visibility = 'public'
        AND e.start_at >= now() AND e.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, e.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT m.id) FROM public.meetups m
       JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
       LEFT JOIN public.areas a ON a.id = e.area_id
      WHERE e.sport_id = p_sport_id AND e.is_cancelled = false
        AND e.listing_visibility = 'public'
        AND e.start_at >= now() AND e.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, e.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT v.id) FROM public.venues v
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE v.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)
        AND ( (v_key IS NOT NULL AND v.sports @> ARRAY[v_key])
              OR EXISTS (SELECT 1 FROM public.venue_spaces vs
                          WHERE vs.venue_id = v.id AND vs.sport_id = p_sport_id AND vs.is_active = true) )),

    (SELECT count(DISTINCT vs.id) FROM public.venue_spaces vs
       JOIN public.venues v ON v.id = vs.venue_id AND v.is_active = true
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE vs.sport_id = p_sport_id AND vs.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT po.id) FROM public.posts po
      WHERE po.sport_id = p_sport_id AND po.visibility = 'public'
        AND po.is_deleted = false AND po.is_hidden_admin = false
        AND coalesce(po.is_active, true) = true
        AND (po.expires_at IS NULL OR po.expires_at > now())
        AND NOT public.is_blocked(v_uid, po.author_user_id)),

    (SELECT count(DISTINCT n.id) FROM public.news n
       LEFT JOIN public.areas a ON a.id = n.area_id
      WHERE n.sport_id = p_sport_id AND n.status = 'published'
        AND n.published_at <= now() AND (n.expires_at IS NULL OR n.expires_at > now())
        AND (v_city IS NULL OR a.city_code = v_city)),

    coalesce((SELECT jsonb_agg(jsonb_build_object('display_name', x.display_name,
                                                  'avatar_url', x.avatar_url,
                                                  'username', x.username::text) ORDER BY x.username)
                FROM (SELECT DISTINCT ON (p.id) p.id, p.display_name, p.avatar_url, p.username
                        FROM public.profile_follows f
                        JOIN public.profiles me ON me.id = f.follower_profile_id AND me.user_id = v_uid
                        JOIN public.profiles p  ON p.id = f.following_profile_id
                       WHERE p.interests @> ARRAY[p_sport_id]
                         AND p.user_id <> v_uid
                         AND NOT public.is_blocked(v_uid, p.user_id)
                       ORDER BY p.id
                       LIMIT 3) x), '[]'::jsonb);
END;
$function$
;

REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_sport_overview(uuid, text) TO authenticated, service_role;

-- trgfn_contributor_sports_check()  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.trgfn_contributor_sports_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pid uuid;
  p public.profiles%ROWTYPE;
BEGIN
  IF TG_TABLE_NAME = 'profiles' THEN
    v_pid := NEW.id;
  ELSIF TG_OP = 'DELETE' THEN
    v_pid := OLD.profile_id;
  ELSE
    v_pid := NEW.profile_id;
  END IF;
  SELECT * INTO p FROM public.profiles WHERE id = v_pid;
  IF NOT FOUND OR p.persona_type <> 'contributor' OR p.onboard IS NOT TRUE THEN
    RETURN NULL;                                           -- legacy / partner / incomplete: no rule
  END IF;
  IF p.primary_sport IS NULL
     OR p.interests IS NULL OR NOT (p.interests @> ARRAY[p.primary_sport])
     OR NOT EXISTS (SELECT 1 FROM public.sport_profiles sp
                    WHERE sp.profile_id = p.id AND sp.sport_id = p.primary_sport)
     OR EXISTS (SELECT 1 FROM public.sport_profiles sp
                WHERE sp.profile_id = p.id AND NOT (p.interests @> ARRAY[sp.sport_id])) THEN
    RAISE EXCEPTION 'contributor_sports_incomplete';
  END IF;
  RETURN NULL;
END $function$
;


-- v_sport_profiles_with_user, as captured (relacl {postgres=arwdDxtm,anon=xt,authenticated=xt,service_role=arwdDxtm})
DROP VIEW IF EXISTS public.v_sport_profiles_with_user;
CREATE VIEW public.v_sport_profiles_with_user AS
 SELECT sp.profile_id, COALESCE(s.sport_key, sp.sport) AS sport_key, sp.skill_level, sp.attributes, sp.overall_level,
    sp.xp_total, sp.xp_level, sp.xp_next_level, sp.matches_played, sp.primary_position, sp.secondary_positions,
    sp.playstyle, sp.form_score, sp.form_trend, sp.last_5_matches, sp.attendance_rate, sp.cancellation_rate,
    sp.punctuality_score, sp.teamwork_score, sp.rating_count, sp.rating_total, sp.reliability_score,
    sp.verification_status, sp.verified_by, sp.verification_media, sp.verification_note, sp.verification_date,
    sp.performance_highlights, sp.ml_last_vector, sp.ml_avg_vector, sp.ml_vector_count, sp.heatmap_json,
    sp.movement_intensity, sp.stamina_score, sp.preferred_venues, sp.performance_by_venue, sp.tier_id,
    p.user_id, p.profile_type, p.username AS profile_username, p.display_name AS profile_display_name,
    u.email AS user_email
   FROM sport_profiles sp
     JOIN profiles p ON sp.profile_id = p.id
     JOIN auth.users u ON p.user_id = u.id
     LEFT JOIN sports s ON s.id = sp.sport_id;
REVOKE ALL ON public.v_sport_profiles_with_user FROM PUBLIC, anon, authenticated, service_role;
GRANT REFERENCES, TRIGGER ON public.v_sport_profiles_with_user TO anon, authenticated;
GRANT ALL ON public.v_sport_profiles_with_user TO service_role;

-- Data: interests / preferred_sport from the backup table.
SET CONSTRAINTS ALL IMMEDIATE;   -- flush pending deferred checks so the table can be altered
ALTER TABLE public.profiles DISABLE TRIGGER update_profiles_last_seen;
UPDATE public.profiles p SET interests = b.interests, preferred_sport = b.preferred_sport
FROM public._kan1059_backup_profiles b WHERE b.id = p.id;
ALTER TABLE public.profiles ENABLE TRIGGER update_profiles_last_seen;
SET CONSTRAINTS ALL DEFERRED;

-- Grants / policy.
GRANT DELETE ON public.sport_profiles TO authenticated;
CREATE POLICY sport_profiles_delete_own ON public.sport_profiles FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = sport_profiles.profile_id AND p.user_id = auth.uid()));

-- Columns last (drop is acceptable in a rollback only). Hidden cards become visible again.
ALTER TABLE public.sport_profiles DROP COLUMN IF EXISTS hidden_at;
ALTER TABLE public.sport_profiles DROP COLUMN IF EXISTS skill_level_set_at;
ALTER TABLE public.sports DROP COLUMN IF EXISTS player_count;
SELECT public.recompute_sport_user_counts();
DROP TABLE IF EXISTS public._kan1059_backup_profiles;

COMMIT;
