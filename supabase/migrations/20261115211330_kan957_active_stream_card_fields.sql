-- KAN-957 (backend half): public.active_stream gains the card fields the Home Feed Active tab renders.
-- The 7 existing columns stay first and in order; 8 columns are appended:
--   actor_display_name, actor_avatar_url  profiles via actor_profile_id (NULL for venue_added)
--   detail                                games/meetups: venue name_en, else area name; venue_added: area name; player_joined: NULL
--   start_at, end_at                      games: events.start_at/end_at; meetups: start_at, coalesce(end_at, start_at); else NULL
--   is_live                               games/meetups: start_at <= now() < end_at (cancelled rows are already excluded); else false
--   sport_names_en, sport_names_ar        game/meetup: events.sport_id; venue: venue_spaces.sport_id UNION venues.sports (sport_key);
--                                         player: primary_sport, preferred_sport, interests. '{}' when none. Both arrays share one order.
-- city_ar is NOT added: public.areas has no Arabic city column (only country, city, name, district, codes).
-- Body re-authored from the live pg_get_functiondef (pre-image md5 guarded); the 8 event branches, visibility, block
-- filters, city/type filters and keyset predicate are unchanged. Card fields are resolved only for the returned page.
-- Return type change => DROP + CREATE; owner, SECURITY DEFINER, search_path, comment and the pre-image ACL
-- (postgres, authenticated, service_role; no PUBLIC, no anon) are restored and asserted.
-- Callers: no lib/, workers/, supabase/functions/ call site; no SQL function or view references active_stream.
-- Applied under G-002 by backend-2.

DO $pre$
DECLARE v_md5 text; v_acl text[];
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)), (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)
    INTO v_md5, v_acl
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF v_md5 IS DISTINCT FROM '3b153424412536bf93456f05b876811c' THEN
    RAISE EXCEPTION 'KAN-957 pre-image md5 mismatch: %', v_md5;
  END IF;
  IF v_acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres'] THEN
    RAISE EXCEPTION 'KAN-957 pre-image ACL mismatch: %', v_acl;
  END IF;
END
$pre$;

DROP FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid);

CREATE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text,
               actor_display_name text, actor_avatar_url text, detail text, start_at timestamp with time zone, end_at timestamp with time zone,
               is_live boolean, sport_names_en text[], sport_names_ar text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title,
           NULL::text AS detail, NULL::timestamptz AS start_at, NULL::timestamptz AS end_at, NULL::uuid AS sport_id
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en,
           a.name, NULL::timestamptz, NULL::timestamptz, NULL::uuid
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, e.created_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
  ),
  filtered AS (
    SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
      FROM ev, prm
     WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
       AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
       AND (
         p_before IS NULL
         OR ev.event_at < p_before
         OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
             AND ev.event_at = p_before
             AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
       )
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
  ),
  page AS (
    SELECT f.*
      FROM filtered f
     ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
     LIMIT (SELECT lim FROM prm)
  )
  SELECT pg.event_type, pg.event_at, pg.entity_kind, pg.entity_id, pg.actor_profile_id, pg.city, pg.title,
         ap.display_name, ap.avatar_url,
         pg.detail, pg.start_at, pg.end_at,
         COALESCE(pg.entity_kind IN ('game', 'meetup') AND pg.start_at <= now() AND now() < pg.end_at, false),
         COALESCE(sp.en, '{}'::text[]), COALESCE(sp.ar, '{}'::text[])
    FROM page pg
    LEFT JOIN public.profiles ap ON ap.id = pg.actor_profile_id
    LEFT JOIN LATERAL (
      SELECT array_agg(s.name_en ORDER BY s.name_en, s.id) AS en,
             array_agg(s.name_ar ORDER BY s.name_en, s.id) AS ar
        FROM public.sports s
       WHERE (pg.entity_kind IN ('game', 'meetup') AND s.id = pg.sport_id)
          OR (pg.entity_kind = 'venue'
              AND (EXISTS (SELECT 1 FROM public.venue_spaces vs WHERE vs.venue_id = pg.entity_id AND vs.sport_id = s.id)
                   OR EXISTS (SELECT 1 FROM public.venues v WHERE v.id = pg.entity_id AND s.sport_key = ANY (v.sports))))
          OR (pg.entity_kind = 'profile'
              AND EXISTS (SELECT 1 FROM public.profiles pp
                           WHERE pp.id = pg.entity_id
                             AND (s.id = pp.primary_sport OR s.id = pp.preferred_sport OR s.id = ANY (pp.interests))))
    ) sp ON true
   ORDER BY pg.event_at DESC, pg.event_type DESC, pg.entity_id DESC;
$function$;

ALTER FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) IS
  'KAN-595 Active stream: player_joined, venue_added, game_created/started/ended, meetup_created/started/completed; newest first; viewer-visible, block-filtered; selected-city text filter, no location. KAN-957: + actor_display_name, actor_avatar_url, detail, start_at, end_at, is_live, sport_names_en, sport_names_ar.';

DO $post$
DECLARE r record;
BEGIN
  SELECT pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.proconfig,
         (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x) AS acl,
         pg_get_function_result(p.oid) AS res
    INTO r
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF r.owner <> 'postgres' OR NOT r.prosecdef
     OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
     OR has_function_privilege('anon', 'public.active_stream(text[],text,integer,timestamptz,text,uuid)', 'EXECUTE')
     OR r.res NOT LIKE 'TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text, actor_display_name text, %' THEN
    RAISE EXCEPTION 'KAN-957 post-image mismatch: owner=% secdef=% cfg=% acl=% res=%', r.owner, r.prosecdef, r.proconfig, r.acl, r.res;
  END IF;
END
$post$;
