-- KAN-724 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load position: AFTER KAN-718 (20261104110300) and BEFORE 20261104100500_kan714_b05_search_filter_indexes.sql
-- and supabase/tests/events_p2/kan714_b05_search_indexes.sql. Full ordered chain: the Build header of that test
-- file, or supabase/tests/events_p2/build_kan724.sh, which runs it end to end on a fresh cluster.
--
-- Why it exists: no earlier harness creates public.rpc_unified_search_sectioned, so without this file the
-- migration refuses at precondition P5 and the test dies at its first call (S1). It COMMITS:
--   1. the PRE-IMAGE rpc_unified_search_sectioned, VERBATIM from
--      supabase/migrations/20260829080500_baseline_schema.sql:16246-16337 (CREATE OR REPLACE + ALTER OWNER),
--      and its three grants VERBATIM from :36875-36877. Extracted by line range with sed, not retyped.
--      md5(prosrc) must equal the migration's P5 pin fe3382197842fa66564b2f62d9b754f5; asserted at the end.
--   2. empty stand-ins for the six sections not under test (hashtags, squads, comments tables; the columns the
--      pre-image reads on profiles, posts, venues, challenges). Same DDL as the test file's own stand-in block
--      (IF NOT EXISTS), committed here so the migration's Q3 before/after probe calls the function for real
--      instead of comparing 42P01 errors. Only the games and meetups sections are under test.
-- unaccent is already stubbed (identity) by supabase/tests/events_p1/local_harness_kan711.sql:69.

\set ON_ERROR_STOP 1
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-724 harness: this looks like a Supabase database; local throwaway cluster only';
  END IF;
  IF to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-724 harness: rpc_unified_search_sectioned already exists; load this once, on a fresh chain';
  END IF;
END $$;

BEGIN;

-- 1. Pre-image, verbatim: baseline_schema.sql:16246-16337 ------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."rpc_unified_search_sectioned"("p_query" "text", "p_sport_id" "uuid" DEFAULT NULL::"uuid", "p_lat" double precision DEFAULT NULL::double precision, "p_lng" double precision DEFAULT NULL::double precision, "p_radius_km" double precision DEFAULT NULL::double precision, "p_limit_per_section" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tsquery tsquery;
  v_q       text;
BEGIN
  IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN jsonb_build_object(
      'profiles','[]'::jsonb,'games','[]'::jsonb,'venues','[]'::jsonb,
      'squads','[]'::jsonb,'posts','[]'::jsonb,'meetups','[]'::jsonb,
      'challenges','[]'::jsonb,'hashtags','[]'::jsonb);
  END IF;
  v_tsquery := plainto_tsquery('simple', unaccent(p_query));
  v_q       := '%' || lower(trim(p_query)) || '%';
  RETURN jsonb_build_object(
    'hashtags', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT h.id, h.tag AS slug, h.display_tag, h.usage_count
        FROM public.hashtags h
        WHERE lower(h.tag) LIKE v_q
          AND (h.is_banned IS NULL OR h.is_banned = false)
          AND (h.is_searchable IS NULL OR h.is_searchable = true)
          AND (h.is_approved IS NULL OR h.is_approved = true)
        ORDER BY h.usage_count DESC NULLS LAST LIMIT p_limit_per_section) t),
    'posts', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'post' AS entity_type, p.id AS entity_id, left(p.body,80) AS title,
          p.author_display_name AS subtitle, NULL::text AS image_url,
          '/post/' || p.id AS route,
          ts_rank(p.search_tsv, v_tsquery)
          + (COALESCE(p.priority_score,0) * 0.01)
          + (SELECT COUNT(*) * 0.05 FROM public.comments pc
             WHERE pc.parent_activity_id = p.id
               AND pc.search_tsv @@ v_tsquery
               AND pc.is_deleted = FALSE AND pc.is_hidden_admin = FALSE) AS score
        FROM public.posts p
        WHERE p.search_tsv @@ v_tsquery AND p.visibility = 'public'
          AND p.is_deleted = FALSE AND p.is_hidden_admin = FALSE AND p.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'profiles', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'profile' AS entity_type, p.user_id AS entity_id, p.id AS profile_id,
          p.display_name AS title, p.username AS subtitle, p.avatar_url AS image_url,
          p.persona_type AS profile_type, p.is_active, '/profile/' || p.username AS route,
          ts_rank(p.search_tsv, v_tsquery) AS score
        FROM public.profiles p WHERE p.search_tsv @@ v_tsquery
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'games', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'game' AS entity_type, g.id AS entity_id, g.title AS title,
          NULL::text AS subtitle, NULL::text AS image_url, '/game/' || g.id AS route,
          ts_rank(g.search_tsv, v_tsquery) + CASE WHEN g.start_at > NOW() THEN 0.2 ELSE 0 END AS score
        FROM public.games g
        WHERE g.search_tsv @@ v_tsquery AND g.listing_visibility = 'public' AND g.is_cancelled = FALSE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'venues', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'venue' AS entity_type, v.id AS entity_id, v.name_en AS title,
          v.area AS subtitle, NULL::text AS image_url, '/venue/' || v.id AS route,
          ts_rank(v.search_tsv, v_tsquery) + (COALESCE(v.rating,0) * 0.05) AS score
        FROM public.venues v WHERE v.search_tsv @@ v_tsquery AND v.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'squads', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'squad' AS entity_type, s.id AS entity_id, s.name AS title,
          s.city AS subtitle, s.logo_url AS image_url, '/squad/' || s.id AS route,
          ts_rank(s.search_tsv, v_tsquery) AS score
        FROM public.squads s WHERE s.search_tsv @@ v_tsquery AND s.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'meetups', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'meetup' AS entity_type, m.id AS entity_id, m.title AS title,
          m.location_name AS subtitle, NULL::text AS image_url, '/meetup/' || m.id AS route,
          ts_rank(m.search_tsv, v_tsquery) AS score
        FROM public.meetups m WHERE m.search_tsv @@ v_tsquery
          AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'challenges', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'challenge' AS entity_type, c.id AS entity_id, c.title AS title,
          c.status AS subtitle, NULL::text AS image_url, '/challenge/' || c.id AS route,
          ts_rank(c.search_tsv, v_tsquery) AS score
        FROM public.challenges c WHERE c.search_tsv @@ v_tsquery AND c.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t)
  );
