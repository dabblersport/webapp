-- KAN-718: per-writer equality probe for every game writer, live, in ONE transaction that always rolls back.
--
-- Run it whole (Supabase MCP execute_sql or psql -1). It never commits: the last statement raises
-- KX718 with the report as its message, so every probe row, the setup rows and the trigger toggles are
-- undone. Expect the run to "fail" with SQLSTATE KX718 and read the report from the message.
--
-- Each scenario runs in its own subtransaction (undone by a RAISE), as the real caller (SET LOCAL ROLE
-- authenticated + the caller's jwt claims; the two service-only entry points run as postgres with the
-- same claims). The deferred checks (games_event_id_fkey, the event-link, series-occurrence, exclusive
-- and series-start constraint triggers) are forced to IMMEDIATE inside the scenario, so what commit
-- would reject is rejected here.
--
-- Per scenario the report gives md5(normalised result): the games row and the events row of every game
-- the write touched (id / event_id dropped, timestamps equal to now() written as "NOW", which keeps the
-- md5 stable across transactions), the return value where it is deterministic, and per row
--   drift  = the 22 shared columns differ between games and events,
--   orphan = a games row with no events parent.
-- Phase "on"  : every trigger as live.
-- Phase "off" : trg_zz_kan712_games_guard, trg_zz_kan712_games_after_delete, trg_kan713_games_a/b/c and
--               trg_zz_kan712_events_compat_mirror DISABLED (ALTER TABLE, undone by the rollback).
-- PASS: every scenario's md5 is equal in "on" and "off", no row has drift or orphan, and (against the
-- md5 captured before KAN-718 was applied) "on" equals the pre-KAN-718 behaviour.
-- After 921-924 / 918 / 919 drop those triggers, "off" disables only what still exists.

CREATE TEMP TABLE k718_res (phase text, scen text, res jsonb);

-- Fixed-id setup (rolled back with everything else).
INSERT INTO public.challenges (id, owner_profile_id, owner_user_id, title, sport, sport_id)
VALUES ('00000718-0000-4000-8000-000000000001', 'b0eb97de-f437-47cc-85dc-5df1523ab790',
        '6f7d9bcc-8371-4495-a78e-86f27d6dfe25', 'K718 probe challenge', 'padel', '2502490a-0339-436c-8b5e-5ac1514606c9');
INSERT INTO public.challenge_fixtures (id, challenge_id)
VALUES ('00000718-0000-4000-8000-000000000002', '00000718-0000-4000-8000-000000000001');
INSERT INTO public.game_series (id, creator_user_id, creator_profile_id, sport_id, sport_variant_id, venue_space_id,
       geo_location_id, area_id, title, capacity, start_time_local, duration_minutes, rrule, timezone, starts_on)
VALUES ('00000718-0000-4000-8000-000000000003', '6f7d9bcc-8371-4495-a78e-86f27d6dfe25',
        'b0eb97de-f437-47cc-85dc-5df1523ab790', '2502490a-0339-436c-8b5e-5ac1514606c9',
        '9208e6be-811a-4c76-9149-8dc736983dcc', '05c42917-8f73-46f4-9ddc-293e92c9f755',
        '04c12264-6c43-4a1d-a625-1e9ac33367af', 'a0000000-0000-0000-0000-000000000022',
        'K718 probe series', 4, '18:00', 90, 'FREQ=WEEKLY', 'Asia/Dubai', '2027-01-04');

