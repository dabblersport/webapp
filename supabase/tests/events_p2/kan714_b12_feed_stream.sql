-- KAN-731 (KAN-714 B12): probes for 20261104101200_kan714_b12_feed_notifications_stream.sql.
-- LOCAL THROWAWAY DATABASE ONLY. Runs inside BEGIN ... ROLLBACK and leaves nothing behind.
-- Build (bash, from the repository root; PostgreSQL 16 initdb/pg_ctl/psql on PATH; brand new cluster):
--   bash supabase/tests/events_p2/build_kan731.sh /tmp/kan731_pg 54731
-- That script is the complete ordered chain, every file loaded with psql -v ON_ERROR_STOP=1 into database k731:
--    1 supabase/tests/events_p1/local_harness_kan711.sql
--    2 supabase/tests/events_p1/local_seed_kan711.sql
--    3 supabase/tests/events_p2/local_harness_kan712.sql
--    4 supabase/tests/events_p2_kan713/local_harness_kan713.sql
--    5 supabase/migrations/20261101140000_kan710_events_parent_schema.sql
--    6 supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql
--    7 supabase/migrations/20261102120000_kan711_events_backfill.sql
--    8 CALL public.kan711_events_backfill_run();  SELECT public.kan711_events_validate_links();
--    9 supabase/migrations/20261103100000_kan712_events_write_contract.sql
--   10 supabase/migrations/20261103110000_kan712_cutover.sql
--   11 supabase/migrations/20261104100000_kan713_access_helpers.sql
--   12 supabase/migrations/20261104110000_kan713_location_triggers.sql
--   13 supabase/migrations/20261104110300_kan718_d07_series_occurrence_unique.sql
--   14 supabase/tests/events_p2/local_harness_kan731.sql   (PRE-IMAGES verbatim: rpc_get_activity_feed from
--      20261101130000_kan689_rpc_get_activity_feed_fix.sql:7-81, trg_meetup_rsvps_notify and
--      trg_meetups_cancel_notify from 20260915150000_meetups_notifications.sql:113-197 / 202-240, active_stream from
--      20261020120000_kan595_active_stream.sql:46-172, with owner/grants; md5 pins asserted; column stand-ins)
-- Run (same shell; C="-X -v ON_ERROR_STOP=1 -h /tmp -p 54731 -U postgres -d k731"):
--   a. pre-image:  PGOPTIONS='-c kan731.local=on' psql $C -f supabase/tests/events_p2/kan714_b12_feed_stream.sql
--                  -> 'PRE-IMAGE OK: every [=] passes and every [K] fails (N K checks)'
--   b. apply:      psql $C -f supabase/migrations/20261104101200_kan714_b12_feed_notifications_stream.sql
--                  -> NOTICE 'KAN-731 applied: Q1-Q3 ok, N probe outputs identical (...)'
--   c. applied:    PGOPTIONS='-c kan731.local=on' psql $C -f supabase/tests/events_p2/kan714_b12_feed_stream.sql
--                  -> 'ALL PASS (N checks, migration applied)'
--   d. rollback:   psql $C -f supabase/tests/events_p2/datahash_kan731.sql
--                  sed -n '/^-- ROLLBACK (run as postgres/,$p' supabase/migrations/20261104101200_kan714_b12_feed_notifications_stream.sql \
--                    | sed -n '/^-- begin;/,/^-- commit;/p' | sed -E 's/^-- ?//' | psql $C
--                  psql $C -f supabase/tests/events_p2/datahash_kan731.sql
--                  -> the six table hashes identical; the four fn md5s equal the pins
--   e. restored:   repeat (a) -> 'PRE-IMAGE OK ...'
--   stop:          pg_ctl -D /tmp/kan731_pg stop -m fast
--
-- Check kinds:
--   [=] parity: must PASS on the pre-image AND after the migration (shape, ids, counts, no doubles, pagination,
--       filters, viewer/blocked parity, no N+1, notification count and payload parity, attributes).
--   [K] change: must FAIL on the pre-image and PASS after (events is read: values, cancel, visibility, triggers).
--   [R] rollback (only when applied): restoring the pre-image texts in a subtransaction leaves the data hashes
--       equal, md5s equal to the pins and ACLs unchanged.
-- Output: one PASS/FAIL line per check, then 'ALL PASS' (applied) or 'PRE-IMAGE OK: every [=] passes and every
-- [K] fails' (not applied).
--
-- Seed (inside the transaction): one game G 73100000-...-0001 and one meetup M 73100000-...-0101 (request policy),
-- both hosted by a1, in area c2; a second meetup M2 = 71300000-...-0102 is reused for the system-cancel path.
-- Actors: a1 owner, a2 non-member, a4 roster member, a5 follower/friend, a6 BLOCKED by a1, a7 invitee.
-- a3 is a harness admin and is not used as a plain non-owner.

\set ON_ERROR_STOP 1
begin;

do $$ begin
  if coalesce(current_setting('kan731.local', true), '') <> 'on' then
    raise exception 'KAN-731 probes: refusing to run; set kan731.local=on (local throwaway database only)';
  end if;
end $$;

create temp table res (id text primary key, kind text, got text, want text, ord serial);
grant all on res to public;
grant all on res_ord_seq to public;

-- Legacy references: the verbatim pre-image bodies under other names (pg_get_functiondef of the pinned texts).
CREATE OR REPLACE FUNCTION public.kan731_legacy_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH me AS (
    SELECT auth.uid() AS user_id
  ),
  game_created AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'created'::text                                               AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      g.created_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN me ON g.creator_user_id = me.user_id
    WHERE g.is_cancelled = false
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND g.is_cancelled = false
      AND g.creator_user_id <> me.user_id
  ),
  game_events AS (
    SELECT * FROM game_created
    UNION ALL
    SELECT * FROM game_joined
  ),
  filtered AS (
    SELECT * FROM game_events e
    WHERE (_period = 'all' OR e.time_bucket = _period)
      AND (_cursor IS NULL OR e.happened_at < _cursor)
  )
  SELECT f.* FROM filtered f
  ORDER BY
    CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
    f.scheduled_for ASC,
    f.happened_at DESC,
    f.priority DESC
  LIMIT _limit;
