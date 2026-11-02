-- KAN-711 (Events P1) stage 2 of 3: one-way transactional mirror games/meetups -> events.
-- STATUS: authored only, not applied. needs-ops. PEER route (backend-N reviewer).
--
-- Built on KAN-710 (20261101140000_kan710_events_parent_schema.sql), which owns public.events, the
-- games/meetups.event_id columns, their UNIQUE + FK (ON DELETE CASCADE, DEFERRABLE INITIALLY DEFERRED),
-- forced RLS, and every integrity check: the subtype link check (event_id = id, no orphan, right
-- subtype, not owned by the other subtype), the parent-side exclusive check, the type/id immutability
-- guard, the series check, search_tsv and updated_at. KAN-711 duplicates none of them. It adds only:
--   * two mapping functions (the single place the field mapping lives; mirror, backfill and parity
--     all use them),
--   * an upsert,
--   * a BEFORE trigger that assigns event_id := id when it is NULL (KAN-710's link check then
--     enforces event_id = id; this trigger no longer re-checks it),
--   * the AFTER INSERT/UPDATE/DELETE mirror triggers,
--   * a BEFORE UPDATE trigger on public.events that restores the exact legacy updated_at after KAN-710's
--     trg_events_touch has overwritten it with now(), and ONLY when the write comes from the KAN-711
--     upsert (section 2a). Every other events UPDATE keeps KAN-710's now().
--
-- Direction is legacy -> events ONLY. Capture begins the moment this commits: every INSERT/UPDATE on a
-- legacy row (old or new) assigns event_id = id and upserts its events row in the same transaction.
-- Rows nobody touches wait for the backfill. Install this BEFORE running the backfill.
--
-- RISK, stated plainly: the mirror runs inside the user's transaction. If it raises, the user's legacy
-- write is rolled back. Reachable causes: (a) a type mismatch (U10 id collision), (b) an events
-- request-id conflict (U12), (c) a legacy row that passes the legacy CHECKs but fails a stricter
-- KAN-710 CHECK, notably events_end_after_start (KAN-710:65), which legacy tables do not have.
-- parity_kan711.sql section 0b counts (c) before apply. See KAN711_CONTRACT.md "Risks".

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-711: applying role % must be superuser or BYPASSRLS (meetups and events are FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'games_event_id_fkey'   AND conrelid = 'public.games'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'meetups_event_id_fkey' AND conrelid = 'public.meetups'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_games_event_link_check'   AND tgrelid = 'public.games'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_meetups_event_link_check' AND tgrelid = 'public.meetups'::regclass) THEN
    RAISE EXCEPTION 'KAN-711: KAN-710 (20261101140000) not applied: events / event_id FK / link checks missing';
  END IF;
END $$;

-- 1. Mapping (pure; positional over public.events column order, KAN-710:22-46). ---------------------
-- search_tsv is passed NULL: KAN-710's trg_events_search_tsv (KAN-710:262) derives it on INSERT and on
-- UPDATE OF title. description / location_name / is_indoor are not parent columns in KAN-710; they
-- stay on the meetups subtype (KAN-710:124-126).
CREATE FUNCTION public.kan711_events_map_game(g public.games)
RETURNS public.events LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT ROW(
    g.id, 'game'::text, g.creator_profile_id, g.creator_user_id, g.title,
    g.start_at, g.end_at, g.capacity,
    g.listing_visibility, g.join_policy,
    g.is_cancelled, g.cancelled_at, g.cancelled_reason,
    g.sport_id, g.area_id, g.geo_location_id, g.venue_id,
    g.min_skill::smallint, g.max_skill::smallint,      -- legacy integer -> KAN-710 smallint
    g.joining_rule, g.cost_cover, g.request_id,
    NULL::tsvector,                                     -- derived by KAN-710
    g.created_at, g.updated_at
  )::public.events
$$;

CREATE FUNCTION public.kan711_events_map_meetup(m public.meetups)
RETURNS public.events LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT ROW(
    m.id, 'meetup'::text, m.creator_profile_id, m.creator_user_id, m.title,
    m.start_at,
    m.end_at,                                           -- may be NULL; never inferred
    m.capacity,                                         -- may be NULL (unlimited); never defaulted
    m.listing_visibility,
    m.rsvp_policy,                                      -- alias -> join_policy
    m.is_cancelled,
    NULL::timestamptz,                                  -- cancelled_at: meetups has none (KAN-710:90 requires NULL)
    NULL::text,                                         -- cancelled_reason: meetups has none
    m.sport_id, m.area_id, m.geo_location_id,
    m.venue_id,                                         -- meta->>'venue_space_id' is NOT copied
    m.min_skill::smallint, m.max_skill::smallint,
    m.joining_rule, m.cost_cover, m.request_id,
    NULL::tsvector,
    m.created_at, m.updated_at
  )::public.events
