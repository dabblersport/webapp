-- KAN-933 (backend half): rpc_unified_search_sectioned, the only search RPC the app calls
-- (lib/data/repositories/search_repository_impl.dart).
--   1. meetups section: route '/meetup/<id>' -> '/meetups/<id>' (app route /meetups/:id, key = meetups.id, which
--      equals events.id for every live row).
--   2. games section, rule recorded on the ticket: a host sees their own non-public games in search (a series is a
--      set of games, so its occurrences are covered). Cancelled games stay out for everyone. Everyone else still
--      sees public games only.
-- Re-authored from live pg_get_functiondef; only those two places change. CREATE OR REPLACE keeps owner, SECURITY
-- DEFINER, search_path and ACL; the post-assert checks them.
-- Pre-image md5(prosrc) 4fb01f55aca1997e1ecf5d3dfb77135b.
-- Proof: supabase/tests/events_p4/kan931_broken_functions_test.sql (S1..S3).

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc
      WHERE oid = to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'))
     IS DISTINCT FROM '4fb01f55aca1997e1ecf5d3dfb77135b' THEN
    RAISE EXCEPTION 'KAN-933 guard: rpc_unified_search_sectioned is not the pinned pre-image';
  END IF;
END $guard$;

CREATE OR REPLACE FUNCTION public.rpc_unified_search_sectioned(p_query text, p_sport_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT NULL::double precision, p_limit_per_section integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        SELECT 'game' AS entity_type, e.id AS entity_id, e.title AS title,
          NULL::text AS subtitle, NULL::text AS image_url, '/game/' || e.id AS route,
          ts_rank(e.search_tsv, v_tsquery) + CASE WHEN e.start_at > NOW() THEN 0.2 ELSE 0 END AS score
        FROM public.events e
        JOIN public.kan714_games_read g ON g.event_id = e.id
        WHERE e.event_type = 'game' AND e.search_tsv @@ v_tsquery
          AND (e.listing_visibility = 'public'
               OR (auth.uid() IS NOT NULL AND e.creator_user_id = auth.uid()))
          AND e.is_cancelled = FALSE
          AND g.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
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
        SELECT 'meetup' AS entity_type, e.id AS entity_id, e.title AS title,
          m.location_name AS subtitle, NULL::text AS image_url, '/meetups/' || m.id AS route,
          ts_rank(m.search_tsv, v_tsquery) AS score
        FROM public.kan714_meetups_read m
        JOIN public.events e ON e.id = m.event_id
        WHERE e.event_type = 'meetup' AND m.search_tsv @@ v_tsquery
          AND e.listing_visibility = 'public' AND e.is_cancelled = FALSE
          AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
    'challenges', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'challenge' AS entity_type, c.id AS entity_id, c.title AS title,
          c.status AS subtitle, NULL::text AS image_url, '/challenge/' || c.id AS route,
          ts_rank(c.search_tsv, v_tsquery) AS score
        FROM public.challenges c WHERE c.search_tsv @@ v_tsquery AND c.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t)
  );
END;
$function$;

DO $post$
DECLARE r record;
BEGIN
  SELECT pg_get_userbyid(p.proowner) own, p.prosecdef, p.proconfig::text cfg, p.proacl::text acl INTO r
  FROM pg_proc p WHERE p.oid = to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)');
  IF r.own <> 'postgres' OR NOT r.prosecdef OR r.cfg <> '{search_path=public}'
     OR r.acl <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-933 post: attributes changed: % % % %', r.own, r.prosecdef, r.cfg, r.acl;
  END IF;
END $post$;
