-- KAN-731 (KAN-714 B12, Epic KAN-708 Events P2): the activity feed, the meetup notification triggers and the
-- active stream read the event-shared columns from public.events, joined on the subtype's event_id.
-- AUTHORED, NOT APPLIED. Author: backend-4 (Min), team Ramesseum.
-- Verified only on a throwaway local PostgreSQL 16 cluster (/tmp/kan731_pg, port 54731, stopped afterwards) with
-- supabase/tests/events_p2/kan714_b12_feed_stream.sql. Production was not read (brief: never touch
-- wtncuzcskpigqpmnxwws, not even to read), so the pre-images below come from the repo migrations, latest
-- definition wins, and each replacement is fail-closed against the live body by an md5(prosrc) pin (T-058).
--
-- ============================================================================================================
-- 1. INVENTORY (three surfaces, four functions; none is re-defined or dropped by a later migration)
--  #  object                                       latest definition (file:line)               action
--  F1 rpc_get_activity_feed(text,int,timestamptz)  20261101130000_kan689_rpc_get_activity_feed CHANGED. game_created /
--     SECURITY DEFINER, search_path public,pg_temp _fix.sql:7-81 (owner baseline:12877, grants      game_joined join events on
--     md5 73036a69dbec39c5bd44209b80147f1e          baseline:36361-36363)                       g.event_id; time_bucket,
--                                                                                               happened_at (created),
--                                                                                               scheduled_for, creator
--                                                                                               ownership read events;
--                                                                                               cancel = g AND e
--                                                                                               (intersection). gr.joined_at,
--                                                                                               ids, payload unchanged.
--  F2 trg_meetup_rsvps_notify()                    20260915150000_meetups_notifications:113-197 CHANGED. Host uid and title
--     md5 55efefd5cf5b5556d11f6ac093fd64b8                                                       from events (one join in the
--                                                                                               existing single lookup).
--  F3 trg_meetups_cancel_notify()                  20260915150000_meetups_notifications:202-240 CHANGED. Creator and title
--     md5 48990a6a71e751614d5fbd6f29c2fdde                                                       from events, looked up ONCE
--                                                                                               before the recipient loop.
--                                                                                               Firing condition untouched
--                                                                                               (meetups.is_cancelled, which
--                                                                                               the KAN-712 compat mirror
--                                                                                               writes from events).
--  F4 active_stream(text[],text,int,timestamptz,   20261020120000_kan595_active_stream:46-172  CHANGED. 3 game + 3 meetup
--     text,uuid)  STABLE SECURITY DEFINER                                                       branches join events: event_at,
--     md5 0e7b7eddfce6dee2746734fb47fbf332                                                       actor_profile_id, title,
--                                                                                               area (city) from events.
--                                                                                               Filters are intersections:
--                                                                                               cancel g/m AND e; block on
--                                                                                               legacy creator AND events
--                                                                                               creator; meetup visibility
--                                                                                               legacy can_view_owner AND
--                                                                                               kan713_meetup_visible (KAN-713
--                                                                                               helper); games keep
--                                                                                               _can_view_game (already
--                                                                                               converted by KAN-713).
--  Unchanged on purpose: subtype-only columns (games roster/price/etc., meetups location_name/description,
--  game_roster.joined_at); every id in payloads, notifications and routes stays the subtype id; trigger
--  definitions (pg_get_triggerdef) are asserted identical; no new feed item or notification kind.
--  None of the four is in kan712_wrapped_rpcs (asserted, P6), so a plain CREATE OR REPLACE is the correct path.
--
-- 2. PRECONDITIONS (section A; any failure aborts the whole transaction)
--   P1 applying role is superuser or BYPASSRLS.
--   P2 KAN-712 stage B is live: the five trg_zz_kan712_* triggers exist and are enabled, kan712_wrapped_rpcs is
--      non-empty.
--   P3 KAN-713 is in: kan713_meetup_visible(uuid) exists and the six trg_kan713_* triggers exist.
--   P4 the two notify triggers exist, are enabled, and have exactly the reviewed definitions.
--   P5 each of the four functions has exactly one overload, the pinned md5(prosrc), SECURITY DEFINER, proconfig
--      {search_path=public, pg_temp} and the pinned volatility.
--   P6 none is in kan712_wrapped_rpcs and none has a *_kan712_inner twin.
--   P7 not already applied (no pinned body carries the KAN-731 marker).
--   P8 shared-value parity for every linked row: games/meetups title, start_at, end_at, created_at,
--      creator_user_id, creator_profile_id, area_id, is_cancelled, listing_visibility = events'. Zero rows may
--      differ; otherwise outputs or notification payloads could change at apply.
-- 3. CHANGES (section B): four CREATE OR REPLACE FUNCTION, bodies = pinned pre-image with only the reads above
--    edited.
-- 4. POSTCONDITIONS (section C)
--   Q1 owner, proacl, prosecdef, proconfig, provolatile equal the captured pre-image; md5 changed; one overload;
--      body joins public.events.
--   Q2 both trigger definitions identical to the captured pre-image, still enabled.
--   Q3 LIVE OUTPUT PARITY (read-only, no rows written): for up to 12 viewers (anonymous + the 11 lowest user ids
--      among event creators, active roster members and meetup RSVPs) the feed (4 periods + 2 cursors, limit 1000,
--      compared as a multiset) and the stream (all types, each type, up to 5 cities, keyset page 2; ordered, the
--      stream has a total order) captured in section A equal the new output; an error before must be the same
--      SQLSTATE after. Trigger firing parity (same count, same payloads) is proven in the test (T1-T3), not
--      here: the migration writes no data, and P8 guarantees the values the triggers read are equal.
-- 5. LOCKS: SHARE ROW EXCLUSIVE on events, games, meetups, meetup_rsvps, game_roster for the transaction (blocks
--    writes, not reads, so probes are stable); lock_timeout 10s.
-- 6. ROLLBACK: commented block at the end of this file. Restores the exact pre-image texts. No unwrap/rewrap.
--    Data is not touched (test R1: per-table md5 hashes equal before/after).
-- ============================================================================================================

