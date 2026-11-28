-- KAN-1059: sports model (Follow vs Add to my sports). Plan: polymorphic-jumping-mochi (CEO-approved 2026-11-28).
-- Rollback: supabase/rollbacks/20261128120000_kan1059_sports_model_rollback.sql
-- Add-only: no column is dropped. preferred_sport stays (backfilled = primary_sport); primary_sport semantics untouched.
-- Replaced bodies are authored from pg_get_functiondef on the live catalogue (2026-11-28).
-- Not changed: register_dubai_gym_seed_profile (fresh INSERT, skill_level_set_at defaults to NULL already),
-- get_home_feed / active_stream, every n8n seeding RPC.
-- trgfn_contributor_sports_check is NOT widened to other personas: after the backfill 18 onboarded non-socialiser
-- profiles still have no card for their primary (8 player, 10 organiser), so it stays contributor-only.
BEGIN;

-- 1. Columns -----------------------------------------------------------------------------------------------
ALTER TABLE public.sport_profiles ADD COLUMN IF NOT EXISTS hidden_at timestamptz NULL;
ALTER TABLE public.sport_profiles ADD COLUMN IF NOT EXISTS skill_level_set_at timestamptz NULL;
ALTER TABLE public.sports ADD COLUMN IF NOT EXISTS player_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.sport_profiles.hidden_at IS 'KAN-1059: removed from my sports (card kept with its stats). NULL = active.';
COMMENT ON COLUMN public.sport_profiles.skill_level_set_at IS 'KAN-1059: when the user chose skill_level. NULL = never asked (app asks at first join).';
COMMENT ON COLUMN public.sports.player_count IS 'KAN-1059: active (non-hidden) sport_profiles of active profiles. recompute_sport_user_counts().';

UPDATE public.sport_profiles SET skill_level_set_at = created_at
 WHERE skill_level <> 1 AND skill_level_set_at IS NULL;

-- 2. Owner check shared by the new RPCs (not callable by clients) ------------------------------------------
-- Returns 'player' (owned player, or owned active contributor with a player row: cards) or 'organiser'
-- (owned organiser: organiser rows). Same rule as rpc_create_sport_profile, plus the organiser path.
CREATE OR REPLACE FUNCTION public._kan1059_sport_owner_kind(p_profile_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles
              WHERE id = p_profile_id AND persona_type = 'player' AND user_id = auth.uid())
     OR EXISTS (SELECT 1 FROM public.profiles pc
                 WHERE pc.id = p_profile_id AND pc.persona_type = 'contributor' AND pc.is_active = true
                   AND pc.user_id = public.effective_actor_uid()
                   AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pc.id)) THEN
    RETURN 'player';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
              WHERE id = p_profile_id AND persona_type = 'organiser' AND user_id = auth.uid()) THEN
    RETURN 'organiser';
  END IF;
  RAISE EXCEPTION USING errcode = '42501', message = 'sport_profile requires owned player profile';
