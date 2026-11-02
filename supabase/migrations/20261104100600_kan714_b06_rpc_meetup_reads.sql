-- KAN-725 (KAN-714 piece B06, Epic KAN-708) — meetup read RPCs read their SHARED facts from public.events.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p2/kan714_b06_meetup_reads.sql.
-- Rollback: supabase/tests/events_p2/rollback_kan714_b06.sql (restores the pre-image below, verbatim).
--
-- PRE-IMAGE: authored from pg_get_functiondef on the KAN-713 stage catalogue (T-058), not from a migration file.
-- Latest definitions: rpc_meetup_card 20260915130000_meetups_card_fields.sql:80, rpc_meetup_attendees
-- 20260915120000_meetups_hardening.sql:406, rpc_meetup_my baseline 20260829080500_baseline_schema.sql:13835.
-- No later migration redefines any of the three.
--
-- SCOPE, per RPC:
--   rpc_meetup_card(uuid,text)        REPOINTED. Shared columns now read from events: creator_user_id (visibility gate,
--                                     is_host), creator_profile_id (owner_profile_id), title, start_at, end_at, capacity,
--                                     listing_visibility (gate + 'visibility'), is_cancelled, sport_id, area_id, venue_id,
--                                     min_skill, max_skill (events smallint, cast back to integer). Kept on meetups (no events
--                                     column): id, description, location_name, host_actor_id.
--   rpc_meetup_attendees(uuid,text,integer,integer)
--                                     REPOINTED. Shared columns read from events: creator_user_id, listing_visibility
--                                     (gate + host test). Rows still come from meetup_rsvps; filters, ordering, clamps verbatim.
--   rpc_meetup_my()                   UNCHANGED, by design. Its pre-image references meetups.owner_user_id / starts_at /
--                                     visibility, none of which exist: every call raises 42703 (pinned in the test, R1).
--                                     There is no working legacy behaviour to make equivalent; repointing it would mean
--                                     fixing it (new behaviour) and, as SECURITY INVOKER, it could not read events at all.
--                                     It has no app call site (lib/core/config/supabase_config.dart has no constant for it).
--                                     Pinned below and asserted untouched. Reported, not fixed.
--
-- JOIN: meetups mt JOIN events e ON e.id = mt.event_id AND e.event_type = 'meetup', by mt.id = p_meetup_id (PK).
-- events.id is the PK, so 1:0..1; the stage guard proves exactly one meetup parent for every meetups row. A row whose
-- parent is missing or of type 'game' is now meetup_not_found (the guard proves none exists today).
-- STRUCTURE: everything except the source of the shared columns is the pre-image verbatim. The only declared-type
-- change is the local variable m: public.meetups%rowtype -> record (same field names), so the bodies' later references
-- are textually unchanged. Response shape (signature, return columns, jsonb keys and value types, ordering, pagination,
-- counts, errors) is unchanged.
-- VISIBILITY: the same can_view_with_scope(me, creator_user_id, listing_visibility, null) gate, fed from events.
-- meetups and events share the visibility vocabulary (public/circle/invite/link/hidden: meetups_listing_visibility_check
-- = events_meetup_visibility_check), and the KAN-711 parity view is 0, so the gate sees the same values.
--
-- ACCESS: both RPCs stay SECURITY DEFINER, owner postgres (superuser: reads events past FORCE RLS), search_path public.
-- CREATE OR REPLACE FUNCTION keeps owner and ACL; captured before and asserted equal after. public.events stays FORCE
-- RLS, zero policies, no API grants. No grant is added or changed.
-- KAN-712: none of the three is a wrapped RPC (kan712_wrapped_rpcs, asserted in the guard), so the unwrap/wrap path
-- does not apply. The one caller, rpc_meetup_update_kan712_inner (wrapped rpc_meetup_update), calls rpc_meetup_card
-- and is not changed; its returned jsonb shape is unchanged (test C1).
--
-- No DROP, no CASCADE, no data mutation, no grant change. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_has boolean;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-725: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-725: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B (cutover) and KAN-713 markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  ELSE
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs)' INTO v_has;
    IF NOT v_has THEN
      v_missing := v_missing || 'public.kan712_wrapped_rpcs (empty: stage B not run)'::text;
    END IF;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-725: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- None of the three is KAN-712-wrapped: a bare CREATE OR REPLACE is the legal path only while that holds.
  EXECUTE $q$SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs
                             WHERE name IN ('rpc_meetup_card', 'rpc_meetup_attendees', 'rpc_meetup_my'))$q$ INTO v_has;
  IF v_has OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                       AND proname IN ('rpc_meetup_card_kan712_inner', 'rpc_meetup_attendees_kan712_inner',
                                       'rpc_meetup_my_kan712_inner')) THEN
    RAISE EXCEPTION 'KAN-725: a meetup read RPC is KAN-712-wrapped — use the unwrap/wrap path (KAN712_CONTRACT.md), stop';
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-725: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every meetups row has exactly one parent of event_type 'meetup' (INNER JOIN loses and doubles nothing).
  IF EXISTS (SELECT 1 FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-725: a meetups row has no events parent of event_type meetup';
  END IF;

  -- The function owners must read events past FORCE RLS, and stay SECURITY DEFINER.
  FOR r IN SELECT p.oid::regprocedure::text AS fn, p.proowner AS own, p.prosecdef FROM pg_proc p
            WHERE p.oid IN ('public.rpc_meetup_card(uuid,text)'::regprocedure,
                            'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure) LOOP
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-725: % is no longer SECURITY DEFINER; reading events would break API callers — stop', r.fn;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-725: owner of % cannot bypass RLS on public.events', r.fn;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins on the pre-image: md5 of pg_get_functiondef for all three, and the exact list of public functions
--    whose body calls any of them (their dependents). Already-applied state fails here too (md5 differs).
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_card(uuid,text)',                       'ba562664e6a99fee30a75de6fe5cbbeb'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',  '9c82e357c7b0fe58afc645f37d889523'),
      ('public.rpc_meetup_my()',                                  '9459dd31f4dfc534d26b3e37e49326b9')) AS t(fn, md)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-725 pin: % missing', r.fn;
    END IF;
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-725 pin: % definition drifted (md5 % expected %) — already applied, or the pre-image moved',
        r.fn, v, r.md;
    END IF;
  END LOOP;
  SELECT string_agg(p.oid::regprocedure::text, ',' ORDER BY p.oid::regprocedure::text) INTO v
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prosrc ~ 'rpc_meetup_(card|attendees|my)'
     AND p.proname NOT IN ('rpc_meetup_card', 'rpc_meetup_attendees', 'rpc_meetup_my');
  IF v IS DISTINCT FROM 'rpc_meetup_update_kan712_inner(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)' THEN
    RAISE EXCEPTION 'KAN-725 pin: callers of the meetup read RPCs drifted (got %) — re-assess', v;
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP: nothing persists).
CREATE TEMP TABLE kan725_pre ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig,
         pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res,
         md5(pg_get_functiondef(p.oid)) AS def
    FROM pg_proc p
   WHERE p.oid IN ('public.rpc_meetup_card(uuid,text)'::regprocedure,
                   'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure,
                   'public.rpc_meetup_my()'::regprocedure);