begin;
set local lock_timeout = '10s';
lock table public.events, public.games, public.meetups, public.meetup_rsvps, public.game_roster
  in share row exclusive mode;

-- A. Preconditions -------------------------------------------------------------------------------------------
create temp table kan731_pre (fn text primary key, sig regprocedure, owner oid, acl aclitem[], secdef boolean,
  config text[], volatile "char", src_md5 text) on commit drop;
create temp table kan731_trg (tgname text primary key, def text) on commit drop;
create temp table kan731_probe (k text primary key, pre jsonb, post jsonb) on commit drop;

do $$
declare
  r     record;
  v_fn  regprocedure;
  v_n   bigint;
  v_md5 text;
begin
  -- P1
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-731: applying role % must be superuser or BYPASSRLS', current_user;
  end if;
  -- P2
  if (select count(*) from pg_trigger where not tgisinternal and tgenabled = 'O' and tgname in (
        'trg_zz_kan712_games_guard', 'trg_zz_kan712_meetups_guard', 'trg_zz_kan712_games_after_delete',
        'trg_zz_kan712_meetups_after_delete', 'trg_zz_kan712_events_compat_mirror')) <> 5
     or to_regclass('public.kan712_wrapped_rpcs') is null
     or not exists (select 1 from public.kan712_wrapped_rpcs) then
    raise exception 'KAN-731: KAN-712 stage B (20261103110000) is not live';
  end if;
  -- P3
  if to_regprocedure('public.kan713_meetup_visible(uuid)') is null
     or (select count(*) from pg_trigger where not tgisinternal and tgname like 'trg_kan713_%') <> 6 then
    raise exception 'KAN-731: KAN-713 (20261104100000, 20261104110000) is not applied';
  end if;
  -- P4
  for r in select * from (values
      ('trg_meetup_rsvps_notify', 'public.meetup_rsvps'::regclass,
       'CREATE TRIGGER trg_meetup_rsvps_notify AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps FOR EACH ROW EXECUTE FUNCTION trg_meetup_rsvps_notify()'),
      ('trg_meetups_cancel_notify', 'public.meetups'::regclass,
       'CREATE TRIGGER trg_meetups_cancel_notify AFTER UPDATE OF is_cancelled ON public.meetups FOR EACH ROW WHEN (((new.is_cancelled IS TRUE) AND (old.is_cancelled IS DISTINCT FROM true))) EXECUTE FUNCTION trg_meetups_cancel_notify()')
    ) t(tgname, rel, def) loop
    if (select count(*) from pg_trigger t where t.tgname = r.tgname and t.tgrelid = r.rel and not t.tgisinternal
          and t.tgenabled = 'O' and pg_get_triggerdef(t.oid) = r.def) <> 1 then
      raise exception 'KAN-731: trigger % missing, disabled or not the reviewed definition', r.tgname;
    end if;
    insert into kan731_trg select r.tgname, pg_get_triggerdef(t.oid) from pg_trigger t
     where t.tgname = r.tgname and t.tgrelid = r.rel;
  end loop;
  -- P5, P6, P7
  for r in select * from (values
    ('rpc_get_activity_feed', 'public.rpc_get_activity_feed(text,integer,timestamp with time zone)', '73036a69dbec39c5bd44209b80147f1e', '{"search_path=public, pg_temp"}', 'v'),
    ('trg_meetup_rsvps_notify', 'public.trg_meetup_rsvps_notify()', '55efefd5cf5b5556d11f6ac093fd64b8', '{"search_path=public, pg_temp"}', 'v'),
    ('trg_meetups_cancel_notify', 'public.trg_meetups_cancel_notify()', '48990a6a71e751614d5fbd6f29c2fdde', '{"search_path=public, pg_temp"}', 'v'),
    ('active_stream', 'public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)', '0e7b7eddfce6dee2746734fb47fbf332', '{"search_path=public, pg_temp"}', 's')
    ) t(fn, sig, md5, cfg, vol) loop
    v_fn := to_regprocedure(r.sig);
    if v_fn is null or (select count(*) from pg_proc where proname = r.fn and pronamespace = 'public'::regnamespace) <> 1 then
      raise exception 'KAN-731: %: expected exactly one overload with signature %', r.fn, r.sig;
    end if;
    select md5(prosrc) into v_md5 from pg_proc where oid = v_fn;
    if position('KAN-731' in (select prosrc from pg_proc where oid = v_fn)) > 0 then
      raise exception 'KAN-731: already applied (% carries the KAN-731 marker)', r.fn;  -- P7
    end if;
    if v_md5 <> r.md5 then
      raise exception 'KAN-731: % live body differs from the reviewed pre-image (md5 %)', r.fn, v_md5;
    end if;
    if not exists (select 1 from pg_proc where oid = v_fn and prosecdef and proconfig = r.cfg::text[]
                    and provolatile = r.vol::"char") then
      raise exception 'KAN-731: % attributes differ from the pre-image (secdef/search_path/volatility)', r.fn;
    end if;
    if exists (select 1 from public.kan712_wrapped_rpcs w where w.name = r.fn)
       or exists (select 1 from pg_proc where proname = r.fn || '_kan712_inner') then
      raise exception 'KAN-731: % is KAN-712-wrapped; use kan712_unwrap_rpc -> replace -> kan712_wrap_rpc', r.fn;  -- P6
    end if;
    insert into kan731_pre
    select r.fn, v_fn, proowner, proacl, prosecdef, proconfig, provolatile, md5(prosrc) from pg_proc where oid = v_fn;
  end loop;
  -- P8
  select count(*) into v_n from public.games g join public.events e on e.id = g.event_id
   where e.event_type <> 'game'
      or g.title is distinct from e.title or g.start_at is distinct from e.start_at
      or g.end_at is distinct from e.end_at or g.created_at is distinct from e.created_at
      or g.creator_user_id is distinct from e.creator_user_id or g.creator_profile_id is distinct from e.creator_profile_id
      or g.area_id is distinct from e.area_id or g.is_cancelled is distinct from e.is_cancelled
      or g.listing_visibility is distinct from e.listing_visibility;
  if v_n <> 0 then
    raise exception 'KAN-731: % games rows differ from events on a shared column read by these surfaces', v_n;
  end if;
  select count(*) into v_n from public.meetups m join public.events e on e.id = m.event_id
   where e.event_type <> 'meetup'
      or m.title is distinct from e.title or m.start_at is distinct from e.start_at
      or m.end_at is distinct from e.end_at or m.created_at is distinct from e.created_at
      or m.creator_user_id is distinct from e.creator_user_id or m.creator_profile_id is distinct from e.creator_profile_id
      or m.area_id is distinct from e.area_id or m.is_cancelled is distinct from e.is_cancelled
      or m.listing_visibility is distinct from e.listing_visibility;
  if v_n <> 0 then
    raise exception 'KAN-731: % meetups rows differ from events on a shared column read by these surfaces', v_n;
  end if;
