-- KAN-728 (KAN-714 piece B09) — booking reads. rpc_booking_hold_for_meetup: owner_user_id blocker fixed, creator read
-- from public.events. Every other booking reader is pinned UNCHANGED (see the migration header for why).
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end: no data survives.
--
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|expect=|pass=|fail=, plus #PLAN| / #FINGERPRINT| / #COUNT| lines.
--
-- Variable :expect selects which image is asserted:
--   post (default) — 20261104100900_kan714_b09_booking_conflicts_hold.sql applied.
--   pre            — legacy pre-image (no migration, or after rollback_kan714_b09.sql).
-- RED/GREEN protocol:
--   chain without migration,  expect=post  -> FAIL lines (D1, H1, H2, H3, H7, L1, P1, P2, X1)   RED
--   chain without migration,  expect=pre   -> 0 FAIL
--   chain with migration,     expect=post  -> 0 FAIL                                           GREEN
--   migration + rollback,     expect=pre   -> 0 FAIL, and #FINGERPRINT| equal to the pre-migration DB
--
-- Groups: S shape/attributes, D definitions (changed one + untouched readers), H hold RPC literals (creator / outsider /
--         admin / anon / not-found), L legacy parity over the whole meetups dataset x 5 callers, P provenance (events
--         made to disagree with meetups), C conflict reader _slot_conflicts_game (unchanged, games + its E4 blocker),
--         G game hold (wrapped, unchanged, still works), A access, X EXPLAIN shape.
\set ON_ERROR_STOP 1
\set hold_post_md5 9d113b77a82df489569a765ad30445f7
\set hold_pre_md5 446285fd3e9d6b814fbed14af8121c27
\if :{?expect}
\else
  \set expect post
\endif
BEGIN;
SELECT set_config('kan728.expect', :'expect', true);
SET LOCAL TimeZone = 'UTC';
CREATE TEMP TABLE res (n serial, id text, ok boolean, detail text);

CREATE FUNCTION pg_temp.post() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('kan728.expect') = 'post' $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, ok, detail)
  VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