CREATE TEMP TABLE kan725_pre_events ON COMMIT DROP AS
  SELECT relacl::text AS acl, relrowsecurity, relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Functions
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_meetup_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       record;
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
  -- KAN-725: shared facts from the events parent; id/description/location_name/host_actor_id stay on meetups.
  select mt.id, mt.description, mt.location_name, mt.host_actor_id, e.creator_user_id, e.creator_profile_id, e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.is_cancelled, e.sport_id, e.area_id, e.venue_id, e.min_skill::integer as min_skill, e.max_skill::integer as max_skill
    into m
    from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id;
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

CREATE OR REPLACE FUNCTION public.rpc_meetup_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(actor_profile_id uuid, display_name text, username citext, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       record;
  v_host  boolean;
begin
  -- KAN-725: visibility owner and scope from the events parent.
  select mt.id, e.creator_user_id, e.listing_visibility
    into m
    from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id;
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

-- rpc_meetup_my: intentionally not touched (see header).

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- Exact new definitions (md5 of pg_get_functiondef); rpc_meetup_my byte-identical.
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_card(uuid,text)',                       '11a9f38356fc23e4430c9353b246eb8f'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',  'bb414558f86659d89497da378babcb7f'),
      ('public.rpc_meetup_my()',                                  '9459dd31f4dfc534d26b3e37e49326b9')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-725 post: % definition md5 % (expected %)', r.fn, v, r.md;
    END IF;
  END LOOP;

  -- Signature, result, owner, ACL, SECURITY DEFINER, volatility, search_path identical to the pre-image.
  IF EXISTS (SELECT 1 FROM pg_temp.kan725_pre p JOIN pg_proc c ON c.oid = p.oid
              WHERE c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_result(c.oid) <> p.res)
     OR (SELECT count(*) FROM pg_temp.kan725_pre) <> 3 THEN
    RAISE EXCEPTION 'KAN-725 post: signature / owner / ACL / SECURITY DEFINER / search_path changed';
  END IF;
  -- No overload appeared.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_meetup_card', 'rpc_meetup_attendees', 'rpc_meetup_my')) <> 3 THEN
    RAISE EXCEPTION 'KAN-725 post: overload count changed';
  END IF;

  -- events still closed to the API, attributes identical.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_temp.kan725_pre_events p, pg_class c
                 WHERE c.oid = 'public.events'::regclass
                   AND (c.relacl::text IS DISTINCT FROM p.acl OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity)) THEN
    RAISE EXCEPTION 'KAN-725 post: public.events opened to the API or its posture changed';
  END IF;
END
$post$;

COMMIT;