END;
$function$;
CREATE OR REPLACE FUNCTION public.kan731_legacy_rsvps_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_host_uid   uuid;
  v_title      text;
  v_name       text;
  v_old        text;
BEGIN
  -- OLD is unassigned on INSERT, so read it once, guarded.
  IF TG_OP = 'UPDATE' THEN v_old := OLD.status; END IF;

  -- Only status changes (and brand-new rows) are events.
  IF TG_OP = 'UPDATE' AND v_old IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT m.creator_user_id, m.title INTO v_host_uid, v_title
    FROM public.meetups m WHERE m.id = NEW.meetup_id;
  IF v_host_uid IS NULL THEN RETURN NEW; END IF;

  SELECT p.display_name INTO v_name
    FROM public.profiles p
   WHERE p.user_id = NEW.user_id AND p.is_active = true
   LIMIT 1;
  v_name := COALESCE(v_name, 'Someone');

  -- Someone asks to join (request policy): tell the host. Never the host's own row.
  IF NEW.status = 'pending'
     AND v_old IS DISTINCT FROM 'pending'
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.request_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' asked to join your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Attendee flips to 'going' themselves (UPDATE only: a fresh INSERT is covered
  -- by the existing meetup.player_joined chain; see header).
  IF TG_OP = 'UPDATE' AND NEW.status = 'going'
     AND v_actor IS NOT NULL AND v_actor = NEW.user_id
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.rsvp_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' is going to your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Somebody else (the host or an admin) decides a pending request: tell the attendee.
  IF TG_OP = 'UPDATE' AND v_old = 'pending'
     AND v_actor IS NOT NULL AND v_actor <> NEW.user_id
  THEN
    IF NEW.status = 'going' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'You''re in! Your request to join was approved', v_title);
    ELSIF NEW.status = 'interested' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'Your request was approved, but the meet-up is full', v_title);
    ELSIF NEW.status IN ('cancelled', 'declined') THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_declined', 'meetup', NEW.meetup_id, v_actor,
        'Your request to join was declined', v_title);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION public.kan731_legacy_cancel_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  r       record;
BEGIN
  IF NOT (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) THEN
    RETURN NEW;
  END IF;

  FOR r IN
    SELECT DISTINCT s.user_id
      FROM public.meetup_rsvps s
     WHERE s.meetup_id = NEW.id
       AND s.status IN ('going', 'interested', 'pending')
       AND s.user_id IS DISTINCT FROM v_actor
  LOOP
    PERFORM public.process_notification_event(
      r.user_id, 'meetup.cancelled', 'meetup', NEW.id,
      COALESCE(v_actor, NEW.creator_user_id),
      'A meet-up you signed up for was cancelled', NEW.title);
  END LOOP;

  RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION public.kan731_legacy_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, g.created_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, g.start_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, g.end_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, m.created_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, m.start_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND m.start_at <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(m.end_at, m.start_at), 'meetup'::text, m.id, m.creator_profile_id,
           a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND COALESCE(m.end_at, m.start_at) <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
  ),
  filtered AS (
    SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
      FROM ev, prm
     WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
       AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
       AND (
         p_before IS NULL
         OR ev.event_at < p_before
         OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
             AND ev.event_at = p_before
             AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
       )
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
  )
  SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
    FROM filtered f
   ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
   LIMIT (SELECT lim FROM prm);
$function$;

-- Is the migration applied?
create temp table st as
select position('KAN-731' in prosrc) > 0 as applied from pg_proc
 where oid = 'public.rpc_get_activity_feed(text,integer,timestamp with time zone)'::regprocedure;

-- Helpers -----------------------------------------------------------------------------------------------------
create function pg_temp.as_user(u uuid) returns void language sql as $f$
  select set_config('request.jwt.claim.sub', coalesce(u::text, ''), true),
         set_config('request.jwt.claims', case when u is null then ''
                    else json_build_object('sub', u, 'role', 'authenticated')::text end, true);
$f$;
create function pg_temp.feed(fn text, u uuid, per text, lim int, cur timestamptz) returns jsonb language plpgsql as $f$
declare j jsonb;
begin
  perform pg_temp.as_user(u);
  execute format('select coalesce(jsonb_agg(to_jsonb(f) - %L order by f.ordinality), %L::jsonb) from %s($1, $2, $3) with ordinality f',
                 'ordinality', '[]', fn) into j using per, lim, cur;
  return j;
end $f$;
create function pg_temp.stream(fn text, u uuid, types text[], city text, lim int, bef timestamptz, btype text, bent uuid)
returns jsonb language plpgsql as $f$
declare j jsonb;
begin
  perform pg_temp.as_user(u);
  execute format('select coalesce(jsonb_agg(to_jsonb(f) - %L order by f.ordinality), %L::jsonb) from %s($1, $2, $3, $4, $5, $6) with ordinality f',
                 'ordinality', '[]', fn) into j using types, city, lim, bef, btype, bent;
  return j;
end $f$;
create function pg_temp.msort(j jsonb) returns jsonb language sql immutable as $f$
  select coalesce(jsonb_agg(e order by e::text), '[]'::jsonb) from jsonb_array_elements(j) e
$f$;
create function pg_temp.sig(j jsonb) returns text language sql immutable as $f$
  select md5(j::text) || ' n=' || jsonb_array_length(j)
$f$;
create function pg_temp.keys(j jsonb) returns text language sql immutable as $f$
  select coalesce(string_agg(distinct k || ':' || jsonb_typeof(v), ','), '') from jsonb_array_elements(j) e, jsonb_each(e) x(k, v)
$f$;
-- keyset walk of the stream, page size p, until exhausted (max 40 pages)
create function pg_temp.walk(fn text, u uuid, p int) returns text language plpgsql as $f$
declare j jsonb; lastr jsonb; acc text := ''; i int := 0;
begin
  j := pg_temp.stream(fn, u, null, null, p, null, null, null);
  while jsonb_array_length(j) > 0 and i < 40 loop
    acc := acc || (select string_agg(e->>'event_type' || '/' || (e->>'entity_id'), ',' order by o) from jsonb_array_elements(j) with ordinality x(e, o)) || ';';
    lastr := j -> -1;
    j := pg_temp.stream(fn, u, null, null, p, (lastr->>'event_at')::timestamptz, lastr->>'event_type', (lastr->>'entity_id')::uuid);
    i := i + 1;
  end loop;
  return acc;