-- One call under a role and a JWT sub: the scalar result as text, or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
-- Hold outcome class: ok | ERR <sqlstate> <message>.
CREATE FUNCTION pg_temp.hold(p_fn text, p_role text, p_uid uuid, p_m uuid, p_space uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  v := pg_temp.as_(p_role, p_uid, format(
         $f$SELECT %s(%L::uuid, %L::uuid, timestamptz '2031-01-01 10:00+00', timestamptz '2031-01-01 11:00+00')::text$f$,
         p_fn, p_m, p_space));
  RETURN CASE WHEN v ~ '^[0-9a-f]{8}-' THEN 'ok' ELSE v END;
END $$;
CREATE FUNCTION pg_temp.plan(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE l text; o text := '';
BEGIN
  FOR l IN EXECUTE 'EXPLAIN (COSTS OFF) ' || p_sql LOOP o := o || l || E'\n'; END LOOP;
  RETURN o;
END $$;
CREATE FUNCTION pg_temp.cnt(p_hay text, p_re text) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM regexp_matches(p_hay, p_re, 'g')
$$;

-- Data fingerprint of every table the booking readers read or write, BEFORE this script seeds anything.
SELECT '#FINGERPRINT|' || md5(
         (SELECT coalesce(string_agg(m::text, '|' ORDER BY m.id), '') FROM public.meetups m) ||
         (SELECT coalesce(string_agg(g::text, '|' ORDER BY g.id), '') FROM public.games g) ||
         (SELECT coalesce(string_agg(e::text, '|' ORDER BY e.id), '') FROM public.events e) ||
         (SELECT coalesce(string_agg(b::text, '|' ORDER BY b.id), '') FROM public.venue_bookings b)) AS fingerprint;

-- ---------------------------------------------------------------- legacy reference bodies, as temp functions
-- (a) the pre-image, verbatim (pg_get_functiondef of the KAN-713 stage catalogue).
CREATE FUNCTION pg_temp.legacy_hold_verbatim(p_meetup_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m record;
  vid uuid;
  bid uuid;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.owner_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  -- (optional) store human location on meetup side already; no FK change here.
  return bid;
end;
$function$;
-- (b) the pre-image with ONLY owner_user_id -> creator_user_id, still reading meetups: the intended legacy behaviour.
CREATE FUNCTION pg_temp.legacy_hold_intended(p_meetup_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m record;
  vid uuid;
  bid uuid;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.creator_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  return bid;
end;
$function$;
-- (c) _slot_conflicts_game, verbatim.
CREATE FUNCTION pg_temp.legacy_slot_conflicts_game(p_space uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists(
    select 1 from public.games g
    where g.venue_space_id = p_space
      and g.is_cancelled = false
      and tstzrange(g.start_at, g.end_at, '[)') && tstzrange(p_start, p_end, '[)')
  );
$function$;

-- Actors: a1 creator of M1/M2, a2 creator of M3, a3 harness admin (harness_admins), a4/a5 outsiders to M1.
-- Spaces: ee11, ee12 (venue ee01), ee21 (venue ee02).
\set M1 '30000000-0000-0000-0000-000000000001'
\set M2 '30000000-0000-0000-0000-000000000002'
\set M3 '30000000-0000-0000-0000-000000000003'
\set SP '00000000-0000-0000-0000-00000000ee11'

-- ---------------------------------------------------------------- S: shape and attributes
SELECT pg_temp.chk('S1 signature : result : owner : ACL : SECURITY DEFINER : volatility : search_path',
  (SELECT pg_get_function_identity_arguments(p.oid) || ' : ' || pg_get_function_result(p.oid) || ' : ' || p.proowner::regrole
          || ' : ' || p.proacl::text || ' : ' || p.prosecdef || ' : ' || p.provolatile::text || ' : ' || array_to_string(p.proconfig, ',')
     FROM pg_proc p WHERE p.oid = 'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure),
  'p_meetup_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone : uuid : postgres : '
  || '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres} : true : v : search_path=public');
SELECT pg_temp.chk('S2 one overload, no _kan712_inner, not in kan712_wrapped_rpcs',
  (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_booking_hold_for_meetup')::text
  || ':' || (to_regproc('public.rpc_booking_hold_for_meetup_kan712_inner') IS NULL)::text
  || ':' || (SELECT count(*) FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_booking_hold_for_meetup')::text,
  '1:true:0');

-- ---------------------------------------------------------------- D: definitions
SELECT pg_temp.chk('D1 rpc_booking_hold_for_meetup definition md5 is the expected image',
  md5(pg_get_functiondef('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure)),
  CASE WHEN pg_temp.post() THEN :'hold_post_md5' ELSE :'hold_pre_md5' END);
SELECT pg_temp.chk('D2 untouched booking readers byte-identical (slot_conflicts_game, hold_for_game + inner, booking_cancel, game_belongs_to_venue)',
  (SELECT string_agg(md5(pg_get_functiondef(f::regprocedure)), ',' ORDER BY o) FROM (VALUES
     (1, 'public._slot_conflicts_game(uuid,timestamptz,timestamptz)'),
     (2, 'public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)'),
     (3, 'public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamptz,timestamptz)'),
     (4, 'public.rpc_booking_cancel(uuid)'),
     (5, 'public._game_belongs_to_venue(uuid,uuid)')) t(o, f)),
  '42729f5c67c2b2fa453addf51fec26c6,5857515b031fcb57926549d754af89a5,ddb9fe12e37d1a651c0ee3104988ec6b,97e9c289b9d768ff7212529876ecff08,6e5901ff6904c44012897b99d5b0c830');
SELECT pg_temp.chk('D3 rpc_booking_hold_for_game still wrapped by KAN-712 (wrapper calls the inner, kan712.contract=on)',
  (SELECT (prosrc LIKE '%rpc_booking_hold_for_game_kan712_inner%')::text || ':' || array_to_string(proconfig, ',')
     FROM pg_proc WHERE oid = 'public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)'::regprocedure),
  'true:search_path="",kan712.contract=on');

-- ---------------------------------------------------------------- H: hold RPC literals (authenticated role, real ACL)
SELECT pg_temp.chk('H1 creator a1 holds M1 (pre: owner_user_id 42703)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a1', :'M1', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ok' ELSE 'ERR 42703 record "m" has no field "owner_user_id"' END);
SELECT pg_temp.chk('H2 outsider a2 on M1 is refused not_authorized (pre: 42703)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a2', :'M1', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ERR P0001 not_authorized' ELSE 'ERR 42703 record "m" has no field "owner_user_id"' END);
SELECT pg_temp.chk('H3 admin a3 holds M1 (pre: 42703)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a3', :'M1', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ok' ELSE 'ERR 42703 record "m" has no field "owner_user_id"' END);
SELECT pg_temp.chk('H4 unknown meetup -> meetup_not_found; unknown space -> space_not_found (both images)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a1', gen_random_uuid(), :'SP')
  || ' | ' || pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a1', :'M1', gen_random_uuid()),
  'ERR P0001 meetup_not_found | ERR P0001 space_not_found');
SELECT pg_temp.chk('H5 anon cannot execute (both images)',
  split_part(pg_temp.hold('public.rpc_booking_hold_for_meetup', 'anon', NULL, :'M1', :'SP'), ' ', 2), '42501');
SELECT pg_temp.chk('H6 creator a1 of M1 cannot hold M3 (creator a2)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a1', :'M3', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ERR P0001 not_authorized' ELSE 'ERR 42703 record "m" has no field "owner_user_id"' END);
SELECT pg_temp.chk('H7 bookings for M1: exactly one row per successful call, fields as written (no doubling, refusals write nothing)',
  (SELECT count(*) || ':' || coalesce(string_agg(venue_space_id || '/' || source_type || '/' || status || '/' || created_by || '/'
                                   || starts_at || '/' || ends_at, ';' ORDER BY created_by), '')
     FROM public.venue_bookings WHERE source_id = :'M1'),
  CASE WHEN pg_temp.post()
       THEN '2:00000000-0000-0000-0000-00000000ee11/meetup/confirmed/00000000-0000-0000-0000-0000000000a1/2031-01-01 10:00:00+00/2031-01-01 11:00:00+00;'
         || '00000000-0000-0000-0000-00000000ee11/meetup/confirmed/00000000-0000-0000-0000-0000000000a3/2031-01-01 10:00:00+00/2031-01-01 11:00:00+00'
       ELSE '0:' END);

-- ---------------------------------------------------------------- L: legacy parity over every meetup x 5 callers
-- post: public fn vs legacy_hold_intended (same body reading meetups.creator_user_id). pre: vs legacy_hold_verbatim.
CREATE TEMP TABLE l_out AS
  SELECT m.id AS mid, u.uid,
         pg_temp.hold('public.rpc_booking_hold_for_meetup', NULL, u.uid, m.id, :'SP') AS got,
         pg_temp.hold(CASE WHEN pg_temp.post() THEN 'pg_temp.legacy_hold_intended' ELSE 'pg_temp.legacy_hold_verbatim' END,
                      NULL, u.uid, m.id, :'SP') AS want,
         (u.uid = m.creator_user_id OR u.uid = '00000000-0000-0000-0000-0000000000a3') AS entitled
    FROM public.meetups m
   CROSS JOIN (VALUES ('00000000-0000-0000-0000-0000000000a1'::uuid), ('00000000-0000-0000-0000-0000000000a2'),
                      ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4'),
                      ('00000000-0000-0000-0000-0000000000a5')) u(uid);
SELECT '#COUNT|L calls=' || count(*) || '|ok=' || count(*) FILTER (WHERE got = 'ok') || '|refused=' || count(*) FILTER (WHERE got LIKE 'ERR P0001 not_authorized')
       || '|42703=' || count(*) FILTER (WHERE got LIKE 'ERR 42703%') || '|mismatch=' || count(*) FILTER (WHERE got IS DISTINCT FROM want) FROM l_out;
SELECT pg_temp.chk('L1 every (meetup, caller): outcome equals the legacy reference; ok exactly when creator or admin',
  (SELECT count(*) FILTER (WHERE got IS DISTINCT FROM want) || ':'
          || count(*) FILTER (WHERE got = 'ok' AND NOT entitled) || ':'
          || count(*) FILTER (WHERE got <> 'ok' AND entitled AND pg_temp.post()) || ':'
          || (count(*) FILTER (WHERE got = 'ok') = CASE WHEN pg_temp.post() THEN count(*) FILTER (WHERE entitled) ELSE 0 END)
     FROM l_out),
  '0:0:0:true');
SELECT pg_temp.chk('L2 rows not doubled: meetup bookings in the probe window = H successes + 2 x L ok calls (one row per ok call, per fn)',
  ((SELECT count(*) FROM public.venue_bookings WHERE starts_at = timestamptz '2031-01-01 10:00+00' AND source_type = 'meetup')
   - (SELECT count(*) FROM res WHERE (id LIKE 'H1 %' OR id LIKE 'H3 %') AND ok) * (CASE WHEN pg_temp.post() THEN 1 ELSE 0 END)
   - 2 * (SELECT count(*) FROM l_out WHERE got = 'ok'))::text,
  '0');

-- ---------------------------------------------------------------- P: provenance — events DISAGREES with meetups
-- Triggers off for this transaction only (session_replication_role = replica) so the compat mirror cannot reconcile.
SET LOCAL session_replication_role = replica;
UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a4'
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = :'M2');
-- Flip M3's parent to a game; the game-only CHECKs are satisfied by copying a real game parent's required columns.
UPDATE public.events e SET event_type = 'game', area_id = g.area_id, geo_location_id = g.geo_location_id, sport_id = g.sport_id,
       capacity = g.capacity, join_policy = g.join_policy, listing_visibility = g.listing_visibility,
       end_at = e.start_at + interval '1 hour'
  FROM (SELECT * FROM public.events WHERE event_type = 'game' ORDER BY id LIMIT 1) g
 WHERE e.id = (SELECT event_id FROM public.meetups WHERE id = :'M3');
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('P1 creator follows events (M2 events creator a4, meetups creator a1): a4 holds, a1 refused',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a4', :'M2', :'SP') || ' | '
  || pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a1', :'M2', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ok | ERR P0001 not_authorized'
       ELSE 'ERR 42703 record "m" has no field "owner_user_id" | ERR 42703 record "m" has no field "owner_user_id"' END);
SELECT pg_temp.chk('P2 event_type filter: M3 whose parent says game is meetup_not_found (creator a2)',
  pg_temp.hold('public.rpc_booking_hold_for_meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a2', :'M3', :'SP'),
  CASE WHEN pg_temp.post() THEN 'ERR P0001 meetup_not_found' ELSE 'ERR 42703 record "m" has no field "owner_user_id"' END);

-- ---------------------------------------------------------------- C: _slot_conflicts_game (unchanged; games conflicts)
-- Seed: three games placed on spaces (games.venue_space_id is not a shared field; the guard allows it for postgres).
CREATE TEMP TABLE c_games AS
  SELECT g.id, g.event_id, row_number() OVER (ORDER BY g.id) AS k
    FROM public.games g WHERE NOT g.is_cancelled AND g.end_at IS NOT NULL ORDER BY g.id LIMIT 2;
INSERT INTO c_games SELECT g.id, g.event_id, 3 FROM public.games g WHERE g.is_cancelled AND g.end_at IS NOT NULL ORDER BY g.id LIMIT 1;
UPDATE public.games g SET venue_space_id = CASE c.k WHEN 2 THEN '00000000-0000-0000-0000-00000000ee12'::uuid
                                                     ELSE '00000000-0000-0000-0000-00000000ee11'::uuid END
  FROM c_games c WHERE g.id = c.id;
-- Every game's own window (and the touching window just after it) on all three spaces: function vs verbatim copy.
CREATE TEMP TABLE c_out AS
  SELECT g.id, s.id AS sp, w.kind,
         public._slot_conflicts_game(s.id, w.ws, w.we) AS got,
         pg_temp.legacy_slot_conflicts_game(s.id, w.ws, w.we) AS want
    FROM public.games g
   CROSS JOIN public.venue_spaces s
   CROSS JOIN LATERAL (VALUES ('own', g.start_at, g.end_at), ('touch', g.end_at, g.end_at + interval '1 hour')) w(kind, ws, we)
   WHERE g.end_at IS NOT NULL;
SELECT '#COUNT|C probes=' || count(*) || '|true=' || count(*) FILTER (WHERE got) || '|mismatch=' || count(*) FILTER (WHERE got IS DISTINCT FROM want) FROM c_out;
SELECT pg_temp.chk('C1 _slot_conflicts_game equals its verbatim copy over every game window x space (both images)',
  (SELECT count(*) FILTER (WHERE got IS DISTINCT FROM want) FROM c_out)::text, '0');
SELECT pg_temp.chk('C2 conflict literals: active G1 own window on its space true; touching window false; cancelled G3 false; other space false',
  (SELECT string_agg(x, ',' ORDER BY o) FROM (
     SELECT 1 o, public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', g.start_at, g.end_at)::text x FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 1
     UNION ALL SELECT 2, public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', g.end_at, g.end_at + interval '1 hour')::text FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 1
     UNION ALL SELECT 3, public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', g.start_at, g.end_at)::text FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 3
       WHERE NOT EXISTS (SELECT 1 FROM public.games g2 JOIN c_games c2 ON c2.id = g2.id AND c2.k = 1
                          WHERE tstzrange(g2.start_at, g2.end_at, '[)') && tstzrange(g.start_at, g.end_at, '[)'))
     UNION ALL SELECT 4, public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee21', g.start_at, g.end_at)::text FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 1) z),
  'true,false,false,false');
SELECT pg_temp.chk('C3 E4 blocker: an INVOKER read of events under authenticated raises 42501; _slot_conflicts_game under authenticated runs',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$SELECT exists(SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game')::text$q$) || ' | '
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$SELECT public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', now(), now() + interval '1 hour')::text$q$),
  'ERR 42501 permission denied for table events | false');
-- Provenance, stated honestly: an events-only move of G1 does NOT move the conflict answer, in either image, because
-- _slot_conflicts_game is blocked (E4) and still reads games. This is the reported limitation, asserted as fact.
SET LOCAL session_replication_role = replica;
UPDATE public.events e SET start_at = e.start_at + interval '10 days', end_at = e.end_at + interval '10 days'
  FROM c_games c WHERE c.k = 1 AND e.id = c.event_id;
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('C4 events-only move of G1: conflict at the games window stays true, at the events window stays false (reader not repointed)',
  (SELECT public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', g.start_at, g.end_at)::text || ','
          || public._slot_conflicts_game('00000000-0000-0000-0000-00000000ee11', e.start_at, e.end_at)::text
     FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 1 JOIN public.events e ON e.id = g.event_id),
  'true,false');

-- ---------------------------------------------------------------- G: game hold (wrapped, untouched) still works
SELECT pg_temp.chk('G1 rpc_booking_hold_for_game via its wrapper: creator ok, outsider not_authorized (both images)',
  (SELECT pg_temp.as_('authenticated', g.creator_user_id, format(
            $f$SELECT CASE WHEN public.rpc_booking_hold_for_game(%L, %L, timestamptz '2032-01-01 10:00+00', timestamptz '2032-01-01 11:00+00') IS NOT NULL THEN 'ok' END$f$,
            g.id, '00000000-0000-0000-0000-00000000ee21'))
          || ' | ' ||
          pg_temp.as_('authenticated', (SELECT u FROM (VALUES ('00000000-0000-0000-0000-0000000000a4'::uuid), ('00000000-0000-0000-0000-0000000000a5')) v(u)
                                          WHERE u <> g.creator_user_id LIMIT 1), format(
            $f$SELECT public.rpc_booking_hold_for_game(%L, %L, timestamptz '2032-01-01 12:00+00', timestamptz '2032-01-01 13:00+00')::text$f$,
            g.id, '00000000-0000-0000-0000-00000000ee21'))
     FROM public.games g JOIN c_games c ON c.id = g.id AND c.k = 2),
  'ok | ERR P0001 not_authorized');

-- ---------------------------------------------------------------- A: access
SELECT pg_temp.chk('A1 API roles still cannot read public.events directly',
  split_part(pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.events'), ' ', 2) || ','
  || split_part(pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.events'), ' ', 2),
  '42501,42501');
SELECT pg_temp.chk('A2 events posture unchanged (ACL, RLS, FORCE RLS, zero policies)',
  (SELECT coalesce(relacl::text, '-') || ':' || relrowsecurity || ':' || relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
  || ':' || (SELECT count(*) FROM pg_policy WHERE polrelid = 'public.events'::regclass),
  '{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres}:true:true:0');

-- ---------------------------------------------------------------- X: EXPLAIN shape of the hold's lookup statement
-- The statement explained is asserted to be the one inside the function body (not a paraphrase).
SELECT '#PLAN|hold lookup|' || replace(pg_temp.plan(
  CASE WHEN pg_temp.post()
       THEN $s$select mt.id, e.creator_user_id from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id = '30000000-0000-0000-0000-000000000001'$s$
       ELSE $s$select * from public.meetups where id = '30000000-0000-0000-0000-000000000001'$s$ END), E'\n', E'\n#PLAN|  ');
SELECT '#PLAN|slot_conflicts_game|' || replace(pg_temp.plan(
  $s$select exists(select 1 from public.games g where g.venue_space_id = '00000000-0000-0000-0000-00000000ee11' and g.is_cancelled = false and tstzrange(g.start_at, g.end_at, '[)') && tstzrange(now(), now() + interval '1 hour', '[)'))$s$),
  E'\n', E'\n#PLAN|  ');
SELECT pg_temp.chk('X1 hold lookup: events scans : SubPlans : statement is in the body',
  (WITH p AS (SELECT pg_temp.plan(CASE WHEN pg_temp.post()
       THEN $s$select mt.id, e.creator_user_id from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id = '30000000-0000-0000-0000-000000000001'$s$
       ELSE $s$select * from public.meetups where id = '30000000-0000-0000-0000-000000000001'$s$ END) t)
   SELECT pg_temp.cnt(t, ' on events') || ':' || pg_temp.cnt(t, 'SubPlan') FROM p) || ':' ||
  (SELECT position(CASE WHEN pg_temp.post() THEN 'from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = ''meetup''' ELSE 'select * into m from public.meetups where id = p_meetup_id' END
                   IN prosrc) > 0 FROM pg_proc WHERE oid = 'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure)::text,
  CASE WHEN pg_temp.post() THEN '1:0:true' ELSE '0:0:true' END);
SELECT pg_temp.chk('X2 slot_conflicts_game: SubPlans (unchanged)',
  pg_temp.cnt(pg_temp.plan($s$select exists(select 1 from public.games g where g.venue_space_id = '00000000-0000-0000-0000-00000000ee11' and g.is_cancelled = false and tstzrange(g.start_at, g.end_at, '[)') && tstzrange(now(), now() + interval '1 hour', '[)'))$s$), 'SubPlan')::text,
  '0');

SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY n;
SELECT '#SUMMARY|expect=' || current_setting('kan728.expect') || '|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;
