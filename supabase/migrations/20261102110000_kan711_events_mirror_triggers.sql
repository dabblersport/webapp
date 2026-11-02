-- KAN-711 (Events P1) stage 2 of 3: one-way transactional mirror games/meetups -> events.
-- STATUS: authored only, not applied. needs-ops. PEER route (backend-N reviewer).
-- PROVISIONAL (E1 absent): the field mapping lives in exactly two functions, kan711_events_map_game
-- and kan711_events_map_meetup, used by the mirror, the backfill and the parity check alike.
--
-- Direction is legacy -> events ONLY. Nothing writes back to games/meetups except the stage-3 backfill
-- setting event_id = id. events carries no side-effect trigger: only the deferred integrity check.
--
-- Capture begins the moment this commits: every INSERT/UPDATE on a legacy row (old or new) assigns
-- event_id = id and upserts its events row in the same transaction. Rows nobody touches wait for the
-- backfill. Install this BEFORE running the backfill (the contract's ordering rule).
--
-- RISK, stated plainly: the mirror runs inside the user's transaction. If it raises (type mismatch,
-- events request-id conflict, a CHECK the legacy row passes but events refuses) the user's legacy
-- write is rolled back. The events CHECKs are union domains of both legacy tables so the second case
-- should be unreachable; the request-id case is reachable only when one profile maps to two users
-- for meetups (games force creator_user_id from the profile). See KAN711_CONTRACT.md "Risks".

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-711: applying role % must be superuser or BYPASSRLS (meetups is FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-711: stage 1 (20261102100000) not applied';
  END IF;
END $$;

-- 1. Mapping (pure; positional over public.events column order as created in stage 1). ------------
CREATE FUNCTION public.kan711_events_map_game(g public.games)
RETURNS public.events LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT ROW(
    g.id, 'game'::text, g.title,
    NULL::text,                                   -- description: games has none
    g.creator_profile_id, g.creator_user_id, g.sport_id, g.start_at, g.end_at, g.capacity,
    g.venue_id, g.geo_location_id, g.area_id,
    NULL::text,                                   -- location_name: games has none, not inferred from venue
    NULL::boolean,                                -- is_indoor: games has none, not inferred from venue_space
    g.listing_visibility, g.join_policy, g.min_skill, g.max_skill, g.joining_rule, g.cost_cover,
    g.is_cancelled, g.cancelled_at, g.cancelled_reason, g.request_id,
    g.created_at, g.updated_at, g.search_tsv
  )::public.events
$$;

CREATE FUNCTION public.kan711_events_map_meetup(m public.meetups)
RETURNS public.events LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT ROW(
    m.id, 'meetup'::text, m.title, m.description,
    m.creator_profile_id, m.creator_user_id, m.sport_id, m.start_at,
    m.end_at,                                     -- may be NULL; never inferred
    m.capacity,                                   -- may be NULL (unlimited); never defaulted
    m.venue_id,                                   -- meta->>'venue_space_id' is NOT copied (Venue/Space mix)
    m.geo_location_id, m.area_id, m.location_name, m.is_indoor,
    m.listing_visibility,
    m.rsvp_policy,                                -- alias -> join_policy
    m.min_skill, m.max_skill, m.joining_rule, m.cost_cover, m.is_cancelled,
    NULL::timestamptz,                            -- cancelled_at: meetups has none, not inferred from updated_at
    NULL::text,                                   -- cancelled_reason: meetups has none
    m.request_id, m.created_at, m.updated_at, m.search_tsv
  )::public.events
$$;

-- 2. Upsert: insert, or update only when same type, not newer, and actually different. -------------
CREATE FUNCTION public.kan711_events_upsert(r public.events)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_type text;
BEGIN
  INSERT INTO public.events AS e
  SELECT (r).*
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    creator_profile_id = EXCLUDED.creator_profile_id, creator_user_id = EXCLUDED.creator_user_id,
    sport_id = EXCLUDED.sport_id, start_at = EXCLUDED.start_at, end_at = EXCLUDED.end_at,
    capacity = EXCLUDED.capacity, venue_id = EXCLUDED.venue_id,
    geo_location_id = EXCLUDED.geo_location_id, area_id = EXCLUDED.area_id,
    location_name = EXCLUDED.location_name, is_indoor = EXCLUDED.is_indoor,
    listing_visibility = EXCLUDED.listing_visibility, join_policy = EXCLUDED.join_policy,
    min_skill = EXCLUDED.min_skill, max_skill = EXCLUDED.max_skill,
    joining_rule = EXCLUDED.joining_rule, cost_cover = EXCLUDED.cost_cover,
    is_cancelled = EXCLUDED.is_cancelled, cancelled_at = EXCLUDED.cancelled_at,
    cancelled_reason = EXCLUDED.cancelled_reason, request_id = EXCLUDED.request_id,
    created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at,
    search_tsv = EXCLUDED.search_tsv
  WHERE e.event_type = EXCLUDED.event_type          -- never retype
    AND e.updated_at <= EXCLUDED.updated_at         -- never overwrite a newer events row
    AND (e.*) IS DISTINCT FROM (EXCLUDED.*);        -- no-op writes are skipped (idempotent)

  IF NOT FOUND THEN
    SELECT e.event_type INTO v_type FROM public.events e WHERE e.id = r.id;
    IF v_type IS DISTINCT FROM r.event_type THEN
      RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan711_event_type_mismatch',
        DETAIL = format('events.id %s is %s; refusing to mirror a %s onto it', r.id, v_type, r.event_type);
    END IF;
  END IF;
END $$;

-- 3. event_id = id, always. BEFORE INSERT OR UPDATE on each legacy table. ------------------------
CREATE FUNCTION public.kan711_assign_event_id()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.event_id IS NULL THEN
    NEW.event_id := NEW.id;
  ELSIF NEW.event_id IS DISTINCT FROM NEW.id THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan711_event_id_must_equal_id',
      DETAIL = format('%s.id %s cannot point at event %s', TG_TABLE_NAME, NEW.id, NEW.event_id);
  END IF;
  RETURN NEW;
END $$;

-- 4. Mirror. AFTER INSERT/UPDATE/DELETE, same transaction, SECURITY DEFINER. -----------------------
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

-- 5. Integrity at the transaction boundary (deferred constraint triggers). -----------------------
-- Legacy side: a linked row's event must be of the same type; a deleted row leaves no event behind.
CREATE FUNCTION public.kan711_legacy_integrity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_kind   text := CASE TG_TABLE_NAME WHEN 'games' THEN 'game' WHEN 'meetups' THEN 'meetup' END;
  v_id     uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  v_alive  boolean;
  v_type   text;
BEGIN
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.%I WHERE id = $1)', TG_TABLE_SCHEMA, TG_TABLE_NAME)
     INTO v_alive USING v_id;
  SELECT e.event_type INTO v_type FROM public.events e WHERE e.id = v_id;

  IF NOT v_alive THEN
    IF v_type = v_kind THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan711_orphan_event',
        DETAIL = format('%s %s was deleted but its events row remains', TG_TABLE_NAME, v_id);
    END IF;
    RETURN NULL;
  END IF;

  IF v_type IS NOT NULL AND v_type <> v_kind THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan711_event_type_mismatch',
      DETAIL = format('%s %s is linked to an events row of type %s', TG_TABLE_NAME, v_id, v_type);
  END IF;
  RETURN NULL;
