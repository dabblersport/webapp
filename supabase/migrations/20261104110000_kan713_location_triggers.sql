-- KAN-713 (Events P2), migration 2 of 2: LOCATION RULES CONSOLIDATED ONTO ONE OWNER PER TABLE.
--
-- STATUS: authored, NOT applied to any Supabase project. Executed on a local throwaway PG 16 only
-- (supabase/tests/events_p2_kan713/KAN713_CONTRACT.md, "Local run").
--
-- STAGE GATE: requires 20261104100000_kan713_access_helpers.sql (which itself requires KAN-712 stage A+B).
--
-- WHAT CHANGES. The five legacy location BEFORE triggers are DISABLED (not dropped -- rollback re-enables
-- them) and replaced by trg_kan713_* triggers whose bodies are the legacy bodies verbatim plus:
--   * one compat skip: when the KAN-712 compat mirror is writing this legacy row (trigger depth > 1 AND
--     kan712.compat = NEW.id) the trigger does nothing -- the KAN-712 guard copies the events values onto
--     NEW afterwards anyway, so the legacy recomputation there was dead work whose result was discarded.
--     A session-level SET kan712.compat at depth 1 is NOT honoured (same rule as the KAN-712 guard).
--   * Venue vs Space resolved only through the venue_spaces row (venue_spaces.venue_id); a space that does
--     not exist is refused (23503 kan713_space_not_found), a venue that is not the space's venue is refused
--     (23514 kan713_space_venue_mismatch) -- each only when the write CHANGES venue or space, so existing
--     rows are never made un-updatable by an unrelated write.
--   * D-1 fixed: fn_meetups_sync_joining_rule looked the meetup's VENUE id up as a SPACE id
--     (COALESCE(venue_id, meta space)) so any meetup with a venue got joining_rule 'free'. The space now
--     comes only from meta.venue_space_id.
--   * D-2 fixed: changing a game's space alone kept the OLD venue (COALESCE(NEW.venue_id, ...)), leaving a
--     venue/space pair that disagree. The venue now follows the new space when the write did not set it.
--   * public.events gets trg_kan713_events_location: an events-first write of venue_id (the KAN-712 ops
--     path kan712_update_event_shared, or a direct postgres write) validates the pair and derives
--     geo_location_id / area_id from the venue exactly as the legacy trigger does; before KAN-713 that write
--     reached legacy with the old geo (the compat guard overwrote the legacy recomputation). Skipped while
--     the KAN-712 guard is routing a legacy write into events (that write's geo was computed on legacy).
-- UNCHANGED: sport guards (trg_games_inherit_sport_from_space, trg_games_require_challenge_sport,
-- trg_meetups_enforce_solo_sport), every search_tsv trigger, joining_rule/cost_cover vocabulary, every
-- other trigger. Old-trigger -> new-owner table: KAN713_CONTRACT.md "Trigger ownership".
--
-- ORDER. BEFORE row triggers fire alphabetically: trg_games_* / trg_meetups_* (legacy, incl. sport guards and
-- search_tsv), trg_kan711_*, then trg_kan713_* (a_location, b_joining, c_venue_geo -- the legacy relative order
-- inherit_geo, sync_joining, inherit_venue_geo kept), then trg_zz_kan712_* (the guard maps the final values).
-- search_tsv reads title/description/location_name only, so moving the location rules after it changes nothing.

BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL search_path = public, pg_catalog;

LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;

-- 1. Stage gate + preconditions ----------------------------------------------------------------------
DO $$
DECLARE
  v_bad text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-713: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  -- Separate IFs: the count query cannot even be planned until kan713_preimage exists.
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL OR to_regclass('public.kan713_preimage') IS NULL THEN
    RAISE EXCEPTION 'KAN-713: 20261104100000_kan713_access_helpers.sql must be applied first';
  END IF;
  IF (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'function') <> 5 THEN
    RAISE EXCEPTION 'KAN-713: 20261104100000_kan713_access_helpers.sql must be applied first (function pre-images incomplete)';
  END IF;
  IF to_regprocedure('public.kan713_games_location()') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: location triggers already applied';
  END IF;
  SELECT string_agg(n, ',') INTO v_bad
    FROM unnest(ARRAY['events.trg_zz_kan712_events_compat_mirror', 'games.trg_zz_kan712_games_guard',
                      'meetups.trg_zz_kan712_meetups_guard']) n
   WHERE NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
                      WHERE c.relnamespace = 'public'::regnamespace AND c.relname || '.' || t.tgname = n AND t.tgenabled = 'O');
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: KAN-712 stage B not live; missing or disabled: %', v_bad;
  END IF;
  -- The legacy triggers being replaced: present, enabled, attached as reviewed, bodies as reviewed.
  SELECT string_agg(x.tbl || '.' || x.tg || ' (' || coalesce(t.tgenabled::text, 'absent') || ', '
                    || coalesce(md5(p.prosrc), '-') || ')', '; ') INTO v_bad
    FROM (VALUES
      ('games',   'trg_games_inherit_geo',         'fn_games_inherit_geo',           '5814c38b75db828bf1e4e04a5a4830fa'),
      ('games',   'trg_games_inherit_venue_geo',   'trg_fn_games_inherit_venue_geo', '518dbad689be63eac3eb452d5ae17c48'),
      ('games',   'trg_games_sync_joining_rule',   'fn_games_sync_joining_rule',     'ce429c698d15b303793572cd6570afec'),
      ('meetups', 'trg_meetups_inherit_geo',       'fn_meetups_inherit_geo',         '9eb953007b7d9e707003192958434588'),
      ('meetups', 'trg_meetups_sync_joining_rule', 'fn_meetups_sync_joining_rule',   'ffbc58a3f6b12721e7182622981491a7')
    ) AS x(tbl, tg, fn, md5)
    LEFT JOIN pg_trigger t ON t.tgrelid = ('public.' || x.tbl)::regclass AND t.tgname = x.tg
    LEFT JOIN pg_proc p ON p.oid = t.tgfoid
   WHERE t.oid IS NULL OR t.tgenabled <> 'O' OR p.proname <> x.fn OR md5(p.prosrc) <> x.md5;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: legacy location trigger differs from the reviewed pre-image: %', v_bad;
  END IF;
