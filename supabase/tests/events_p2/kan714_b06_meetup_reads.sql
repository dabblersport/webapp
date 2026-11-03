-- KAN-725 (KAN-714 piece B06) — rpc_meetup_card / rpc_meetup_attendees read shared facts from public.events;
-- rpc_meetup_my is pinned UNCHANGED (it cannot execute in the pre-image — see R1).
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end: no data survives.
--
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|expect=|pass=|fail=, plus #PLAN| and #FINGERPRINT| lines.
--
-- Variable :expect selects which image is asserted:
--   post (default) — 20261104100600_kan714_b06_rpc_meetup_reads.sql applied.
--   pre            — legacy pre-image (no migration, or after rollback_kan714_b06.sql).
-- Build the chain from tracked files only: bash supabase/tests/events_p2/build_kan725.sh <new-datadir> <port>
--   (database k725; it ends with local_harness_kan725.sql: the three pre-image RPCs, citext, stand-in columns).
-- RED/GREEN protocol:
--   chain without migration,  expect=post  -> FAIL lines (D1, D2, D3, P1..P4, X1)   RED
--   chain without migration,  expect=pre   -> 0 FAIL
--   chain with migration,     expect=post  -> 0 FAIL                                 GREEN
--   migration + rollback,     expect=pre   -> 0 FAIL, and #FINGERPRINT| equal to the pre-migration DB
--
-- Groups: S shape/attributes, D definition provenance, L legacy parity over the whole dataset,
--         V visibility literals (owner / circle member / blocked / admin / outsider / anon), G games do not leak,
--         A access, C consumer (wrapped rpc_meetup_update returns the card), R rpc_meetup_my,
--         X EXPLAIN shape, P provenance (events made to disagree with meetups).
\set ON_ERROR_STOP 1
\set card_post_md5 11a9f38356fc23e4430c9353b246eb8f
\set att_post_md5 bb414558f86659d89497da378babcb7f
\if :{?expect}
\else
  \set expect post
\endif
BEGIN;
SELECT set_config('kan725.expect', :'expect', true);
SET LOCAL TimeZone = 'UTC';
CREATE TEMP TABLE res (n serial, id text, ok boolean, detail text);
GRANT INSERT, SELECT ON res TO anon, authenticated;
GRANT USAGE ON SEQUENCE res_n_seq TO anon, authenticated;

CREATE FUNCTION pg_temp.post() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('kan725.expect') = 'post' $$;
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
    v := 'ERR ' || s;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, ok, detail)
  VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
