-- KAN-976 [W0-3] event change signal: live test. Run as postgres on wtncuzcskpigqpmnxwws, the whole file in one
-- session (it uses a pg_temp results table). Nothing persists: every write happens inside a sub-block that ends by
-- raising 'kan976_rollback', which rolls the sub-block back; only the results survive (plpgsql variables).
-- Test rows are picked live, no hard-coded ids:
--   G  a game that is not cancelled, has a venue, no series and no venue space (so kan713 / kan718 do not interfere)
--   V2 another active venue with a geo location (for the venue move)
--   M  a meetup that is not cancelled, has a venue and no venue space
--   A  a game without a venue (its area drives event_timezone)
--   F  a meetup without venue and without area (fallback)
-- Expected: every row of the final SELECT has pass = true.
-- N1 is the negative control: with the trigger disabled (inside the rolled-back block) the same start_at move writes
-- no row and does not bump, so the P1 predicate would be false. N1 passes when that happens.
--
-- Run 2026-11-17 by backend-3 (Shed):
--   Before apply: C1 false, C2 12 triggers / no kan976, outbox and event_timezone absent; block B fails with 42703
--   (record "g" has no field "schedule_revision"). Cancel baseline on G: roster 1, notifications +1.
--   After apply of 20261117045201: all 25 rows pass (C1-C5, P1-P12, T1-T6, N1, R). G = 3f7d280f-e27a-4b5f-93b7-60f9206014a3,
--   M = 22c9b070-da8f-4c2d-b898-6391f42dc187. P5 venue move wrote area_id, geo_location_id, venue_id in one group, rev +1.
--   P8 cancel: notifications +1 for roster 1 (same as the baseline). Afterwards event_changes held 0 rows and every
--   events.schedule_revision was 0 (nothing persisted).
--
-- KAN-976b (PEER 16410, migration 20261117053118) added S1, S2, N2 and T7.
--   Before the fix: S1 false (ACL {postgres=rwU,anon=rwU,authenticated=rwU,service_role=rwU}); T7 returned 'UTC+4'.
--   After the fix, 2026-11-17: all 29 rows pass. S1 ACL {postgres=rwU,service_role=rwU}; S2 42501; N2 grant to anon ->
--   S1 predicate false, true again after rollback; T7 'UTC+4' -> Asia/Qatar (area map).
--
-- KAN-976c (PEER 16414, migration 20261117054042) replaced the pg_timezone_names lookup with a shape check plus a
-- guarded AT TIME ZONE probe, and added the zone table T1, T2, T7-T15, the P13 timing assert and the N3 control.
--   Before the fix: 315 event_timezone calls took 16848 ms (P13 false).
--   After the fix, 2026-11-17: all 39 rows pass. P13 315 calls = 79.0 ms; N3 (kan976b body) = 16499.9 ms.
--   Zones: Asia/Tokyo, UTC, America/Argentina/Buenos_Aires and '  Asia/Tokyo ' (trimmed) are accepted. Mars/Olympus,
--   UTC+4, GST, +04, asia/tokyo, '' and EST5EDT fall through to the area map (Asia/Qatar).
--
-- KAN-976d (review 16424, migration 20261117055656) tightened the shape to ^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$
-- in event_timezone and in CHECK venues_timezone_shape_chk. Added T16-T20, the Z layer (what venues can store), Z0 and
-- the N4 control. The T layer drops the CHECK inside the rolled-back block so the function's own check is exercised.
--   Run 2026-11-17 after apply: all 62 rows pass. N4: under the kan976c shape, 'Asia/Dubai+4' and 'Etc/GMT+4' matched
--   and AT TIME ZONE accepted both, so the old function returned them. Now T16-T18 -> Asia/Qatar and Z16-Z18 are
--   refused (23514). Port-au-Prince and North_Dakota/New_Salem are accepted at both layers.
--   P13 = 563.5 ms this run (79.0 ms the run before), N3 = 21223.7 ms.

