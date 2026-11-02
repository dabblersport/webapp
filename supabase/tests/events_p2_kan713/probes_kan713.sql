-- KAN-713 PROBES. LOCAL THROWAWAY POSTGRES ONLY. Run as postgres. One transaction, ROLLBACK at the end;
-- every probe additionally undoes itself (raised P0001 'kan713_undo' inside a subtransaction).
--
-- Output: one line per probe   PASS|<id>|<kind>|<observed>   or   FAIL|<id>|<kind>|observed=<x> want=<y>
--   kind K  = a KAN-713 behaviour. MUST FAIL on the pre-KAN-713 database (KAN-712 A+B only) and PASS after.
--   kind =  = an invariant. MUST PASS on both (equivalence: same values, same update counts).
--   kind E  = named-exception evidence (E-1, E-2): records the error, passes when the error is the known one.
-- Last line: #SUMMARY|pass=<n>|fail=<n>
--
-- Fixture (local_harness_kan713.sql seed): G-pub 71300000-...-0001 (public/open, a1's), M-pub ...-0101 (public/open, a1's);
-- venue ee01 -> geo d1 / area c1 (venue area c1), venue ee02 -> geo d2 / area c2; space ee12 in ee01 ('paid'),
-- space ee21 in ee02 ('members_only'), space ee11 in ee01 ('free').
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
SET LOCAL search_path = public, pg_catalog;
CREATE TEMP TABLE res (n serial, id text, kind text, got text, want text);

CREATE FUNCTION pg_temp.upd(p_rel text) RETURNS bigint LANGUAGE sql AS $$
  SELECT coalesce((SELECT n_tup_upd FROM pg_stat_xact_user_tables WHERE schemaname = 'public' AND relname = p_rel), 0) $$;
CREATE FUNCTION pg_temp.as_(p_role text, p_uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid, ''), true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
END $$;

-- ===== ACCESS: the events conjunct is real (fail-first for the permission matrix) =====================
-- With the compat mirror disabled, events is made NARROWER than legacy. Pre-KAN-713 every answer ignores
-- events (unchanged); after KAN-713 the narrower events answer wins. Each row is one cell of the matrix.
DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET listing_visibility = 'hidden' WHERE id = '71300000-0000-0000-0000-000000000101';
    PERFORM pg_temp.as_('anon', NULL);
    SELECT count(*)::text INTO r FROM public.meetups WHERE id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A1 anon reads M-pub when events says hidden (meetups_select_visible)', 'K', r, '0');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET listing_visibility = 'hidden' WHERE id = '71300000-0000-0000-0000-000000000101';
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a2');
    SELECT count(*)::text INTO r FROM public.meetup_attendees WHERE meetup_id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A2 a2 reads M-pub attendees when events says hidden (attendee policies)', 'K', r, '0');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a2',
                             creator_profile_id = '00000000-0000-0000-0000-0000000000b2'
     WHERE id = '71300000-0000-0000-0000-000000000101';
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a3');
    -- a3 is admin: can_write_row(legacy creator a1) is true for an admin, so to isolate the events conjunct use
    -- a5 (not the creator under either side, not admin): the write must stay refused; and a1 (legacy creator,
    -- no longer the events creator, not the attendee) must now be refused too.
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1');
    WITH u AS (UPDATE public.meetup_attendees SET status = status
                WHERE meetup_id = '71300000-0000-0000-0000-000000000101' RETURNING 1)
    SELECT count(*)::text INTO r FROM u;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A3 legacy creator a1 writes M-pub attendees when events names another creator (meetup_attendees_write)', 'K', r, '0');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET listing_visibility = 'private' WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM pg_temp.as_('service_role', '00000000-0000-0000-0000-0000000000a5');
    r := public.can_current_user_join_game('71300000-0000-0000-0000-000000000001', 'player', NULL)->>'reason';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A4 join G-pub when events says private (can_current_user_join_game)', 'K', r, 'visibility_denied');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET join_policy = 'request' WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM pg_temp.as_('service_role', '00000000-0000-0000-0000-0000000000a5');
    r := public.can_current_user_join_game('71300000-0000-0000-0000-000000000001', 'player', NULL)->>'reason';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A5 join G-pub when events join_policy disagrees (fail closed)', 'K', r, 'policy_mismatch');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET listing_visibility = 'hidden' WHERE id = '71300000-0000-0000-0000-000000000101';
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a5');
    r := public.can_current_user_rsvp_meetup('71300000-0000-0000-0000-000000000101', NULL)->>'reason';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A6 rsvp M-pub when events says hidden (can_current_user_rsvp_meetup)', 'K', r, 'visibility_denied');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a2',
                             creator_profile_id = '00000000-0000-0000-0000-0000000000b2'
     WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1');
    r := public._is_game_host('71300000-0000-0000-0000-000000000001')::text || ',' ||
         public._is_game_host('71300000-0000-0000-0000-000000000002')::text;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A7 _is_game_host: events creator disagrees on G-pub only', 'K', r, 'false,true');