CREATE FUNCTION pg_temp.plan(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE l text; o text := '';
BEGIN
  FOR l IN EXECUTE 'EXPLAIN (COSTS OFF) ' || p_sql LOOP o := o || l || E'\n'; END LOOP;
  RETURN o;
END $$;
CREATE FUNCTION pg_temp.cnt(p_hay text, p_re text) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM regexp_matches(p_hay, p_re, 'g')
$$;
-- Outcome of one call as text: the jsonb / row list, or 'ERR <sqlstate> <message>'. Caller identity = request.jwt.claim.sub.
CREATE FUNCTION pg_temp.card_out(p_fn text, p_id uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  EXECUTE format('SELECT %s($1, %L)::text', p_fn, 'player') INTO v USING p_id;
  RETURN coalesce(v, '<null>');
EXCEPTION WHEN OTHERS THEN RETURN 'ERR ' || SQLSTATE || ' ' || SQLERRM;
END $$;
CREATE FUNCTION pg_temp.att_out(p_fn text, p_id uuid, p_status text, p_limit int, p_offset int) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  EXECUTE format('SELECT coalesce(string_agg(t::text, %L ORDER BY t.o), %L) FROM %s($1, $2, $3, $4) WITH ORDINALITY AS t(a, d, u, s, o)',
                 '|', '', p_fn) INTO v USING p_id, p_status, p_limit, p_offset;
  RETURN v;
EXCEPTION WHEN OTHERS THEN RETURN 'ERR ' || SQLSTATE || ' ' || SQLERRM;
END $$;
CREATE FUNCTION pg_temp.as_uid(p_uid uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true); SELECT NULL::void
$$;
-- Compact card for literal checks: ok:<is_host>:<going>/<interested>/<declined>/<pending>, or the error message.
CREATE FUNCTION pg_temp.card_brief(p_fn text, p_id uuid, p_uid uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; j jsonb;
BEGIN
  PERFORM pg_temp.as_uid(p_uid);
  v := pg_temp.card_out(p_fn, p_id);
  PERFORM pg_temp.as_uid(NULL);
  IF v LIKE 'ERR %' THEN RETURN split_part(v, ' ', 3); END IF;
  j := v::jsonb;
  RETURN 'ok:' || (j->>'is_host') || ':' || (j->'counts'->>'going') || '/' || (j->'counts'->>'interested') || '/'
         || (j->'counts'->>'declined') || '/' || coalesce(j->'counts'->>'pending', '-');
END $$;

-- Attendee statuses (sorted) for one caller, or the error message.
CREATE FUNCTION pg_temp.att_brief(p_fn text, p_id uuid, p_uid uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  PERFORM pg_temp.as_uid(p_uid);
  BEGIN
    EXECUTE format('SELECT coalesce(string_agg(t.status, %L ORDER BY t.status), %L) FROM %s($1) t', ',', '', p_fn) INTO v USING p_id;
  EXCEPTION WHEN OTHERS THEN v := SQLERRM;
  END;
  PERFORM pg_temp.as_uid(NULL);
  RETURN v;
END $$;
CREATE FUNCTION pg_temp.card_key(p_id uuid, p_uid uuid, p_key text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  PERFORM pg_temp.as_uid(p_uid);
  BEGIN
    SELECT public.rpc_meetup_card(p_id) ->> p_key INTO v;
  EXCEPTION WHEN OTHERS THEN v := SQLERRM;
  END;
  PERFORM pg_temp.as_uid(NULL);
  RETURN v;
END $$;

-- Data fingerprint of every table the three RPCs read, BEFORE this script seeds anything.
SELECT '#FINGERPRINT|' || md5(
         (SELECT coalesce(string_agg(m::text, '|' ORDER BY m.id), '') FROM public.meetups m) ||
         (SELECT coalesce(string_agg(e::text, '|' ORDER BY e.id), '') FROM public.events e) ||
         (SELECT coalesce(string_agg(r::text, '|' ORDER BY r.meetup_id, r.user_id), '') FROM public.meetup_rsvps r)) AS fingerprint;

-- ---------------------------------------------------------------- legacy reference: the pre-image bodies, verbatim, as temp functions
CREATE FUNCTION pg_temp.legacy_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
  g int; i int; d int; pn int;
  my_status_ text;
  hp_name text;
  hp_user citext;
  counts_ jsonb;
  hp_avatar text;
  sp public.sports%rowtype;
  v_area text;
  v_venue text;
  atts jsonb := '[]'::jsonb;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int,
    (count(*) filter (where r.status = 'pending'))::int
    into g, i, d, pn
  from public.meetup_rsvps r
  where r.meetup_id = p_meetup_id;

  if me is not null then
    select r.status into my_status_
    from public.meetup_rsvps r
    where r.meetup_id = p_meetup_id and r.user_id = me;
  end if;

  select hp.display_name, hp.username, hp.avatar_url into hp_name, hp_user, hp_avatar
  from public.profiles hp where hp.id = m.host_actor_id;

  select * into sp from public.sports s where s.id = m.sport_id;
  select a.name into v_area from public.areas a where a.id = m.area_id;
  select v.name_en into v_venue from public.venues v where v.id = m.venue_id;

  -- member names/avatars: authenticated callers only (the card is anon-callable)
  if me is not null then
    select coalesce(jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name)
                              order by x.updated_at desc nulls last), '[]'::jsonb)
      into atts
    from (select r.profile_id, r.updated_at from public.meetup_rsvps r
          where r.meetup_id = p_meetup_id and r.status = 'going'
          order by r.updated_at desc nulls last, r.created_at desc limit 8) x
    join public.profiles ap on ap.id = x.profile_id;
  end if;

  counts_ := jsonb_build_object(
    'going',      coalesce(g,0),
    'interested', coalesce(i,0),
    'declined',   coalesce(d,0)
  );
  if v_host then
    counts_ := counts_ || jsonb_build_object('pending', coalesce(pn,0));
  end if;

  return jsonb_build_object(
    'id',               m.id,
    'title',            m.title,
    'description',      m.description,
    'start_at',         m.start_at,
    'end_at',           m.end_at,
    'location_name',    m.location_name,
    'capacity',         m.capacity,
    'visibility',       m.listing_visibility,
    'is_cancelled',     m.is_cancelled,
    'owner_profile_id', m.creator_profile_id,
    'host', jsonb_build_object(
      'actor_profile_id', m.host_actor_id,
      'display_name',     hp_name,
      'username',         hp_user,
      'avatar_url',       hp_avatar
    ),
    'counts',    counts_,
    'my_status', my_status_,
    'sport_key',     sp.sport_key,
    'sport_name_en', sp.name_en,
    'sport_name_ar', sp.name_ar,
    'min_skill',     m.min_skill,
    'max_skill',     m.max_skill,
    'area_name',     v_area,
    'venue_name',    v_venue,
    'attendees',     atts,
    'is_host',   v_host
  );
end;
$function$;

CREATE FUNCTION pg_temp.legacy_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(actor_profile_id uuid, display_name text, username citext, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  return query
  select
    r.profile_id,
    p.display_name,
    p.username,
    r.status
  from public.meetup_rsvps r
  left join public.profiles p on p.id = r.profile_id
  where r.meetup_id = p_meetup_id
    and (p_status is null or r.status = p_status)
    and (v_host or r.status in ('going','interested'))
  order by r.updated_at desc nulls last, r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

-- ---------------------------------------------------------------- seed (normal write path: KAN-712 guard writes events first)
-- All by a1 (profile b1). Fixtures already in the dataset: a1~a5 synced (accepted friendship); a1~a6 synced BUT a1 blocks a6;
-- a3 is admin (harness_admins); a4 is an outsider; NULL = anon.
-- M1 public, M2 circle, M3 hidden, M4 invite, M5 link, M6 public (creator provenance), M7 public (type filter),
-- M8 public (consumer: wrapped rpc_meetup_update), M9 public with NULL end/capacity/skills (null preservation).
INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at,
                            listing_visibility, rsvp_policy, sport_id, geo_location_id, area_id, capacity, is_cancelled,
                            location_name, is_indoor, min_skill, max_skill)
SELECT ('72500000-0000-0000-0001-00000000000' || n)::uuid, 'B06 M' || n || ' ' || vis, 'desc ' || n,
       '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
       timestamptz '2031-04-01 10:00+00' + n * interval '1 day',
       CASE WHEN n = 9 THEN NULL ELSE timestamptz '2031-04-01 12:00+00' + n * interval '1 day' END,
       vis, 'open', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1',
       '00000000-0000-0000-0000-0000000000c1', CASE WHEN n = 9 THEN NULL ELSE 10 END, false, 'Here', false,
       CASE WHEN n = 9 THEN NULL ELSE 2 END, CASE WHEN n = 9 THEN NULL ELSE 8 END
  FROM (VALUES (1, 'public'), (2, 'circle'), (3, 'hidden'), (4, 'invite'), (5, 'link'),
               (6, 'public'), (7, 'public'), (8, 'public'), (9, 'public')) AS v(n, vis);
INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status, updated_at, created_at)
SELECT ('72500000-0000-0000-0001-00000000000' || n)::uuid, ('00000000-0000-0000-0000-0000000000a' || u)::uuid,
       ('00000000-0000-0000-0000-0000000000b' || u)::uuid, st,
       timestamptz '2031-01-01' + (n * 10 + u) * interval '1 minute', timestamptz '2031-01-01'
  FROM generate_series(1, 9) n,
       (VALUES (2, 'going'), (4, 'interested'), (5, 'declined'), (7, 'pending'), (6, 'going')) AS r(u, st);

-- ---------------------------------------------------------------- S: shape and attributes (both images)
SELECT pg_temp.chk('S1 signatures and result types',
  (SELECT string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')->' || pg_get_function_result(p.oid), ' ; '
                     ORDER BY p.proname)
     FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('rpc_meetup_card', 'rpc_meetup_my', 'rpc_meetup_attendees')),
  'rpc_meetup_attendees(p_meetup_id uuid, p_status text, p_limit integer, p_offset integer)->TABLE(actor_profile_id uuid, display_name text, username citext, status text) ; '
  || 'rpc_meetup_card(p_meetup_id uuid, p_profile_type text)->jsonb ; '
  || 'rpc_meetup_my()->TABLE(id uuid, title text, starts_at timestamp with time zone, visibility text, host_actor_id uuid, updated_at timestamp with time zone)');
SELECT pg_temp.chk('S2 owner / secdef / volatility / config / ACL unchanged',
  (SELECT string_agg(p.proname || ':' || pg_get_userbyid(p.proowner) || ':' || p.prosecdef || ':' || p.provolatile::text || ':'
                     || coalesce(array_to_string(p.proconfig, ';'), '-') || ':' || coalesce(p.proacl::text, '-'), ' ' ORDER BY p.proname)
     FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('rpc_meetup_card', 'rpc_meetup_my', 'rpc_meetup_attendees')),
  'rpc_meetup_attendees:postgres:true:v:search_path=public:{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres} '
  || 'rpc_meetup_card:postgres:true:v:search_path=public:{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres} '
  || 'rpc_meetup_my:postgres:false:s:search_path=public, pg_temp:{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}');
SELECT pg_temp.chk('S3 none of the three is KAN-712-wrapped (no registry row, no _kan712_inner)',
  (SELECT count(*) FROM public.kan712_wrapped_rpcs w WHERE w.name IN ('rpc_meetup_card', 'rpc_meetup_my', 'rpc_meetup_attendees'))::text
  || ':' || (SELECT count(*) FROM pg_proc WHERE proname IN ('rpc_meetup_card_kan712_inner', 'rpc_meetup_my_kan712_inner',
                                                           'rpc_meetup_attendees_kan712_inner'))::text, '0:0');

-- ---------------------------------------------------------------- D: definition provenance (md5 of pg_get_functiondef)
SELECT pg_temp.chk('D1 rpc_meetup_card definition',
  md5(pg_get_functiondef('public.rpc_meetup_card(uuid,text)'::regprocedure)),
  CASE WHEN pg_temp.post() THEN :'card_post_md5' ELSE 'ba562664e6a99fee30a75de6fe5cbbeb' END);
SELECT pg_temp.chk('D2 rpc_meetup_attendees definition',
  md5(pg_get_functiondef('public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure)),
  CASE WHEN pg_temp.post() THEN :'att_post_md5' ELSE '9c82e357c7b0fe58afc645f37d889523' END);
SELECT pg_temp.chk('D3 card + attendees read events by id + type; legacy meetups read of shared columns gone',
  (SELECT string_agg(p.proname || ':' || (p.prosrc ~ 'join public\.events e on e\.id = mt\.event_id and e\.event_type = ''meetup''')
                     || ':' || (p.prosrc ~ 'select \* into m from public\.meetups'), ' ' ORDER BY p.proname)
     FROM pg_proc p WHERE p.oid IN ('public.rpc_meetup_card(uuid,text)'::regprocedure,
                                    'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure)),
  CASE WHEN pg_temp.post() THEN 'rpc_meetup_attendees:true:false rpc_meetup_card:true:false'
       ELSE 'rpc_meetup_attendees:false:true rpc_meetup_card:false:true' END);
SELECT pg_temp.chk('D4 rpc_meetup_my definition UNCHANGED (both images)',
  md5(pg_get_functiondef('public.rpc_meetup_my()'::regprocedure)), '9459dd31f4dfc534d26b3e37e49326b9');

-- ---------------------------------------------------------------- L: legacy parity over the whole dataset
-- Every meetup x every user (a1..a7) + anon: card outcome text identical (jsonb or error), counts equal, non-vacuous.
DO $l1$
DECLARE u uuid; mid uuid; a text; b text; d int := 0; ok_n int := 0; err_n int := 0; calls int := 0;
BEGIN
  FOR u IN SELECT p.user_id FROM public.profiles p UNION ALL SELECT NULL::uuid LOOP
    PERFORM pg_temp.as_uid(u);
    FOR mid IN SELECT id FROM public.meetups LOOP
      a := pg_temp.card_out('public.rpc_meetup_card', mid);
      b := pg_temp.card_out('pg_temp.legacy_card', mid);
      calls := calls + 1;
      IF a IS DISTINCT FROM b THEN d := d + 1; END IF;
      IF b LIKE 'ERR %' THEN err_n := err_n + 1; ELSE ok_n := ok_n + 1; END IF;
    END LOOP;
  END LOOP;
  PERFORM pg_temp.as_uid(NULL);
  INSERT INTO res (id, ok, detail) VALUES ('L1 rpc_meetup_card == legacy for every meetup x caller',
    d = 0 AND ok_n > 0 AND err_n > 0, format('calls=%s diff=%s legacy_ok=%s legacy_err=%s', calls, d, ok_n, err_n));
END $l1$;
-- Every meetup x every caller, default args: attendee rows identical in content and order; total row count equal.
DO $l2$
DECLARE u uuid; mid uuid; a text; b text; d int := 0; ra bigint := 0; rb bigint := 0; calls int := 0;
BEGIN
  FOR u IN SELECT p.user_id FROM public.profiles p UNION ALL SELECT NULL::uuid LOOP
    PERFORM pg_temp.as_uid(u);
    FOR mid IN SELECT id FROM public.meetups LOOP
      a := pg_temp.att_out('public.rpc_meetup_attendees', mid, NULL, 50, 0);
      b := pg_temp.att_out('pg_temp.legacy_attendees', mid, NULL, 50, 0);
      calls := calls + 1;
      IF a IS DISTINCT FROM b THEN d := d + 1; END IF;
      IF a NOT LIKE 'ERR %' AND a <> '' THEN ra := ra + array_length(string_to_array(a, '|'), 1); END IF;
      IF b NOT LIKE 'ERR %' AND b <> '' THEN rb := rb + array_length(string_to_array(b, '|'), 1); END IF;
    END LOOP;
  END LOOP;
  PERFORM pg_temp.as_uid(NULL);
  INSERT INTO res (id, ok, detail) VALUES ('L2 rpc_meetup_attendees == legacy (rows, order, count; not doubled)',
    d = 0 AND ra = rb AND rb > 0, format('calls=%s diff=%s rows=%s legacy_rows=%s', calls, d, ra, rb));
END $l2$;
-- Filters and pagination: 20 busiest meetups + seeded M1..M5, callers owner/admin/member/blocked/outsider/anon,
-- status NULL/going/interested/declined/pending/bogus, (limit,offset) incl. clamps and NULLs.
DO $l3$
DECLARE u uuid; mid uuid; st text; lo record; a text; b text; d int := 0; calls int := 0; nonempty int := 0;
BEGIN
  FOR u IN SELECT * FROM (VALUES ('00000000-0000-0000-0000-0000000000a1'::uuid), ('00000000-0000-0000-0000-0000000000a3'::uuid),
                                 ('00000000-0000-0000-0000-0000000000a5'::uuid), ('00000000-0000-0000-0000-0000000000a6'::uuid),
                                 ('00000000-0000-0000-0000-0000000000a4'::uuid), (NULL::uuid)) x(u) LOOP
    PERFORM pg_temp.as_uid(u);
    FOR mid IN (SELECT meetup_id FROM public.meetup_rsvps GROUP BY meetup_id ORDER BY count(*) DESC, meetup_id LIMIT 20)
               UNION SELECT ('72500000-0000-0000-0001-00000000000' || n)::uuid FROM generate_series(1, 5) n LOOP
      FOREACH st IN ARRAY ARRAY[NULL, 'going', 'interested', 'declined', 'pending', 'bogus'] LOOP
        FOR lo IN SELECT * FROM (VALUES (50, 0), (2, 0), (2, 2), (1, 3), (0, 0), (500, 0), (NULL::int, NULL::int), (3, -1)) v(l, o) LOOP
          a := pg_temp.att_out('public.rpc_meetup_attendees', mid, st, lo.l, lo.o);
          b := pg_temp.att_out('pg_temp.legacy_attendees', mid, st, lo.l, lo.o);
          calls := calls + 1;
          IF a IS DISTINCT FROM b THEN d := d + 1; END IF;
          IF b NOT LIKE 'ERR %' AND b <> '' THEN nonempty := nonempty + 1; END IF;
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
  PERFORM pg_temp.as_uid(NULL);
  INSERT INTO res (id, ok, detail) VALUES ('L3 attendees filters/pagination == legacy', d = 0 AND nonempty > 0,
    format('calls=%s diff=%s legacy_nonempty=%s', calls, d, nonempty));
END $l3$;
SELECT pg_temp.chk('L4 null preservation on M9 (end_at, capacity, min/max_skill JSON null; same as legacy)',
  (SELECT concat_ws(',', (j->'end_at')::text, (j->'capacity')::text, (j->'min_skill')::text, (j->'max_skill')::text) || ':'
          || (pg_temp.card_out('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000009')
              = pg_temp.card_out('pg_temp.legacy_card', '72500000-0000-0000-0001-000000000009'))::text
     FROM (SELECT pg_temp.card_out('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000009')::jsonb j) s),
  'null,null,null,null:true');

-- ---------------------------------------------------------------- V: visibility literals (identical in both images)
-- Seeded rsvps per meetup: going a2+a6, interested a4, declined a5, pending a7.
SELECT pg_temp.chk('V1 card: M1 public  [owner a1, admin a3, member a5, blocked a6, outsider a4, anon]',
  (SELECT string_agg(pg_temp.card_brief('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000001', u), ' ' ORDER BY o)
     FROM unnest(ARRAY['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a5',
                       '00000000-0000-0000-0000-0000000000a6', '00000000-0000-0000-0000-0000000000a4', NULL]::uuid[]) WITH ORDINALITY t(u, o)),
  'ok:true:2/1/1/1 ok:true:2/1/1/1 ok:false:2/1/1/- not_allowed ok:false:2/1/1/- ok:false:2/1/1/-');
SELECT pg_temp.chk('V2 card: M2 circle / M3 hidden / M4 invite / M5 link, same callers',
  (SELECT string_agg(n || '=' || (SELECT string_agg(pg_temp.card_brief('public.rpc_meetup_card', ('72500000-0000-0000-0001-00000000000' || n)::uuid, u), ' ' ORDER BY o)
     FROM unnest(ARRAY['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a5',
                       '00000000-0000-0000-0000-0000000000a6', '00000000-0000-0000-0000-0000000000a4', NULL]::uuid[]) WITH ORDINALITY t(u, o)), ' | ' ORDER BY n)
     FROM generate_series(2, 5) n),
  -- circle: owner a1 and admin a3 are refused (can_view_with_scope 'circle' = are_synced(viewer, owner), never true for
  -- self, no admin branch) — a PRE-IMAGE quirk, preserved, reported, not fixed here.
  '2=not_allowed not_allowed ok:false:2/1/1/- not_allowed not_allowed not_allowed | '
  || '3=ok:true:2/1/1/1 not_allowed not_allowed not_allowed not_allowed not_allowed | '
  || '4=ok:true:2/1/1/1 ok:true:2/1/1/1 not_allowed not_allowed not_allowed not_allowed | '
  || '5=ok:true:2/1/1/1 ok:true:2/1/1/1 not_allowed not_allowed not_allowed not_allowed');
SELECT pg_temp.chk('V3 attendees M1: owner a1 / admin a3 see all statuses; member a5 / outsider a4 going+interested; blocked a6 refused',
  pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-0000000000a1') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-0000000000a3') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-0000000000a5') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-0000000000a4') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-0000000000a6'),
  'declined,going,going,interested,pending declined,going,going,interested,pending going,going,interested going,going,interested not_allowed');
SELECT pg_temp.as_uid(NULL);

-- ---------------------------------------------------------------- G: games do not leak into meetup RPCs
SELECT pg_temp.chk('G1 a game id / its events id are meetup_not_found on card and attendees',
  (SELECT string_agg(split_part(pg_temp.card_out('public.rpc_meetup_card', x), ' ', 3) || '/'
                     || split_part(pg_temp.att_out('public.rpc_meetup_attendees', x, NULL, 50, 0), ' ', 3), ' ')
     FROM ((SELECT g.id AS x FROM public.games g ORDER BY g.id LIMIT 1)
           UNION ALL (SELECT g.event_id FROM public.games g ORDER BY g.event_id DESC LIMIT 2)) s),
  'meetup_not_found/meetup_not_found meetup_not_found/meetup_not_found meetup_not_found/meetup_not_found');

-- ---------------------------------------------------------------- A: access parity
SELECT pg_temp.chk('A1 anon may call card (M1), may not call attendees; authenticated may call both',
  pg_temp.as_('anon', NULL, $q$SELECT (public.rpc_meetup_card('72500000-0000-0000-0001-000000000001')->>'is_host')$q$) || ','
  || pg_temp.as_('anon', NULL, $q$SELECT count(*)::text FROM public.rpc_meetup_attendees('72500000-0000-0000-0001-000000000001')$q$) || ','
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a4',
                 $q$SELECT count(*)::text FROM public.rpc_meetup_attendees('72500000-0000-0000-0001-000000000001')$q$),
  'false,ERR 42501,3');
SELECT pg_temp.chk('A2 API roles still cannot read public.events directly',
  pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.events') || ','
  || pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.events'),
  'ERR 42501,ERR 42501');
SELECT pg_temp.chk('A3 events posture unchanged (ACL, RLS, FORCE RLS, zero policies)',
  (SELECT coalesce(relacl::text, '-') || ':' || relrowsecurity || ':' || relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
  || ':' || (SELECT count(*) FROM pg_policy WHERE polrelid = 'public.events'::regclass),
  '{postgres=arwdDxt/postgres,service_role=arwdDxt/postgres}:true:true:0');

-- ---------------------------------------------------------------- R: rpc_meetup_my (pre-image cannot execute; pinned unchanged)
SELECT pg_temp.chk('R1 rpc_meetup_my raises 42703 (undefined column) in both images',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1', 'SELECT count(*)::text FROM public.rpc_meetup_my()'), 'ERR 42703');

-- ---------------------------------------------------------------- X: EXPLAIN shape of the function's lookup statement
-- The statement text explained is asserted to be the one inside the function body (not a paraphrase).
SELECT '#PLAN|card lookup|' || replace(pg_temp.plan(
  CASE WHEN pg_temp.post()
       THEN $s$select mt.id, mt.description, mt.location_name, mt.host_actor_id, e.creator_user_id, e.creator_profile_id, e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.is_cancelled, e.sport_id, e.area_id, e.venue_id, e.min_skill::integer as min_skill, e.max_skill::integer as max_skill from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id = '72500000-0000-0000-0001-000000000001'$s$
       ELSE $s$select * from public.meetups where id = '72500000-0000-0000-0001-000000000001'$s$ END), E'\n', E'\n#PLAN|  ');
SELECT pg_temp.chk('X1 card lookup: events scans : SubPlans : statement is in the body',
  (WITH p AS (SELECT pg_temp.plan(CASE WHEN pg_temp.post()
       THEN $s$select mt.id, mt.description, mt.location_name, mt.host_actor_id, e.creator_user_id, e.creator_profile_id, e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.is_cancelled, e.sport_id, e.area_id, e.venue_id, e.min_skill::integer as min_skill, e.max_skill::integer as max_skill from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id = '72500000-0000-0000-0001-000000000001'$s$
       ELSE $s$select * from public.meetups where id = '72500000-0000-0000-0001-000000000001'$s$ END) t)
   SELECT pg_temp.cnt(t, ' on events') || ':' || pg_temp.cnt(t, 'SubPlan') FROM p) || ':' ||
  (SELECT position(CASE WHEN pg_temp.post() THEN 'join public.events e on e.id = mt.event_id and e.event_type = ''meetup''' ELSE 'select * into m from public.meetups where id = p_meetup_id' END
                   IN prosrc) > 0 FROM pg_proc WHERE oid = 'public.rpc_meetup_card(uuid,text)'::regprocedure)::text,
  CASE WHEN pg_temp.post() THEN '1:0:true' ELSE '0:0:true' END);
SELECT pg_temp.chk('X2 attendees lookup: events scans : SubPlans',
  (WITH p AS (SELECT pg_temp.plan(CASE WHEN pg_temp.post()
       THEN $s$select mt.id, e.creator_user_id, e.listing_visibility from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id = '72500000-0000-0000-0001-000000000001'$s$
       ELSE $s$select * from public.meetups where id = '72500000-0000-0000-0001-000000000001'$s$ END) t)
   SELECT pg_temp.cnt(t, ' on events') || ':' || pg_temp.cnt(t, 'SubPlan') FROM p),
  CASE WHEN pg_temp.post() THEN '1:0' ELSE '0:0' END);

-- ---------------------------------------------------------------- C: consumer — wrapped rpc_meetup_update returns rpc_meetup_card
-- Runs through the KAN-712 wrapper (events lock -> inner -> guard routes to events -> mirror). Returned card must carry the
-- new title and equal the legacy card read immediately after.
SELECT pg_temp.chk('C1 rpc_meetup_update(M8) returns the updated card, equal to legacy',
  pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$SELECT (j->>'title') || ':' || (j->>'capacity') || ':' || (j::text = pg_temp.legacy_card('72500000-0000-0000-0001-000000000008')::text)
         FROM (SELECT public.rpc_meetup_update('72500000-0000-0000-0001-000000000008', 'B06 M8 renamed', NULL, NULL, NULL, NULL, 12) j) s$q$),
  'B06 M8 renamed:12:true');

-- ---------------------------------------------------------------- P: provenance — events DISAGREES with meetups
-- Triggers off for this transaction only (session_replication_role = replica) so the mirror cannot reconcile.
SET LOCAL session_replication_role = replica;
UPDATE public.events SET title = 'B06 events title', capacity = 77, is_cancelled = true,
                         start_at = timestamptz '2035-06-01 09:00+00', end_at = timestamptz '2035-06-01 10:00+00',
                         min_skill = 3, max_skill = 9
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '72500000-0000-0000-0001-000000000001');
UPDATE public.events SET listing_visibility = 'hidden'
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '72500000-0000-0000-0001-000000000002');
UPDATE public.events SET listing_visibility = 'public'
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '72500000-0000-0000-0001-000000000003');
UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a4', creator_profile_id = '00000000-0000-0000-0000-0000000000b4'
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '72500000-0000-0000-0001-000000000006');
UPDATE public.events SET event_type = 'game'
 WHERE id = (SELECT event_id FROM public.meetups WHERE id = '72500000-0000-0000-0001-000000000007');