END $$;

-- Events side: every events row has exactly one legacy parent, in the table its type names. id and
-- event_type are immutable.
CREATE FUNCTION public.kan711_events_integrity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_type text;
  v_game boolean;
  v_meet boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND (OLD.id IS DISTINCT FROM NEW.id OR OLD.event_type IS DISTINCT FROM NEW.event_type) THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan711_event_identity_immutable',
      DETAIL = format('events %s: id/event_type cannot change (%s -> %s)', OLD.id, OLD.event_type, NEW.event_type);
  END IF;

  SELECT e.event_type INTO v_type FROM public.events e WHERE e.id = NEW.id;
  IF NOT FOUND THEN
    RETURN NULL;                                     -- removed later in the same transaction
  END IF;
  v_game := EXISTS (SELECT 1 FROM public.games   WHERE id = NEW.id);
  v_meet := EXISTS (SELECT 1 FROM public.meetups WHERE id = NEW.id);
  IF (v_type = 'game'   AND (NOT v_game OR v_meet))
  OR (v_type = 'meetup' AND (NOT v_meet OR v_game)) THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan711_orphan_or_mistyped_event',
      DETAIL = format('events %s type %s: games parent=%s, meetups parent=%s', NEW.id, v_type, v_game, v_meet);
  END IF;
  RETURN NULL;
END $$;

-- 6. Triggers. Names sort after every existing legacy trigger, so the mirror sees the final row. --
CREATE TRIGGER trg_kan711_games_assign_event_id   BEFORE INSERT OR UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan711_assign_event_id();
CREATE TRIGGER trg_kan711_meetups_assign_event_id BEFORE INSERT OR UPDATE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan711_assign_event_id();

CREATE TRIGGER trg_kan711_games_mirror   AFTER INSERT OR UPDATE OR DELETE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan711_games_mirror();
CREATE TRIGGER trg_kan711_meetups_mirror AFTER INSERT OR UPDATE OR DELETE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan711_meetups_mirror();

CREATE CONSTRAINT TRIGGER trg_kan711_games_integrity   AFTER INSERT OR UPDATE OR DELETE ON public.games
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.kan711_legacy_integrity();
CREATE CONSTRAINT TRIGGER trg_kan711_meetups_integrity AFTER INSERT OR UPDATE OR DELETE ON public.meetups
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.kan711_legacy_integrity();
CREATE CONSTRAINT TRIGGER trg_kan711_events_integrity  AFTER INSERT OR UPDATE ON public.events
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.kan711_events_integrity();

-- 7. Privileges. Trigger functions need no EXECUTE grant to fire (checked at CREATE TRIGGER only).
-- pg_default_acl grants anon/authenticated BY NAME, so PUBLIC alone is not enough.
REVOKE ALL ON FUNCTION public.kan711_events_map_game(public.games)       FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_map_meetup(public.meetups)   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_upsert(public.events)        FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_assign_event_id()                   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_games_mirror()                      FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_meetups_mirror()                    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_legacy_integrity()                  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan711_events_integrity()                  FROM PUBLIC, anon, authenticated, service_role;

-- 8. Post-conditions: assert proacl and trigger shape, not that the statements ran. ----------------
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
  -- events: the only non-internal trigger is the integrity check. No side-effect triggers.
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal
              AND tgname <> 'trg_kan711_events_integrity') THEN
    RAISE EXCEPTION 'KAN-711 post: events carries an unexpected trigger';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_kan711\_%' AND tgenabled = 'O') <> 7 THEN
    RAISE EXCEPTION 'KAN-711 post: expected 7 enabled kan711 triggers';
  END IF;
END $$;

COMMIT;
