-- KAN-595 Active stream: source-event model behind ONE read RPC.   AUTHORED, NOT APPLIED.
--
-- EVENT TABLE (event_type -> source table / column -> event_at)
--   player_joined     -> public.profiles (profile_type = 'personal')  -> profiles.created_at
--   venue_added       -> public.venues                                -> venues.created_at
--   game_created      -> public.games                                 -> games.created_at
--   game_started      -> public.games                                 -> games.start_at   (only when start_at <= now())
--   game_ended        -> public.games                                 -> games.end_at     (only when end_at <= now())
--   meetup_created    -> public.meetups                               -> meetups.created_at
--   meetup_started    -> public.meetups                               -> meetups.start_at (only when start_at <= now())
--   meetup_completed  -> public.meetups                               -> COALESCE(meetups.end_at, meetups.start_at)
--                                                                        (only when that value <= now())
--
-- STARTED / ENDED DEFINITION. games and meetups carry NO status column and NO transition timestamp (baseline
-- 20260829080500: games has start_at/end_at NOT NULL, is_cancelled, cancelled_at; meetups has start_at NOT NULL,
-- end_at NULLABLE, is_cancelled). "Started" is therefore defined as scheduled start_at <= now() and "ended/completed"
-- as scheduled end_at (meetups: COALESCE(end_at, start_at)) <= now(), for NON-cancelled items only. The event time is
-- the scheduled time, not an observed transition. No view/visit counters are read.
--
-- CITY. Selected-city text (the app's manual city selection), compared case-insensitively against areas.city
-- (games/venues/meetups via area_id) and profiles.city (players). NULL p_city = all cities. The function takes no
-- coordinates and never needs device location permission (LOCATION RULE: the city comes from manual selection).
--
-- VISIBILITY (reuses existing predicates, no copied logic):
--   games    public._can_view_game(id)            (owner/roster/waitlist/admin or can_view_with_scope on
--                                                   listing_visibility; includes the block check)
--   meetups  public.can_view_owner(creator_user_id, listing_visibility)  (the meetups_select_visible RLS predicate)
--   venues   is_active = true                     (the venues_public_active RLS predicate)
--   profiles public.is_profile_publicly_visible(id)  (is_active, not benched, not hidden from search)
--   cancelled games/meetups are excluded from EVERY event type (created included).
-- BLOCKS. Every branch also excludes rows whose actor/owner user is blocked by, or blocks, the viewer:
--   NOT public.is_blocked(auth.uid(), <actor user>) -- both directions, narrowed to the caller (KAN-497).
-- No message content and no posts/news are read. auth.uid() IS NULL returns no rows.
--
-- DE-DUPLICATION. Eight disjoint UNION ALL branches, each one row per source primary key; DISTINCT ON
-- (event_type, entity_id) guards the contract. Order: event_at DESC, event_type DESC, entity_id DESC.
-- Keyset: (p_before, p_before_type, p_before_entity) = the last row's (event_at, event_type, entity_id);
-- with only p_before given, rows with event_at < p_before. p_limit is clamped to 1..50.
--
-- SECURITY DEFINER because public.games has RLS enabled and no SELECT policy (reads go through definer RPCs); the
-- predicates above are applied explicitly for auth.uid(). search_path pinned. EXECUTE: authenticated only.
-- No table, no index, no DROP, no write.

BEGIN;

CREATE OR REPLACE FUNCTION public.active_stream(
  p_event_types text[] DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_limit int DEFAULT 30,
  p_before timestamptz DEFAULT NULL,
  p_before_type text DEFAULT NULL,
  p_before_entity uuid DEFAULT NULL
)
RETURNS TABLE (
  event_type text,
  event_at timestamptz,
  entity_kind text,
  entity_id uuid,
  actor_profile_id uuid,
  city text,
  title text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public', 'pg_temp'
AS $$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, g.created_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, g.start_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, g.end_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, m.created_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, m.start_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND m.start_at <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(m.end_at, m.start_at), 'meetup'::text, m.id, m.creator_profile_id,
           a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND COALESCE(m.end_at, m.start_at) <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
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
  )
  SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
    FROM filtered f
   ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
   LIMIT (SELECT lim FROM prm);
$$;

REVOKE ALL ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) TO authenticated;

COMMENT ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) IS
  'KAN-595 Active stream: player_joined, venue_added, game_created/started/ended, meetup_created/started/completed; newest first; viewer-visible, block-filtered; selected-city text filter, no location.';

COMMIT;