end $$;

-- Read-only probe set, run before (section A) and after (section C) the change. Viewers are impersonated through
-- the JWT GUCs auth.uid() reads (transaction-local). No row is written.
create function pg_temp.kan731_probe_set() returns table (k text, v jsonb)
language plpgsql as $f$
declare
  u      uuid;
  per    text;
  cur    timestamptz;
  t      text;
  c      text;
  j      jsonb;
  lastr  jsonb;
  types  text[] := array['player_joined','venue_added','game_created','game_started','game_ended',
                         'meetup_created','meetup_started','meetup_completed'];
begin
  for u in
    select null::uuid
    union all
    (select x.uid from (
        select e.creator_user_id as uid from public.events e
        union select gr.user_id from public.game_roster gr where gr.status = 'active'
        union select s.user_id from public.meetup_rsvps s) x
      where x.uid is not null order by x.uid limit 11)
  loop
    perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), true);
    perform set_config('request.jwt.claims',
      case when u is null then '' else json_build_object('sub', u, 'role', 'authenticated')::text end, true);
    -- feed: periods and cursors, multiset (ORDER BY ties are not a total order), limit 1000 so no truncation
    foreach per in array array['all','past','present','upcoming'] loop
      begin
        select coalesce(jsonb_agg(to_jsonb(f) order by to_jsonb(f)::text), '[]') into j
          from public.rpc_get_activity_feed(per, 1000, null) f;
      exception when others then j := jsonb_build_object('error', sqlstate); end;
      k := 'feed|' || coalesce(u::text, 'anon') || '|' || per; v := j; return next;
    end loop;
    foreach cur in array array[now(), (select percentile_disc(0.5) within group (order by e.created_at) from public.events e)] loop
      begin
        select coalesce(jsonb_agg(to_jsonb(f) order by to_jsonb(f)::text), '[]') into j
          from public.rpc_get_activity_feed('all', 1000, cur) f;
      exception when others then j := jsonb_build_object('error', sqlstate); end;
      k := 'feed|' || coalesce(u::text, 'anon') || '|cursor|' || coalesce(cur::text, 'null'); v := j; return next;
    end loop;
    -- stream: total order (event_at, event_type, entity_id), so compared as an ordered array
    begin
      select coalesce(jsonb_agg(to_jsonb(s) order by s.event_at desc, s.event_type desc, s.entity_id desc), '[]')
        into j from public.active_stream(null, null, 50, null, null, null) s;
    exception when others then j := jsonb_build_object('error', sqlstate); end;
    k := 'stream|' || coalesce(u::text, 'anon') || '|all'; v := j; return next;
    lastr := case when jsonb_typeof(j) = 'array' and jsonb_array_length(j) > 0 then j -> -1 end;
    if lastr is not null then
      begin
        select coalesce(jsonb_agg(to_jsonb(s) order by s.event_at desc, s.event_type desc, s.entity_id desc), '[]')
          into j from public.active_stream(null, null, 50, (lastr->>'event_at')::timestamptz,
                                           lastr->>'event_type', (lastr->>'entity_id')::uuid) s;
      exception when others then j := jsonb_build_object('error', sqlstate); end;
      k := 'stream|' || coalesce(u::text, 'anon') || '|page2'; v := j; return next;
    end if;
    foreach t in array types loop
      begin
        select coalesce(jsonb_agg(to_jsonb(s) order by s.event_at desc, s.event_type desc, s.entity_id desc), '[]')
          into j from public.active_stream(array[t], null, 50, null, null, null) s;
      exception when others then j := jsonb_build_object('error', sqlstate); end;
      k := 'stream|' || coalesce(u::text, 'anon') || '|type|' || t; v := j; return next;
    end loop;
    for c in select distinct a.city from public.areas a where a.city is not null order by a.city limit 5 loop
      begin
        select coalesce(jsonb_agg(to_jsonb(s) order by s.event_at desc, s.event_type desc, s.entity_id desc), '[]')
          into j from public.active_stream(null, c, 50, null, null, null) s;
      exception when others then j := jsonb_build_object('error', sqlstate); end;
      k := 'stream|' || coalesce(u::text, 'anon') || '|city|' || c; v := j; return next;
    end loop;
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end $f$;

