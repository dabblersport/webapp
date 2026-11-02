-- KAN-714 ADVERSARIAL + PROVENANCE PROBES. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|pass=|fail=.
--
-- Group P (provenance, must FAIL before KAN-714 and PASS after): events is made to DISAGREE with the legacy
--   mirror (triggers off via session_replication_role = replica, inside this transaction only) and each reader
--   must follow events. Both directions are probed: events WIDER than legacy (reader must widen) and events
--   NARROWER than legacy (reader must narrow — a stale legacy 'public' must never leak a private row).
-- Group A (adversarial, must PASS before and after): API roles cannot read events or the pre-image table,
--   grants did not widen, gated readers still refuse.
\set ON_ERROR_STOP 1
BEGIN;
CREATE TEMP TABLE res (id text, ok boolean, detail text);
GRANT INSERT, SELECT ON res TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    v := 'ERR ' || s || ' ' || SQLERRM;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
CREATE FUNCTION pg_temp.chk_like(p_id text, p_got text, p_pat text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res VALUES (p_id, coalesce(p_got LIKE p_pat, false), 'got=' || coalesce(p_got, '<null>') || ' want~' || p_pat)
$$;

-- ---------------------------------------------------------------- Group A (posture)
SELECT pg_temp.chk_like('A1 anon cannot read events', pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.events'), 'ERR 42501%');
SELECT pg_temp.chk_like('A2 authenticated cannot read events', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.events'), 'ERR 42501%');
SELECT pg_temp.chk('A3 anon/auth/service cannot read kan714_preimage',
  CASE WHEN to_regclass('public.kan714_preimage') IS NULL THEN 'absent'
       WHEN has_table_privilege('anon', 'public.kan714_preimage', 'SELECT') OR has_table_privilege('authenticated', 'public.kan714_preimage', 'SELECT')
         OR has_table_privilege('service_role', 'public.kan714_preimage', 'SELECT') THEN 'readable' ELSE 'closed' END,
  CASE WHEN to_regclass('public.kan714_preimage') IS NULL THEN 'absent' ELSE 'closed' END);
SELECT pg_temp.chk('A4 anon EXECUTE on gated RPCs',
  has_function_privilege('anon', 'public.rpc_meetup_attendees(uuid,text,integer,integer)', 'EXECUTE')::text || ','
  || has_function_privilege('anon', 'public.rpc_games_following_joined(uuid[])', 'EXECUTE')::text || ','
  || has_function_privilege('anon', 'public.rpc_sport_overview(uuid,text)', 'EXECUTE')::text, 'false,false,false');
SELECT pg_temp.chk('A5 anon SELECT on v_meetup_counts / v_host_weekly_metrics / v_game_rating',
  has_table_privilege('anon', 'public.v_meetup_counts', 'SELECT')::text || ','
  || has_table_privilege('anon', 'public.v_host_weekly_metrics', 'SELECT')::text || ','
  || has_table_privilege('anon', 'public.v_game_rating', 'SELECT')::text, 'false,false,false');
SELECT pg_temp.chk('A6 definer + search_path of repointed functions',
  (SELECT string_agg(p.proname || ':' || p.prosecdef || ':' || array_to_string(p.proconfig, ';'), ' ' ORDER BY p.proname)
     FROM pg_proc p WHERE p.oid IN ('public.meetup_counts(uuid)'::regprocedure, 'public.rpc_games_following_joined(uuid[])'::regprocedure,
       'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure, 'public.rpc_meetup_card(uuid,text)'::regprocedure,
       'public.rpc_sport_overview(uuid,text)'::regprocedure)),
  'meetup_counts:true:search_path=public, pg_temp rpc_games_following_joined:true:search_path=public, pg_temp rpc_meetup_attendees:true:search_path=public rpc_meetup_card:true:search_path=public rpc_sport_overview:true:search_path=public, pg_temp');
SELECT pg_temp.chk('A7 views are owner views (no security_invoker=on)',
  (SELECT count(*)::text FROM pg_class WHERE relnamespace = 'public'::regnamespace
     AND relname IN ('v_game_card','v_my_games','v_meetup_list','v_meetup_counts','v_rateable_after_game','v_host_weekly_metrics')
     AND coalesce(array_to_string(reloptions, ','), '') LIKE '%security_invoker=on%'), '0');
SELECT pg_temp.chk_like('A8 rpc_sport_overview refuses anon-uid service_role call', pg_temp.as_('service_role', NULL, 'SELECT count(*)::text FROM public.rpc_sport_overview(''00000000-0000-0000-0000-0000000000e1'')'), 'ERR 42501%');
SELECT pg_temp.chk_like('A9 rpc_meetup_card on a game id', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT public.rpc_meetup_card(''71300000-0000-0000-0000-000000000001'')::text'), 'ERR P0001 meetup_not_found');
SELECT pg_temp.chk_like('A10 rpc_meetup_attendees M-hidden as non-member a9', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT count(*)::text FROM public.rpc_meetup_attendees(''71300000-0000-0000-0000-000000000105'')'), 'ERR P0001 not_allowed');

-- ---------------------------------------------------------------- Group P (provenance)
SET LOCAL session_replication_role = replica;

-- P1/P2: G-pri (events private). Legacy says public -> non-member a9 must still NOT see it (events narrower).
UPDATE public.games SET listing_visibility = 'public', join_policy = 'open' WHERE id = '71300000-0000-0000-0000-000000000003';
-- P3: G-pub (events public). Legacy says private -> a9 must STILL see it (events wider).
UPDATE public.games SET listing_visibility = 'private' WHERE id = '71300000-0000-0000-0000-000000000001';
-- P4/P5: events title/capacity/start differ from legacy on G-fol (owner a1 view).
UPDATE public.events SET title = 'G-fol EVENTS', capacity = 7, start_at = '2031-01-01 10:00+00', end_at = '2031-01-01 11:00+00'
 WHERE id = (SELECT event_id FROM public.games WHERE id = '71300000-0000-0000-0000-000000000002');
-- P6..P9: M-hidden (events hidden). Legacy says public.
UPDATE public.meetups SET listing_visibility = 'public' WHERE id = '71300000-0000-0000-0000-000000000105';
-- P10/P11: M-public: events title + rsvp policy differ from legacy.
UPDATE public.events SET title = 'M-public EVENTS', join_policy = 'request', min_skill = 4
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '71300000-0000-0000-0000-000000000101');
-- P14: v_rateable_after_game: legacy creator of G-fol moved to a4 (the rater); events says a1.
UPDATE public.games SET creator_user_id = '00000000-0000-0000-0000-0000000000a4' WHERE id = '71300000-0000-0000-0000-000000000002';
-- P13: v_my_games / v_rateable_after_game: legacy creator of G-pub moved to a9; events says a1.
UPDATE public.games SET creator_user_id = '00000000-0000-0000-0000-0000000000a9' WHERE id = '71300000-0000-0000-0000-000000000001';
SET LOCAL session_replication_role = origin;

SELECT pg_temp.chk('P1 v_game_card hides G-pri from a9 (stale legacy public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT count(*)::text FROM public.v_game_card WHERE id = ''71300000-0000-0000-0000-000000000003'''), '0');
SELECT pg_temp.chk('P2 v_game_card G-pri not in a9 public/open filter',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT count(*)::text FROM public.v_game_card WHERE id = ''71300000-0000-0000-0000-000000000003'' AND listing_visibility = ''public'''), '0');
SELECT pg_temp.chk('P3 v_game_card shows G-pub to a9 (events public, legacy private)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT count(*)::text || '':'' || min(listing_visibility) FROM public.v_game_card WHERE id = ''71300000-0000-0000-0000-000000000001'''), '1:public');
SELECT pg_temp.chk('P4 v_game_card shared fields from events (G-fol, owner)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT title || '':'' || capacity || '':'' || total_slots || '':'' || (start_at AT TIME ZONE ''UTC'') FROM public.v_game_card WHERE id = ''71300000-0000-0000-0000-000000000002'''),
  'G-fol EVENTS:7:' || (7 + (SELECT bench_slots FROM public.games WHERE id = '71300000-0000-0000-0000-000000000002')) || ':2031-01-01 10:00:00');
SELECT pg_temp.chk('P5 v_my_games shared fields from events (G-fol, a4 member)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a4', 'SELECT title || '':'' || capacity FROM public.v_my_games WHERE id = ''71300000-0000-0000-0000-000000000002'''), 'G-fol EVENTS:7');
SELECT pg_temp.chk_like('P6 rpc_meetup_card refuses M-hidden to a9 (stale legacy public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT public.rpc_meetup_card(''71300000-0000-0000-0000-000000000105'')::text'), 'ERR P0001 not_allowed');
SELECT pg_temp.chk_like('P7 rpc_meetup_attendees refuses M-hidden to a9 (stale legacy public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT count(*)::text FROM public.rpc_meetup_attendees(''71300000-0000-0000-0000-000000000105'')'), 'ERR P0001 not_allowed');
-- meetup_counts is an ungrouped aggregate: it always returns one row; a refused meetup yields 0,0,0
-- (M-hidden truly has interested=1, declined=1).
SELECT pg_temp.chk('P8 meetup_counts zeroed for M-hidden as a9 (stale legacy public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT going || '','' || interested || '','' || declined FROM public.meetup_counts(''71300000-0000-0000-0000-000000000105'')'), '0,0,0');
SELECT pg_temp.chk('P9 v_meetup_list / v_meetup_counts hide M-hidden from a9',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT (SELECT count(*) FROM public.v_meetup_list WHERE id = ''71300000-0000-0000-0000-000000000105'') || '':'' || (SELECT count(*) FROM public.v_meetup_counts WHERE meetup_id = ''71300000-0000-0000-0000-000000000105'')'), '0:0');
SELECT pg_temp.chk('P10 v_meetup_list shared fields from events (M-public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT title || '':'' || rsvp_policy || '':'' || min_skill FROM public.v_meetup_list WHERE id = ''71300000-0000-0000-0000-000000000101'''), 'M-public EVENTS:request:4');
SELECT pg_temp.chk('P11 rpc_meetup_card shared fields from events (M-public)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a9', 'SELECT (c->>''title'') || '':'' || (c->>''min_skill'') FROM public.rpc_meetup_card(''71300000-0000-0000-0000-000000000101'') c'), 'M-public EVENTS:4');
SELECT pg_temp.chk('P13 v_my_games lists G-pub for creator a1 (legacy creator a9)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.v_my_games WHERE id = ''71300000-0000-0000-0000-000000000001'' AND creator_user_id = ''00000000-0000-0000-0000-0000000000a1'''), '1');
SELECT pg_temp.chk('P14 v_rateable_after_game: a4 self-row on G-fol kept (events host a1, legacy host a4)',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a4', 'SELECT count(*)::text || '':'' || coalesce(min(ratee_role), ''-'') FROM public.v_rateable_after_game WHERE game_id = ''71300000-0000-0000-0000-000000000002'''), '1:player');
SELECT pg_temp.chk('P15 v_host_weekly_metrics attributes G-pub week to a1 (legacy creator a9)',
  pg_temp.as_('service_role', NULL, 'SELECT count(*)::text FROM public.v_host_weekly_metrics WHERE user_id = ''00000000-0000-0000-0000-0000000000a9'''), '0');

SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY id;
SELECT '#SUMMARY|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;