SET LOCAL session_replication_role = origin;

SELECT pg_temp.as_uid('00000000-0000-0000-0000-0000000000a1');
SELECT pg_temp.chk('P1 card shared keys follow events (title, capacity, cancelled, start/end, skills); unshared keep meetups',
  (SELECT concat_ws(',', j->>'title', j->>'capacity', j->>'is_cancelled', j->>'start_at', j->>'end_at', j->>'min_skill', j->>'max_skill',
                    j->>'description', j->>'location_name')
     FROM (SELECT public.rpc_meetup_card('72500000-0000-0000-0001-000000000001') j) s),
  CASE WHEN pg_temp.post()
       THEN 'B06 events title,77,true,2035-06-01T09:00:00+00:00,2035-06-01T10:00:00+00:00,3,9,desc 1,Here'
       ELSE 'B06 M1 public,10,false,2031-04-02T10:00:00+00:00,2031-04-02T12:00:00+00:00,2,8,desc 1,Here' END);
SELECT pg_temp.as_uid(NULL);
SELECT pg_temp.chk('P2 visibility follows events: M2 circle->hidden (member a5), M3 hidden->public (outsider a4, card + attendees)',
  pg_temp.card_brief('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000002', '00000000-0000-0000-0000-0000000000a5') || ' '
  || pg_temp.card_brief('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000003', '00000000-0000-0000-0000-0000000000a4') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000003', '00000000-0000-0000-0000-0000000000a4'),
  CASE WHEN pg_temp.post() THEN 'not_allowed ok:false:2/1/1/- going,going,interested' ELSE 'ok:false:2/1/1/- not_allowed not_allowed' END);