insert into kan731_probe (k, pre) select p.k, p.v from pg_temp.kan731_probe_set() p;

-- B. Changes: four CREATE OR REPLACE. Each body is pg_get_functiondef of the pinned pre-image with only the
--    shared-column reads edited (KAN-731 comments mark every edit). Signature, return type, language,
--    volatility, SECURITY DEFINER, search_path, owner and ACL unchanged (CREATE OR REPLACE keeps owner/ACL).
-- ------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      e.created_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON e.creator_user_id = me.user_id
    WHERE g.is_cancelled = false
      AND e.is_cancelled = false                                           -- KAN-731: intersection, never wider
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND g.is_cancelled = false
      AND e.is_cancelled = false                                           -- KAN-731: intersection, never wider
      AND e.creator_user_id <> me.user_id
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

CREATE OR REPLACE FUNCTION public.trg_meetup_rsvps_notify()
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

  SELECT e.creator_user_id, e.title INTO v_host_uid, v_title
    FROM public.meetups m
    JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731: shared columns from events
   WHERE m.id = NEW.meetup_id;
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

CREATE OR REPLACE FUNCTION public.trg_meetups_cancel_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor   uuid := auth.uid();
  r         record;
  v_creator uuid;
  v_title   text;
BEGIN
  IF NOT (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) THEN
    RETURN NEW;
  END IF;

  -- KAN-731: creator and title from events, looked up once (not per recipient). The firing condition stays on
  -- meetups.is_cancelled, which the KAN-712 compat mirror writes from events.is_cancelled.
  SELECT e.creator_user_id, e.title INTO v_creator, v_title
    FROM public.events e WHERE e.id = NEW.event_id AND e.event_type = 'meetup';

  FOR r IN
    SELECT DISTINCT s.user_id
      FROM public.meetup_rsvps s
     WHERE s.meetup_id = NEW.id
       AND s.status IN ('going', 'interested', 'pending')
       AND s.user_id IS DISTINCT FROM v_actor
  LOOP
    PERFORM public.process_notification_event(
      r.user_id, 'meetup.cancelled', 'meetup', NEW.id,
      COALESCE(v_actor, v_creator),
      'A meet-up you signed up for was cancelled', v_title);
  END LOOP;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
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
    SELECT 'game_created'::text, e.created_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
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

