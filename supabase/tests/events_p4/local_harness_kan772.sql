-- KAN-772 (KAN-718 D04) local harness: the four B15 open-read functions that the KAN-711..714 local chain does not
-- carry, re-created VERBATIM from their latest repository definition (none is redefined or dropped after the
-- baseline; checked with grep over supabase/migrations/), with the baseline's owner and grants, so that
-- 20261104110100_kan718_d04_last_shared_field_reads.sql has the same pre-image here as on a full chain.
--
-- LOCAL DISPOSABLE DATABASE ONLY (k772* names). Never run this against a hosted project.
-- It also adds profiles.primary_sport / profiles.is_original (baseline columns, absent from the harness
-- profiles table) so get_open_games_for_seeding can run. Nothing here reads or writes events.
\set ON_ERROR_STOP 1
DO $g$ BEGIN
  IF current_database() NOT LIKE 'k772%' THEN
    RAISE EXCEPTION 'KAN-772 harness: refusing database %: local disposable k772* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-772 harness: this looks like a Supabase database; local or disposable database only';
  END IF;
END $g$;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS primary_sport uuid;              -- baseline profiles column
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_original boolean NOT NULL DEFAULT true;  -- baseline profiles column

-- baseline 20260829080500_baseline_schema.sql:1493-1510
CREATE OR REPLACE FUNCTION "public"."_recent_activity_score"("u" "uuid", "p_recent_days" integer) RETURNS numeric
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  with r as (
    select 1
    from public.game_roster gr
    join public.games g on g.id = gr.game_id
    where gr.user_id = u
      and gr.status = 'active'
      and g.start_at >= now() - (p_recent_days || ' days')::interval
    limit 1
  )
  select case when exists(select 1 from r) then 1.0 else 0.0 end
$$;


ALTER FUNCTION "public"."_recent_activity_score"("u" "uuid", "p_recent_days" integer) OWNER TO "postgres";

-- baseline 20260829080500_baseline_schema.sql:6812-6824
CREATE OR REPLACE FUNCTION "public"."game_is_joinable"("p_game" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select not is_cancelled and start_at > now()
  from public.games where id = p_game
$$;


ALTER FUNCTION "public"."game_is_joinable"("p_game" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."game_is_joinable"("p_game" "uuid") IS 'True if not cancelled and in the future.';

-- baseline 20260829080500_baseline_schema.sql:7164-7201
CREATE OR REPLACE FUNCTION "public"."get_games_needing_players"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT
      g.id                                      AS game_id,
      g.sport_id,
      g.area_id,
      g.capacity,
      s.sport_key,
      a.city,
      COUNT(gr.profile_id)                      AS current_players,
      g.capacity - COUNT(gr.profile_id)         AS spots_remaining,
      -- get all profile_ids already in this game as array
      ARRAY_AGG(gr.profile_id) FILTER (WHERE gr.profile_id IS NOT NULL) AS existing_profiles
    FROM public.games g
    JOIN public.sports s       ON s.id = g.sport_id
    JOIN public.areas a        ON a.id = g.area_id
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id AND gr.status = 'active'
    WHERE g.is_cancelled = false
      AND g.start_at > now()
    GROUP BY g.id, g.sport_id, g.area_id, g.capacity, s.sport_key, a.city
    HAVING g.capacity - COUNT(gr.profile_id) > 0
    ORDER BY spots_remaining DESC
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_games_needing_players"() OWNER TO "postgres";

-- baseline 20260829080500_baseline_schema.sql:7617-7662
CREATE OR REPLACE FUNCTION "public"."get_open_games_for_seeding"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT DISTINCT ON (g.id)
      g.id                    AS game_id,
      g.sport_id,
      g.area_id,
      g.capacity,
      g.start_at,
      s.sport_key,
      a.city,
      p.id                    AS profile_id,
      p.user_id,
      p.display_name
    FROM public.games g
    JOIN public.sports s       ON s.id = g.sport_id
    JOIN public.areas a        ON a.id = g.area_id
    JOIN public.profiles p     ON p.city = a.city
                               AND p.primary_sport = g.sport_id
                               AND p.is_original = false
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id
                               AND gr.profile_id = p.id
    WHERE g.is_cancelled = false
      AND g.start_at > now()
      AND gr.profile_id IS NULL
      AND (
        SELECT COUNT(*) FROM public.game_roster
        WHERE game_id = g.id AND status = 'active'
      ) < g.capacity
    ORDER BY g.id, random()
    LIMIT 10
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_open_games_for_seeding"() OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."_recent_activity_score"("u" "uuid", "p_recent_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_recent_activity_score"("u" "uuid", "p_recent_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_recent_activity_score"("u" "uuid", "p_recent_days" integer) TO "service_role";
GRANT ALL ON FUNCTION "public"."game_is_joinable"("p_game" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."game_is_joinable"("p_game" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."game_is_joinable"("p_game" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."get_games_needing_players"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_games_needing_players"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_games_needing_players"() TO "service_role";
GRANT ALL ON FUNCTION "public"."get_open_games_for_seeding"() TO "service_role";