END $$;

-- 2. Trigger pre-images (rollback input) --------------------------------------------------------------
DELETE FROM public.kan713_preimage WHERE kind = 'trigger';
INSERT INTO public.kan713_preimage (kind, object, definition, tg_enabled, pol_table)
SELECT 'trigger', c.relname || '.' || t.tgname, pg_get_triggerdef(t.oid), t.tgenabled, c.relname
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE c.relnamespace = 'public'::regnamespace
   AND (c.relname, t.tgname) IN (('games', 'trg_games_inherit_geo'), ('games', 'trg_games_inherit_venue_geo'),
                                 ('games', 'trg_games_sync_joining_rule'), ('meetups', 'trg_meetups_inherit_geo'),
                                 ('meetups', 'trg_meetups_sync_joining_rule'));

-- 3. games --------------------------------------------------------------------------------------------
-- a_location: Venue/Space validation + legacy fn_games_inherit_geo (baseline 20260829080500, verbatim in
-- the manifest). SECURITY INVOKER + search_path '' like the legacy (invoker) functions it replaces.
CREATE FUNCTION public.kan713_games_location() RETURNS trigger
  LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_geo_location_id uuid;
  v_area_id         uuid;
  v_space_found     boolean;
  v_space_venue     uuid;
  v_space_changed   boolean;
  v_venue_changed   boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    RETURN NEW;                                      -- KAN-712 compat write: the guard sets every shared field
  END IF;
  v_space_changed := TG_OP = 'INSERT' OR NEW.venue_space_id IS DISTINCT FROM OLD.venue_space_id;
  v_venue_changed := TG_OP = 'INSERT' OR NEW.venue_id IS DISTINCT FROM OLD.venue_id;

  -- Venue vs Space: only through venue_spaces.venue_id.
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT true, vs.venue_id INTO v_space_found, v_space_venue
      FROM public.venue_spaces vs WHERE vs.id = NEW.venue_space_id;
    IF v_space_found IS NULL THEN
      IF v_space_changed THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan713_space_not_found',
          DETAIL = format('games %s: venue_space_id %s does not exist', NEW.id, NEW.venue_space_id);
      END IF;
    ELSIF v_space_venue IS NOT NULL THEN
      IF NEW.venue_id IS NULL OR (v_space_changed AND NOT v_venue_changed) THEN
        NEW.venue_id := v_space_venue;               -- D-2: the venue follows the space
      ELSIF NEW.venue_id <> v_space_venue AND (v_space_changed OR v_venue_changed) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
          DETAIL = format('games %s: venue %s is not the venue (%s) of space %s', NEW.id, NEW.venue_id, v_space_venue, NEW.venue_space_id);
      END IF;
    END IF;
  END IF;

  -- legacy fn_games_inherit_geo, verbatim (names qualified)
  -- Priority 1: venue_space_id
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM public.venue_spaces  vs
      JOIN public.venues        v  ON v.id  = vs.venue_id
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE vs.id = NEW.venue_space_id;

  -- Priority 2: venue_id
  ELSIF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM public.venues        v
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = NEW.venue_id;
  END IF;

  IF v_geo_location_id IS NOT NULL THEN
    NEW.geo_location_id := v_geo_location_id;
    NEW.area_id         := v_area_id;
  END IF;

  RETURN NEW;