END;
$$;


ALTER FUNCTION "public"."rpc_unified_search_sectioned"("p_query" "text", "p_sport_id" "uuid", "p_lat" double precision, "p_lng" double precision, "p_radius_km" double precision, "p_limit_per_section" integer) OWNER TO "postgres";

-- Grants, verbatim: baseline_schema.sql:36875-36877 --------------------------------------------------------
GRANT ALL ON FUNCTION "public"."rpc_unified_search_sectioned"("p_query" "text", "p_sport_id" "uuid", "p_lat" double precision, "p_lng" double precision, "p_radius_km" double precision, "p_limit_per_section" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_unified_search_sectioned"("p_query" "text", "p_sport_id" "uuid", "p_lat" double precision, "p_lng" double precision, "p_radius_km" double precision, "p_limit_per_section" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_unified_search_sectioned"("p_query" "text", "p_sport_id" "uuid", "p_lat" double precision, "p_lng" double precision, "p_radius_km" double precision, "p_limit_per_section" integer) TO "service_role";

-- 2. Stand-ins for the other six sections (empty); copied from kan714_b05_search_indexes.sql ---------------
create table if not exists public.hashtags (id uuid primary key default gen_random_uuid());
create table if not exists public.squads (id uuid primary key default gen_random_uuid());
create table if not exists public.comments (id uuid primary key default gen_random_uuid());
alter table public.hashtags add column if not exists tag text, add column if not exists display_tag text,
  add column if not exists usage_count int, add column if not exists is_banned boolean,
  add column if not exists is_searchable boolean, add column if not exists is_approved boolean;
alter table public.squads add column if not exists name text, add column if not exists city text,
  add column if not exists logo_url text, add column if not exists search_tsv tsvector, add column if not exists is_active boolean;
alter table public.comments add column if not exists parent_activity_id uuid, add column if not exists search_tsv tsvector,
  add column if not exists is_deleted boolean, add column if not exists is_hidden_admin boolean;
alter table public.profiles add column if not exists search_tsv tsvector, add column if not exists display_name text,
  add column if not exists username text, add column if not exists avatar_url text;
alter table public.posts add column if not exists body text, add column if not exists author_display_name text,
  add column if not exists priority_score numeric, add column if not exists search_tsv tsvector,
  add column if not exists visibility text, add column if not exists is_deleted boolean,
  add column if not exists is_hidden_admin boolean, add column if not exists is_active boolean;
alter table public.venues add column if not exists name_en text, add column if not exists area text,
  add column if not exists search_tsv tsvector, add column if not exists rating numeric, add column if not exists is_active boolean;
alter table public.challenges add column if not exists status text, add column if not exists search_tsv tsvector,
  add column if not exists is_active boolean;

-- 3. Assert the pin -------------------------------------------------------------------------------------------
DO $$ BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure)
     <> 'fe3382197842fa66564b2f62d9b754f5' THEN
    RAISE EXCEPTION 'KAN-724 harness: pre-image md5 does not match the P5 pin';
  END IF;
END $$;

COMMIT;