$$;

-- 2. Upsert. Legacy is authoritative in P1: an existing same-type events row is overwritten with the
-- mapped legacy values whenever any mirrored column differs; identical rows are not rewritten.
-- search_tsv is NOT in the SET list nor in the comparison: KAN-710 derives it (trg_events_search_tsv,
-- KAN-710:262, re-derives it because title is in the SET list).
-- updated_at IS in both (KAN-709/02 row 54: the parent carries the legacy updated_at exactly). A
-- legacy edit that changes only a subtype-only column (games.rules) still advances the legacy
-- updated_at, so the parent must be rewritten for that alone. KAN-710's trg_events_touch
-- (KAN-710:260-261 -> touch_updated_at(), baseline 20260829080500:17390-17394) unconditionally sets
-- NEW.updated_at := now() on every events UPDATE, so writing EXCLUDED.updated_at is not enough on its
-- own. The upsert therefore publishes the source value in the transaction-local setting
-- kan711.src_updated_at for the duration of its one statement, and trg_kan711_events_keep_updated_at
-- (section 2a; sorts after trg_events_touch) puts that exact value back. The setting is cleared
-- straight after, and set_config(..., true) is rolled back with the (sub)transaction on error.
-- An INSERT has no touch (it is BEFORE UPDATE only) and keeps the legacy value directly.
CREATE FUNCTION public.kan711_events_upsert(r public.events)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_type  text;
  v_found boolean;
BEGIN
  PERFORM set_config('kan711.src_updated_at', r.updated_at::text, true);
  INSERT INTO public.events AS e
  SELECT (r).*
  ON CONFLICT (id) DO UPDATE SET
    creator_profile_id = EXCLUDED.creator_profile_id, creator_user_id = EXCLUDED.creator_user_id,
    title = EXCLUDED.title, start_at = EXCLUDED.start_at, end_at = EXCLUDED.end_at,
    capacity = EXCLUDED.capacity, listing_visibility = EXCLUDED.listing_visibility,
    join_policy = EXCLUDED.join_policy, is_cancelled = EXCLUDED.is_cancelled,
    cancelled_at = EXCLUDED.cancelled_at, cancelled_reason = EXCLUDED.cancelled_reason,
    sport_id = EXCLUDED.sport_id, area_id = EXCLUDED.area_id,
    geo_location_id = EXCLUDED.geo_location_id, venue_id = EXCLUDED.venue_id,
    min_skill = EXCLUDED.min_skill, max_skill = EXCLUDED.max_skill,
    joining_rule = EXCLUDED.joining_rule, cost_cover = EXCLUDED.cost_cover,
    request_id = EXCLUDED.request_id, created_at = EXCLUDED.created_at,
    updated_at = EXCLUDED.updated_at                -- re-imposed after touch by section 2a
  WHERE e.event_type = EXCLUDED.event_type          -- never retype (KAN-710:141-153 also refuses)
    AND ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
            e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
            e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
            e.joining_rule, e.cost_cover, e.request_id, e.created_at, e.updated_at)
        IS DISTINCT FROM
        ROW(EXCLUDED.creator_profile_id, EXCLUDED.creator_user_id, EXCLUDED.title, EXCLUDED.start_at,
            EXCLUDED.end_at, EXCLUDED.capacity, EXCLUDED.listing_visibility, EXCLUDED.join_policy,
            EXCLUDED.is_cancelled, EXCLUDED.cancelled_at, EXCLUDED.cancelled_reason, EXCLUDED.sport_id,
            EXCLUDED.area_id, EXCLUDED.geo_location_id, EXCLUDED.venue_id, EXCLUDED.min_skill,
            EXCLUDED.max_skill, EXCLUDED.joining_rule, EXCLUDED.cost_cover, EXCLUDED.request_id,
            EXCLUDED.created_at, EXCLUDED.updated_at); -- no-op writes are skipped (idempotent)
  v_found := FOUND;                                  -- capture before PERFORM resets FOUND

  PERFORM set_config('kan711.src_updated_at', '', true);

  IF NOT v_found THEN
    SELECT e.event_type INTO v_type FROM public.events e WHERE e.id = r.id;
    IF v_type IS DISTINCT FROM r.event_type THEN
      RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan711_event_type_mismatch',
        DETAIL = format('events.id %s is %s; refusing to mirror a %s onto it', r.id, v_type, r.event_type);
    END IF;
  END IF;
END $$;

