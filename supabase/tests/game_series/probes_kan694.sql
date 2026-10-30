-- KAN-694 probes. Run AFTER KAN-671, KAN-693 and 20261030130000_kan694_rpc_series_edit_cancel.sql are applied, as postgres,
-- in ONE transaction that ends in ROLLBACK (nothing persists). NOT YET EXECUTED (the authoring seat may not write to the
-- database); Memphis runs it. One row per probe; the last statement raises if any probe failed.
-- Fixtures: an existing player profile + sport variant (host) and an existing profile of a different user (joiner).
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);
CREATE TEMP TABLE _ctx(uid uuid, sport uuid, variant uuid, geo uuid, area uuid, other_uid uuid, other_pid uuid);

INSERT INTO _ctx
SELECT p.user_id, sv.sport_id, sv.id,
       (SELECT id FROM public.geo_locations ORDER BY id LIMIT 1), (SELECT id FROM public.areas ORDER BY id LIMIT 1),
       o.user_id, o.id
  FROM public.profiles p, public.sport_variants sv,
       LATERAL (SELECT q.user_id, q.id FROM public.profiles q WHERE q.user_id <> p.user_id ORDER BY q.created_at LIMIT 1) o
 WHERE p.persona_type = 'player' AND p.is_active ORDER BY p.created_at, sv.id LIMIT 1;

CREATE FUNCTION pg_temp.as_user(p_user uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p_user, 'role','authenticated')::text, true),
         set_config('request.jwt.claim.sub', COALESCE(p_user::text,''), true) $f$;
CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;
CREATE FUNCTION pg_temp.new_series() RETURNS uuid LANGUAGE sql AS $f$
  SELECT public.rpc_create_game_series('player', c.sport, c.variant, c.geo, c.area, (current_date + 1), time '18:00', 60,
         'Asia/Dubai', 'weekly', 10, 'KAN694 probe', NULL, NULL, 'public', 'open', 4, 0) FROM _ctx c $f$;
CREATE FUNCTION pg_temp.nth_game(p_series uuid, p_n int) RETURNS uuid LANGUAGE sql AS $f$
  SELECT id FROM public.games WHERE series_id = p_series ORDER BY start_at OFFSET p_n LIMIT 1 $f$;
CREATE FUNCTION pg_temp.join_player(p_game uuid) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  SELECT p_game, c.other_pid, c.other_uid, 'player', 'active' FROM _ctx c $f$;

DO $$
DECLARE
  c _ctx; s1 uuid; s2 uuid; s3 uuid; g1 uuid; g2 uuid; j uuid; res jsonb; msg text; n_before int; past uuid;
  titles_before text;