CREATE FUNCTION pg_temp.k718_norm(j jsonb) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT COALESCE(jsonb_object_agg(k, CASE
           WHEN k IN ('created_at', 'updated_at', 'cancelled_at') AND jsonb_typeof(v) = 'string'
                AND (v #>> '{}')::timestamptz = now() THEN to_jsonb('NOW'::text)
           ELSE v END), '{}'::jsonb)
    FROM jsonb_each(j - 'id' - 'event_id') t(k, v)
$f$;

CREATE FUNCTION pg_temp.k718_snap(p_ids uuid[]) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'g', pg_temp.k718_norm(to_jsonb(g)),
           'e', pg_temp.k718_norm(to_jsonb(e)),
           'drift', ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
                        g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
                        g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill::smallint,
                        g.max_skill::smallint, g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
                    IS DISTINCT FROM
                    ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
                        e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
                        e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
                        e.joining_rule, e.cost_cover, e.request_id, e.created_at, e.updated_at),
           'orphan', g.id IS NOT NULL AND e.id IS NULL)
         ORDER BY COALESCE(g.start_at, e.start_at), COALESCE(g.title, e.title)), '[]'::jsonb)
    FROM (SELECT DISTINCT unnest(p_ids) AS id) u
    LEFT JOIN public.games  g ON g.id = u.id
    LEFT JOIN public.events e ON e.id = u.id
   WHERE g.id IS NOT NULL OR e.id IS NOT NULL
$f$;

CREATE FUNCTION pg_temp.k718_run(p_phase text, p_scen text, p_uid uuid, p_role text, p_pre text,
                                 p_call text, p_ids text, p_keep_ret boolean) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE
  v_ret jsonb; v_ids uuid[]; v_res jsonb;
  c_cons constant text := 'public.games_event_id_fkey, public.trg_games_event_link_check, '
    'public.trg_games_series_occurrence_check, public.trg_events_exclusive_check, public.trg_events_series_start_check';
BEGIN
  BEGIN
    EXECUTE 'SET CONSTRAINTS ' || c_cons || ' DEFERRED';
    IF p_pre IS NOT NULL THEN EXECUTE p_pre; END IF;
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    IF p_role = 'authenticated' THEN EXECUTE 'SET LOCAL ROLE authenticated'; END IF;
    EXECUTE p_call INTO v_ret;
    EXECUTE 'RESET ROLE';
    EXECUTE 'SET CONSTRAINTS ' || c_cons || ' IMMEDIATE';
    EXECUTE p_ids INTO v_ids;
    v_res := jsonb_build_object('ret', CASE WHEN p_keep_ret THEN v_ret END, 'rows', pg_temp.k718_snap(v_ids));
    RAISE EXCEPTION USING errcode = 'KX718', message = v_res::text;
  EXCEPTION
    WHEN sqlstate 'KX718' THEN
      INSERT INTO k718_res VALUES (p_phase, p_scen, sqlerrm::jsonb);
    WHEN OTHERS THEN
      INSERT INTO k718_res VALUES (p_phase, p_scen, jsonb_build_object('error', sqlstate, 'msg', sqlerrm));
  END;
END
$f$;

CREATE FUNCTION pg_temp.k718_gen_occ() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM public.fn_generate_game_series_occurrences('00000718-0000-4000-8000-000000000003');
  PERFORM set_config('k718.occ', (SELECT id::text FROM public.games
                                   WHERE series_id = '00000718-0000-4000-8000-000000000003'
                                   ORDER BY start_at LIMIT 1), true);
END
$f$;

-- admin_cleanup pre step: remove this harness's own fixed-id setup rows (challenges.owner_profile_id
-- and game_series are not cleaned by admin_cleanup_user_data and would block the profiles DELETE),
-- then record the host's game ids so the snapshot can show they are gone.
CREATE FUNCTION pg_temp.k718_admin_pre() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  DELETE FROM public.challenge_fixtures WHERE id = '00000718-0000-4000-8000-000000000002';
  DELETE FROM public.challenges WHERE id = '00000718-0000-4000-8000-000000000001';
  DELETE FROM public.game_series WHERE id = '00000718-0000-4000-8000-000000000003';
  PERFORM set_config('k718.del', (SELECT array_agg(id)::text FROM public.games
                                   WHERE creator_profile_id = 'b0eb97de-f437-47cc-85dc-5df1523ab790'), true);
END
$f$;