END $$;

DO $$ DECLARE r text; BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET listing_visibility = 'private' WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a5');
    r := public._can_view_game('71300000-0000-0000-0000-000000000001')::text;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('A8 _can_view_game G-pub when events says private', 'K', r, 'false');
END $$;

-- [=] events stays closed to the API roles (both)
DO $$ DECLARE r text; BEGIN
  r := has_table_privilege('anon', 'public.events', 'SELECT')::text || ',' || has_table_privilege('authenticated', 'public.events', 'SELECT')::text
       || ',' || (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'events')::text
       || ',' || (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)::text;
  INSERT INTO res (id, kind, got, want) VALUES ('A9 events closed: anon/auth SELECT, policy count, FORCE RLS', '=', r, 'false,false,0,true');
END $$;

-- ===== LOCATION =========================================================================================
-- L1 [=] legacy write of a game's space: venue, geo, area, joining, cost_cover; events carries the same;
-- exactly one games and one events tuple update (no echo).
DO $$ DECLARE r text; g0 bigint; e0 bigint; BEGIN
  BEGIN
    g0 := pg_temp.upd('games'); e0 := pg_temp.upd('events');
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee21' WHERE id = '71300000-0000-0000-0000-000000000001';
    SELECT concat_ws(',', right(g.venue_id::text, 4), right(g.geo_location_id::text, 2), right(g.area_id::text, 2), g.joining_rule, g.cost_cover,
                     (e.venue_id, e.geo_location_id, e.area_id, e.joining_rule, e.cost_cover) IS NOT DISTINCT FROM (g.venue_id, g.geo_location_id, g.area_id, g.joining_rule, g.cost_cover),
                     'upd', pg_temp.upd('games') - g0, pg_temp.upd('events') - e0)
      INTO r FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '71300000-0000-0000-0000-000000000001';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L1 game space set (ee21)', '=', r, 'ee02,d2,c2,members_only,members_only,t,upd,1,1');
END $$;

-- L2 [=] INSERT path: a new game on a space (via the trusted path) inherits venue/geo/joining/cost_cover.
DO $$ DECLARE r text; BEGIN
  BEGIN
    INSERT INTO public.games (id, creator_profile_id, title, start_at, end_at, listing_visibility, join_policy, sport_id, capacity, venue_space_id)
    SELECT '71300000-0000-0000-0000-0000000007a1', g.creator_profile_id, 'probe insert', g.start_at, g.end_at, g.listing_visibility, g.join_policy,
           g.sport_id, g.capacity, '00000000-0000-0000-0000-00000000ee12'
      FROM public.games g WHERE g.id = '71300000-0000-0000-0000-000000000001';
    SELECT concat_ws(',', right(g.venue_id::text, 4), right(g.geo_location_id::text, 2), right(g.area_id::text, 2), g.joining_rule, g.cost_cover,
                     (e.venue_id, e.geo_location_id, e.joining_rule) IS NOT DISTINCT FROM (g.venue_id, g.geo_location_id, g.joining_rule))
      INTO r FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '71300000-0000-0000-0000-0000000007a1';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L2 game insert on space ee12', '=', r, 'ee01,d1,c1,paid,paid,t');
