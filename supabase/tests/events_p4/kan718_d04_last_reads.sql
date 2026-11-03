-- KAN-772 (KAN-718 D04): the last shared-field reads named by D01/D02 -- triage proof.
--
-- LOCAL DISPOSABLE DATABASE ONLY. The guard refuses any database whose name does not start with 'k772',
-- anything that looks like Supabase, and a non-superuser. Never point this at a hosted project.
--
-- What it proves (no migration ships with KAN-772; see the triage in the KAN-772 hand-off):
--   T0  each of the 12 D02 section-3 candidates is still the body that was reviewed on b7052576
--       (md5(prosrc)) with the same signature, result shape, SECURITY, volatility, search_path and ACL.
--       A later change to any of them fails here, and that means "re-triage", not "update the pin".
--   C*  each one FOLLOWS events: inside a rolled-back sub-transaction the events parent is diverged from its
--       legacy mirror (session_replication_role=replica, so the KAN-711/712 mirror and guard do not re-sync),
--       and the function returns / decides on the EVENTS value. Each check asserts the divergence really
--       happened (legacy still holds the old value), so a function that reads legacy fails the check.
--       Intersection helpers (KAN-713/731 "intersection, never wider") must narrow when events narrows.
--   N*  a stranger and a blocked user see nothing extra; seeded rows are not doubled; counts equal legacy.
--   R   ROLLBACK leaves games / meetups / events / meetup_rsvps / notifications / venue_bookings and the
--       whole public function catalogue byte-identical (md5).
--
-- Seed: one game and one meetup through the legacy INSERT path (as KAN-770 D02 part B), ids 77200000-*.
-- Run:  psql -X -h <socket> -p <port> -U postgres -d k772<...> -v ON_ERROR_STOP=1 -f kan718_d04_last_reads.sql
-- Exit: 0 and 'KAN-772 TOTAL pass=N fail=0' on success; any failed check raises 'KAN-772 test FAILED'.
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k772%' THEN
    RAISE EXCEPTION 'KAN-772: refusing database %: local disposable k772* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-772: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-772: run as a superuser (session_replication_role and RLS-free counts need it)';
  END IF;
END $g$;

-- Reviewed definitions (b70525761b1575bb768feb0abace1403abb108df chain, clean772.sh).
CREATE TEMP TABLE k772_pin(fn regprocedure, src_md5 text, sig_md5 text);
INSERT INTO k772_pin
SELECT to_regprocedure(f), s, g FROM (VALUES
 ('public._can_view_game(uuid)',                                     '7ee01526ff64e59691ada52fa77474ce', 'a3f51607a81bf361b14956c143fd1b18'),
 ('public._can_view_game_for_join(uuid)',                            '11d7002d7bfa391a8f81c79dcf28e51c', 'ad5e1bd29e1ff77aa36312b7e9af7d7e'),
 ('public._is_game_host(uuid)',                                      '6db7b07bf7cf405d6935ecbf7bc15800', 'a3f51607a81bf361b14956c143fd1b18'),
 ('public.active_stream(text[],text,integer,timestamptz,text,uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', 'dd951aaf358de8e0b208354a8452640f'),
 ('public.admin_cleanup_user_data(uuid,boolean)',                    '09baee67932be2618af9043c89155db2', '2c0e09ffe1a71ec8da632fb34305f90f'),
 ('public.can_current_user_join_game(uuid,text,uuid)',               'c26ddc863eb05995224c7edb6e57f956', 'fbc49451b9ad722629065c74ab09ca0d'),
 ('public.can_current_user_rsvp_meetup(uuid,uuid)',                  'c88d88bb660071e03f0ec8785a767924', 'bebed247e5466905c8944afc46ffb820'),
 ('public.game_slots_left(uuid)',                                    'bd773c6f559b9692753fdfccd1eee959', '1fc20e93525e8d159d9a5e33f76cf4e7'),
 ('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)', '0b7e53391b2a44007316d42036d95134', '0e176101943ad092b8374d2577892707'),
 ('public.rpc_get_activity_feed(text,integer,timestamptz)',          '1d6bb17983ba2ed632cb4f7602257162', 'e53a7dfa1eabcbab3a9835a2374de083'),
 ('public.rpc_meetup_card(uuid,text)',                               'c63da3eae7caced992bca253b712067d', 'f0dd0e76302d0874c39dc30354209033'),
 ('public.trg_meetup_rsvps_notify()',                                'a22ed63dec19a237b005e30e9c038dc1', '72ae2bb5f03f194cf975e370b8a08ce7')
) v(f, s, g);