CREATE FUNCTION pg_temp.k718_all(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  c_host  constant uuid := '6f7d9bcc-8371-4495-a78e-86f27d6dfe25';
  c_admin constant uuid := '2d7024f7-198a-45aa-a64d-f52916b6b6c1';
  c_game  constant text := '''9cd149ad-9048-4897-9f67-552b8620badf''::uuid';
  c_ser   constant text := '''00000718-0000-4000-8000-000000000003''::uuid';
  c_gen   constant text := 'SELECT public.fn_generate_game_series_occurrences(' || '''00000718-0000-4000-8000-000000000003''::uuid' || ')';
  c_ser_ids constant text := 'SELECT array_agg(id) FROM public.games WHERE series_id = ''00000718-0000-4000-8000-000000000003''';
  c_game_ids constant text := 'SELECT ARRAY[''9cd149ad-9048-4897-9f67-552b8620badf''::uuid]';
  c_ret_ids  constant text := 'SELECT ARRAY[current_setting(''k718.gid'')::uuid]';
  c_times constant text := 'SELECT set_config(''k718.s'', e.start_at::text, true), set_config(''k718.e'', e.end_at::text, true) '
                           'FROM public.events e WHERE e.id = ''9cd149ad-9048-4897-9f67-552b8620badf''';
  c_upd   constant text := 'SELECT to_jsonb(public.rpc_update_game(' || '''9cd149ad-9048-4897-9f67-552b8620badf''::uuid' || ', %s, %s, %s, %s, false, '
                           'NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, 0::numeric))';
BEGIN
  -- create: normal (free space), paid space, no space, with request_id, legacy v1
  PERFORM pg_temp.k718_run(p_phase, 'create_free', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_create_game(''player'', ''2502490a-0339-436c-8b5e-5ac1514606c9'', '
    '''9208e6be-811a-4c76-9149-8dc736983dcc'', ''K718 free'', ''05c42917-8f73-46f4-9ddc-293e92c9f755'', '
    '''2027-01-10 18:00+04'', ''2027-01-10 19:30+04'', 0, ''public'', ''open'', NULL, NULL, NULL, NULL, false, false, '
    'NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0::numeric, NULL)::text, true))', c_ret_ids, false);
  PERFORM pg_temp.k718_run(p_phase, 'create_paid', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_create_game(''player'', ''4fd36109-12c2-4b17-a8a2-281be2b8649c'', '
    '''9144d011-0d0c-4475-91cb-5a688c7be2b0'', ''K718 paid'', ''1b0dacf7-f646-4296-ac48-41b948cbdde3'', '
    '''2027-01-11 18:00+04'', ''2027-01-11 19:30+04'', 0, ''public'', ''open'', NULL, NULL, NULL, NULL, false, false, '
    'NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 50::numeric, NULL)::text, true))', c_ret_ids, false);
  PERFORM pg_temp.k718_run(p_phase, 'create_nospace', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_create_game(''player'', ''2502490a-0339-436c-8b5e-5ac1514606c9'', '
    '''490ce916-b984-4da5-af37-c0019402359e'', ''K718 nospace'', NULL, '
    '''2027-01-12 18:00+04'', ''2027-01-12 19:30+04'', 1, ''public'', ''open'', 2, 4, NULL, NULL, true, true, '
    'NULL, ''split'', ''04c12264-6c43-4a1d-a625-1e9ac33367af'', ''a0000000-0000-0000-0000-000000000022'', NULL, NULL, 2, 6, 10::numeric, NULL)::text, true))',
    c_ret_ids, false);
  PERFORM pg_temp.k718_run(p_phase, 'create_request_id', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_create_game(''player'', ''2502490a-0339-436c-8b5e-5ac1514606c9'', '
    '''9208e6be-811a-4c76-9149-8dc736983dcc'', ''K718 req'', ''e561f01a-1cb7-447e-9355-5aa97e1fcef2'', '
    '''2027-01-13 18:00+04'', ''2027-01-13 19:30+04'', 0, ''public'', ''open'', NULL, NULL, NULL, NULL, false, false, '
    'NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0::numeric, ''00000718-0000-4000-8000-0000000000aa'')::text, true))',
    c_ret_ids, false);
  PERFORM pg_temp.k718_run(p_phase, 'create_legacy_v1', c_host, 'postgres', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_create_game_legacy_v1(''player'', ''2502490a-0339-436c-8b5e-5ac1514606c9'', '
    '''9208e6be-811a-4c76-9149-8dc736983dcc'', ''K718 v1'', ''05c42917-8f73-46f4-9ddc-293e92c9f755'', '
    '''2027-01-14 18:00+04'', ''2027-01-14 19:30+04'')::text, true))', c_ret_ids, false);
  -- challenge spawn (KAN-717 F3: 'spawn' must succeed as 'private'/'invite'; challenges carry no location,
  -- so 'spawn_nospace' must raise P0001 challenge_location_required)
  PERFORM pg_temp.k718_run(p_phase, 'spawn', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_challenge_spawn_game(''00000718-0000-4000-8000-000000000002'', '
    '''2027-01-15 18:00+04'', ''e561f01a-1cb7-447e-9355-5aa97e1fcef2'')::text, true))', c_ret_ids, false);
  PERFORM pg_temp.k718_run(p_phase, 'spawn_nospace', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(set_config(''k718.gid'', public.rpc_challenge_spawn_game(''00000718-0000-4000-8000-000000000002'', '
    '''2027-01-16 18:00+04'')::text, true))', c_ret_ids, false);
  -- series: generator (create), edit future, edit occurrence
  PERFORM pg_temp.k718_run(p_phase, 'series_generate', c_host, 'postgres', NULL,
    'SELECT to_jsonb(public.fn_generate_game_series_occurrences(' || c_ser || '))', c_ser_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'series_edit_future', c_host, 'authenticated', c_gen,
    'SELECT public.rpc_edit_game_series_future(' || c_ser || ', ''K718 renamed'', 6, ''19:00'', 60, '
    '''e561f01a-1cb7-447e-9355-5aa97e1fcef2'', NULL, false)', c_ser_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'series_edit_occurrence', c_host, 'authenticated',
    'SELECT pg_temp.k718_gen_occ()',
    'SELECT public.rpc_edit_game_series_occurrence(current_setting(''k718.occ'')::uuid, ''K718 occ'', '
    '''2027-01-04 20:00+04'', NULL, 3, ''1b0dacf7-f646-4296-ac48-41b948cbdde3'') - ''game_id''', c_ser_ids, true);
  -- update: title, time, venue_space_id (free), venue_space_id (paid), legacy v1 with a space
  PERFORM pg_temp.k718_run(p_phase, 'update_title', c_host, 'authenticated', c_times,
    format(c_upd, 'current_setting(''k718.s'')::timestamptz', 'current_setting(''k718.e'')::timestamptz', '''K718 title''', 'NULL'),
    c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'update_time', c_host, 'authenticated', NULL,
    format(c_upd, '''2027-02-01 18:00+04''::timestamptz', '''2027-02-01 19:00+04''::timestamptz', 'NULL', 'NULL'),
    c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'update_space', c_host, 'authenticated', c_times,
    format(c_upd, 'current_setting(''k718.s'')::timestamptz', 'current_setting(''k718.e'')::timestamptz', 'NULL',
           '''f0b1ba31-05e7-40dd-9344-364f94831508''::uuid'),
    c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'update_space_paid', c_host, 'authenticated', c_times,
    format(c_upd, 'current_setting(''k718.s'')::timestamptz', 'current_setting(''k718.e'')::timestamptz', 'NULL',
           '''622e6013-f334-4f0b-9eff-7a6946906b4f''::uuid'),
    c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'update_legacy_v1', c_host, 'postgres', NULL,
    'SELECT to_jsonb(public.rpc_update_game_legacy_v1(' || c_game || ', ''2027-02-04 18:00+04'', ''2027-02-04 19:00+04'', '
    '''K718 v1 upd'', ''f0b1ba31-05e7-40dd-9344-364f94831508'', false, NULL, NULL, NULL, NULL, 1, 3, false, NULL, NULL, 8))',
    c_game_ids, true);
  -- reschedule, cancel, booking hold
  PERFORM pg_temp.k718_run(p_phase, 'reschedule', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(public.rpc_reschedule_game(' || c_game || ', ''2027-02-02 18:00+04'', ''2027-02-02 19:30+04''))',
    c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'cancel', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(public.rpc_cancel_game(' || c_game || ', ''K718 probe''))', c_game_ids, true);
  PERFORM pg_temp.k718_run(p_phase, 'booking_hold', c_host, 'authenticated', NULL,
    'SELECT to_jsonb(public.rpc_booking_hold_for_game(' || c_game || ', ''1b0dacf7-f646-4296-ac48-41b948cbdde3'', '
    '''2027-02-03 18:00+04'', ''2027-02-03 19:30+04''))', c_game_ids, false);
  -- admin cleanup: dry run, then the delete (ids = the host's games and events, which must be gone)
  PERFORM pg_temp.k718_run(p_phase, 'admin_cleanup_dry', c_admin, 'authenticated', NULL,
    'SELECT jsonb_agg(to_jsonb(t) ORDER BY t.affected_table, t.affected_column) FROM public.admin_cleanup_user_data('''
    || c_host || ''', true) t',
    'SELECT array_agg(id) FROM public.events WHERE creator_profile_id = ''b0eb97de-f437-47cc-85dc-5df1523ab790'' AND event_type = ''game''',
    true);
  PERFORM pg_temp.k718_run(p_phase, 'admin_cleanup', c_admin, 'authenticated',
    'SELECT pg_temp.k718_admin_pre()',
    'SELECT jsonb_agg(to_jsonb(t) ORDER BY t.affected_table, t.affected_column) FROM public.admin_cleanup_user_data('''
    || c_host || ''', false) t',
    'SELECT current_setting(''k718.del'')::uuid[] || coalesce((SELECT array_agg(id) FROM public.events WHERE creator_profile_id = ''b0eb97de-f437-47cc-85dc-5df1523ab790''), ''{}'')',
    true);
END
$f$;

CREATE FUNCTION pg_temp.k718_toggle(p_on boolean) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r record; v_done text[] := '{}';
BEGIN
  FOR r IN SELECT t.tgrelid::regclass AS rel, t.tgname FROM pg_trigger t
            WHERE t.tgrelid IN ('public.games'::regclass, 'public.events'::regclass)
              AND t.tgname IN ('trg_zz_kan712_games_guard', 'trg_zz_kan712_games_after_delete',
                               'trg_kan713_games_a_location', 'trg_kan713_games_b_joining',
                               'trg_kan713_games_c_venue_geo', 'trg_zz_kan712_events_compat_mirror')
  LOOP
    EXECUTE format('ALTER TABLE %s %s TRIGGER %I', r.rel, CASE WHEN p_on THEN 'ENABLE' ELSE 'DISABLE' END, r.tgname);
    v_done := v_done || r.tgname::text;
  END LOOP;
  RETURN array_to_string(v_done, ',');
END
$f$;

SELECT pg_temp.k718_all('on');
SELECT pg_temp.k718_toggle(false);
SELECT pg_temp.k718_all('off');
SELECT pg_temp.k718_toggle(true);

DO $report$
DECLARE v jsonb;
BEGIN
  SELECT jsonb_object_agg(scen, d ORDER BY scen) INTO v FROM (
    SELECT o.scen, jsonb_build_object(
             'on',  md5(o.res::text), 'off', md5(f.res::text), 'same', o.res = f.res,
             'on_err',  o.res ->> 'msg', 'off_err', f.res ->> 'msg',
             'on_bad',  (SELECT count(*) FROM jsonb_array_elements(COALESCE(o.res -> 'rows', '[]')) x
                          WHERE (x ->> 'drift')::boolean OR (x ->> 'orphan')::boolean),
             'off_bad', (SELECT count(*) FROM jsonb_array_elements(COALESCE(f.res -> 'rows', '[]')) x
                          WHERE (x ->> 'drift')::boolean OR (x ->> 'orphan')::boolean),
             'nrows', jsonb_array_length(COALESCE(o.res -> 'rows', '[]')),
             'vis', o.res #>> '{rows,0,g,listing_visibility}', 'evis', o.res #>> '{rows,0,e,listing_visibility}') AS d
      FROM k718_res o JOIN k718_res f ON f.scen = o.scen AND f.phase = 'off'
     WHERE o.phase = 'on') s;
  RAISE EXCEPTION USING errcode = 'KX718', message = v::text;
END
$report$;
