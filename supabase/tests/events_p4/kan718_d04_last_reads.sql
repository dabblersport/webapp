-- KAN-772 (KAN-718 D04): the last shared-field reads named by D01/D02 -- triage proof.
--
-- LOCAL DISPOSABLE DATABASE ONLY. The guard refuses any database whose name does not start with 'k772',
-- anything that looks like Supabase, and a non-superuser. Never point this at a hosted project.
--
-- What it proves (return-for-fix 1 adds migration 20261104110100_kan718_d04_last_shared_field_reads.sql; its
-- functions are T2-T4 and D01-D12 below; disposition of all 34 D01 open rows: KAN718_D04_DISPOSITION.md):
--   T0  each of the 12 D02 section-3 candidates is still the body that was reviewed on b7052576
--       (md5(prosrc)) with the same signature, result shape, SECURITY, volatility, search_path and ACL.
--       A later change to any of them fails here, and that means "re-triage", not "update the pin".
--   C*  each one FOLLOWS events: inside a rolled-back sub-transaction the events parent is diverged from its
--       legacy mirror (session_replication_role=replica, so the KAN-711/712 mirror and guard do not re-sync),
--       and the function returns / decides on the EVENTS value. Each check asserts the divergence really
--       happened (legacy still holds the old value), so a function that reads legacy fails the check.
--       Intersection helpers (KAN-713/731 "intersection, never wider") must narrow when events narrows.
--   N*  a stranger and a blocked user see nothing extra; seeded rows are not doubled; counts equal legacy.
--   T2-T4, D01-D12  the KAN-772 fix-1 conversions (same pattern; they FAIL on a chain without 20261104110100).
--   R   ROLLBACK leaves games / meetups / events / meetup_rsvps / notifications / venue_bookings / game_roster /
--       game_waitlist / profiles / areas and the whole public function catalogue byte-identical (md5).
-- Prerequisite for D09/D11: supabase/tests/events_p4/local_harness_kan772.sql (baseline-only functions and
-- profile columns the local chain lacks).
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
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_roster t) gr,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_waitlist t) gw,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.profiles t) pf,
       (SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.areas t) ar,
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

-- T2 (KAN-772 fix 1) the eight D01 "B15 open" functions converted by 20261104110100: present, same result shape
-- and SECURITY / volatility / search_path as the pre-image, and the body joins the typed events parent.
INSERT INTO k772_r
SELECT 'T2 ' || v.f,
       p.oid IS NOT NULL AND pg_get_function_result(p.oid) = v.res AND p.prosecdef = v.secdef AND p.provolatile = v.vol
         AND p.proconfig = array['search_path=public, pg_temp']
         AND regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~* 'public\.events e\s+on e\.id = [gm]\.event_id and e\.event_type = ''(game|meetup)''',
       'res=' || v.res || ' secdef=' || v.secdef || ' vol=' || v.vol || ' events_join=true',
       CASE WHEN p.oid IS NULL THEN 'absent' ELSE 'res=' || pg_get_function_result(p.oid) || ' secdef=' || p.prosecdef::text || ' vol=' || p.provolatile::text
            || ' events_join=' || (regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~* 'public\.events e\s+on e\.id = [gm]\.event_id and e\.event_type = ''(game|meetup)''') END
FROM (VALUES
  ('public._user_hosted_game(uuid,uuid)',         'boolean', false, 's'),
  ('public._recent_activity_score(uuid,integer)', 'numeric', false, 's'),
  ('public.game_is_joinable(uuid)',               'boolean', false, 's'),
  ('public.get_games_needing_players()',          'jsonb',   true,  'v'),
  ('public.get_open_games_for_seeding()',         'jsonb',   true,  'v'),
  ('public.meetup_counts(uuid)',                  'TABLE(going integer, interested integer, declined integer)', true, 'v'),
  ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)', 'uuid', true, 'v'),
  ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)', 'uuid', true, 'v')
) v(f, res, secdef, vol)
LEFT JOIN pg_proc p ON p.oid = to_regprocedure(v.f);