END $$;

-- b_joining: legacy fn_games_sync_joining_rule, verbatim.
CREATE FUNCTION public.kan713_games_joining() RETURNS trigger
  LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_joining_rule text;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    RETURN NEW;
  END IF;
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT vs.joining_rule INTO v_joining_rule
      FROM public.venue_spaces vs WHERE vs.id = NEW.venue_space_id;
    NEW.joining_rule := COALESCE(v_joining_rule, 'free');
    IF TG_OP = 'INSERT' THEN
      NEW.cost_cover := NEW.joining_rule;
    ELSIF TG_OP = 'UPDATE' AND OLD.joining_rule <> NEW.joining_rule THEN
      NEW.cost_cover := NEW.joining_rule;
    END IF;
  ELSE
    NEW.joining_rule := 'free';
    IF TG_OP = 'INSERT' THEN NEW.cost_cover := 'free'; END IF;
  END IF;
  RETURN NEW;
END $$;

-- c_venue_geo: legacy trg_fn_games_inherit_venue_geo, verbatim (the venue fill is now normally already
-- done by a_location; the COALESCEs make it a no-op then).
CREATE FUNCTION public.kan713_games_venue_geo() RETURNS trigger
  LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_venue_id     uuid;
  v_geo_id       uuid;
  v_area_id      uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    RETURN NEW;
  END IF;
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT v.id, v.geo_location_id, v.area_id
      INTO v_venue_id, v_geo_id, v_area_id
      FROM public.venue_spaces vs
      JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = NEW.venue_space_id;

    NEW.venue_id        := COALESCE(NEW.venue_id,        v_venue_id);
    NEW.geo_location_id := COALESCE(NEW.geo_location_id, v_geo_id);
    NEW.area_id         := COALESCE(NEW.area_id,         v_area_id);
  END IF;
  RETURN NEW;
END $$;