end $f$;

create temp table vw (name text, u uuid, ord int);
insert into vw values ('a1', '00000000-0000-0000-0000-0000000000a1', 1), ('a2', '00000000-0000-0000-0000-0000000000a2', 2),
  ('a4', '00000000-0000-0000-0000-0000000000a4', 3), ('a5', '00000000-0000-0000-0000-0000000000a5', 4),
  ('a6-blocked', '00000000-0000-0000-0000-0000000000a6', 5), ('a7', '00000000-0000-0000-0000-0000000000a7', 6), ('anon', null, 7);

-- Seed ----------------------------------------------------------------------------------------------------------
update public.areas set city = 'Dubai' where id = '00000000-0000-0000-0000-0000000000c1';
update public.areas set city = 'Abu Dhabi' where id = '00000000-0000-0000-0000-0000000000c2';
update public.profiles set display_name = 'Player ' || right(user_id::text, 2), profile_type = 'personal',
       created_at = '2025-12-01 00:00+00'::timestamptz + make_interval(days => right(user_id::text, 1)::int)
 where display_name is null;
insert into public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id)
select '73100000-0000-0000-0000-000000000001', 'Kan731 seeded game', g.creator_profile_id, g.creator_user_id,
       '2026-02-01 18:00+00', '2026-02-01 19:00+00', 10, 'public', 'open', g.sport_id, g.geo_location_id,
       '00000000-0000-0000-0000-0000000000c2'
  from public.games g where g.id = '71300000-0000-0000-0000-000000000001';