END $$;

-- L3 [K] D-2: change only the space -> the venue follows the space (legacy kept the old venue).
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee12' WHERE id = '71300000-0000-0000-0000-000000000001';
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee21' WHERE id = '71300000-0000-0000-0000-000000000001';
    SELECT concat_ws(',', right(g.venue_id::text, 4), right(e.venue_id::text, 4), right(g.geo_location_id::text, 2))
      INTO r FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '71300000-0000-0000-0000-000000000001';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L3 D-2 space change moves the venue', 'K', r, 'ee02,ee02,d2');
END $$;

-- L4 [K] invalid pair refused: venue ee01 with space ee21 (space belongs to ee02).
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.games SET venue_id = '00000000-0000-0000-0000-00000000ee01', venue_space_id = '00000000-0000-0000-0000-00000000ee21'
     WHERE id = '71300000-0000-0000-0000-000000000001';
    r := 'accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L4 game venue/space mismatch refused', 'K', r, 'ERR 23514 kan713_space_venue_mismatch');
END $$;

-- L5 [K] a space that does not exist is refused (games.venue_space_id has no FK).
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000dead' WHERE id = '71300000-0000-0000-0000-000000000001';
    r := 'accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L5 game unknown space refused', 'K', r, 'ERR 23503 kan713_space_not_found');
END $$;

-- L6 [=] a game venue write without a space: geo/area from the venue; joining untouched (trigger is OF venue_space_id).
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.games SET venue_id = '00000000-0000-0000-0000-00000000ee02' WHERE id = '71300000-0000-0000-0000-000000000002';
    SELECT concat_ws(',', right(g.venue_id::text, 4), right(g.geo_location_id::text, 2), right(g.area_id::text, 2), g.joining_rule, right(e.geo_location_id::text, 2))
      INTO r FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '71300000-0000-0000-0000-000000000002';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L6 game venue only (ee02)', '=', r, 'ee02,d2,c2,free,d2');
END $$;

-- L7 [=] meetup venue write: geo/area from the venue, joining 'free' (no space).
DO $$ DECLARE r text; m0 bigint; e0 bigint; BEGIN
  BEGIN
    m0 := pg_temp.upd('meetups'); e0 := pg_temp.upd('events');
    UPDATE public.meetups SET venue_id = '00000000-0000-0000-0000-00000000ee02' WHERE id = '71300000-0000-0000-0000-000000000101';
    SELECT concat_ws(',', right(m.geo_location_id::text, 2), right(m.area_id::text, 2), m.joining_rule, right(e.geo_location_id::text, 2),
                     'upd', pg_temp.upd('meetups') - m0, pg_temp.upd('events') - e0)
      INTO r FROM public.meetups m JOIN public.events e ON e.id = m.event_id WHERE m.id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L7 meetup venue only (ee02)', '=', r, 'd2,c2,free,d2,upd,1,1');
END $$;

-- L8 [K] D-1: a meetup with a venue AND a meta space takes joining_rule from the SPACE (legacy looked the
-- venue id up as a space id and always got 'free').
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.meetups SET venue_id = '00000000-0000-0000-0000-00000000ee02',
                              meta = jsonb_build_object('venue_space_id', '00000000-0000-0000-0000-00000000ee21')
     WHERE id = '71300000-0000-0000-0000-000000000101';
    SELECT concat_ws(',', m.joining_rule, m.cost_cover, e.joining_rule)
      INTO r FROM public.meetups m JOIN public.events e ON e.id = m.event_id WHERE m.id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L8 D-1 meetup joining from meta space', 'K', r, 'members_only,members_only,members_only');
END $$;

-- L9 [=] meetup with a meta space and NO venue: joining from the space (legacy path that already worked).
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.meetups SET meta = jsonb_build_object('venue_space_id', '00000000-0000-0000-0000-00000000ee12')
     WHERE id = '71300000-0000-0000-0000-000000000101';
    SELECT concat_ws(',', m.joining_rule, m.cost_cover) INTO r FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L9 meetup meta space only (ee12)', '=', r, 'paid,paid');