-- 4. meetups ------------------------------------------------------------------------------------------
-- a_location: legacy fn_meetups_inherit_geo, verbatim.
CREATE FUNCTION public.kan713_meetups_location() RETURNS trigger
  LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_geo_location_id uuid;
  v_area_id         uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    RETURN NEW;
  END IF;
  IF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM public.venues        v
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = NEW.venue_id;

    IF v_geo_location_id IS NOT NULL THEN
      NEW.geo_location_id := v_geo_location_id;
      NEW.area_id         := v_area_id;
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- b_joining: legacy fn_meetups_sync_joining_rule with D-1 fixed (space from meta only, validated against
-- the venue). A meta value that is not a uuid is treated as "no such space" instead of raising 22P02, so
-- an existing row carrying junk is not made un-updatable; a write that CHANGES it to junk is refused.
CREATE FUNCTION public.kan713_meetups_joining() RETURNS trigger
  LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_space_txt      text := NEW.meta->>'venue_space_id';
  v_venue_space_id uuid;
  v_joining_rule   text;
  v_space_found    boolean;
  v_space_venue    uuid;
  v_space_changed  boolean;
  v_venue_changed  boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    RETURN NEW;
  END IF;
  v_space_changed := TG_OP = 'INSERT' OR v_space_txt IS DISTINCT FROM (OLD.meta->>'venue_space_id');
  v_venue_changed := TG_OP = 'INSERT' OR NEW.venue_id IS DISTINCT FROM OLD.venue_id;
  IF v_space_txt ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    v_venue_space_id := v_space_txt::uuid;
    SELECT true, vs.venue_id, vs.joining_rule INTO v_space_found, v_space_venue, v_joining_rule
      FROM public.venue_spaces vs WHERE vs.id = v_venue_space_id;
  END IF;
  IF v_space_txt IS NOT NULL AND v_space_found IS NULL AND v_space_changed THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan713_space_not_found',
      DETAIL = format('meetups %s: meta.venue_space_id %s does not exist', NEW.id, v_space_txt);
  END IF;
  IF v_space_venue IS NOT NULL AND NEW.venue_id IS NOT NULL AND NEW.venue_id <> v_space_venue
     AND (v_space_changed OR v_venue_changed) THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
      DETAIL = format('meetups %s: venue %s is not the venue (%s) of space %s', NEW.id, NEW.venue_id, v_space_venue, v_venue_space_id);
  END IF;

  -- legacy body from here, verbatim
  IF v_venue_space_id IS NOT NULL THEN
    NEW.joining_rule := COALESCE(v_joining_rule, 'free');
    IF TG_OP = 'INSERT' THEN
      NEW.cost_cover := NEW.joining_rule;
    ELSIF TG_OP = 'UPDATE' AND OLD.joining_rule <> NEW.joining_rule THEN
      NEW.cost_cover := NEW.joining_rule;
    END IF;
  ELSE
    NEW.joining_rule := 'free';
    IF TG_OP = 'INSERT' THEN NEW.cost_cover := 'free'; END IF;
  END IF;
  RETURN NEW;
END $$;

-- 5. events: the events-first venue write -----------------------------------------------------------
-- SECURITY DEFINER: it reads games/meetups (FORCE RLS / grant-restricted) for the subtype's space.
CREATE FUNCTION public.kan713_events_location() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_space_txt   text;
  v_space_venue uuid;
  v_geo         uuid;
  v_area        uuid;
BEGIN
  -- The KAN-712 guard is routing a legacy write into events: geo was computed on the legacy row.
  IF pg_trigger_depth() > 1 AND coalesce(current_setting('kan712.routing', true), '') = NEW.id::text THEN
    RETURN NEW;
  END IF;
  IF NEW.venue_id IS NOT DISTINCT FROM OLD.venue_id OR NEW.venue_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.event_type = 'game' THEN
    SELECT vs.venue_id INTO v_space_venue
      FROM public.games g JOIN public.venue_spaces vs ON vs.id = g.venue_space_id
     WHERE g.id = NEW.id;
  ELSIF NEW.event_type = 'meetup' THEN
    SELECT m.meta->>'venue_space_id' INTO v_space_txt FROM public.meetups m WHERE m.id = NEW.id;
    IF v_space_txt ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      SELECT vs.venue_id INTO v_space_venue FROM public.venue_spaces vs WHERE vs.id = v_space_txt::uuid;
    END IF;
  END IF;
  IF v_space_venue IS NOT NULL AND v_space_venue <> NEW.venue_id THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
      DETAIL = format('events %s: venue %s is not the venue (%s) of the %s''s space', NEW.id, NEW.venue_id, v_space_venue, NEW.event_type);
  END IF;
  SELECT v.geo_location_id, gl.area_id INTO v_geo, v_area
    FROM public.venues v JOIN public.geo_locations gl ON gl.id = v.geo_location_id
   WHERE v.id = NEW.venue_id;
  IF v_geo IS NOT NULL THEN
    NEW.geo_location_id := v_geo;
    NEW.area_id         := v_area;
  END IF;
  RETURN NEW;
END $$;

-- Trigger functions need no EXECUTE to fire; nobody may call them directly.
REVOKE ALL ON FUNCTION public.kan713_games_location(), public.kan713_games_joining(), public.kan713_games_venue_geo(),
  public.kan713_meetups_location(), public.kan713_meetups_joining(), public.kan713_events_location()
  FROM PUBLIC, anon, authenticated, service_role;