-- T3 the five SECURITY DEFINER conversions read no legacy shared column (comments stripped); the three INVOKER
-- ones keep it only in the no-events-privilege branch (KAN-727 pattern, retired with Z01).
INSERT INTO k772_r
SELECT 'T3 ' || p.oid::regprocedure::text || ' no legacy shared-column read',
       NOT (regexp_replace(p.prosrc, '--[^\n]*', '', 'g')
            ~* '\m[gm]\.(creator_user_id|creator_profile_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|request_id|sport_id|area_id|geo_location_id|venue_id|rsvp_policy)\M'),
       'true',
       (NOT (regexp_replace(p.prosrc, '--[^\n]*', '', 'g')
            ~* '\m[gm]\.(creator_user_id|creator_profile_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|request_id|sport_id|area_id|geo_location_id|venue_id|rsvp_policy)\M'))::text
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname IN ('get_games_needing_players', 'get_open_games_for_seeding', 'meetup_counts', 'rpc_create_game', 'rpc_create_meetup');

-- T4 rpc_rate_venue still reaches the converted host gate (so its D01 row is covered by D01/D02)
INSERT INTO k772_r
SELECT 'T4 rpc_rate_venue calls _user_hosted_game', coalesce(bool_or(prosrc ~ 'public\._user_hosted_game\('), false), 'true',
       coalesce(bool_or(prosrc ~ 'public\._user_hosted_game\(')::text, 'absent')
FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_rate_venue';

-- T5 rpc_challenge_spawn_game (D01 #13) reads no legacy row: games/meetups appear only as its INSERT target (the
-- KAN-712 guarded write path, unchanged); its `title` comes from public.challenges.
INSERT INTO k772_r
SELECT 'T5 rpc_challenge_spawn_game: games only as INSERT target, no legacy read',
       coalesce(bool_and(src ~* 'insert\s+into\s+public\.games\M' AND NOT src ~* '(from|join|update|delete\s+from)\s+(public\.)?(games|meetups)\M'), false),
       'true', coalesce(bool_and(src ~* 'insert\s+into\s+public\.games\M' AND NOT src ~* '(from|join|update|delete\s+from)\s+(public\.)?(games|meetups)\M')::text, 'absent')