END $$;

-- L10 [K] meetup venue/space mismatch refused.
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.meetups SET venue_id = '00000000-0000-0000-0000-00000000ee01',
                              meta = jsonb_build_object('venue_space_id', '00000000-0000-0000-0000-00000000ee21')
     WHERE id = '71300000-0000-0000-0000-000000000101';
    r := 'accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L10 meetup venue/space mismatch refused', 'K', r, 'ERR 23514 kan713_space_venue_mismatch');
END $$;

-- L11 [=] an existing row carrying a dangling meta space (seed meetup 3...02, space aaaa) stays updatable by a
-- write that does not change venue or space.
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.meetups SET meta = meta WHERE id = '30000000-0000-0000-0000-000000000002';
    SELECT concat_ws(',', m.joining_rule, m.cost_cover) INTO r FROM public.meetups m WHERE m.id = '30000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L11 dangling meta space, unchanged, still updatable', '=', r, 'free,free');
END $$;

-- L12 [K] ops path (events first): kan712_update_event_shared patches venue_id -> events AND legacy get the
-- venue's geo/area; exactly one events and one games tuple update.
DO $$ DECLARE r text; g0 bigint; e0 bigint; BEGIN
  BEGIN
    g0 := pg_temp.upd('games'); e0 := pg_temp.upd('events');
    PERFORM public.kan712_update_event_shared('71300000-0000-0000-0000-000000000001', jsonb_build_object('venue_id', '00000000-0000-0000-0000-00000000ee02'));
    SELECT concat_ws(',', right(e.venue_id::text, 4), right(e.geo_location_id::text, 2), right(e.area_id::text, 2),
                     right(g.venue_id::text, 4), right(g.geo_location_id::text, 2), right(g.area_id::text, 2),
                     'upd', pg_temp.upd('games') - g0, pg_temp.upd('events') - e0)
      INTO r FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '71300000-0000-0000-0000-000000000001';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L12 ops venue patch derives geo on events and legacy', 'K', r, 'ee02,d2,c2,ee02,d2,c2,upd,1,1');
END $$;

-- L13 [K] ops path invalid pair: the game sits on space ee12 (venue ee01); patching venue ee02 is refused.
DO $$ DECLARE r text; BEGIN
  BEGIN
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee12' WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM public.kan712_update_event_shared('71300000-0000-0000-0000-000000000001', jsonb_build_object('venue_id', '00000000-0000-0000-0000-00000000ee02'));
    r := 'accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L13 ops venue patch contradicting the space refused', 'K', r, 'ERR 23514 kan713_space_venue_mismatch');
END $$;

-- L14 [K] ops path on a meetup: venue patch derives geo on events and the meetup; one update each.
DO $$ DECLARE r text; m0 bigint; e0 bigint; BEGIN
  BEGIN
    m0 := pg_temp.upd('meetups'); e0 := pg_temp.upd('events');
    PERFORM public.kan712_update_event_shared('71300000-0000-0000-0000-000000000101', jsonb_build_object('venue_id', '00000000-0000-0000-0000-00000000ee02'));
    SELECT concat_ws(',', right(e.geo_location_id::text, 2), right(m.geo_location_id::text, 2), right(m.area_id::text, 2),
                     'upd', pg_temp.upd('meetups') - m0, pg_temp.upd('events') - e0)
      INTO r FROM public.meetups m JOIN public.events e ON e.id = m.event_id WHERE m.id = '71300000-0000-0000-0000-000000000101';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L14 ops meetup venue patch derives geo', 'K', r, 'd2,d2,c2,upd,1,1');
END $$;