-- 6. Swap owners -------------------------------------------------------------------------------------
CREATE TRIGGER trg_kan713_games_a_location BEFORE INSERT OR UPDATE OF venue_id, venue_space_id ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan713_games_location();
CREATE TRIGGER trg_kan713_games_b_joining BEFORE INSERT OR UPDATE OF venue_space_id ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan713_games_joining();
CREATE TRIGGER trg_kan713_games_c_venue_geo BEFORE INSERT OR UPDATE OF venue_space_id ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan713_games_venue_geo();
CREATE TRIGGER trg_kan713_meetups_a_location BEFORE INSERT OR UPDATE OF venue_id ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan713_meetups_location();
CREATE TRIGGER trg_kan713_meetups_b_joining BEFORE INSERT OR UPDATE OF venue_id, meta ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan713_meetups_joining();
CREATE TRIGGER trg_kan713_events_location BEFORE UPDATE OF venue_id ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.kan713_events_location();

ALTER TABLE public.games   DISABLE TRIGGER trg_games_inherit_geo;
ALTER TABLE public.games   DISABLE TRIGGER trg_games_inherit_venue_geo;
ALTER TABLE public.games   DISABLE TRIGGER trg_games_sync_joining_rule;
ALTER TABLE public.meetups DISABLE TRIGGER trg_meetups_inherit_geo;
ALTER TABLE public.meetups DISABLE TRIGGER trg_meetups_sync_joining_rule;

-- 7. Postconditions -------------------------------------------------------------------------------------
DO $$
DECLARE
  v_bad text;
BEGIN
  SELECT string_agg(x.tbl || '.' || x.tg || '=' || coalesce(t.tgenabled::text, 'absent'), ', ') INTO v_bad
    FROM (VALUES
      ('games', 'trg_games_inherit_geo', 'D'), ('games', 'trg_games_inherit_venue_geo', 'D'),
      ('games', 'trg_games_sync_joining_rule', 'D'), ('meetups', 'trg_meetups_inherit_geo', 'D'),
      ('meetups', 'trg_meetups_sync_joining_rule', 'D'),
      ('games', 'trg_kan713_games_a_location', 'O'), ('games', 'trg_kan713_games_b_joining', 'O'),
      ('games', 'trg_kan713_games_c_venue_geo', 'O'), ('meetups', 'trg_kan713_meetups_a_location', 'O'),
      ('meetups', 'trg_kan713_meetups_b_joining', 'O'), ('events', 'trg_kan713_events_location', 'O'),
      -- kept: sport guards, search_tsv, KAN-712 contract
      ('games', 'trg_games_inherit_sport_from_space', 'O'), ('games', 'trg_games_require_challenge_sport', 'O'),
      ('meetups', 'trg_meetups_enforce_solo_sport', 'O'), ('games', 'trg_games_search_tsv', 'O'),
      ('meetups', 'trg_meetups_search_tsv', 'O'), ('events', 'trg_events_search_tsv', 'O'),
      ('games', 'trg_zz_kan712_games_guard', 'O'), ('meetups', 'trg_zz_kan712_meetups_guard', 'O'),
      ('events', 'trg_zz_kan712_events_compat_mirror', 'O')
    ) AS x(tbl, tg, want)
    LEFT JOIN pg_trigger t ON t.tgrelid = ('public.' || x.tbl)::regclass AND t.tgname = x.tg
   WHERE t.tgenabled IS DISTINCT FROM x.want;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 postcondition: trigger state wrong: %', v_bad; END IF;
  -- new trigger functions: callable by nobody but the owner
  SELECT string_agg(p.proname, ', ') INTO v_bad
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('kan713_games_location', 'kan713_games_joining', 'kan713_games_venue_geo',
                       'kan713_meetups_location', 'kan713_meetups_joining', 'kan713_events_location')
     AND EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  WHERE a.grantee <> p.proowner);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 postcondition: trigger function executable by a non-owner: %', v_bad; END IF;
  IF (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'trigger') <> 5 THEN
    RAISE EXCEPTION 'KAN-713 postcondition: trigger pre-images incomplete';
  END IF;
END $$;

COMMIT;