END;
$function$;
REVOKE ALL ON FUNCTION public._kan1059_sport_owner_kind(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._kan1059_sport_owner_kind(uuid) TO service_role;

-- 3. RPCs -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_follow_sport(p_profile_id uuid, p_sport_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public._kan1059_sport_owner_kind(p_profile_id);
  IF NOT EXISTS (SELECT 1 FROM public.sports s WHERE s.id = p_sport_id AND s.is_active) THEN
    RETURN 'invalid_sport';
  END IF;
  UPDATE public.profiles SET interests = coalesce(interests, '{}'::uuid[]) || p_sport_id
   WHERE id = p_profile_id AND NOT (coalesce(interests, '{}'::uuid[]) @> ARRAY[p_sport_id]);
  IF NOT FOUND THEN
    RETURN 'unchanged';
  END IF;
  RETURN 'followed';
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_unfollow_sport(p_profile_id uuid, p_sport_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_kind text := public._kan1059_sport_owner_kind(p_profile_id);
  p public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO p FROM public.profiles WHERE id = p_profile_id FOR UPDATE;
  IF NOT (coalesce(p.interests, '{}'::uuid[]) @> ARRAY[p_sport_id]) THEN
    RETURN 'unchanged';
  END IF;
  IF p.primary_sport = p_sport_id THEN
    RETURN 'blocked_primary';
  END IF;
  IF (v_kind = 'player' AND EXISTS (SELECT 1 FROM public.sport_profiles sp
                                     WHERE sp.profile_id = p_profile_id AND sp.sport_id = p_sport_id
                                       AND sp.hidden_at IS NULL))
     OR (v_kind = 'organiser' AND EXISTS (SELECT 1 FROM public.organiser o JOIN public.sports s ON s.sport_key = o.sport
                                           WHERE o.profile_id = p_profile_id AND s.id = p_sport_id
                                             AND o.is_active IS NOT FALSE)) THEN
    RETURN 'blocked_in_my_sports';
  END IF;
  IF cardinality(array_remove(p.interests, p_sport_id)) = 0 THEN
    RETURN 'blocked_last';
  END IF;
  UPDATE public.profiles SET interests = array_remove(interests, p_sport_id) WHERE id = p_profile_id;
  RETURN 'unfollowed';
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_add_my_sport(p_profile_id uuid, p_sport_id uuid, p_skill_level integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_kind text := public._kan1059_sport_owner_kind(p_profile_id);
  v_key text;
  v_hidden timestamptz;
  v_found boolean;
  v_outcome text;
BEGIN
  SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id AND s.is_active;
  IF v_key IS NULL THEN
    RETURN 'invalid_sport';
  END IF;
  IF p_skill_level IS NOT NULL AND (p_skill_level < 1 OR p_skill_level > 10) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_skill_level';
  END IF;

  IF v_kind = 'organiser' THEN
    -- Same row manage_sports_sheet.dart upserts today.
    SELECT (o.is_active IS FALSE) INTO v_found FROM public.organiser o
     WHERE o.profile_id = p_profile_id AND o.sport = v_key;
    IF v_found IS NULL THEN
      INSERT INTO public.organiser (profile_id, sport, organiser_level, commission_type, commission_value, is_verified, is_active)
      VALUES (p_profile_id, v_key, 1, 'percent', 0.0, false, true);
      v_outcome := 'added';
    ELSIF v_found THEN
      UPDATE public.organiser SET is_active = true WHERE profile_id = p_profile_id AND sport = v_key;
      v_outcome := 'restored';
    ELSE
      v_outcome := 'unchanged';
    END IF;
  ELSE
    SELECT sp.hidden_at, true INTO v_hidden, v_found FROM public.sport_profiles sp
     WHERE sp.profile_id = p_profile_id AND sp.sport_id = p_sport_id
     FOR UPDATE;
    IF v_found IS NULL THEN
      INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level, skill_level_set_at)
      VALUES (p_profile_id, v_key, p_sport_id, coalesce(p_skill_level, 1),
              CASE WHEN p_skill_level IS NOT NULL THEN now() END);
      v_outcome := 'added';
    ELSE
      IF v_hidden IS NOT NULL THEN
        UPDATE public.sport_profiles SET hidden_at = NULL
         WHERE profile_id = p_profile_id AND sport_id = p_sport_id;
        v_outcome := 'restored';
      ELSE
        v_outcome := 'unchanged';
      END IF;
      IF p_skill_level IS NOT NULL THEN
        UPDATE public.sport_profiles SET skill_level = p_skill_level, skill_level_set_at = now()
         WHERE profile_id = p_profile_id AND sport_id = p_sport_id;
      END IF;
    END IF;
  END IF;

  UPDATE public.profiles SET interests = coalesce(interests, '{}'::uuid[]) || p_sport_id
   WHERE id = p_profile_id AND NOT (coalesce(interests, '{}'::uuid[]) @> ARRAY[p_sport_id]);
  RETURN v_outcome;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_remove_my_sport(p_profile_id uuid, p_sport_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_kind text := public._kan1059_sport_owner_kind(p_profile_id);
  v_primary uuid;
  v_key text;
BEGIN
  SELECT primary_sport INTO v_primary FROM public.profiles WHERE id = p_profile_id FOR UPDATE;
  IF v_kind = 'organiser' THEN
    SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id;
    IF NOT EXISTS (SELECT 1 FROM public.organiser o WHERE o.profile_id = p_profile_id AND o.sport = v_key
                     AND o.is_active IS NOT FALSE) THEN
      RETURN 'unchanged';
    END IF;
    IF v_primary = p_sport_id THEN
      RETURN 'blocked_primary';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.organiser o WHERE o.profile_id = p_profile_id AND o.sport <> v_key
                     AND o.is_active IS NOT FALSE) THEN
      RETURN 'blocked_last';
    END IF;
    UPDATE public.organiser SET is_active = false WHERE profile_id = p_profile_id AND sport = v_key;
    RETURN 'removed';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = p_profile_id
                   AND sp.sport_id = p_sport_id AND sp.hidden_at IS NULL) THEN
    RETURN 'unchanged';
  END IF;
  IF v_primary = p_sport_id THEN
    RETURN 'blocked_primary';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sport_profiles sp WHERE sp.profile_id = p_profile_id
                   AND sp.sport_id <> p_sport_id AND sp.hidden_at IS NULL) THEN
    RETURN 'blocked_last';
  END IF;
  UPDATE public.sport_profiles SET hidden_at = now()
   WHERE profile_id = p_profile_id AND sport_id = p_sport_id;
  RETURN 'removed';
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_set_sport_level(p_profile_id uuid, p_sport_id uuid, p_skill_level integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_kind text := public._kan1059_sport_owner_kind(p_profile_id);
BEGIN
  IF v_kind <> 'player' THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'sport_profile requires owned player profile';
  END IF;
  IF p_skill_level IS NULL OR p_skill_level < 1 OR p_skill_level > 10 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_skill_level';
  END IF;
  UPDATE public.sport_profiles SET skill_level = p_skill_level, skill_level_set_at = now()
   WHERE profile_id = p_profile_id AND sport_id = p_sport_id AND hidden_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'sport_not_in_my_sports';
  END IF;
  RETURN 'set';
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_follow_sport(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_unfollow_sport(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_add_my_sport(uuid,uuid,integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_remove_my_sport(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_set_sport_level(uuid,uuid,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_follow_sport(uuid,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_unfollow_sport(uuid,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_add_my_sport(uuid,uuid,integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_remove_my_sport(uuid,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_set_sport_level(uuid,uuid,integer) TO authenticated, service_role;

-- 4. Hidden-aware existing code ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_sport_user_counts()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.sports
  SET primary_user_count = 0, interested_user_count = 0, player_count = 0
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

  -- KAN-1059: interested = followers (profiles.interests)
  UPDATE public.sports s
  SET interested_user_count = sub.cnt
  FROM (
    SELECT i.sport_id, COUNT(DISTINCT p.id) AS cnt
    FROM public.profiles p
    CROSS JOIN LATERAL unnest(p.interests) AS i(sport_id)
    WHERE p.is_active = true
    GROUP BY i.sport_id
  ) sub
  WHERE s.id = sub.sport_id;

  -- KAN-1059: players = active (non-hidden) cards
  UPDATE public.sports s
  SET player_count = sub.cnt
  FROM (
    SELECT sp.sport_id, COUNT(DISTINCT sp.profile_id) AS cnt
    FROM public.sport_profiles sp
    JOIN public.profiles p ON p.id = sp.profile_id
    WHERE p.is_active = true AND sp.hidden_at IS NULL
    GROUP BY sp.sport_id
  ) sub
  WHERE s.id = sub.sport_id;
END;
$function$;

-- rpc_sport_overview: new OUT column `players` (needs DROP + CREATE; ACL re-applied exactly).
DROP FUNCTION public.rpc_sport_overview(uuid, text);
CREATE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL::text)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint, posts bigint, news bigint, mutual_followers jsonb, players bigint)
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
                       LIMIT 3) x), '[]'::jsonb),

    -- KAN-1059: players = active (non-hidden) cards
    (SELECT count(DISTINCT sp.profile_id) FROM public.sport_profiles sp
       JOIN public.profiles p ON p.id = sp.profile_id
      WHERE sp.sport_id = p_sport_id AND sp.hidden_at IS NULL
        AND NOT public.is_blocked(v_uid, p.user_id));
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_sport_overview(uuid, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trgfn_contributor_sports_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pid uuid;
  p public.profiles%ROWTYPE;
BEGIN
  -- KAN-1059: read through jsonb so the one body type-checks for both tables (plpgsql_check clean).
  IF TG_TABLE_NAME = 'profiles' THEN
    v_pid := (to_jsonb(NEW) ->> 'id')::uuid;
  ELSIF TG_OP = 'DELETE' THEN
    v_pid := (to_jsonb(OLD) ->> 'profile_id')::uuid;
  ELSE
    v_pid := (to_jsonb(NEW) ->> 'profile_id')::uuid;
  END IF;
  SELECT * INTO p FROM public.profiles WHERE id = v_pid;
  IF NOT FOUND OR p.persona_type <> 'contributor' OR p.onboard IS NOT TRUE THEN
    RETURN NULL;                                           -- legacy / partner / incomplete: no rule
  END IF;
  -- KAN-1059: hidden cards (removed from my sports) are ignored.
  IF p.primary_sport IS NULL
     OR p.interests IS NULL OR NOT (p.interests @> ARRAY[p.primary_sport])
     OR NOT EXISTS (SELECT 1 FROM public.sport_profiles sp
                    WHERE sp.profile_id = p.id AND sp.sport_id = p.primary_sport AND sp.hidden_at IS NULL)
     OR EXISTS (SELECT 1 FROM public.sport_profiles sp
                WHERE sp.profile_id = p.id AND sp.hidden_at IS NULL AND NOT (p.interests @> ARRAY[sp.sport_id])) THEN
    RAISE EXCEPTION 'contributor_sports_incomplete';
  END IF;
  RETURN NULL;
END $function$;

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
    and spm.hidden_at is null
  limit 1;

  return lvl;
end;
$function$;

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
    and sp.hidden_at is null
  limit 1;

  return lvl;
end;
$function$;

-- v_sport_profiles_with_user: active cards only; auth.users.email dropped (rpc_potential_vibes never reads it).
DROP VIEW public.v_sport_profiles_with_user;
CREATE VIEW public.v_sport_profiles_with_user AS
 SELECT sp.profile_id,
    COALESCE(s.sport_key, sp.sport) AS sport_key,
    sp.skill_level,
    sp.attributes,
    sp.overall_level,
    sp.xp_total,
    sp.xp_level,
    sp.xp_next_level,
    sp.matches_played,
    sp.primary_position,
    sp.secondary_positions,
    sp.playstyle,
    sp.form_score,
    sp.form_trend,
    sp.last_5_matches,
    sp.attendance_rate,
    sp.cancellation_rate,
    sp.punctuality_score,
    sp.teamwork_score,
    sp.rating_count,
    sp.rating_total,
    sp.reliability_score,
    sp.verification_status,
    sp.verified_by,
    sp.verification_media,
    sp.verification_note,
    sp.verification_date,
    sp.performance_highlights,
    sp.ml_last_vector,
    sp.ml_avg_vector,
    sp.ml_vector_count,
    sp.heatmap_json,
    sp.movement_intensity,
    sp.stamina_score,
    sp.preferred_venues,
    sp.performance_by_venue,
    sp.tier_id,
    p.user_id,
    p.profile_type,
    p.username AS profile_username,
    p.display_name AS profile_display_name
   FROM sport_profiles sp
     JOIN profiles p ON sp.profile_id = p.id
     LEFT JOIN sports s ON s.id = sp.sport_id
  WHERE sp.hidden_at IS NULL;
REVOKE ALL ON public.v_sport_profiles_with_user FROM PUBLIC, anon, authenticated, service_role;
GRANT REFERENCES, TRIGGER ON public.v_sport_profiles_with_user TO anon, authenticated;
GRANT ALL ON public.v_sport_profiles_with_user TO service_role;

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
  -- KAN-1059: an existing (possibly hidden) card is un-hidden; a level the user chose is never overwritten.
  INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level, skill_level_set_at)
  VALUES (p_profile_id, p_sport_key, p_sport_id, p_skill_level,
          CASE WHEN p_skill_level IS DISTINCT FROM 1 THEN now() END)
  ON CONFLICT (profile_id, sport) DO UPDATE SET
    skill_level = CASE WHEN sport_profiles.skill_level_set_at IS NOT NULL
                       THEN sport_profiles.skill_level ELSE EXCLUDED.skill_level END,
    skill_level_set_at = coalesce(sport_profiles.skill_level_set_at, EXCLUDED.skill_level_set_at),
    hidden_at = NULL;
END;
$function$;

-- Onboarding: primary card stays active with skill_level_set_at NULL (the app asks the level at first join).
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
    ON CONFLICT (profile_id, sport) DO UPDATE SET skill_level = EXCLUDED.skill_level,
      skill_level_set_at = NULL, hidden_at = NULL;   -- KAN-1059: primary card active, level asked at first join
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
$function$;

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
      ON CONFLICT (profile_id, sport) DO UPDATE SET hidden_at = NULL;   -- KAN-1059: primary card active, stats kept
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
       OR NOT EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = v_pid AND sport_id = p_preferred_sport AND hidden_at IS NULL) THEN
      RAISE EXCEPTION 'onboarding_incomplete';
    END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.host WHERE profile_id = v_pid) THEN
    RAISE EXCEPTION 'onboarding_incomplete';
  END IF;

  UPDATE public.profiles SET onboard = true WHERE id = v_pid;

  RETURN v_pid;
END;
$function$;

-- 5. Backfill legacy data (backup first, for the rollback) --------------------------------------------------
CREATE TABLE IF NOT EXISTS public._kan1059_backup_profiles (
  id uuid PRIMARY KEY,
  interests uuid[],
  preferred_sport uuid,
  backed_up_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public._kan1059_backup_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._kan1059_backup_profiles FROM PUBLIC, anon, authenticated;

CREATE TEMP TABLE _kan1059_target ON COMMIT DROP AS
SELECT p.id,
       (SELECT array_agg(x ORDER BY ord) FROM (
          SELECT DISTINCT ON (x) x, ord FROM unnest(
            coalesce(p.interests, '{}'::uuid[])
            || coalesce((SELECT array_agg(sp.sport_id ORDER BY sp.created_at) FROM public.sport_profiles sp
                          WHERE sp.profile_id = p.id AND sp.hidden_at IS NULL AND sp.sport_id IS NOT NULL), '{}'::uuid[])
            || CASE WHEN p.primary_sport IS NOT NULL THEN ARRAY[p.primary_sport] ELSE '{}'::uuid[] END
          ) WITH ORDINALITY AS t(x, ord) ORDER BY x, ord) d) AS new_interests
FROM public.profiles p;

INSERT INTO public._kan1059_backup_profiles (id, interests, preferred_sport)
SELECT p.id, p.interests, p.preferred_sport
FROM public.profiles p JOIN _kan1059_target t ON t.id = p.id
WHERE p.interests IS DISTINCT FROM t.new_interests
   OR (p.primary_sport IS NOT NULL AND p.preferred_sport IS DISTINCT FROM p.primary_sport)
ON CONFLICT (id) DO NOTHING;

-- last_seen must not move for a data backfill.
SET CONSTRAINTS ALL IMMEDIATE;   -- flush pending deferred checks so the table can be altered
ALTER TABLE public.profiles DISABLE TRIGGER update_profiles_last_seen;
UPDATE public.profiles p
SET interests = t.new_interests,
    preferred_sport = coalesce(p.primary_sport, p.preferred_sport)
FROM _kan1059_target t
WHERE t.id = p.id AND p.id IN (SELECT id FROM public._kan1059_backup_profiles);
ALTER TABLE public.profiles ENABLE TRIGGER update_profiles_last_seen;
SET CONSTRAINTS ALL DEFERRED;

SELECT public.recompute_sport_user_counts();

-- 6. Grants: cards are hidden, never deleted by clients ----------------------------------------------------
REVOKE DELETE ON public.sport_profiles FROM authenticated, anon;
DROP POLICY IF EXISTS sport_profiles_delete_own ON public.sport_profiles;

COMMIT;