-- 2a. Keep the exact legacy updated_at on a KAN-711 upsert. BEFORE UPDATE ON public.events.
-- Same-timing row triggers fire in name order; 'trg_kan711_...' sorts after every 'trg_events_...'
-- trigger KAN-710 creates (KAN-710:260-269), so this runs after trg_events_touch and its value is
-- the one stored. It acts only while kan711_events_upsert has published a source value; with the
-- setting unset or '' (every non-KAN-711 write) it returns NEW untouched and KAN-710's now() stands.
-- It copies the value; it never computes one (no now(), no clock_timestamp()).
CREATE FUNCTION public.kan711_events_keep_updated_at()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v text := current_setting('kan711.src_updated_at', true);
BEGIN
  IF v IS NOT NULL AND v <> '' THEN
    NEW.updated_at := v::timestamptz;
  END IF;
  RETURN NEW;
END $$;

-- 3. event_id := id when NULL. BEFORE INSERT OR UPDATE on each legacy table. Assignment only: a
-- non-NULL event_id <> id is refused by KAN-710's events_check_subtype_link (KAN-710:166-169) when
-- event_id is written explicitly.
CREATE FUNCTION public.kan711_assign_event_id()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.event_id IS NULL THEN
    NEW.event_id := NEW.id;
  END IF;
  RETURN NEW;
END $$;

-- 4. Mirror. AFTER INSERT/UPDATE/DELETE, same transaction, SECURITY DEFINER. -----------------------
-- DELETE removes the parent of the deleted legacy row (KAN-710 does not enforce exactly-one-child in
-- phase 1, handoff limitation 3, so without this the parent would be orphaned). Deleting the parent
-- cannot cascade back: the legacy row is already gone when an AFTER DELETE trigger runs.
CREATE FUNCTION public.kan711_games_mirror()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.events WHERE id = OLD.id AND event_type = 'game';
    RETURN OLD;
  END IF;
  PERFORM public.kan711_events_upsert(public.kan711_events_map_game(NEW));
  RETURN NEW;
END $$;

CREATE FUNCTION public.kan711_meetups_mirror()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.events WHERE id = OLD.id AND event_type = 'meetup';
    RETURN OLD;
  END IF;
  PERFORM public.kan711_events_upsert(public.kan711_events_map_meetup(NEW));
  RETURN NEW;
END $$;

-- 5. Triggers. Names sort after every existing legacy trigger, so the mirror sees the final row. --
CREATE TRIGGER trg_kan711_games_assign_event_id   BEFORE INSERT OR UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan711_assign_event_id();
CREATE TRIGGER trg_kan711_meetups_assign_event_id BEFORE INSERT OR UPDATE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan711_assign_event_id();

CREATE TRIGGER trg_kan711_events_keep_updated_at BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.kan711_events_keep_updated_at();

CREATE TRIGGER trg_kan711_games_mirror   AFTER INSERT OR UPDATE OR DELETE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan711_games_mirror();
CREATE TRIGGER trg_kan711_meetups_mirror AFTER INSERT OR UPDATE OR DELETE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan711_meetups_mirror();

-- 6. Privileges. Trigger functions need no EXECUTE grant to fire (checked at CREATE TRIGGER only).
-- pg_default_acl grants anon/authenticated BY NAME, so PUBLIC alone is not enough.
REVOKE ALL ON FUNCTION public.kan711_events_map_game(public.games)       FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_map_meetup(public.meetups)   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_upsert(public.events)        FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_keep_updated_at()            FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_assign_event_id()                   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_games_mirror()                      FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_meetups_mirror()                    FROM PUBLIC, anon, authenticated, service_role;

-- 7. Post-conditions: assert proacl and trigger shape, not that the statements ran. ----------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS f FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%' LOOP
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE')
       OR has_function_privilege('service_role', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-711 post: % is executable by an API role', r.f;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan711\_%'
              AND NOT ('search_path=""' = ANY (coalesce(p.proconfig, '{}')))) THEN
    RAISE EXCEPTION 'KAN-711 post: a kan711 function lacks a pinned empty search_path';
  END IF;
  -- events: exactly KAN-710's five non-internal triggers (KAN-710:260-271) plus KAN-711's one
  -- updated_at keeper, which must sort after trg_events_touch (it does: array order is name order).
  IF (SELECT array_agg(tgname::text ORDER BY tgname) FROM pg_trigger
       WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal)
     IS DISTINCT FROM ARRAY['trg_events_exclusive_check', 'trg_events_search_tsv', 'trg_events_series_start_check',
                            'trg_events_touch', 'trg_events_type_immutable',
                            'trg_kan711_events_keep_updated_at'] THEN
    RAISE EXCEPTION 'KAN-711 post: events trigger set differs from KAN-710''s five + the KAN-711 keeper';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_kan711\_%' AND tgenabled = 'O') <> 5 THEN
    RAISE EXCEPTION 'KAN-711 post: expected 5 enabled kan711 triggers';
  END IF;
END $$;

COMMIT;