insert into public.meetups (id, creator_profile_id, creator_user_id, title, listing_visibility, rsvp_policy, start_at, end_at, area_id)
values ('73100000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        'Kan731 seeded meetup', 'public', 'request', '2026-02-02 08:00+00', '2026-02-02 09:00+00', '00000000-0000-0000-0000-0000000000c2');
insert into public.game_roster (game_id, user_id, profile_id, role, status, joined_at)
values ('73100000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000b4',
        'player', 'active', '2026-01-20 10:00+00');
set constraints all immediate;

insert into res (id, kind, got, want)
select 'S0 seed game + meetup linked to events', '=', count(*)::text, '2'
  from public.events e
 where (e.id = '73100000-0000-0000-0000-000000000001' and e.event_type = 'game'
        and exists (select 1 from public.games g where g.id = e.id and g.event_id = e.id))
    or (e.id = '73100000-0000-0000-0000-000000000101' and e.event_type = 'meetup'
        and exists (select 1 from public.meetups m where m.id = e.id and m.event_id = e.id));

-- S [=] legacy shape: keys, types, ids ----------------------------------------------------------------------------
insert into res (id, kind, got, want)
select 'S1 feed keys/types ' || name, '=',
       pg_temp.keys(pg_temp.feed('public.rpc_get_activity_feed', u, 'all', 1000, null)),
       pg_temp.keys(pg_temp.feed('public.kan731_legacy_feed', u, 'all', 1000, null))
  from vw where name in ('a1', 'a4');
insert into res (id, kind, got, want)
select 'S2 stream keys/types ' || name, '=',
       pg_temp.keys(pg_temp.stream('public.active_stream', u, null, null, 50, null, null, null)),
       pg_temp.keys(pg_temp.stream('public.kan731_legacy_stream', u, null, null, 50, null, null, null))
  from vw where name in ('a1', 'a2');
insert into res (id, kind, got, want)
select 'S3 feed ids are game ids (id = subject_id = games.id)', '=', count(*)::text, '0'
  from vw, jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', u, 'all', 1000, null)) e
 where e->>'id' is distinct from e->>'subject_id' or e->>'subject_type' <> 'game'
    or not exists (select 1 from public.games g where g.id = (e->>'subject_id')::uuid);
insert into res (id, kind, got, want)
select 'S4 stream ids are subtype ids', '=', count(*)::text, '0'
  from vw, jsonb_array_elements(pg_temp.stream('public.active_stream', u, null, null, 50, null, null, null)) e
 where (e->>'entity_kind' = 'game' and not exists (select 1 from public.games g where g.id = (e->>'entity_id')::uuid))
    or (e->>'entity_kind' = 'meetup' and not exists (select 1 from public.meetups m where m.id = (e->>'entity_id')::uuid));
insert into res (id, kind, got, want)
select 'S5 seeded game in a1 feed as created, subject_id = game id', '=',
       (select string_agg(e->>'verb' || '/' || (e->>'subject_id') || '/' || (e->>'payload'), ',')
          from jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', '00000000-0000-0000-0000-0000000000a1', 'all', 1000, null)) e
         where e->>'subject_id' = '73100000-0000-0000-0000-000000000001'),
       'created/73100000-0000-0000-0000-000000000001/{"role": "host"}';
insert into res (id, kind, got, want)
select 'S6 seeded game in a4 feed as joined, happened_at = roster joined_at', '=',
       (select string_agg(e->>'verb' || '/' || ((e->>'happened_at')::timestamptz = '2026-01-20 10:00+00')::text, ',')
          from jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', '00000000-0000-0000-0000-0000000000a4', 'all', 1000, null)) e
         where e->>'subject_id' = '73100000-0000-0000-0000-000000000001'),
       'joined/true';

-- C [=] counts and content equal legacy; no doubled rows -------------------------------------------------------
insert into res (id, kind, got, want)
select 'C1 feed ' || name || ' period=' || per, '=',
       pg_temp.sig(pg_temp.msort(pg_temp.feed('public.rpc_get_activity_feed', u, per, 1000, null))),
       pg_temp.sig(pg_temp.msort(pg_temp.feed('public.kan731_legacy_feed', u, per, 1000, null)))
  from vw, unnest(array['all', 'past', 'present', 'upcoming']) per;
insert into res (id, kind, got, want)
select 'C2 stream ' || name || ' types=' || coalesce(t, 'ALL'), '=',
       pg_temp.sig(pg_temp.stream('public.active_stream', u, case when t is null then null else array[t] end, null, 50, null, null, null)),
       pg_temp.sig(pg_temp.stream('public.kan731_legacy_stream', u, case when t is null then null else array[t] end, null, 50, null, null, null))
  from vw, unnest(array[null, 'player_joined', 'venue_added', 'game_created', 'game_started', 'game_ended',
                        'meetup_created', 'meetup_started', 'meetup_completed']) t;
insert into res (id, kind, got, want)
select 'C3 no doubled feed rows (subject_id, verb)', '=', (count(*) - count(distinct (u, e->>'subject_id', e->>'verb')))::text, '0'
  from vw, jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', u, 'all', 1000, null)) e;
insert into res (id, kind, got, want)
select 'C4 no doubled stream rows (event_type, entity_id)', '=', (count(*) - count(distinct (u, e->>'event_type', e->>'entity_id')))::text, '0'
  from vw, jsonb_array_elements(pg_temp.stream('public.active_stream', u, null, null, 50, null, null, null)) e;
insert into res (id, kind, got, want)
select 'C5 seeded game/meetup each once per stream kind (a2)', '=',
       (select string_agg(e->>'event_type', ',' order by e->>'event_type')
          from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a2', null, null, 50, null, null, null)) e
         where e->>'entity_id' in ('73100000-0000-0000-0000-000000000001', '73100000-0000-0000-0000-000000000101')),
       'game_created,game_ended,game_started,meetup_completed,meetup_created,meetup_started';
insert into res (id, kind, got, want)
select 'C6 stream count per kind equals legacy (all viewers)', '=',
       (select string_agg(k || '=' || n, ',' order by k) from (select e->>'event_type' k, count(*) n from vw,
          jsonb_array_elements(pg_temp.stream('public.active_stream', u, null, null, 50, null, null, null)) e group by 1) s),
       (select string_agg(k || '=' || n, ',' order by k) from (select e->>'event_type' k, count(*) n from vw,
          jsonb_array_elements(pg_temp.stream('public.kan731_legacy_stream', u, null, null, 50, null, null, null)) e group by 1) s);

-- P [=] pagination and filters -----------------------------------------------------------------------------------
insert into res (id, kind, got, want)
select 'P1 feed ordered page ' || name || ' limit=' || lim || ' period=' || per, '=',
       pg_temp.sig(pg_temp.feed('public.rpc_get_activity_feed', u, per, lim, null)),
       pg_temp.sig(pg_temp.feed('public.kan731_legacy_feed', u, per, lim, null))
  from vw, unnest(array[1, 2, 3, 5]) lim, unnest(array['all', 'past']) per where name in ('a1', 'a4');
insert into res (id, kind, got, want)
select 'P2 feed cursor ' || name || ' cursor=' || c, '=',
       pg_temp.sig(pg_temp.msort(pg_temp.feed('public.rpc_get_activity_feed', u, 'all', 1000, c))),
       pg_temp.sig(pg_temp.msort(pg_temp.feed('public.kan731_legacy_feed', u, 'all', 1000, c)))
  from vw, unnest(array['2026-01-01 00:00+00'::timestamptz, '2030-01-01 00:00+00', now(), '2000-01-01 00:00+00']) c
 where name in ('a1', 'a4');
insert into res (id, kind, got, want)
select 'P3 stream keyset walk ' || name || ' page=' || p, '=',
       pg_temp.walk('public.active_stream', u, p), pg_temp.walk('public.kan731_legacy_stream', u, p)
  from vw, unnest(array[1, 3]) p where name in ('a1', 'a2', 'a6-blocked');
insert into res (id, kind, got, want)
select 'P4 stream walk page=3 = one page of 50 (a2)', '=',
       replace(pg_temp.walk('public.active_stream', '00000000-0000-0000-0000-0000000000a2', 3), ';', ','),
       (select string_agg(e->>'event_type' || '/' || (e->>'entity_id'), ',' order by o) || ','
          from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a2', null, null, 50, null, null, null))
               with ordinality x(e, o));
insert into res (id, kind, got, want)
select 'P5 stream filter ' || name || ' types=' || coalesce(array_to_string(t, '+'), 'ALL') || ' city=' || coalesce(c, 'NULL') || ' lim=' || lim, '=',
       pg_temp.sig(pg_temp.stream('public.active_stream', u, t, c, lim, null, null, null)),
       pg_temp.sig(pg_temp.stream('public.kan731_legacy_stream', u, t, c, lim, null, null, null))
  from vw,
       (values (null::text[]), (array['game_created', 'meetup_created']), (array['game_ended', 'meetup_completed', 'venue_added'])) tt(t),
       (values (null::text), ('Dubai'), ('ABU DHABI'), ('  '), ('Nowhere')) cc(c),
       (values (0), (2), (999)) ll(lim)
 where name in ('a1', 'a2');
insert into res (id, kind, got, want)
select 'P6 city filter keeps only that city (a2, Abu Dhabi)', '=',
       (select coalesce(string_agg(distinct e->>'city', ','), '') from jsonb_array_elements(
          pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a2', array['game_created', 'meetup_created'], 'abu dhabi', 50, null, null, null)) e),
       'Abu Dhabi';

-- V [=] non-owner, blocked, role parity ---------------------------------------------------------------------------
insert into res (id, kind, got, want)
select 'V1 blocked a6 sees no a1-hosted game/meetup', '=', count(*)::text, '0'
  from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a6', null, null, 50, null, null, null)) e
 where (e->>'entity_kind' = 'game' and exists (select 1 from public.events x where x.id = (e->>'entity_id')::uuid
          and x.creator_user_id = '00000000-0000-0000-0000-0000000000a1'))
    or (e->>'entity_kind' = 'meetup' and exists (select 1 from public.events x where x.id = (e->>'entity_id')::uuid
          and x.creator_user_id = '00000000-0000-0000-0000-0000000000a1'));
insert into res (id, kind, got, want)
select 'V2 non-owner a2 sees no other user non-public meetup and no cancelled row', '=', count(*)::text, '0'
  from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a2', null, null, 50, null, null, null)) e
  join public.events x on x.id = (e->>'entity_id')::uuid
 where x.creator_user_id <> '00000000-0000-0000-0000-0000000000a2'
   and (x.is_cancelled or (x.event_type = 'meetup' and x.listing_visibility <> 'public'));
insert into res (id, kind, got, want)
select 'V3 a1 (owner) sees own seeded meetup, a6 (blocked) does not', '=',
       (select count(*) from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a1', array['meetup_created'], null, 50, null, null, null)) e
         where e->>'entity_id' = '73100000-0000-0000-0000-000000000101')::text || '/' ||
       (select count(*) from jsonb_array_elements(pg_temp.stream('public.active_stream', '00000000-0000-0000-0000-0000000000a6', array['meetup_created'], null, 50, null, null, null)) e
         where e->>'entity_id' = '73100000-0000-0000-0000-000000000101')::text,
       '1/0';
-- as the API roles: authenticated runs both surfaces; anon may not execute active_stream (no grant) and gets an
-- empty feed (auth.uid() is null). Legacy copies have default PUBLIC execute, so the comparison is on the result.
create temp table vr (who text, f jsonb, s jsonb, err text);
grant all on vr to public;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
set local role authenticated;
insert into vr (who, f, s)
select 'authenticated a2',
       (select coalesce(jsonb_agg(to_jsonb(f) order by f::text), '[]') from public.rpc_get_activity_feed('all', 1000, null) f),
       (select coalesce(jsonb_agg(to_jsonb(s) order by s.event_at desc, s.event_type desc, s.entity_id desc), '[]') from public.active_stream(null, null, 50, null, null, null) s);
reset role;
insert into res (id, kind, got, want)
select 'V4 role authenticated a2 equals legacy', '=', pg_temp.sig(f) || '|' || pg_temp.sig(s),
       pg_temp.sig(pg_temp.msort(pg_temp.feed('public.kan731_legacy_feed', '00000000-0000-0000-0000-0000000000a2', 'all', 1000, null))) || '|' ||
       pg_temp.sig(pg_temp.stream('public.kan731_legacy_stream', '00000000-0000-0000-0000-0000000000a2', null, null, 50, null, null, null))
  from vr where who = 'authenticated a2';
select pg_temp.as_user(null);
set local role anon;
do $$
declare e text := 'none'; n int;
begin
  begin
    perform * from public.active_stream(null, null, 50, null, null, null);
  exception when others then e := sqlstate;
  end;
  select count(*) into n from public.rpc_get_activity_feed('all', 1000, null);
  insert into vr (who, err) values ('anon', e || '/feed=' || n);
end $$;
reset role;
insert into res (id, kind, got, want)
select 'V5 anon: active_stream denied, feed empty', '=', err, '42501/feed=0' from vr where who = 'anon';

-- N no N+1: inlinable copies of the current bodies (same SQL, no SECURITY DEFINER/SET) are EXPLAINed. --------------
do $$
declare
  src text; q text; pf json; ps json; lf json; ls json;
  n_sub_f int; n_sub_s int; n_ev_f int; n_ev_s int; l_sub_f int; l_sub_s int;
begin
  -- stream (LANGUAGE sql): body as is
  for src, q in select p.prosrc, n from pg_proc p, (values ('public.active_stream', 'kan731_s'), ('public.kan731_legacy_stream', 'kan731_ls')) v(f, n)
                 where p.oid = to_regproc(v.f) loop
    execute format('create function pg_temp.%I(p_event_types text[], p_city text, p_limit integer, p_before timestamptz, p_before_type text, p_before_entity uuid) '
                   'returns table(event_type text, event_at timestamptz, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text) '
                   'language sql stable as %L', q, src);
  end loop;
  -- feed (plpgsql RETURN QUERY): the query text between RETURN QUERY and the final END
  for src, q in select p.prosrc, n from pg_proc p, (values ('public.rpc_get_activity_feed', 'kan731_f'), ('public.kan731_legacy_feed', 'kan731_lf')) v(f, n)
                 where p.oid = to_regproc(v.f) loop
    src := substring(src from 'RETURN QUERY(.*);\s*END;\s*$');
    execute format('create function pg_temp.%I(_period text, _limit integer, _cursor timestamptz) '
                   'returns table(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamptz, scheduled_for timestamptz, priority integer, payload jsonb) '
                   'language sql stable as %L', q, src);
  end loop;
  execute 'explain (format json, costs off) select * from pg_temp.kan731_f(''all'', 50, null)' into pf;
  execute 'explain (format json, costs off) select * from pg_temp.kan731_s(null, null, 50, null, null, null)' into ps;
  execute 'explain (format json, costs off) select * from pg_temp.kan731_lf(''all'', 50, null)' into lf;
  execute 'explain (format json, costs off) select * from pg_temp.kan731_ls(null, null, 50, null, null, null)' into ls;
  raise notice E'EXPLAIN active_stream (current body):\n%', jsonb_pretty(ps::jsonb -> 0 -> 'Plan');
  insert into res (id, kind, got, want) values
    ('N0 copies inline (no Function Scan at the top)', '=',
     concat_ws(',', (pf::jsonb #>> '{0,Plan,Node Type}' <> 'Function Scan')::text, (ps::jsonb #>> '{0,Plan,Node Type}' <> 'Function Scan')::text,
                    (lf::jsonb #>> '{0,Plan,Node Type}' <> 'Function Scan')::text, (ls::jsonb #>> '{0,Plan,Node Type}' <> 'Function Scan')::text),
     'true,true,true,true');
  select count(*) into n_sub_f from jsonb_path_query(pf::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan")');
  select count(*) into n_sub_s from jsonb_path_query(ps::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan")');
  select count(*) into l_sub_f from jsonb_path_query(lf::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan")');
  select count(*) into l_sub_s from jsonb_path_query(ls::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan")');
  insert into res (id, kind, got, want) values
    ('N1 SubPlan count equals legacy (feed, stream)', '=', n_sub_f || ',' || n_sub_s, l_sub_f || ',' || l_sub_s);
  select count(*) into n_ev_f from jsonb_path_query(pf::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan").** ? (@."Relation Name" == "events")');
  select count(*) into n_ev_s from jsonb_path_query(ps::jsonb, 'strict $.** ? (@."Parent Relationship" == "SubPlan").** ? (@."Relation Name" == "events")');
  insert into res (id, kind, got, want) values
    ('N2 no events scan inside any SubPlan (feed, stream)', '=', n_ev_f || ',' || n_ev_s, '0,0');
  select count(*) into n_ev_f from jsonb_path_query(pf::jsonb, 'strict $.** ? (@."Relation Name" == "events")');
  select count(*) into n_ev_s from jsonb_path_query(ps::jsonb, 'strict $.** ? (@."Relation Name" == "events")');
  insert into res (id, kind, got, want) values
    ('N3 events joined once per branch in the plan (feed 2, stream 6)', 'K', n_ev_f || ',' || n_ev_s, '2,6');
end $$;
insert into res (id, kind, got, want)
select 'N4 every events read is a JOIN on event_id (feed, rsvps, stream)', 'K',
       string_agg(((length(prosrc) - length(replace(prosrc, 'public.events', ''))) / length('public.events'))::text || '=' ||
                  ((length(prosrc) - length(replace(prosrc, 'JOIN public.events e ON e.id = ', ''))) / length('JOIN public.events e ON e.id = '))::text,
                  ',' order by proname),
       '6=6,2=2,1=1'
  from pg_proc where oid in ('public.rpc_get_activity_feed(text,integer,timestamp with time zone)'::regprocedure,
                             'public.trg_meetup_rsvps_notify()'::regprocedure,
                             'public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)'::regprocedure);
insert into res (id, kind, got, want)
select 'N5 cancel trigger reads events once, before the recipient loop', 'K',
       ((length(prosrc) - length(replace(prosrc, 'public.events', ''))) / length('public.events'))::text || '/' ||
       (position('FROM public.events e WHERE e.id = NEW.event_id' in prosrc) between 1 and position('FOR r IN' in prosrc))::text,
       '1/true'
  from pg_proc where oid = 'public.trg_meetups_cancel_notify()'::regprocedure;

-- T [=] notification triggers: same count, same payloads, current vs legacy bodies --------------------------------
-- Scenario on the seeded meetup M (request policy, host a1): a2 asks (request_received), a1 approves
-- (request_approved), a7 asks and a1 declines (request_received + request_declined), a4 interested -> going
-- herself (rsvp_received), a1 cancels M through events (mirror -> meetups -> meetup.cancelled to a2, a4), and a
-- system cancel of M2 with a5 going (actor falls back to the creator).
create function pg_temp.kan731_scenario() returns jsonb language plpgsql as $f$
declare mx bigint := (select coalesce(max(id), 0) from public.notifications); j jsonb;
begin
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
  insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  values ('73100000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'pending');
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
  update public.meetup_rsvps set status = 'going'
   where meetup_id = '73100000-0000-0000-0000-000000000101' and user_id = '00000000-0000-0000-0000-0000000000a2';
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a7');
  insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  values ('73100000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000b7', 'pending');
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
  update public.meetup_rsvps set status = 'declined'
   where meetup_id = '73100000-0000-0000-0000-000000000101' and user_id = '00000000-0000-0000-0000-0000000000a7';
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a4');
  insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  values ('73100000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000b4', 'interested');
  update public.meetup_rsvps set status = 'going'
   where meetup_id = '73100000-0000-0000-0000-000000000101' and user_id = '00000000-0000-0000-0000-0000000000a4';
  perform pg_temp.as_user(null);
  insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  values ('71300000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000b5', 'going');
  perform pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
  update public.events set is_cancelled = true where id = '73100000-0000-0000-0000-000000000101';
  perform pg_temp.as_user(null);
  update public.events set is_cancelled = true where id = '71300000-0000-0000-0000-000000000102';
  select coalesce(jsonb_agg(jsonb_build_object('user', n.user_id, 'kind', n.kind, 'entity_type', n.entity_type, 'entity_id', n.entity_id,
                                               'actor', n.actor_user_id, 'title', n.title, 'body', n.body) order by n.id), '[]')
    into j from public.notifications n where n.id > mx;
  return j;
end $f$;
do $$
declare cur jsonb; leg jsonb; ok text := 'ok';
begin
  begin
    cur := pg_temp.kan731_scenario();
    raise exception using errcode = 'P0001', message = 'kan731_undo';
  exception when others then
    if sqlerrm <> 'kan731_undo' then cur := jsonb_build_array(jsonb_build_object('error', sqlstate || ' ' || sqlerrm)); end if;
  end;
  begin
    execute replace(pg_get_functiondef('public.kan731_legacy_rsvps_notify()'::regprocedure),
                    'FUNCTION public.kan731_legacy_rsvps_notify(', 'FUNCTION public.trg_meetup_rsvps_notify(');
    execute replace(pg_get_functiondef('public.kan731_legacy_cancel_notify()'::regprocedure),
                    'FUNCTION public.kan731_legacy_cancel_notify(', 'FUNCTION public.trg_meetups_cancel_notify(');
    leg := pg_temp.kan731_scenario();
    raise exception using errcode = 'P0001', message = 'kan731_undo';
  exception when others then
    if sqlerrm <> 'kan731_undo' then leg := jsonb_build_array(jsonb_build_object('error', sqlstate || ' ' || sqlerrm)); end if;
  end;
  perform pg_temp.as_user(null);
  insert into res (id, kind, got, want) values
    ('T1 notification count equals legacy', '=', jsonb_array_length(cur)::text, jsonb_array_length(leg)::text),
    ('T2 notification payloads equal legacy (user, kind, entity, actor, title, body)', '=', md5(cur::text), md5(leg::text)),
    ('T3 triggers fired (meetup.* rows by kind)', '=',
     (select string_agg(k || '=' || n, ',' order by k) from (select e->>'kind' k, count(*) n from jsonb_array_elements(cur) e
        where e->>'kind' like 'meetup.%' group by 1) s),
     'meetup.cancelled=3,meetup.request_approved=1,meetup.request_declined=1,meetup.request_received=2,meetup.rsvp_received=1'),
    ('T4 ids in notifications are subtype ids', '=',
     (select count(*) from jsonb_array_elements(cur) e where e->>'kind' like 'meetup.%'
        and not exists (select 1 from public.meetups m where m.id = (e->>'entity_id')::uuid))::text, '0'),
    ('T5 system cancel of M2: actor = creator, body = title', '=',
     (select string_agg((e->>'actor') || '/' || (e->>'body'), ',') from jsonb_array_elements(cur) e
       where e->>'kind' = 'meetup.cancelled' and e->>'entity_id' = '71300000-0000-0000-0000-000000000102'),
     '00000000-0000-0000-0000-0000000000a1/M-circle');
end $$;

-- K [K] events is the authority. Diverge events only (KAN-712 compat mirror off, plus the meetups guard and the
-- KAN-711 mirror where meetups is written directly) inside a subtransaction that is undone.
do $$
declare
  g  uuid := '73100000-0000-0000-0000-000000000001';
  m  uuid := '73100000-0000-0000-0000-000000000101';
  a1 uuid := '00000000-0000-0000-0000-0000000000a1';
  a2 uuid := '00000000-0000-0000-0000-0000000000a2';
  r  text[] := array_fill(null::text, array[12]);
  mx bigint;
begin
  begin
    alter table public.events disable trigger trg_zz_kan712_events_compat_mirror;
    -- feed
    update public.events set start_at = '2031-01-01 10:00+00', end_at = '2031-01-01 12:00+00', created_at = '2020-01-01 00:00+00' where id = g;
    update public.events set is_cancelled = true where id = '10000000-0000-0000-0000-000000000001';
    r[1] := (select count(*) > 0 from jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', a1, 'upcoming', 1000, null)) e
              where e->>'subject_id' = g::text)::text;
    r[2] := (select count(*) > 0 from jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', a1, 'all', 1000, null)) e
              where e->>'subject_id' = '10000000-0000-0000-0000-000000000001')::text;
    r[3] := (select string_agg(((e->>'happened_at')::timestamptz = '2020-01-01 00:00+00')::text, ',')
               from jsonb_array_elements(pg_temp.feed('public.rpc_get_activity_feed', a1, 'all', 1000, null)) e
              where e->>'subject_id' = g::text);
    -- stream
    update public.events set title = 'Kan731zebra', area_id = '00000000-0000-0000-0000-0000000000c1' where id = g;
    update public.events set start_at = '2025-01-01 10:00+00', end_at = '2025-01-01 11:00+00' where id = '71300000-0000-0000-0000-000000000001';
    r[4] := (select string_agg(e->>'title' || '/' || (e->>'city'), ',') from jsonb_array_elements(
               pg_temp.stream('public.active_stream', a2, array['game_created'], null, 50, null, null, null)) e where e->>'entity_id' = g::text);
    r[5] := (select count(*) from jsonb_array_elements(pg_temp.stream('public.active_stream', a2, array['game_started'], null, 50, null, null, null)) e
              where e->>'entity_id' = '71300000-0000-0000-0000-000000000001')::text;
    update public.events set listing_visibility = 'hidden' where id = m;
    r[6] := (select count(*) from jsonb_array_elements(pg_temp.stream('public.active_stream', a2, array['meetup_created'], null, 50, null, null, null)) e
              where e->>'entity_id' = m::text)::text;
    update public.events set listing_visibility = 'public', is_cancelled = true where id = m;
    r[7] := (select count(*) from jsonb_array_elements(pg_temp.stream('public.active_stream', a1, array['meetup_created'], null, 50, null, null, null)) e
              where e->>'entity_id' = m::text)::text;
    -- rsvps trigger: title and host from events
    update public.events set is_cancelled = false, title = 'Kan731zebra meetup',
           creator_user_id = '00000000-0000-0000-0000-0000000000a5', creator_profile_id = '00000000-0000-0000-0000-0000000000b5' where id = m;
    mx := (select coalesce(max(id), 0) from public.notifications);
    perform pg_temp.as_user(a2);
    insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status) values (m, a2, '00000000-0000-0000-0000-0000000000b2', 'pending');
    r[8] := (select string_agg(n.user_id || '/' || n.body, ',') from public.notifications n where n.id > mx and n.kind = 'meetup.request_received');
    -- cancel trigger: creator and title from events (meetups written directly, its guard and KAN-711 mirror off)
    update public.events set title = 'Kan731zebra cancel', creator_user_id = '00000000-0000-0000-0000-0000000000a5',
           creator_profile_id = '00000000-0000-0000-0000-0000000000b5' where id = '71300000-0000-0000-0000-000000000102';
    perform pg_temp.as_user(null);
    insert into public.meetup_rsvps (meetup_id, user_id, profile_id, status)
    values ('71300000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000b7', 'going');
    alter table public.meetups disable trigger trg_zz_kan712_meetups_guard;
    alter table public.meetups disable trigger trg_kan711_meetups_mirror;
    mx := (select coalesce(max(id), 0) from public.notifications);
    update public.meetups set is_cancelled = true where id = '71300000-0000-0000-0000-000000000102';
    r[9] := (select string_agg(n.actor_user_id || '/' || n.body, ',') from public.notifications n where n.id > mx and n.kind = 'meetup.cancelled');
    raise exception using errcode = 'P0001', message = 'kan731_undo';
  exception when others then
    if sqlerrm <> 'kan731_undo' then r := array_fill(('ERR ' || sqlstate || ' ' || sqlerrm)::text, array[12]); end if;
  end;
  perform pg_temp.as_user(null);
  insert into res (id, kind, got, want) values
    ('K1 feed time_bucket/scheduled_for from events.start_at', 'K', r[1], 'true'),
    ('K2 feed: events.is_cancelled excludes the game', 'K', r[2], 'false'),
    ('K3 feed happened_at = events.created_at', 'K', r[3], 'true'),
    ('K4 stream title and city from events', 'K', r[4], 'Kan731zebra/Dubai'),
    ('K5 stream game_started from events.start_at', 'K', r[5], '1'),
    ('K6 stream meetup visibility from events (KAN-713 helper)', 'K', r[6], '0'),
    ('K7 stream meetup cancel from events', 'K', r[7], '0'),
    ('K8 rsvps trigger: host and title from events', 'K', r[8], '00000000-0000-0000-0000-0000000000a5/Kan731zebra meetup'),
    ('K9 cancel trigger: creator and title from events', 'K', r[9], '00000000-0000-0000-0000-0000000000a5/Kan731zebra cancel');
end $$;

-- X [=] attributes, owner, ACL, trigger definitions are the pre-image's ---------------------------------------------
insert into res (id, kind, got, want)
select 'X1 ' || proname || ' attributes/owner/acl', '=',
       concat_ws('|', prosecdef, proconfig::text, provolatile, proowner::regrole::text, proacl::text, prorettype::regtype::text),
       w.want
  from pg_proc p join (values
    ('public.rpc_get_activity_feed(text,integer,timestamp with time zone)',
     't|{"search_path=public, pg_temp"}|v|postgres|{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}|record'),
    ('public.trg_meetup_rsvps_notify()', 't|{"search_path=public, pg_temp"}|v|postgres|{postgres=X/postgres,service_role=X/postgres}|trigger'),
    ('public.trg_meetups_cancel_notify()', 't|{"search_path=public, pg_temp"}|v|postgres|{postgres=X/postgres,service_role=X/postgres}|trigger'),
    ('public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)',
     't|{"search_path=public, pg_temp"}|s|postgres|{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}|record')
  ) w(sig, want) on p.oid = w.sig::regprocedure;
insert into res (id, kind, got, want)
select 'X2 trigger definitions unchanged', '=',
       string_agg(pg_get_triggerdef(t.oid), ' || ' order by t.tgname),
       'CREATE TRIGGER trg_meetup_rsvps_notify AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps FOR EACH ROW EXECUTE FUNCTION trg_meetup_rsvps_notify() || '
       'CREATE TRIGGER trg_meetups_cancel_notify AFTER UPDATE OF is_cancelled ON public.meetups FOR EACH ROW WHEN (((new.is_cancelled IS TRUE) AND (old.is_cancelled IS DISTINCT FROM true))) EXECUTE FUNCTION trg_meetups_cancel_notify()'
  from pg_trigger t where t.tgname in ('trg_meetup_rsvps_notify', 'trg_meetups_cancel_notify') and not t.tgisinternal and t.tgenabled = 'O';

-- R [R] rollback in a subtransaction (only when applied): restore the four verbatim pre-image texts. ----------------
create temp table hashes (t text, h text, phase text);
create function pg_temp.datahash() returns table (t text, h text) language sql as $f$
  select 'events', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.events x
  union all select 'games', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.games x
  union all select 'meetups', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.meetups x
  union all select 'meetup_rsvps', md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from public.meetup_rsvps x
  union all select 'game_roster', md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from public.game_roster x
  union all select 'notifications', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.notifications x
$f$;
do $$
declare r text; v_after jsonb; f record;
begin
  if not (select applied from st) then
    insert into res (id, kind, got, want) values ('R1 rollback (not applied: skipped)', 'R', 'skip', 'skip');
    return;
  end if;
  insert into hashes select d.t, d.h, 'before' from pg_temp.datahash() d;
  begin
    for f in select * from (values ('kan731_legacy_feed', 'rpc_get_activity_feed'), ('kan731_legacy_rsvps_notify', 'trg_meetup_rsvps_notify'),
                                   ('kan731_legacy_cancel_notify', 'trg_meetups_cancel_notify'), ('kan731_legacy_stream', 'active_stream')) v(l, n) loop
      execute replace(pg_get_functiondef(('public.' || f.l)::regproc), 'FUNCTION public.' || f.l || '(', 'FUNCTION public.' || f.n || '(');
    end loop;
    select jsonb_object_agg(d.t, d.h) into v_after from pg_temp.datahash() d;   -- survives the undo below
    select string_agg(proname || '=' || md5(prosrc) || ':' || coalesce(proacl::text, 'NULL'), ' ' order by proname) into r
      from pg_proc where pronamespace = 'public'::regnamespace
       and proname in ('rpc_get_activity_feed', 'trg_meetup_rsvps_notify', 'trg_meetups_cancel_notify', 'active_stream');
    raise exception using errcode = 'P0001', message = 'kan731_undo';
  exception when others then
    if sqlerrm <> 'kan731_undo' then r := 'ERR ' || sqlstate || ' ' || sqlerrm; end if;
  end;
  insert into res (id, kind, got, want) values
    ('R1 rollback restores the four pins, keeps ACLs', 'R', r,
     'active_stream=0e7b7eddfce6dee2746734fb47fbf332:{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres} '
     'rpc_get_activity_feed=73036a69dbec39c5bd44209b80147f1e:{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres} '
     'trg_meetup_rsvps_notify=55efefd5cf5b5556d11f6ac093fd64b8:{postgres=X/postgres,service_role=X/postgres} '
     'trg_meetups_cancel_notify=48990a6a71e751614d5fbd6f29c2fdde:{postgres=X/postgres,service_role=X/postgres}');
  insert into res (id, kind, got, want)
  select 'R2 data hash ' || b.t || ' unchanged by rollback', 'R', coalesce(v_after->>b.t, 'missing'), b.h
    from hashes b where b.phase = 'before';
end $$;

-- Report --------------------------------------------------------------------------------------------------
\pset format unaligned
\pset tuples_only on
select case when got is not distinct from want then 'PASS ' else 'FAIL ' end || '[' || kind || '] ' || id ||
       case when got is distinct from want then '  got=' || coalesce(got, 'NULL') || ' want=' || coalesce(want, 'NULL') else '' end
  from res order by ord;
select case
  when (select applied from st) and not exists (select 1 from res where got is distinct from want)
    then 'ALL PASS (' || (select count(*) from res) || ' checks, migration applied)'
  when not (select applied from st)
       and not exists (select 1 from res where kind in ('=', 'R') and got is distinct from want)
       and not exists (select 1 from res where kind = 'K' and got is not distinct from want)
    then 'PRE-IMAGE OK: every [=] passes and every [K] fails (' || (select count(*) from res where kind = 'K') || ' K checks)'
  else 'NOT PASS'
end;

rollback;