SELECT pg_temp.as_uid(NULL);
SELECT pg_temp.chk('P3 host follows events.creator_user_id (M6 -> a4): is_host, owner_profile_id, pending visible',
  pg_temp.card_brief('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000006', '00000000-0000-0000-0000-0000000000a4') || ' '
  || right(pg_temp.card_key('72500000-0000-0000-0001-000000000006', '00000000-0000-0000-0000-0000000000a4', 'owner_profile_id'), 2) || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000006', '00000000-0000-0000-0000-0000000000a4'),
  CASE WHEN pg_temp.post() THEN 'ok:true:2/1/1/1 b4 declined,going,going,interested,pending' ELSE 'ok:false:2/1/1/- b1 going,going,interested' END);
SELECT pg_temp.as_uid(NULL);
SELECT pg_temp.chk('P4 event_type filter: M7 whose parent says game is meetup_not_found on card and attendees',
  pg_temp.card_brief('public.rpc_meetup_card', '72500000-0000-0000-0001-000000000007', '00000000-0000-0000-0000-0000000000a1') || ' '
  || pg_temp.att_brief('public.rpc_meetup_attendees', '72500000-0000-0000-0001-000000000007', '00000000-0000-0000-0000-0000000000a1'),
  CASE WHEN pg_temp.post() THEN 'meetup_not_found meetup_not_found' ELSE 'ok:true:2/1/1/1 declined,going,going,interested,pending' END);

SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY n;
SELECT '#SUMMARY|expect=' || current_setting('kan725.expect') || '|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;