FROM (SELECT regexp_replace(prosrc, '--[^\n]*', '', 'g') src FROM pg_proc
       WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_challenge_spawn_game') x;

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
  R2 uuid := '77200000-0000-0000-0000-0000000000e2';   -- a request_id written to events only
  ret uuid;
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

    -- =========================================================================================
    -- KAN-772 return-for-fix 1: the D01 "B15 open" functions converted by
    -- 20261104110100_kan718_d04_last_shared_field_reads.sql (D01-D12), and rpc_join_game (D13,
    -- no legacy shared read: proved, not changed). Same divergence pattern as C01-C13.
    -- =========================================================================================

    -- D01 _user_hosted_game (rpc_rate_venue's host gate): creator from events
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET creator_user_id = V WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := format('legacy_is_O=%s O=%s V=%s unknown=%s', (SELECT creator_user_id FROM public.games WHERE id = G) = O,
                    public._user_hosted_game(O, G), public._user_hosted_game(V, G),
                    public._user_hosted_game(O, '77200000-0000-0000-0000-0000000000ff'));
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D01 _user_hosted_game follows events creator_user_id', 'got', got,
      'want', 'legacy_is_O=t O=f V=t unknown=f');

    -- D02 _user_hosted_game called by a client role (no events grant): no 42501, pre-image answer
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SET LOCAL ROLE authenticated;
      -- the answer must equal the pre-image query run under the same role and RLS
      got := format('events_priv=%s O_same=%s V_same=%s', has_table_privilege('public.events', 'SELECT'),
                    public._user_hosted_game(O, G) IS NOT DISTINCT FROM EXISTS (SELECT 1 FROM public.games gx WHERE gx.id = G AND gx.creator_user_id = O),
                    public._user_hosted_game(V, G) IS NOT DISTINCT FROM EXISTS (SELECT 1 FROM public.games gx WHERE gx.id = G AND gx.creator_user_id = V));
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D02 _user_hosted_game as authenticated: no error, unchanged answer', 'got', got,
      'want', 'events_priv=f O_same=t V_same=t');

    -- D03 meetup_counts: the visibility gate follows events (stranger loses the counts, owner keeps them)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (M, V, '00000000-0000-0000-0000-0000000000b5', 'going');
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      SELECT 'before=' || concat_ws('/', c.going, c.interested, c.declined) INTO got FROM public.meetup_counts(M) c;
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET listing_visibility = 'hidden' WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT got || ' stranger_after=' || concat_ws('/', c.going, c.interested, c.declined) || ' rows=' || count(*) OVER ()
        INTO got FROM public.meetup_counts(M) c;
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT got || ' owner_after=' || concat_ws('/', c.going, c.interested, c.declined) INTO got FROM public.meetup_counts(M) c;
      got := got || ' legacy=' || (SELECT listing_visibility FROM public.meetups WHERE id = M);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D03 meetup_counts follows events listing_visibility; one row', 'got', got,
      'want', 'before=1/0/0 stranger_after=0/0/0 rows=1 owner_after=1/0/0 legacy=public');

    -- D04 meetup_counts: the blocked user sees no counts (events-only gate, before any divergence)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (M, V, '00000000-0000-0000-0000-0000000000b5', 'going');
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', B::text, true);
      SELECT concat_ws('/', c.going, c.interested, c.declined) INTO got FROM public.meetup_counts(M) c;
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D04 meetup_counts: blocked user sees 0/0/0', 'want', '0/0/0', 'got', got);

    -- D05 rpc_create_game: the idempotency lookup keys on events (creator_user_id, request_id)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      ret := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1',
                                    p_sport_variant_id => NULL, p_request_id => R2);
      got := format('legacy_req=%s served_seed=%s games_delta=%s', coalesce((SELECT request_id::text FROM public.games WHERE id = G), 'null'),
                    ret = G, (SELECT count(*) FROM public.games) - ng0);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D05 rpc_create_game replay served from events request_id; nothing created', 'got', got,
      'want', 'legacy_req=null served_seed=t games_delta=1');

    -- D06 rpc_create_game: another user replaying the same request_id is never served the seed
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      BEGIN
        ret := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1',
                                      p_sport_variant_id => NULL, p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN ret := NULL;
      END;
      got := 'served_seed=' || coalesce((ret = G)::text, 'false');
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D06 rpc_create_game: non-creator never served the seed', 'want', 'served_seed=false', 'got', got);

    -- D07 rpc_create_meetup: same, for meetups
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      ret := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1',
                                      p_sport_variant_id => NULL, p_title => 'D04 replay', p_request_id => R2);
      got := format('legacy_req=%s served_seed=%s meetups_delta=%s', coalesce((SELECT request_id::text FROM public.meetups WHERE id = M), 'null'),
                    ret = M, (SELECT count(*) FROM public.meetups) - nm0);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      BEGIN
        ret := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1',
                                        p_sport_variant_id => NULL, p_title => 'D04 replay', p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN ret := NULL;
      END;
      got := got || ' other_served_seed=' || coalesce((ret = M)::text, 'false');
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D07 rpc_create_meetup replay served from events request_id; non-creator never', 'got', got,
      'want', 'legacy_req=null served_seed=t meetups_delta=1 other_served_seed=false');

    -- D08 game_is_joinable: cancel state and start from events
    BEGIN
      got := 'before=' || public.game_is_joinable(G);
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' cancelled=' || public.game_is_joinable(G);
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = false, start_at = now() - interval '2 hours', end_at = now() - interval '1 hour' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' past=' || public.game_is_joinable(G) || ' unknown=' || coalesce(public.game_is_joinable('77200000-0000-0000-0000-0000000000ff')::text, 'null')
                 || ' legacy=' || (SELECT format('%s/%s', is_cancelled, start_at > now()) FROM public.games WHERE id = G);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D08 game_is_joinable follows events is_cancelled / start_at; unknown stays NULL', 'got', got,
      'want', 'before=true cancelled=false past=false unknown=null legacy=f/t');

    -- D09 _recent_activity_score: recency from events.start_at (user a7 has no other active roster row)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
      VALUES (G, '00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000b7', 'player', 'active');
      PERFORM set_config('session_replication_role', 'origin', true);
      got := 'other_rows=' || (SELECT count(*) FROM public.game_roster WHERE user_id = '00000000-0000-0000-0000-0000000000a7' AND game_id <> G AND status = 'active')
             || ' before=' || public._recent_activity_score('00000000-0000-0000-0000-0000000000a7', 30);
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET start_at = now() - interval '60 days', end_at = now() - interval '60 days' + interval '1 hour' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      got := got || ' after=' || public._recent_activity_score('00000000-0000-0000-0000-0000000000a7', 30)
                 || ' legacy_recent=' || (SELECT start_at >= now() - interval '30 days' FROM public.games WHERE id = G);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D09 _recent_activity_score follows events start_at', 'got', got,
      'want', 'other_rows=0 before=1.0 after=0.0 legacy_recent=true');

    -- D10 get_games_needing_players: capacity and cancel state from events; one element per game; keys unchanged
    BEGIN
      SELECT format('before_cap=%s n=%s keys=%s', max(j->>'capacity'), count(*),
                    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(min(j::text)::jsonb) k))
        INTO got FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET capacity = 7 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT got || format(' after_cap=%s spots=%s', max(j->>'capacity'), max(j->>'spots_remaining'))
        INTO got FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT got || ' cancelled_n=' || count(*) INTO got
        FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      got := got || ' legacy=' || (SELECT format('%s/%s', capacity, is_cancelled) FROM public.games WHERE id = G);
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D10 get_games_needing_players follows events capacity / is_cancelled; keys unchanged', 'got', got,
      'want', 'before_cap=10 n=1 keys=area_id,capacity,city,current_players,existing_profiles,game_id,sport_id,sport_key,spots_remaining after_cap=7 spots=7 cancelled_n=0 legacy=10/f');

    -- D11 get_open_games_for_seeding: area (and so city) from events; cancel from events; keys unchanged
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      INSERT INTO public.areas (id, name, city) VALUES ('77200000-0000-0000-0000-0000000000c9', 'K772 area', 'K772City');
      UPDATE public.profiles SET city = 'K772City', primary_sport = '00000000-0000-0000-0000-0000000000e1', is_original = false
       WHERE id = '00000000-0000-0000-0000-0000000000b5';
      UPDATE public.events SET area_id = '77200000-0000-0000-0000-0000000000c9' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT format('present=%s profile=%s keys=%s', count(*), max(j->>'profile_id'),
                    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(min(j::text)::jsonb) k))
        INTO got FROM jsonb_array_elements(public.get_open_games_for_seeding()) j WHERE j->>'game_id' = G::text;
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT got || ' cancelled=' || count(*) INTO got
        FROM jsonb_array_elements(public.get_open_games_for_seeding()) j WHERE j->>'game_id' = G::text;
      got := got || ' legacy_area_is_c1=' || ((SELECT area_id FROM public.games WHERE id = G) = '00000000-0000-0000-0000-0000000000c1');
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D11 get_open_games_for_seeding follows events area_id / is_cancelled; keys unchanged', 'got', got,
      'want', 'present=1 profile=00000000-0000-0000-0000-0000000000b5 keys=area_id,capacity,city,display_name,game_id,profile_id,sport_id,sport_key,start_at,user_id cancelled=0 legacy_area_is_c1=true');

    -- D12 rpc_join_game (D01 #18): no legacy shared read -- the slot decision follows events capacity
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET capacity = 2 WHERE id = G;
      INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES
        (G, '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active'),
        (G, '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'player', 'active');
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', V::text, true);
      SELECT format('legacy_cap=%s result=%s', (SELECT capacity FROM public.games WHERE id = G), j.result)
        INTO got FROM public.rpc_join_game('player', G, NULL) j;
      RAISE EXCEPTION 'k772_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k772_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('id', 'D12 rpc_join_game: events capacity full -> waitlisted (legacy capacity 10 ignored)', 'got', got,
      'want', 'legacy_cap=10 result=waitlisted');

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
FROM (SELECT (SELECT concat_ws(' ', left(g, 8), left(m, 8), left(e, 8), left(rs, 8), left(n, 8), left(vb, 8), left(gr, 8), left(gw, 8), left(pf, 8), left(ar, 8), left(fn, 8)) FROM k772_fp) fp_then,
             concat_ws(' ',
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.meetup_rsvps t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.notifications t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.venue_bookings t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_roster t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_waitlist t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.profiles t), 8),
               left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.areas t), 8),
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