-- C. Postconditions -----------------------------------------------------------------------------------------
do $$
declare
  f     record;
  v_bad int;
begin
  -- Q1
  for f in select * from kan731_pre loop
    if (select count(*) from pg_proc where proname = f.fn and pronamespace = 'public'::regnamespace) <> 1
       or not exists (select 1 from pg_proc where oid = f.sig
                       and proowner = f.owner and proacl is not distinct from f.acl and prosecdef = f.secdef
                       and proconfig::text[] is not distinct from f.config and provolatile = f.volatile
                       and md5(prosrc) <> f.src_md5 and prosrc like '%public.events e%') then
      raise exception 'KAN-731 Q1: % attributes/ACL changed or body not replaced', f.fn;
    end if;
  end loop;
  -- Q2
  if (select count(*) from kan731_trg k join pg_trigger t on t.tgname = k.tgname and not t.tgisinternal
       where t.tgenabled = 'O' and pg_get_triggerdef(t.oid) = k.def) <> 2 then
    raise exception 'KAN-731 Q2: a notify trigger definition changed or it is no longer enabled';
  end if;
  -- Q3
  update kan731_probe x set post = p.v from pg_temp.kan731_probe_set() p where p.k = x.k;
  select count(*) into v_bad from kan731_probe where pre is distinct from post;
  if v_bad <> 0 or (select count(*) from pg_temp.kan731_probe_set()) <> (select count(*) from kan731_probe) then
    raise exception 'KAN-731 Q3: % probe outputs differ after the change (first: %)', v_bad,
      (select k from kan731_probe where pre is distinct from post order by k limit 1);
  end if;
  raise notice 'KAN-731 applied: Q1-Q3 ok, % probe outputs identical (% non-empty)',
    (select count(*) from kan731_probe),
    (select count(*) from kan731_probe where pre <> '[]'::jsonb);