CREATE TEMP TABLE IF NOT EXISTS kan976_results (probe text, pass boolean, detail text);
TRUNCATE kan976_results;

-- C: catalogue and grants (read-only) ---------------------------------------------------------------------------------
INSERT INTO kan976_results
SELECT 'C1 column', count(*) = 1, string_agg(data_type || ' null=' || is_nullable || ' default=' || column_default, ';')
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'events' AND column_name = 'schedule_revision'
   AND data_type = 'integer' AND is_nullable = 'NO' AND column_default = '0';

INSERT INTO kan976_results
SELECT 'C2 one new BEFORE UPDATE trigger, 13 total', count(*) = 13 AND bool_or(tgname = 'trg_kan976_events_change_signal'
         AND (tgtype & 2) = 2 AND (tgtype & 16) = 16 AND tgenabled = 'O'), count(*)::text
  FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal;

INSERT INTO kan976_results
SELECT 'C3 outbox server only',
       relrowsecurity
   AND NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = c.oid)
   AND NOT has_table_privilege('anon', c.oid, 'SELECT') AND NOT has_table_privilege('anon', c.oid, 'INSERT')
   AND NOT has_table_privilege('anon', c.oid, 'UPDATE') AND NOT has_table_privilege('anon', c.oid, 'DELETE')
   AND NOT has_table_privilege('authenticated', c.oid, 'SELECT') AND NOT has_table_privilege('authenticated', c.oid, 'INSERT')
   AND NOT has_table_privilege('authenticated', c.oid, 'UPDATE') AND NOT has_table_privilege('authenticated', c.oid, 'DELETE')
   AND has_table_privilege('service_role', c.oid, 'SELECT') AND has_table_privilege('service_role', c.oid, 'UPDATE'),
       coalesce(relacl::text, '<null>')
  FROM pg_class c WHERE c.oid = 'public.event_changes'::regclass;