BEGIN
  SELECT * INTO c FROM _ctx;
  IF c.uid IS NULL OR c.other_uid IS NULL THEN RAISE EXCEPTION 'kan694_probe_no_fixture: need a player profile, a sport variant and a second user profile'; END IF;
  PERFORM pg_temp.as_user(c.uid);

  -- E1 edit THIS occurrence: exactly one row changes, series_id stays
  s1 := pg_temp.new_series();
  g1 := pg_temp.nth_game(s1, 1);
  res := public.rpc_edit_game_series_occurrence(g1, 'KAN694 THIS', NULL, NULL, 8, NULL);
  PERFORM pg_temp.chk('E1 edit-this changes one row',
    (SELECT count(*) FROM public.games WHERE series_id = s1 AND title = 'KAN694 THIS') = 1
    AND (SELECT capacity FROM public.games WHERE id = g1) = 8
    AND (SELECT count(*) FROM public.games WHERE series_id = s1 AND capacity = 10) = 3);
  PERFORM pg_temp.chk('E2 edit-this keeps series_id and template',
    (SELECT series_id FROM public.games WHERE id = g1) = s1
    AND (SELECT title FROM public.game_series WHERE id = s1) = 'KAN694 probe'
    AND (res->>'series_id')::uuid = s1);

  -- E3 edit-this time clash inside the series is refused (unique (series_id, start_at))
  BEGIN
    PERFORM public.rpc_edit_game_series_occurrence(g1, NULL, (SELECT start_at FROM public.games WHERE id = pg_temp.nth_game(s1, 2)), NULL, NULL, NULL);
    PERFORM pg_temp.chk('E3 edit-this time clash refused', false, 'expected occurrence_time_taken');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.chk('E3 edit-this time clash refused', SQLERRM LIKE '%occurrence_time_taken%', SQLERRM);
  END;

  -- F1 edit ALL FUTURE: unjoined future rows regenerated in place, joined row untouched and reported
  s2 := pg_temp.new_series();
  j := pg_temp.nth_game(s2, 1);
  PERFORM pg_temp.join_player(j);
  res := public.rpc_edit_game_series_future(s2, 'KAN694 ALL', 12, NULL, NULL, NULL, NULL, false);
  PERFORM pg_temp.chk('F1 all-future updates unjoined future rows',
    (SELECT count(*) FROM public.games WHERE series_id = s2 AND title = 'KAN694 ALL' AND capacity = 12) = 3
    AND (res->>'updated')::int = 3);
  PERFORM pg_temp.chk('F2 all-future leaves the joined row alone',
    (SELECT title FROM public.games WHERE id = j) = 'KAN694 probe' AND (SELECT capacity FROM public.games WHERE id = j) = 10);
  PERFORM pg_temp.chk('F3 all-future reports the joined row',
    res->'kept_with_players' @> to_jsonb(ARRAY[j]) AND jsonb_array_length(res->'kept_with_players') = 1, res::text);
  PERFORM pg_temp.chk('F4 all-future updates the template',
    (SELECT title FROM public.game_series WHERE id = s2) = 'KAN694 ALL' AND (SELECT capacity FROM public.game_series WHERE id = s2) = 12);
  PERFORM pg_temp.chk('F5 all-future deletes nothing', (SELECT count(*) FROM public.games WHERE series_id = s2) = 4);

  -- F6 time change moves unjoined rows only; joined row keeps its start; top-up skipped to avoid a same-day duplicate
  res := public.rpc_edit_game_series_future(s2, NULL, NULL, time '19:30', NULL, NULL, NULL, false);
  PERFORM pg_temp.chk('F6 time change applies to unjoined rows only',
    (SELECT count(*) FROM public.games WHERE series_id = s2 AND id <> j AND (start_at AT TIME ZONE 'Asia/Dubai')::time = time '19:30') = 3
    AND (SELECT (start_at AT TIME ZONE 'Asia/Dubai')::time FROM public.games WHERE id = j) = time '18:00'
    AND (res->>'topup_skipped')::boolean AND (SELECT count(*) FROM public.games WHERE series_id = s2) = 4, res::text);

  -- F7 ends_on earlier: unjoined rows past it are cancelled (not deleted), joined row stays active
  res := public.rpc_edit_game_series_future(s2, NULL, NULL, NULL, NULL, NULL, current_date + 1 + 7, false);
  PERFORM pg_temp.chk('F7 shorter end date cancels unjoined rows beyond it',
    (SELECT count(*) FROM public.games WHERE series_id = s2 AND is_cancelled) = 2
    AND (SELECT NOT is_cancelled FROM public.games WHERE id = j) AND (SELECT count(*) FROM public.games WHERE series_id = s2) = 4, res::text);

  -- C1 cancel series: ended, future rows cancelled, joined player notified via the single-game cancel trigger, past kept
  s3 := pg_temp.new_series();
  past := pg_temp.nth_game(s3, 0);
  UPDATE public.games SET start_at = now() - interval '2 days', end_at = now() - interval '2 days' + interval '1 hour' WHERE id = past;
  PERFORM pg_temp.join_player(pg_temp.nth_game(s3, 2));
  res := public.rpc_cancel_game_series(s3, 'probe');
  PERFORM pg_temp.chk('C1 cancel ends the series', (SELECT status FROM public.game_series WHERE id = s3) = 'ended');
  PERFORM pg_temp.chk('C2 cancel cancels every future occurrence',
    NOT EXISTS (SELECT 1 FROM public.games WHERE series_id = s3 AND start_at > now() AND NOT is_cancelled)
    AND (res->>'cancelled')::int = 3, res::text);
  PERFORM pg_temp.chk('C3 cancel reports the joined player to be notified', (res->>'player_notifications')::int = 1, res::text);
  PERFORM pg_temp.chk('C4 cancel keeps the past row untouched',
    EXISTS (SELECT 1 FROM public.games WHERE id = past AND NOT is_cancelled) AND (res->>'past_kept')::int = 1);
  PERFORM pg_temp.chk('C5 ended series is not regenerated',
    public.fn_generate_game_series_occurrences(s3) = 0);

  -- N1 non-host refused on all three RPCs
  PERFORM pg_temp.as_user(c.other_uid);
  BEGIN PERFORM public.rpc_edit_game_series_occurrence(g1, 'x'); PERFORM pg_temp.chk('N1 non-host edit-this refused', false);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('N1 non-host edit-this refused', SQLERRM LIKE '%not_host_or_not_found%', SQLERRM); END;
  BEGIN PERFORM public.rpc_edit_game_series_future(s2, 'x'); PERFORM pg_temp.chk('N2 non-host edit-future refused', false);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('N2 non-host edit-future refused', SQLERRM LIKE '%not_host_or_not_found%', SQLERRM); END;
  BEGIN PERFORM public.rpc_cancel_game_series(s1); PERFORM pg_temp.chk('N3 non-host cancel refused', false);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('N3 non-host cancel refused', SQLERRM LIKE '%not_host_or_not_found%', SQLERRM); END;
  PERFORM pg_temp.chk('N4 non-host cancel changed nothing',
    (SELECT status FROM public.game_series WHERE id = s1) = 'active'
    AND NOT EXISTS (SELECT 1 FROM public.games WHERE series_id = s1 AND is_cancelled));

  -- N5 no session refused
  PERFORM pg_temp.as_user(NULL);
  BEGIN PERFORM public.rpc_cancel_game_series(s1); PERFORM pg_temp.chk('N5 no session refused', false);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('N5 no session refused', SQLERRM LIKE '%not_authenticated%', SQLERRM); END;

  -- N6 anon has no EXECUTE on any of the three
  BEGIN
    SET LOCAL ROLE anon;
    PERFORM public.rpc_cancel_game_series(s1);
    RESET ROLE;
    PERFORM pg_temp.chk('N6 anon refused', false);
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    PERFORM pg_temp.chk('N6 anon refused', SQLERRM LIKE '%permission denied%', SQLERRM);
  END;
  PERFORM pg_temp.chk('N7 no PUBLIC/anon grant on the three functions',
    NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
                 WHERE p.proname IN ('rpc_edit_game_series_occurrence','rpc_edit_game_series_future','rpc_cancel_game_series')
                   AND p.pronamespace = 'public'::regnamespace AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)));
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN694 probes failed: %', (SELECT string_agg(name, ', ') FROM _r WHERE NOT ok); END IF;
END $$;
ROLLBACK;