-- L15 [=] depth guard: a session-level kan712.compat = <id> at depth 1 does NOT make the location rules skip.
DO $$ DECLARE r text; BEGIN
  BEGIN
    PERFORM set_config('kan712.compat', '71300000-0000-0000-0000-000000000001', true);
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee21' WHERE id = '71300000-0000-0000-0000-000000000001';
    SELECT concat_ws(',', right(g.geo_location_id::text, 2), g.joining_rule) INTO r FROM public.games g WHERE g.id = '71300000-0000-0000-0000-000000000001';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L15 spoofed kan712.compat at depth 1 ignored', '=', r, 'd2,members_only');
END $$;

-- L16 [=] search_tsv unchanged by a location write (games and meetups).
DO $$ DECLARE r text; t1 tsvector; t2 tsvector; BEGIN
  BEGIN
    SELECT search_tsv INTO t1 FROM public.games WHERE id = '71300000-0000-0000-0000-000000000001';
    SELECT search_tsv INTO t2 FROM public.meetups WHERE id = '71300000-0000-0000-0000-000000000101';
    UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee21' WHERE id = '71300000-0000-0000-0000-000000000001';
    UPDATE public.meetups SET venue_id = '00000000-0000-0000-0000-00000000ee02' WHERE id = '71300000-0000-0000-0000-000000000101';
    SELECT concat_ws(',', (SELECT search_tsv = t1 FROM public.games WHERE id = '71300000-0000-0000-0000-000000000001'),
                          (SELECT search_tsv = t2 FROM public.meetups WHERE id = '71300000-0000-0000-0000-000000000101')) INTO r;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L16 search_tsv unchanged by location writes', '=', r, 't,t');
END $$;

-- L17 [=] KAN-712 contract still holds: a direct service_role shared write to games is refused.
DO $$ DECLARE r text; BEGIN
  BEGIN
    PERFORM pg_temp.as_('service_role', NULL);
    UPDATE public.games SET venue_id = '00000000-0000-0000-0000-00000000ee02' WHERE id = '71300000-0000-0000-0000-000000000001';
    r := 'accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('L17 direct service_role shared write still refused', '=', r, 'ERR 42501 kan712_direct_shared_write_refused');
END $$;

-- ===== NAMED EXCEPTIONS (evidence, before and after) ====================================================
-- E-1 rpc_booking_hold_for_meetup reads meetups.owner_user_id, which does not exist.
DO $$ DECLARE r text; BEGIN
  BEGIN
    PERFORM pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1');
    PERFORM public.rpc_booking_hold_for_meetup('71300000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-00000000ee12',
                                                now() + interval '2 days', now() + interval '2 days 1 hour');
    r := 'returned';
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('E-1 rpc_booking_hold_for_meetup', 'E', r, 'ERR 42703 record "m" has no field "owner_user_id"');
END $$;

-- E-2 can_current_user_join_game's invite branch reads game_invites.to_profile_id, which does not exist.
DO $$ DECLARE r text; BEGIN
  BEGIN
    -- G-pub made 'invite' through the trusted legacy path (KAN-712 routes it to events, so both agree);
    -- a5 can see G-pub, so the invite branch is reached. (G-pri itself is private, so no actor reaches it.)
    UPDATE public.games SET join_policy = 'invite' WHERE id = '71300000-0000-0000-0000-000000000001';
    PERFORM pg_temp.as_('service_role', '00000000-0000-0000-0000-0000000000a5');
    r := public.can_current_user_join_game('71300000-0000-0000-0000-000000000001', 'player', NULL)::text;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
  INSERT INTO res (id, kind, got, want) VALUES ('E-2 join invite branch', 'E', r, 'ERR 42703 column i.to_profile_id does not exist');
END $$;

SELECT CASE WHEN got IS NOT DISTINCT FROM want THEN 'PASS|' || id || '|' || kind || '|' || coalesce(got, '<null>')
            ELSE 'FAIL|' || id || '|' || kind || '|observed=' || coalesce(got, '<null>') || ' want=' || want END
  FROM res ORDER BY n;
SELECT '#SUMMARY|pass=' || count(*) FILTER (WHERE got IS NOT DISTINCT FROM want) || '|fail=' || count(*) FILTER (WHERE got IS DISTINCT FROM want) FROM res;
ROLLBACK;