INSERT INTO kan976_results
SELECT 'C4 function attributes and ACL',
       bool_and(p.prosecdef AND p.proconfig = ARRAY['search_path=""']
                AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
                AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE'))
   AND bool_and(p.proname <> 'event_timezone' OR (p.provolatile = 's' AND has_function_privilege('service_role', p.oid, 'EXECUTE'))),
       string_agg(p.proname || ' ' || coalesce(p.proacl::text, '<null>'), '; ')
  FROM pg_proc p
 WHERE p.oid IN ('public.event_timezone(uuid)'::regprocedure, 'public.kan976_events_change_signal()'::regprocedure);

-- C5 a client session cannot read the outbox (42501), proved by switching role.
DO $c5$
DECLARE v_ok boolean := false; v_err text;
BEGIN
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM 1 FROM public.event_changes LIMIT 1;
    v_err := 'read succeeded';
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true; v_err := SQLSTATE;
  END;
  RESET ROLE;
  INSERT INTO pg_temp.kan976_results VALUES ('C5 authenticated SELECT event_changes -> 42501', v_ok, v_err);
END $c5$;

-- S: the outbox sequence (KAN-976b, 20261117053118). A client with UPDATE on it could setval() it and break every
-- tracked events UPDATE on the event_changes primary key.
CREATE OR REPLACE FUNCTION pg_temp.kan976_seq_closed() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT NOT (has_sequence_privilege('anon', 'public.event_changes_id_seq', 'USAGE')
           OR has_sequence_privilege('anon', 'public.event_changes_id_seq', 'SELECT')
           OR has_sequence_privilege('anon', 'public.event_changes_id_seq', 'UPDATE')
           OR has_sequence_privilege('authenticated', 'public.event_changes_id_seq', 'USAGE')
           OR has_sequence_privilege('authenticated', 'public.event_changes_id_seq', 'SELECT')
           OR has_sequence_privilege('authenticated', 'public.event_changes_id_seq', 'UPDATE'))
     AND (SELECT relacl::text FROM pg_class WHERE oid = 'public.event_changes_id_seq'::regclass) !~ '(^|[{,])=' $$;

INSERT INTO kan976_results
SELECT 'S1 sequence: no privilege for PUBLIC, anon, authenticated', pg_temp.kan976_seq_closed(), relacl::text
  FROM pg_class WHERE oid = 'public.event_changes_id_seq'::regclass;

-- S2 as authenticated, setval fails with 42501. The call re-sets the current value, so it is harmless even if allowed.
DO $s2$
DECLARE v_last bigint; v_called boolean; v_ok boolean := false; v_err text;
BEGIN
  SELECT last_value, is_called INTO v_last, v_called FROM public.event_changes_id_seq;
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM setval('public.event_changes_id_seq', v_last, v_called);
    v_err := 'setval succeeded';
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true; v_err := SQLSTATE;
  END;
  RESET ROLE;
  INSERT INTO pg_temp.kan976_results VALUES ('S2 authenticated setval(event_changes_id_seq) -> 42501', v_ok, v_err);
END $s2$;

-- N2 negative control: with USAGE, UPDATE granted to anon inside a rolled-back block, the S1 predicate goes false.
DO $n2$
DECLARE v_closed boolean;
BEGIN
  BEGIN
    GRANT USAGE, UPDATE ON SEQUENCE public.event_changes_id_seq TO anon;
    v_closed := pg_temp.kan976_seq_closed();
    RAISE EXCEPTION 'kan976_rollback';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'kan976_rollback' THEN RAISE; END IF;
  END;
  INSERT INTO pg_temp.kan976_results
  VALUES ('N2 control: grant to anon -> S1 predicate false', v_closed IS FALSE,
          format('closed with grant=%s; closed after rollback=%s', v_closed, pg_temp.kan976_seq_closed()));
END $n2$;

-- B: behaviour (all writes rolled back) -------------------------------------------------------------------------------
DO $b$
DECLARE
  r         text[] := '{}';        -- probe|pass|detail triples, survive the rollback
  g         public.events;
  m         public.events;
  a_ev      uuid;
  a_area    uuid;
  f_ev      uuid;
  v2        uuid;
  rev0      int;
  n         int;
  grp_n     int;
  ok        boolean;
  rec       record;
  notif0    int;
  notif1    int;
  roster_n  int;
  pol       text;
  s         text;
BEGIN
  SELECT e.* INTO g FROM public.events e JOIN public.games gm ON gm.event_id = e.id
   WHERE e.event_type = 'game' AND NOT e.is_cancelled AND e.venue_id IS NOT NULL
     AND gm.series_id IS NULL AND gm.venue_space_id IS NULL
   ORDER BY (SELECT count(*) FROM public.game_roster gr WHERE gr.game_id = e.id AND gr.user_id <> e.creator_user_id) DESC, e.id
   LIMIT 1;
  SELECT v.id INTO v2 FROM public.venues v JOIN public.geo_locations gl ON gl.id = v.geo_location_id
   WHERE v.id <> g.venue_id AND v.is_active AND gl.area_id IS DISTINCT FROM g.area_id ORDER BY v.id LIMIT 1;
  SELECT e.* INTO m FROM public.events e JOIN public.meetups mt ON mt.event_id = e.id
   WHERE e.event_type = 'meetup' AND NOT e.is_cancelled AND e.venue_id IS NOT NULL
     AND (mt.meta->>'venue_space_id') IS NULL ORDER BY e.id LIMIT 1;
  SELECT e.id, e.area_id INTO a_ev, a_area FROM public.events e
   WHERE e.venue_id IS NULL AND e.area_id IS NOT NULL ORDER BY e.id LIMIT 1;
  SELECT e.id INTO f_ev FROM public.events e
   WHERE e.venue_id IS NULL AND e.area_id IS NULL AND e.geo_location_id IS NULL ORDER BY e.id LIMIT 1;

  IF g.id IS NULL OR v2 IS NULL OR m.id IS NULL OR a_ev IS NULL OR f_ev IS NULL THEN
    RAISE EXCEPTION 'kan976 test: fixture missing g=% v2=% m=% a=% f=%', g.id, v2, m.id, a_ev, f_ev;
  END IF;

  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', g.creator_user_id, 'role', 'authenticated')::text, true);
    rev0 := g.schedule_revision;

    -- P1 game time move: 2 rows (start_at, end_at), one bump, actor, one change_group, old/new values right.
    UPDATE public.events SET start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour' WHERE id = g.id;
    SELECT count(*), count(DISTINCT change_group) INTO n, grp_n FROM public.event_changes WHERE event_id = g.id;
    SELECT bool_and(schedule_change AND revision = rev0 + 1 AND actor_user_id = g.creator_user_id
                    AND ((field = 'start_at' AND (old_value #>> '{}')::timestamptz = g.start_at
                                              AND (new_value #>> '{}')::timestamptz = g.start_at + interval '1 hour')
                      OR (field = 'end_at'   AND (old_value #>> '{}')::timestamptz = g.end_at
                                              AND (new_value #>> '{}')::timestamptz = g.end_at + interval '1 hour'))),
           string_agg(field, ',' ORDER BY field)
      INTO ok, s FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P1 game time: 2 rows, rev+1, actor, values',
                    (n = 2 AND grp_n = 1 AND ok AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 1)::text,
                    format('rows=%s groups=%s fields=%s rev %s->%s', n, grp_n, s, rev0,
                           (SELECT schedule_revision FROM public.events WHERE id = g.id))];

    -- P2 capacity: 1 row, schedule_change false, no bump.
    DELETE FROM public.event_changes WHERE event_id = g.id;
    UPDATE public.events SET capacity = CASE WHEN capacity >= 64 THEN capacity - 1 ELSE capacity + 1 END WHERE id = g.id;
    SELECT count(*) FILTER (WHERE field = 'capacity' AND NOT schedule_change AND revision = rev0 + 1
                                  AND (new_value #>> '{}')::int <> (old_value #>> '{}')::int), count(*)
      INTO n, grp_n FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P2 capacity: 1 row, no bump', (n = 1 AND grp_n = 1
                    AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 1)::text,
                    format('capacity rows=%s total=%s', n, grp_n)];

    -- P3 join rules: join_policy + min_skill + max_skill in one UPDATE -> 3 rows, no bump.
    DELETE FROM public.event_changes WHERE event_id = g.id;
    pol := CASE WHEN g.join_policy = 'request' THEN 'open' ELSE 'request' END;
    UPDATE public.events SET join_policy = pol,
                             min_skill = CASE WHEN min_skill IS NULL THEN 2 ELSE NULL END,
                             max_skill = CASE WHEN max_skill IS NULL THEN 9 ELSE NULL END
     WHERE id = g.id;
    SELECT string_agg(field, ',' ORDER BY field), bool_and(NOT schedule_change), count(*) INTO s, ok, n
      FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P3 join rules: join_policy, min_skill, max_skill rows, no bump',
                    (s = 'join_policy,max_skill,min_skill' AND ok
                     AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 1)::text,
                    format('fields=%s', s)];

    -- P4 joining_rule + cost_cover (events_cost_cover_logic: free/free <-> members_only/members_only).
    DELETE FROM public.event_changes WHERE event_id = g.id;
    UPDATE public.events
       SET joining_rule = CASE WHEN joining_rule = 'members_only' THEN 'free' ELSE 'members_only' END,
           cost_cover   = CASE WHEN joining_rule = 'members_only' THEN 'free' ELSE 'members_only' END
     WHERE id = g.id;
    SELECT string_agg(field, ',' ORDER BY field) INTO s FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P4 joining_rule + cost_cover rows, no bump',
                    (s = 'cost_cover,joining_rule' AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 1)::text,
                    format('fields=%s', s)];

    -- P5 venue move: kan713 derives geo + area; all place rows in one group, exactly one bump.
    DELETE FROM public.event_changes WHERE event_id = g.id;
    UPDATE public.events SET venue_id = v2 WHERE id = g.id;
    SELECT string_agg(field, ',' ORDER BY field), count(DISTINCT change_group), bool_and(schedule_change AND revision = rev0 + 2)
      INTO s, grp_n, ok FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P5 venue move: venue_id + derived place rows, one bump',
                    (s LIKE '%venue_id%' AND grp_n = 1 AND ok
                     AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 2)::text,
                    format('fields=%s groups=%s', s, grp_n)];

    -- P6 negative: title only -> no row, no bump.
    DELETE FROM public.event_changes WHERE event_id = g.id;
    UPDATE public.events SET title = coalesce(title, '') || ' kan976' WHERE id = g.id;
    SELECT count(*) INTO n FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P6 negative: title change writes nothing, no bump',
                    (n = 0 AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 2)::text,
                    format('rows=%s', n)];

    -- P7 a direct write of schedule_revision is ignored and writes no row.
    UPDATE public.events SET schedule_revision = 999 WHERE id = g.id;
    SELECT count(*) INTO n FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P7 direct schedule_revision write ignored',
                    (n = 0 AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 2)::text,
                    format('rows=%s rev=%s', n, (SELECT schedule_revision FROM public.events WHERE id = g.id))];

    -- P8 game cancel: one is_cancelled row (cancelled_at/reason are not recorded), no bump; the existing cancel
    -- notification still fires once per non-creator roster row (behaviour unchanged).
    SELECT count(*) INTO roster_n FROM public.game_roster WHERE game_id = g.id AND user_id <> g.creator_user_id;
    SELECT count(*) INTO notif0 FROM public.notifications;
    UPDATE public.events SET is_cancelled = true, cancelled_at = now(), cancelled_reason = 'kan976 test' WHERE id = g.id;
    SELECT count(*) INTO notif1 FROM public.notifications;
    SELECT string_agg(field || ':' || old_value::text || '->' || new_value::text, ',') INTO s
      FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['P8 game cancel recorded, no bump, cancel notification unchanged',
                    (s = 'is_cancelled:false->true' AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = rev0 + 2
                     AND notif1 - notif0 <= roster_n)::text,
                    format('rows=%s roster=%s notifications +%s', s, roster_n, notif1 - notif0)];

    -- P9 meetup time move: rows + bump.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', m.creator_user_id, 'role', 'authenticated')::text, true);
    UPDATE public.events SET start_at = start_at + interval '30 minutes',
                             end_at = CASE WHEN end_at IS NULL THEN NULL ELSE end_at + interval '30 minutes' END
     WHERE id = m.id;
    SELECT string_agg(field, ',' ORDER BY field), bool_and(schedule_change AND event_type = 'meetup'
             AND revision = m.schedule_revision + 1 AND actor_user_id = m.creator_user_id)
      INTO s, ok FROM public.event_changes WHERE event_id = m.id;
    r := r || ARRAY['P9 meetup time move: rows, rev+1',
                    (s IN ('start_at', 'end_at,start_at') AND ok
                     AND (SELECT schedule_revision FROM public.events WHERE id = m.id) = m.schedule_revision + 1)::text,
                    format('fields=%s', s)];

    -- P10 meetup capacity: row, no bump.
    DELETE FROM public.event_changes WHERE event_id = m.id;
    UPDATE public.events SET capacity = coalesce(capacity, 10) + 1 WHERE id = m.id;
    SELECT string_agg(field, ',') INTO s FROM public.event_changes WHERE event_id = m.id;
    r := r || ARRAY['P10 meetup capacity: row, no bump',
                    (s = 'capacity' AND (SELECT schedule_revision FROM public.events WHERE id = m.id) = m.schedule_revision + 1)::text,
                    format('fields=%s', s)];

    -- P11 meetup cancel: is_cancelled only (events_meetup_cancel_null keeps cancelled_at/reason NULL).
    DELETE FROM public.event_changes WHERE event_id = m.id;
    UPDATE public.events SET is_cancelled = true WHERE id = m.id;
    SELECT string_agg(field || ':' || old_value::text || '->' || new_value::text, ',') INTO s
      FROM public.event_changes WHERE event_id = m.id;
    r := r || ARRAY['P11 meetup cancel recorded, no bump',
                    (s = 'is_cancelled:false->true' AND (SELECT schedule_revision FROM public.events WHERE id = m.id) = m.schedule_revision + 1)::text,
                    format('rows=%s', s)];

    -- P12 meetup title only: negative control for the meetup path.
    DELETE FROM public.event_changes WHERE event_id = m.id;
    UPDATE public.events SET title = left(title, 70) || ' k976' WHERE id = m.id;
    SELECT count(*) INTO n FROM public.event_changes WHERE event_id = m.id;
    r := r || ARRAY['P12 negative: meetup title writes nothing', (n = 0)::text, format('rows=%s', n)];

    -- Venue zone probes, two layers (KAN-976c/976d). G's area is set to QA, so every rejected zone must come back
    -- as the area map's 'Asia/Qatar'.
    --   Z: venues_timezone_shape_chk (20261117055656) decides what can be stored: each zone is written once, and
    --      23514 means refused.
    --   T: event_timezone itself, with the constraint dropped inside this rolled-back block so the function's own
    --      shape check and AT TIME ZONE probe see every value (data written before the CHECK, or by a superuser).
    UPDATE public.areas SET country_code = 'QA' WHERE id = (SELECT area_id FROM public.events WHERE id = g.id);
    CREATE TEMP TABLE IF NOT EXISTS kan976_zones (probe text, zone text, want text, storable boolean) ON COMMIT DROP;
    TRUNCATE pg_temp.kan976_zones;
    INSERT INTO pg_temp.kan976_zones VALUES
        ('T1 venue zone wins (Asia/Tokyo)',                 'Asia/Tokyo',                     'Asia/Tokyo',                     true),
        ('T2 unknown well-shaped zone -> area map',         'Mars/Olympus',                   'Asia/Qatar',                     true),
        ('T7 POSIX UTC+4 -> area map',                      'UTC+4',                          'Asia/Qatar',                     false),
        ('T8 abbreviation GST -> area map',                 'GST',                            'Asia/Qatar',                     false),
        ('T9 offset +04 -> area map',                       '+04',                            'Asia/Qatar',                     false),
        ('T10 lowercase asia/tokyo -> area map',            'asia/tokyo',                     'Asia/Qatar',                     false),
        ('T11 empty string -> area map',                    '',                               'Asia/Qatar',                     false),
        ('T12 legacy EST5EDT -> area map (accepted loss)',  'EST5EDT',                        'Asia/Qatar',                     false),
        ('T13 UTC accepted',                                'UTC',                            'UTC',                            true),
        ('T14 three-part zone accepted',                    'America/Argentina/Buenos_Aires', 'America/Argentina/Buenos_Aires', true),
        ('T15 padded zone trimmed',                         '  Asia/Tokyo ',                  'Asia/Tokyo',                     false),
        ('T16 POSIX-like Asia/Dubai+4 -> area map',         'Asia/Dubai+4',                   'Asia/Qatar',                     false),
        ('T17 Etc/GMT+4 -> area map',                       'Etc/GMT+4',                      'Asia/Qatar',                     false),
        ('T18 Etc/GMT+99 -> area map',                      'Etc/GMT+99',                     'Asia/Qatar',                     false),
        ('T19 hyphenated America/Port-au-Prince accepted',  'America/Port-au-Prince',         'America/Port-au-Prince',         true),
        ('T20 America/North_Dakota/New_Salem accepted',     'America/North_Dakota/New_Salem', 'America/North_Dakota/New_Salem', true);

    FOR rec IN SELECT * FROM pg_temp.kan976_zones LOOP
      BEGIN
        UPDATE public.venues SET timezone = rec.zone WHERE id = v2;
        ok := true;
      EXCEPTION WHEN check_violation THEN ok := false;
      END;
      r := r || ARRAY['Z' || substr(rec.probe, 2, strpos(rec.probe, ' ') - 1) || 'stored=' || rec.storable || ' ' || quote_literal(rec.zone),
                      (ok = rec.storable)::text, format('%L stored=%s', rec.zone, ok)];
    END LOOP;

    ALTER TABLE public.venues DROP CONSTRAINT venues_timezone_shape_chk;   -- rolled back with this block
    FOR rec IN SELECT * FROM pg_temp.kan976_zones LOOP
      UPDATE public.venues SET timezone = rec.zone WHERE id = v2;
      s := public.event_timezone(g.id);
      r := r || ARRAY[rec.probe, (s IS NOT DISTINCT FROM rec.want)::text, format('%L -> %s', rec.zone, coalesce(s, '<null>'))];
    END LOOP;
    -- T3 no venue: area country map.
    UPDATE public.areas SET country_code = 'SA' WHERE id = a_area;
    r := r || ARRAY['T3 no venue -> area country (SA)', (public.event_timezone(a_ev) = 'Asia/Riyadh')::text,
                    coalesce(public.event_timezone(a_ev), '<null>')];
    -- T4 unmapped country (GB) -> Asia/Dubai.
    UPDATE public.areas SET country_code = 'GB' WHERE id = a_area;  -- areas.country_code has an FK to ref_countries
    r := r || ARRAY['T4 unmapped country (GB) -> Asia/Dubai', (public.event_timezone(a_ev) = 'Asia/Dubai')::text,
                    coalesce(public.event_timezone(a_ev), '<null>')];
    -- T5 neither venue nor area -> Asia/Dubai; T6 unknown id -> NULL.
    r := r || ARRAY['T5 no venue, no area -> Asia/Dubai', (public.event_timezone(f_ev) = 'Asia/Dubai')::text,
                    coalesce(public.event_timezone(f_ev), '<null>')];
    r := r || ARRAY['T6 unknown event -> NULL', (public.event_timezone(gen_random_uuid()) IS NULL)::text,
                    coalesce(public.event_timezone(gen_random_uuid()), '<null>')];

    RAISE EXCEPTION 'kan976_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan976_rollback' THEN RAISE; END IF;
  END;

  -- N1 negative control: trigger disabled -> the P1 move writes nothing and does not bump (P1 would fail).
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_kan976_events_change_signal;
    UPDATE public.events SET start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour' WHERE id = g.id;
    SELECT count(*) INTO n FROM public.event_changes WHERE event_id = g.id;
    r := r || ARRAY['N1 control: trigger off -> 0 rows, no bump (P1 predicate false)',
                    (n = 0 AND (SELECT schedule_revision FROM public.events WHERE id = g.id) = g.schedule_revision)::text,
                    format('rows=%s rev=%s', n, (SELECT schedule_revision FROM public.events WHERE id = g.id))];
    RAISE EXCEPTION 'kan976_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan976_rollback' THEN RAISE; END IF;
  END;

  -- R: nothing persisted.
  r := r || ARRAY['R nothing persisted',
                  ((SELECT count(*) FROM public.event_changes WHERE event_id IN (g.id, m.id)) = 0
                   AND (SELECT start_at FROM public.events WHERE id = g.id) = g.start_at
                   AND (SELECT is_cancelled FROM public.events WHERE id = m.id) = false
                   AND (SELECT timezone FROM public.venues WHERE id = v2) <> 'Mars/Olympus')::text,
                  format('g=%s m=%s', g.id, m.id)];

  FOR i IN 1 .. array_length(r, 1) / 3 LOOP
    INSERT INTO pg_temp.kan976_results VALUES (r[3 * i - 2], r[3 * i - 1]::boolean, r[3 * i]);
  END LOOP;
END $b$;

-- P13 timing (KAN-976c): 315 calls of event_timezone on live events must take under 1 s. The scheduler and producers
-- call it once per event. N3 negative control: the same 315 calls through a pg_temp copy of the kan976b body (EXISTS on
-- pg_timezone_names) take over 1 s, so the P13 predicate would be false for it.
CREATE OR REPLACE FUNCTION pg_temp.kan976_tz_kan976b(p_event_id uuid) RETURNS text LANGUAGE plpgsql STABLE AS $f$
DECLARE v_found boolean; v_venue text; v_country text;
BEGIN
  SELECT true, v.timezone, upper(btrim(a.country_code)) INTO v_found, v_venue, v_country
    FROM public.events e
    LEFT JOIN public.venues v ON v.id = e.venue_id
    LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
    LEFT JOIN public.areas a ON a.id = coalesce(e.area_id, gl.area_id)
   WHERE e.id = p_event_id;
  IF v_found IS NULL THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names tz WHERE tz.name = btrim(v_venue)) THEN RETURN btrim(v_venue); END IF;
  RETURN coalesce(CASE v_country WHEN 'AE' THEN 'Asia/Dubai' END, 'Asia/Dubai');
END $f$;

DO $t$
DECLARE t0 timestamptz; ms_new numeric; ms_old numeric; n int := 0; e record; x text;
BEGIN
  t0 := clock_timestamp();
  FOR e IN SELECT id FROM public.events ORDER BY id LIMIT 315 LOOP
    x := public.event_timezone(e.id); n := n + 1;
  END LOOP;
  ms_new := round(extract(epoch FROM clock_timestamp() - t0) * 1000, 1);
  INSERT INTO pg_temp.kan976_results VALUES ('P13 timing: 315 event_timezone calls < 1000 ms', n = 315 AND ms_new < 1000,
                                             format('calls=%s ms=%s', n, ms_new));
  t0 := clock_timestamp();
  FOR e IN SELECT id FROM public.events ORDER BY id LIMIT 315 LOOP
    x := pg_temp.kan976_tz_kan976b(e.id);
  END LOOP;
  ms_old := round(extract(epoch FROM clock_timestamp() - t0) * 1000, 1);
  INSERT INTO pg_temp.kan976_results VALUES ('N3 control: kan976b body, 315 calls >= 1000 ms (P13 predicate false)',
                                             ms_old >= 1000, format('ms=%s', ms_old));
END $t$;

-- N4 negative control (KAN-976d): the kan976c shape accepts 'Asia/Dubai+4' and 'Etc/GMT+4' and Postgres accepts them
-- in AT TIME ZONE, so the old function would have returned them (T16/T17 would be false). Read-only.
DO $n4$
DECLARE z text; old_ok boolean; pg_ok boolean; d text := ''; all_ok boolean := true;
BEGIN
  FOREACH z IN ARRAY ARRAY['Asia/Dubai+4', 'Etc/GMT+4'] LOOP
    old_ok := z ~ '^(UTC|[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+)$';
    BEGIN PERFORM now() AT TIME ZONE z; pg_ok := true;
    EXCEPTION WHEN invalid_parameter_value THEN pg_ok := false; END;
    all_ok := all_ok AND old_ok AND pg_ok AND NOT (z ~ '^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$');
    d := d || format('%s old_shape=%s pg_accepts=%s; ', z, old_ok, pg_ok);
  END LOOP;
  INSERT INTO pg_temp.kan976_results VALUES ('N4 control: kan976c shape + AT TIME ZONE accept Asia/Dubai+4, Etc/GMT+4', all_ok, d);
  INSERT INTO pg_temp.kan976_results
  SELECT 'Z0 venues_timezone_shape_chk present and validated after the run', count(*) = 1, string_agg(pg_get_constraintdef(oid), '')
    FROM pg_constraint WHERE conrelid = 'public.venues'::regclass AND conname = 'venues_timezone_shape_chk' AND convalidated;
END $n4$;

SELECT probe, pass, detail FROM pg_temp.kan976_results ORDER BY probe;