CREATE TEMP TABLE k772_r(id text, ok boolean, want text, got text);

-- Fingerprints before the scenario.
CREATE TEMP TABLE k772_fp AS
SELECT (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t) g,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t) m,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t) e,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.meetup_rsvps t) rs,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.notifications t) n,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.venue_bookings t) vb,
       (SELECT md5(string_agg(p.oid::regprocedure::text || md5(pg_get_functiondef(p.oid)) || coalesce(p.proacl::text, ''), '|'
                   ORDER BY p.oid::regprocedure::text))
          FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f') fn;

-- ---------------------------------------------------------------------------------------------
-- T0 triage pins
-- ---------------------------------------------------------------------------------------------
INSERT INTO k772_r
SELECT 'T0 ' || coalesce(k.fn::text, '(missing)'),
       p.oid IS NOT NULL AND md5(p.prosrc) = k.src_md5
         AND md5(concat_ws('|', pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef,
                           p.provolatile, p.proconfig::text, p.proacl::text)) = k.sig_md5,
       'src=' || k.src_md5 || ' sig=' || k.sig_md5,
       CASE WHEN p.oid IS NULL THEN 'absent'
            ELSE 'src=' || md5(p.prosrc) || ' sig=' || md5(concat_ws('|', pg_get_function_identity_arguments(p.oid),
                 pg_get_function_result(p.oid), p.prosecdef, p.provolatile, p.proconfig::text, p.proacl::text)) END
FROM k772_pin k LEFT JOIN pg_proc p ON p.oid = k.fn;

-- T1 each reviewed body joins the events parent by the subtype's event_id (comments stripped).
INSERT INTO k772_r
SELECT 'T1 ' || p.oid::regprocedure::text || ' joins events by event_id',
       regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~* 'public\.events\s+(\w+\s+)?(on|where)\s+\w*\.?id\s*=\s*\w+\.event_id',
       'true', (regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~* 'public\.events\s+(\w+\s+)?(on|where)\s+\w*\.?id\s*=\s*\w+\.event_id')::text
FROM k772_pin k JOIN pg_proc p ON p.oid = k.fn;

-- ---------------------------------------------------------------------------------------------
-- Scenario. Everything below runs inside one sub-transaction that is rolled back on purpose; each
-- check runs in its own nested sub-transaction so its divergence is undone before the next check.
-- ---------------------------------------------------------------------------------------------
DO $s$
DECLARE
  O  uuid := '00000000-0000-0000-0000-0000000000a1';   -- owner (profile b1)
  V  uuid := '00000000-0000-0000-0000-0000000000a5';   -- unrelated player (profile b5)
  B  uuid := '00000000-0000-0000-0000-0000000000a6';   -- blocked by the owner (KAN-713 harness user_blocks)
  G  uuid := '77200000-0000-0000-0000-000000000001';
  M  uuid := '77200000-0000-0000-0000-00000000f001';
  EVT text := 'D04 events title';
  res jsonb := '[]';
  got text; want text; n bigint; x text; ng0 bigint; nm0 bigint; ne0 bigint;
BEGIN
  BEGIN
    SELECT count(*) INTO ng0 FROM public.games;
    SELECT count(*) INTO nm0 FROM public.meetups;
    SELECT count(*) INTO ne0 FROM public.events;

    INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                              join_policy, sport_id, geo_location_id, area_id)
    VALUES (G, 'D04 game legacy', '00000000-0000-0000-0000-0000000000b1', O, '2031-02-01 18:00+00', '2031-02-01 19:00+00',
            10, 'public', 'open', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1',
            '00000000-0000-0000-0000-0000000000c1');
    INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(src) || jsonb_build_object(
        'id', M, 'event_id', NULL, 'request_id', NULL, 'title', 'D04 meetup legacy',
        'start_at', '2031-02-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public', 'created_at', now(), 'updated_at', now()))).*
      FROM public.meetups src WHERE src.id = '71300000-0000-0000-0000-000000000101';

    -- N1 not doubled / counts equal legacy
    got := format('events=%s eid_eq_id=%s dup=%s dg=%s dm=%s de=%s pergame=%s permeetup=%s',
      (SELECT count(*) FROM public.events WHERE id IN (G, M)),
      (SELECT count(*) FROM public.games WHERE id = G AND event_id = id) + (SELECT count(*) FROM public.meetups WHERE id = M AND event_id = id),
      (SELECT count(*) - count(DISTINCT id) FROM public.events),
      (SELECT count(*) FROM public.games) - ng0, (SELECT count(*) FROM public.meetups) - nm0, (SELECT count(*) FROM public.events) - ne0,
      (SELECT count(*) FROM public.games) = (SELECT count(*) FROM public.events WHERE event_type = 'game'),
      (SELECT count(*) FROM public.meetups) = (SELECT count(*) FROM public.events WHERE event_type = 'meetup'));
    res := res || jsonb_build_object('id', 'N1 seed: one events parent each, not doubled, counts equal legacy',
      'want', 'events=2 eid_eq_id=2 dup=0 dg=1 dm=1 de=2 pergame=t permeetup=t', 'got', got);

    -- C01 rpc_meetup_card reads title/start_at from events (shape and key names unchanged)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET title = EVT, start_at = '2031-02-03 18:00+00' WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT format('legacy=%s card.title=%s card.start=%s keys=%s', mt.title, c->>'title', (c->>'start_at')::timestamptz AT TIME ZONE 'UTC',
                    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(c) k))
        INTO got FROM public.meetups mt, public.rpc_meetup_card(M, 'player') c WHERE mt.id = M;
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C01 rpc_meetup_card follows events (title, start_at); keys unchanged', 'got', got,
      'want', 'legacy=D04 meetup legacy card.title=D04 events title card.start=2031-02-03 18:00:00 keys=area_name,attendees,capacity,counts,description,end_at,host,id,is_cancelled,is_host,location_name,max_skill,min_skill,my_status,owner_profile_id,sport_key,sport_name_ar,sport_name_en,start_at,title,venue_name,visibility');

    -- N2 rpc_meetup_card: the blocked user gets nothing
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', B::text, true);
      got := 'returned ' || left(public.rpc_meetup_card(M, 'player')::text, 40);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'N2 rpc_meetup_card refuses the blocked user', 'want', 'ERR P0001 not_allowed', 'got', got);

    -- C02 trg_meetup_rsvps_notify: the host notification carries the events title
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET title = EVT WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (M, V, '00000000-0000-0000-0000-0000000000b5', 'pending');
      SELECT format('legacy=%s notified=%s body=%s', (SELECT title FROM public.meetups WHERE id = M), count(*), string_agg(nt.body, ','))
        INTO got FROM public.notifications nt WHERE nt.user_id = O AND nt.entity_id = M AND nt.kind = 'meetup.request_received';
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C02 trg_meetup_rsvps_notify uses the events title, one notification', 'got', got,
      'want', 'legacy=D04 meetup legacy notified=1 body=D04 events title');

    -- C03 active_stream: game_created / meetup_created titles from events, one row each
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET title = EVT WHERE id IN (G, M);
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT format('legacy=%s rows=%s titles=%s', (SELECT title FROM public.games WHERE id = G), count(*), string_agg(DISTINCT s.title, ','))
        INTO got FROM public.active_stream(ARRAY['game_created', 'meetup_created'], NULL, 50) s WHERE s.entity_id IN (G, M);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C03 active_stream follows events title; one row per entity', 'got', got,
      'want', 'legacy=D04 game legacy rows=2 titles=D04 events title');

    -- N3 active_stream: the blocked user sees neither seeded entity
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', B::text, true);
      SELECT 'rows=' || count(*) INTO got FROM public.active_stream(NULL, NULL, 50) s WHERE s.entity_id IN (G, M);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'N3 active_stream shows the blocked user nothing seeded', 'want', 'rows=0', 'got', got);

    -- C04 rpc_get_activity_feed: scheduled_for from events.start_at; rows equal the legacy count
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET start_at = '2031-03-01 18:00+00', end_at = '2031-03-01 19:00+00' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT format('legacy=%s rows=%s sched=%s total=%s legacy_total=%s',
                    (SELECT start_at AT TIME ZONE 'UTC' FROM public.games WHERE id = G),
                    count(*) FILTER (WHERE f.subject_id = G), max(f.scheduled_for) FILTER (WHERE f.subject_id = G) AT TIME ZONE 'UTC',
                    count(*) FILTER (WHERE f.verb = 'created'),
                    (SELECT count(*) FROM public.games g2 WHERE g2.creator_user_id = O AND NOT g2.is_cancelled))
        INTO got FROM public.rpc_get_activity_feed('all', 100000, NULL) f;
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    SELECT format('legacy=2031-02-01 18:00:00 rows=1 sched=2031-03-01 18:00:00 total=%1$s legacy_total=%1$s',
                  (SELECT count(*) FROM public.games g2 WHERE g2.creator_user_id = O AND NOT g2.is_cancelled)) INTO want;
    res := res || jsonb_build_object('id', 'C04 rpc_get_activity_feed follows events start_at; created rows = legacy count', 'want', want, 'got', got);

    -- C05 game_slots_left: capacity from events (caller with events SELECT -- the SECURITY DEFINER callers)
    BEGIN
      SELECT count(*) INTO n FROM public.game_roster r JOIN public.games g2 ON g2.id = r.game_id
       WHERE r.game_id = G AND r.status = 'active' AND (r.role = 'player' OR (r.role = 'host' AND g2.game_type = 'hosted'));
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET capacity = 7 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := format('legacy_cap=%s slots=%s expected=%s', (SELECT capacity FROM public.games WHERE id = G), public.game_slots_left(G), greatest(7 - n, 0));
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    x := split_part(got, 'expected=', 2);
    res := res || jsonb_build_object('id', 'C05 game_slots_left follows events capacity', 'want', 'legacy_cap=10 slots=' || x || ' expected=' || x, 'got', got);

    -- C06 rpc_booking_hold_for_meetup: authority from events.creator_user_id (legacy creator is refused)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET creator_user_id = V WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      got := 'legacy creator allowed: ' || public.rpc_booking_hold_for_meetup(M, '00000000-0000-0000-0000-00000000ee11', '2031-02-02 18:00+00', '2031-02-02 19:00+00');
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C06 rpc_booking_hold_for_meetup refuses the legacy-only creator', 'want', 'ERR P0001 not_authorized', 'got', got);
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET creator_user_id = V WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      PERFORM public.rpc_booking_hold_for_meetup(M, '00000000-0000-0000-0000-00000000ee11', '2031-02-02 18:00+00', '2031-02-02 19:00+00');
      SELECT 'held=' || count(*) INTO got FROM public.venue_bookings WHERE source_type = 'meetup' AND source_id = M;
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C07 rpc_booking_hold_for_meetup allows the events creator', 'want', 'held=1', 'got', got);

    -- C08 _is_game_host: both must agree; events disagreeing makes the legacy host not a host
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      got := 'before=' || public._is_game_host(G);
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET creator_user_id = V WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' after=' || public._is_game_host(G) || ' legacy_creator_is_O=' || ((SELECT creator_user_id FROM public.games WHERE id = G) = O);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C08 _is_game_host follows events (intersection)', 'want', 'before=true after=false legacy_creator_is_O=true', 'got', got);

    -- C09/C10 _can_view_game and _can_view_game_for_join narrow when events visibility narrows
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      got := format('before=%s/%s', public._can_view_game(G), public._can_view_game_for_join(G));
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET listing_visibility = 'private' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || format(' after=%s/%s legacy=%s', public._can_view_game(G), public._can_view_game_for_join(G),
                           (SELECT listing_visibility FROM public.games WHERE id = G));
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C09 _can_view_game / _can_view_game_for_join follow events visibility (intersection)',
      'want', 'before=t/t after=f/f legacy=public', 'got', got);

    -- N4 the blocked user cannot view the game, before any divergence
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', B::text, true);
      got := format('%s/%s', public._can_view_game(G), public._can_view_game_for_join(G));
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'N4 blocked user: _can_view_game / _for_join false', 'want', 'f/f', 'got', got);

    -- C11 can_current_user_join_game: events.is_cancelled decides
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      got := 'before=' || (public.can_current_user_join_game(G, 'player', NULL)->>'cta');
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' after=' || (public.can_current_user_join_game(G, 'player', NULL)->>'cta')
                 || ' legacy_cancelled=' || (SELECT is_cancelled FROM public.games WHERE id = G);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C11 can_current_user_join_game follows events is_cancelled', 'want', 'before=join after=cancelled legacy_cancelled=false', 'got', got);

    -- C12 can_current_user_rsvp_meetup: events.is_cancelled decides; N5 blocked user not visible
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      got := 'before=' || (public.can_current_user_rsvp_meetup(M, NULL)->>'cta');
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' after=' || (public.can_current_user_rsvp_meetup(M, NULL)->>'cta')
                 || ' legacy_cancelled=' || (SELECT is_cancelled FROM public.meetups WHERE id = M);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'C12 can_current_user_rsvp_meetup follows events is_cancelled', 'want', 'before=rsvp_going after=cancelled legacy_cancelled=false', 'got', got);
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', B::text, true);
      got := public.can_current_user_rsvp_meetup(M, NULL)->>'cta';
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'N5 blocked user: can_current_user_rsvp_meetup not_visible', 'want', 'not_visible', 'got', got);

    -- C13 admin_cleanup_user_data: the games delete is keyed on events.creator_profile_id (structural; the
    -- function deletes across every user_id/profile_id table, so it is not executed here)
    got := (SELECT (regexp_replace(prosrc, '--[^\n]*', '', 'g') ~* 'DELETE FROM public\.games g\s+USING public\.events e\s+WHERE e\.id = g\.event_id AND e\.event_type = ''game''\s+AND e\.creator_profile_id = v_profile_id')::text
              FROM pg_proc WHERE oid = to_regprocedure('public.admin_cleanup_user_data(uuid,boolean)'));
    res := res || jsonb_build_object('id', 'C13 admin_cleanup_user_data deletes games by events.creator_profile_id (structural)', 'want', 'true', 'got', coalesce(got, 'absent'));

    RAISE EXCEPTION 'k772_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k772_undo' THEN
      res := res || jsonb_build_object('id', 'SCENARIO aborted', 'want', 'no error', 'got', 'ERR ' || SQLSTATE || ' ' || SQLERRM);
    END IF;
  END;
  INSERT INTO k772_r SELECT r->>'id', (r->>'got') IS NOT DISTINCT FROM (r->>'want'), r->>'want', r->>'got' FROM jsonb_array_elements(res) r;
