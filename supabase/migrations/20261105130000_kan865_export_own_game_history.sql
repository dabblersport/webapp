-- KAN-880 (supports KAN-865, Events Epic KAN-708): public.export_own_game_history(), the server-side replacement for
-- the data export's games/game_roster read (data_export_service.dart _getEnhancedGameHistoryData: games.* +
-- game_roster!inner(user_id, joined_at, status, role), newest created_at first). CTO ruling dreq-5087907b point 1.
--
-- AUTHORED, NOT APPLIED BY THIS TICKET. Local proof only: supabase/tests/events_p4/kan865_export_own_game_history_test.sql
-- (throwaway PG16). Additive: one new function, nothing else is created, replaced, altered, revoked or dropped.
--
-- WHY SECURITY DEFINER: public.events is RLS FORCED with zero policies and no client grants (kan710), so an INVOKER
-- function could not read it. search_path is '' and every object is schema-qualified.
--
-- COLUMNS. Every column the old games.* select exposed, under its old key:
--   * moved to public.events by KAN-710/711 (and dropped from games by KAN-719 Z01, 20261105100000): title,
--     creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy, min_skill,
--     max_skill, is_cancelled, cancelled_at, cancelled_reason, created_at, updated_at, search_tsv, sport_id,
--     geo_location_id, area_id, venue_id, joining_rule, cost_cover, request_id. Read from e (same names on events;
--     min_skill/max_skill are smallint on events, integer on games).
--   * retained on games (the 13 KAN-719 keeps): id, game_type, venue_space_id, allow_spectators, rules, squad_id,
--     sport_specific_data, allows_waitlist, sport_variant_id, bench_slots, price_aed, series_id, event_id. Read from g,
--     so the function works both before and after Z01.
--   plus event_type (events), and my_roster: the caller's own game_roster row as
--   {user_id, joined_at, status, role} (the four columns the old embed selected), NULL when the caller is only the
--   creator. game_roster's key is (game_id, profile_id), not user_id; if one user has more than one profile on the
--   same game, the most recent joined_at wins.
--
-- ROSTER KEY. game_roster.game_id references games(id) (live: game_roster_game_id_fkey
-- FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE), so the roster is joined on g.id. games.event_id =
-- games.id is enforced by events_check_subtype_link, so this equals e.id, but the FK names games.
--
-- ROWS: event_type = 'game' and (the caller created it OR the caller has a roster row on it), newest created_at first.
-- A null auth.uid() raises 28000.
--
-- GRANT: EXECUTE to authenticated. Nothing is revoked here (ruling: one GRANT, no REVOKE). NOTE for review:
-- Postgres grants EXECUTE on a new function to PUBLIC by default, and on Supabase pg_default_acl also grants anon
-- by name, so after this migration anon can call it too. A null auth.uid() raises 28000 before any read, so anon
-- gets the error and no rows.

CREATE FUNCTION public.export_own_game_history()
  RETURNS TABLE (
    event_id            uuid,
    event_type          text,
    id                  uuid,
    game_type           text,
    title               text,
    creator_profile_id  uuid,
    creator_user_id     uuid,
    venue_space_id      uuid,
    start_at            timestamptz,
    end_at              timestamptz,
    capacity            integer,
    listing_visibility  text,
    join_policy         text,
    allow_spectators    boolean,
    min_skill           smallint,
    max_skill           smallint,
    rules               jsonb,
    is_cancelled        boolean,
    cancelled_at        timestamptz,
    cancelled_reason    text,
    created_at          timestamptz,
    updated_at          timestamptz,
    squad_id            uuid,
    search_tsv          tsvector,
    sport_specific_data jsonb,
    allows_waitlist     boolean,
    sport_id            uuid,
    geo_location_id     uuid,
    area_id             uuid,
    venue_id            uuid,
    sport_variant_id    uuid,
    bench_slots         integer,
    joining_rule        text,
    cost_cover          text,
    price_aed           numeric,
    request_id          uuid,
    series_id           uuid,
    my_roster           jsonb
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'export_own_game_history: not authenticated' USING ERRCODE = '28000';
  END IF;

  RETURN QUERY
  SELECT e.id,
         e.event_type,
         g.id,
         g.game_type,
         e.title,
         e.creator_profile_id,
         e.creator_user_id,
         g.venue_space_id,
         e.start_at,
         e.end_at,
         e.capacity,
         e.listing_visibility,
         e.join_policy,
         g.allow_spectators,
         e.min_skill,
         e.max_skill,
         g.rules,
         e.is_cancelled,
         e.cancelled_at,
         e.cancelled_reason,
         e.created_at,
         e.updated_at,
         g.squad_id,
         e.search_tsv,
         g.sport_specific_data,
         g.allows_waitlist,
         e.sport_id,
         e.geo_location_id,
         e.area_id,
         e.venue_id,
         g.sport_variant_id,
         g.bench_slots,
         e.joining_rule,
         e.cost_cover,
         g.price_aed,
         e.request_id,
         g.series_id,
         (SELECT pg_catalog.jsonb_build_object('user_id', gr.user_id, 'joined_at', gr.joined_at,
                                               'status', gr.status, 'role', gr.role)
            FROM public.game_roster gr
           WHERE gr.game_id = g.id AND gr.user_id = v_uid
           ORDER BY gr.joined_at DESC NULLS LAST
           LIMIT 1)
    FROM public.events e
    JOIN public.games g ON g.event_id = e.id
   WHERE e.event_type = 'game'
     AND (e.creator_user_id = v_uid
          OR EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = g.id AND gr.user_id = v_uid))
   ORDER BY e.created_at DESC;
END
$function$;

COMMENT ON FUNCTION public.export_own_game_history() IS
  'KAN-880/KAN-865: the caller''s game history for the data export: every game the caller created or has a '
  'game_roster row on, with every column the old games.* select exposed (events + retained games columns), '
  'event_id, event_type and my_roster (own roster row, NULL when creator only), newest created_at first. '
  'Raises 28000 when auth.uid() is null.';

GRANT EXECUTE ON FUNCTION public.export_own_game_history() TO authenticated;
