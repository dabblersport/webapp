-- KAN-773 (KAN-718 D05, Epic KAN-708): event-backed compatibility projections for clients that read
-- public.games / public.meetups directly (D03, KAN-771: 18-20 direct games reads in every build since 1.3.0).
--
-- AUTHORED FOR REVIEW. NEVER APPLIED BY THIS TICKET. Local proof only: supabase/tests/events_p4/kan718_d05_compat.sql.
--
-- WHAT IT ADDS (additive only; no table, column, policy, trigger or data is changed):
--   public.kan718_games_compat    exactly the columns of public.games, same names, order and types
--   public.kan718_meetups_compat  exactly the columns of public.meetups, same names, order and types
-- Every column KAN-718 slates for deletion is read from public.events through event_id; the retained subtype
-- columns are read from the subtype row. Ids, NULLs and original timestamps come through unchanged; nothing is
-- invented. Rows: one per subtype row (inner join on event_id = events.id, event_type pinned), so no doubling.
--
-- EXCEPTIONS (named, not hidden):
--   * meetups.rsvp_policy        <- events.join_policy (the contract's known join_policy/rsvp_policy conflict)
--   * min_skill / max_skill      <- events smallint, cast back to the legacy integer
--   * meetups.description, location_name, is_indoor  <- still the meetups row: events has no column for them and
--     KAN-718 does not retain them (KAN-774 D06 contract gap). The projection therefore still depends on those
--     three meetups columns; they are not event-backed and stay blocked until that decision lands.
--   * meetups.search_tsv         <- events.search_tsv, which does NOT index description/location_name (the legacy
--     meetups tsv does). Value mismatch, reported in the test; no client reads meetups directly (D03 2c).
--
-- VISIBILITY = THE LEGACY TABLE'S, ROW FOR ROW. The views are owned by postgres like v_game_card / v_meetup_list
-- (API roles have no SELECT on events, KAN-710), so the legacy row-security rule is re-stated in the view and the
-- view is a security_barrier (no leaky predicate pushdown):
--   games:   RLS enabled and NO policy (baseline; KAN-671 finding) -> an RLS-subject role sees no row; a
--            BYPASSRLS role (service_role, postgres) sees all. Encoded as NOT row_security_active('public.games'),
--            which is evaluated for the CALLING role (current_user is not switched by a view).
--   meetups: meetups_select_visible = can_view_owner(creator_user_id, listing_visibility) AND
--            kan713_meetup_visible(event_id), stated on the events values (the mirror makes them equal).
-- The guard below refuses if games gains a policy or meetups' policies differ from that pin, so the projection
-- can never silently diverge from the table it stands in for. Grants: SELECT only, to the roles holding SELECT on
-- the legacy tables. The views are read-only; direct legacy writes are already denied (games: no policy;
-- meetups_no_direct_insert) and the authorised write path stays the KAN-712 RPCs.
--
-- PHASE-4 USE (authored here as text only, NOT executed by this migration). Old builds address the name `games`,
-- so the projection takes over that name in the same transaction that retires the slated columns:
--     ALTER TABLE public.games RENAME TO games_subtype;  ALTER VIEW public.kan718_games_compat RENAME TO games;
--     ALTER TABLE public.meetups RENAME TO meetups_subtype; ALTER VIEW public.kan718_meetups_compat RENAME TO meetups;
-- The test runs exactly that swap inside BEGIN ... ROLLBACK and replays the D03 queries against the old names.
-- Not in scope and not demonstrated: PostgREST embedding (game_favorites!inner, game_roster!inner) through a view
-- and realtime on a view (Realtime publishes tables only). Both are listed as limitations in the test.
--
-- ROLLBACK: DROP VIEW public.kan718_meetups_compat; DROP VIEW public.kan718_games_compat;  (no data touched)
-- IDEMPOTENT: CREATE OR REPLACE VIEW; re-running is a no-op.

DO $guard$
DECLARE pol text;
BEGIN
  IF to_regclass('public.events') IS NULL OR to_regclass('public.games') IS NULL OR to_regclass('public.meetups') IS NULL THEN
    RAISE EXCEPTION 'KAN-773: events/games/meetups missing; apply KAN-710..714 first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'event_id' AND NOT attisdropped)
     OR NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attname = 'event_id' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-773: games/meetups.event_id missing; apply KAN-711 first';
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL OR to_regprocedure('public.can_view_owner(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-773: kan713_meetup_visible(uuid) / can_view_owner(uuid,text) missing; apply KAN-713 first';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.games'::regclass)
     OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.meetups'::regclass) THEN
    RAISE EXCEPTION 'KAN-773: games/meetups row security is not enabled; the projection''s visibility pin does not hold';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.games'::regclass) THEN
    RAISE EXCEPTION 'KAN-773: public.games has a policy; the projection pins "no policy" and would diverge. Re-derive first';
  END IF;
  SELECT string_agg(polname || ':' || polcmd::text || ':' || coalesce(pg_get_expr(polqual, polrelid), '') || ':'
                    || coalesce(pg_get_expr(polwithcheck, polrelid), ''), ' ; ' ORDER BY polname)
    INTO pol FROM pg_policy WHERE polrelid = 'public.meetups'::regclass;
  IF pol IS DISTINCT FROM 'meetups_no_direct_insert:a::false ; meetups_select_visible:r:(can_view_owner(creator_user_id, listing_visibility) AND kan713_meetup_visible(event_id)):' THEN
    RAISE EXCEPTION 'KAN-773: public.meetups policies differ from the pin (%); re-derive the projection first', pol;
  END IF;
END $guard$;

CREATE OR REPLACE VIEW public.kan718_games_compat WITH (security_barrier = true) AS
SELECT g.id,
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
       e.min_skill::integer AS min_skill,
       e.max_skill::integer AS max_skill,
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
       g.event_id
  FROM public.games g
  JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
 WHERE NOT row_security_active('public.games'::regclass);

CREATE OR REPLACE VIEW public.kan718_meetups_compat WITH (security_barrier = true) AS
SELECT m.id,
       e.creator_profile_id,
       e.creator_user_id,
       e.title,
       m.description,
       m.vibe_key,
       e.listing_visibility,
       e.join_policy AS rsvp_policy,
       e.capacity,
       e.start_at,
       e.end_at,
       e.is_cancelled,
       m.meta,
       e.created_at,
       e.updated_at,
       m.host_actor_id,
       e.search_tsv,
       e.geo_location_id,
       e.sport_id,
       e.area_id,
       e.venue_id,
       e.min_skill::integer AS min_skill,
       e.max_skill::integer AS max_skill,
       m.members_only,
       e.joining_rule,
       e.cost_cover,
       m.location_name,
       m.is_indoor,
       e.request_id,
       m.event_id
  FROM public.meetups m
  JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE NOT row_security_active('public.meetups'::regclass)
    OR (public.can_view_owner(e.creator_user_id, e.listing_visibility) AND public.kan713_meetup_visible(m.event_id));

COMMENT ON VIEW public.kan718_games_compat IS
  'KAN-773 (KAN-718 D05): event-backed projection of public.games for old direct-read clients; same columns/visibility as the table.';
COMMENT ON VIEW public.kan718_meetups_compat IS
  'KAN-773 (KAN-718 D05): event-backed projection of public.meetups for old direct-read clients; same columns/visibility as the table.';

REVOKE ALL ON public.kan718_games_compat, public.kan718_meetups_compat FROM PUBLIC;
DO $grant$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      IF has_table_privilege(r, 'public.games', 'SELECT') THEN EXECUTE format('GRANT SELECT ON public.kan718_games_compat TO %I', r); END IF;
      IF has_table_privilege(r, 'public.meetups', 'SELECT') THEN EXECUTE format('GRANT SELECT ON public.kan718_meetups_compat TO %I', r); END IF;
    END IF;
  END LOOP;
END $grant$;