END $s$;

-- R rollback leaves data and the public function catalogue intact
INSERT INTO k772_r
SELECT 'R  data + function catalogue md5 identical after the scenario', f.fp_now = f.fp_then, f.fp_then, f.fp_now
FROM (SELECT (SELECT concat_ws(' ', left(g, 8), left(m, 8), left(e, 8), left(rs, 8), left(n, 8), left(vb, 8), left(fn, 8)) FROM k772_fp) fp_then,
             concat_ws(' ',
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.meetup_rsvps t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.notifications t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.venue_bookings t), 8),
               left((SELECT md5(string_agg(p.oid::regprocedure::text || md5(pg_get_functiondef(p.oid)) || coalesce(p.proacl::text, ''), '|'
                       ORDER BY p.oid::regprocedure::text)) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'), 8)) fp_now) f;

DO $t$
DECLARE r record; p int := 0; f int := 0;
BEGIN
  FOR r IN SELECT * FROM k772_r ORDER BY id LOOP
    IF r.ok THEN p := p + 1; RAISE NOTICE 'KAN-772 PASS %: %', r.id, r.got;
    ELSE f := f + 1; RAISE NOTICE 'KAN-772 FAIL %: want=[%] got=[%]', r.id, r.want, r.got; END IF;
  END LOOP;
  RAISE NOTICE 'KAN-772 TOTAL pass=% fail=%', p, f;
  IF f > 0 THEN RAISE EXCEPTION 'KAN-772 test FAILED (% of % checks)', f, p + f; END IF;
END $t$;