end $$;

drop function pg_temp.kan731_probe_set();

commit;

-- ============================================================================================================
-- ROLLBACK (run as postgres, one transaction). Restores the exact pre-images (pg_get_functiondef of the pinned
-- bodies; md5(prosrc) 73036a69dbec39c5bd44209b80147f1e, 55efefd5cf5b5556d11f6ac093fd64b8,
-- 48990a6a71e751614d5fbd6f29c2fdde, 0e7b7eddfce6dee2746734fb47fbf332). No unwrap/rewrap: none is a KAN-712
-- wrapped RPC. CREATE OR REPLACE keeps owner and ACL. Trigger definitions are not touched. No data is touched
-- (verified: per-table md5 hashes equal before/after, test R1).
-- ------------------------------------------------------------------------------------------------------------
-- begin;
-- set local lock_timeout = '10s';
-- do $$ begin
--   if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and position('KAN-731' in prosrc) > 0
--         and proname in ('rpc_get_activity_feed', 'trg_meetup_rsvps_notify', 'trg_meetups_cancel_notify', 'active_stream')) <> 4 then
--     raise exception 'KAN-731 rollback: not applied (expected 4 bodies carrying the KAN-731 marker)';
--   end if;
-- end $$;
-- CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
--  RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- BEGIN
--   RETURN QUERY
--   WITH me AS (
--     SELECT auth.uid() AS user_id
--   ),
--   game_created AS (
--     SELECT
--       g.id                                                          AS id,
--       'game'::text                                                  AS subject_type,
--       g.id                                                          AS subject_id,
--       'created'::text                                               AS verb,
--       NULL::text                                                    AS status,
--       CASE
--         WHEN g.end_at < NOW()                              THEN 'past'
--         WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
--         WHEN g.start_at > NOW()                           THEN 'upcoming'
--         ELSE 'past'
--       END                                                           AS time_bucket,
--       g.created_at                                                  AS happened_at,
--       g.start_at                                                    AS scheduled_for,
--       90                                                            AS priority,
--       jsonb_build_object('role', 'host')                            AS payload
--     FROM public.games g
--     JOIN me ON g.creator_user_id = me.user_id
--     WHERE g.is_cancelled = false
--   ),
--   game_joined AS (
--     SELECT
--       g.id                                                          AS id,
--       'game'::text                                                  AS subject_type,
--       g.id                                                          AS subject_id,
--       'joined'::text                                                AS verb,
--       NULL::text                                                    AS status,
--       CASE
--         WHEN g.end_at < NOW()                              THEN 'past'
--         WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
--         WHEN g.start_at > NOW()                           THEN 'upcoming'
--         ELSE 'past'
--       END                                                           AS time_bucket,
--       gr.joined_at                                                  AS happened_at,
--       g.start_at                                                    AS scheduled_for,
--       80                                                            AS priority,
--       jsonb_build_object('role', 'player')                          AS payload
--     FROM public.game_roster gr
--     JOIN public.games g ON g.id = gr.game_id
--     JOIN me ON gr.user_id = me.user_id
--     WHERE gr.status = 'active'
--       AND g.is_cancelled = false
--       AND g.creator_user_id <> me.user_id
--   ),
--   game_events AS (
--     SELECT * FROM game_created
--     UNION ALL
--     SELECT * FROM game_joined
--   ),
--   filtered AS (
--     SELECT * FROM game_events e
--     WHERE (_period = 'all' OR e.time_bucket = _period)
--       AND (_cursor IS NULL OR e.happened_at < _cursor)
--   )
--   SELECT f.* FROM filtered f
--   ORDER BY
--     CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
--     f.scheduled_for ASC,
--     f.happened_at DESC,
--     f.priority DESC
--   LIMIT _limit;
-- END;
-- $function$;
-- CREATE OR REPLACE FUNCTION public.trg_meetup_rsvps_notify()
--  RETURNS trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   v_actor      uuid := auth.uid();
--   v_host_uid   uuid;
--   v_title      text;
--   v_name       text;
--   v_old        text;
-- BEGIN
--   -- OLD is unassigned on INSERT, so read it once, guarded.
--   IF TG_OP = 'UPDATE' THEN v_old := OLD.status; END IF;
--
--   -- Only status changes (and brand-new rows) are events.
--   IF TG_OP = 'UPDATE' AND v_old IS NOT DISTINCT FROM NEW.status THEN
--     RETURN NEW;
--   END IF;
--
--   SELECT m.creator_user_id, m.title INTO v_host_uid, v_title
--     FROM public.meetups m WHERE m.id = NEW.meetup_id;
--   IF v_host_uid IS NULL THEN RETURN NEW; END IF;
--
--   SELECT p.display_name INTO v_name
--     FROM public.profiles p
--    WHERE p.user_id = NEW.user_id AND p.is_active = true
--    LIMIT 1;
--   v_name := COALESCE(v_name, 'Someone');
--
--   -- Someone asks to join (request policy): tell the host. Never the host's own row.
--   IF NEW.status = 'pending'
--      AND v_old IS DISTINCT FROM 'pending'
--   THEN
--     IF NEW.user_id <> v_host_uid THEN
--       PERFORM public.process_notification_event(
--         v_host_uid, 'meetup.request_received', 'meetup', NEW.meetup_id, NEW.user_id,
--         v_name || ' asked to join your meet-up', v_title);
--     END IF;
--     RETURN NEW;
--   END IF;
--
--   -- Attendee flips to 'going' themselves (UPDATE only: a fresh INSERT is covered
--   -- by the existing meetup.player_joined chain; see header).
--   IF TG_OP = 'UPDATE' AND NEW.status = 'going'
--      AND v_actor IS NOT NULL AND v_actor = NEW.user_id
--   THEN
--     IF NEW.user_id <> v_host_uid THEN
--       PERFORM public.process_notification_event(
--         v_host_uid, 'meetup.rsvp_received', 'meetup', NEW.meetup_id, NEW.user_id,
--         v_name || ' is going to your meet-up', v_title);
--     END IF;
--     RETURN NEW;
--   END IF;
--
--   -- Somebody else (the host or an admin) decides a pending request: tell the attendee.
--   IF TG_OP = 'UPDATE' AND v_old = 'pending'
--      AND v_actor IS NOT NULL AND v_actor <> NEW.user_id
--   THEN
--     IF NEW.status = 'going' THEN
--       PERFORM public.process_notification_event(
--         NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
--         'You''re in! Your request to join was approved', v_title);
--     ELSIF NEW.status = 'interested' THEN
--       PERFORM public.process_notification_event(
--         NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
--         'Your request was approved, but the meet-up is full', v_title);
--     ELSIF NEW.status IN ('cancelled', 'declined') THEN
--       PERFORM public.process_notification_event(
--         NEW.user_id, 'meetup.request_declined', 'meetup', NEW.meetup_id, v_actor,
--         'Your request to join was declined', v_title);
--     END IF;
--   END IF;
--
--   RETURN NEW;
-- END;
-- $function$;
-- CREATE OR REPLACE FUNCTION public.trg_meetups_cancel_notify()
--  RETURNS trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   v_actor uuid := auth.uid();
--   r       record;
-- BEGIN
--   IF NOT (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) THEN
--     RETURN NEW;
--   END IF;
--
--   FOR r IN
--     SELECT DISTINCT s.user_id
--       FROM public.meetup_rsvps s
--      WHERE s.meetup_id = NEW.id
--        AND s.status IN ('going', 'interested', 'pending')
--        AND s.user_id IS DISTINCT FROM v_actor
--   LOOP
--     PERFORM public.process_notification_event(
--       r.user_id, 'meetup.cancelled', 'meetup', NEW.id,
--       COALESCE(v_actor, NEW.creator_user_id),
--       'A meet-up you signed up for was cancelled', NEW.title);
--   END LOOP;
--
--   RETURN NEW;
-- END;
-- $function$;
-- CREATE OR REPLACE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
--  RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
--  LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
--   WITH prm AS (
--     SELECT auth.uid() AS viewer,
--            LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
--            NULLIF(btrim(p_city), '') AS city
--   ),
--   ev AS (
--     -- player_joined
--     SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
--            p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
--       FROM public.profiles p, prm
--      WHERE prm.viewer IS NOT NULL
--        AND p.profile_type = 'personal'
--        AND p.created_at IS NOT NULL
--        AND public.is_profile_publicly_visible(p.id)
--        AND NOT public.is_blocked(prm.viewer, p.user_id)
--     UNION ALL
--     -- venue_added
--     SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
--       FROM public.venues v
--       JOIN public.areas a ON a.id = v.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND v.is_active = true
--        AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
--     UNION ALL
--     -- game_created
--     SELECT 'game_created'::text, g.created_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
--       FROM public.games g
--       JOIN public.areas a ON a.id = g.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND g.is_cancelled = false
--        AND public._can_view_game(g.id)
--        AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
--     UNION ALL
--     -- game_started
--     SELECT 'game_started'::text, g.start_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
--       FROM public.games g
--       JOIN public.areas a ON a.id = g.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND g.is_cancelled = false
--        AND g.start_at <= now()
--        AND public._can_view_game(g.id)
--        AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
--     UNION ALL
--     -- game_ended
--     SELECT 'game_ended'::text, g.end_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
--       FROM public.games g
--       JOIN public.areas a ON a.id = g.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND g.is_cancelled = false
--        AND g.end_at <= now()
--        AND public._can_view_game(g.id)
--        AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
--     UNION ALL
--     -- meetup_created
--     SELECT 'meetup_created'::text, m.created_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
--       FROM public.meetups m
--       LEFT JOIN public.areas a ON a.id = m.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND m.is_cancelled = false
--        AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
--        AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
--     UNION ALL
--     -- meetup_started
--     SELECT 'meetup_started'::text, m.start_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
--       FROM public.meetups m
--       LEFT JOIN public.areas a ON a.id = m.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND m.is_cancelled = false
--        AND m.start_at <= now()
--        AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
--        AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
--     UNION ALL
--     -- meetup_completed
--     SELECT 'meetup_completed'::text, COALESCE(m.end_at, m.start_at), 'meetup'::text, m.id, m.creator_profile_id,
--            a.city, m.title
--       FROM public.meetups m
--       LEFT JOIN public.areas a ON a.id = m.area_id, prm
--      WHERE prm.viewer IS NOT NULL
--        AND m.is_cancelled = false
--        AND COALESCE(m.end_at, m.start_at) <= now()
--        AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
--        AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
--   ),
--   filtered AS (
--     SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
--       FROM ev, prm
--      WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
--        AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
--        AND (
--          p_before IS NULL
--          OR ev.event_at < p_before
--          OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
--              AND ev.event_at = p_before
--              AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
--        )
--      ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
--   )
--   SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
--     FROM filtered f
--    ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
--    LIMIT (SELECT lim FROM prm);
-- $function$;
-- do $$ begin
--   if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and md5(prosrc) in (
--         '73036a69dbec39c5bd44209b80147f1e', '55efefd5cf5b5556d11f6ac093fd64b8',
--         '48990a6a71e751614d5fbd6f29c2fdde', '0e7b7eddfce6dee2746734fb47fbf332')) <> 4 then
--     raise exception 'KAN-731 rollback: restored bodies do not match the pinned pre-images';
--   end if;
-- end $$;
-- commit;
