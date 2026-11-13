-- KAN-714 (part 2) — Events P2: move the remaining consumers to parent (public.events) reads.
-- Re-authored under KAN-858 (KAN-839 ruling, Jira comment 15440: X1 option c, X2 part 2 only).
--
-- AUTHORED, NOT APPLIED. Local proof: supabase/tests/events_p4/kan858_part2_guard_test.sh.
-- Stands alone: it does not depend on, read, or roll back any other KAN-714 file.
-- Release order (KAN-811, Jira comment 15381): after B01-B07 and D04; BEFORE the D04 blocker files
-- (KAN-798/799/800/801/803/804/806/807/808), which own the 16 functions this file no longer touches.
--
-- What this does, in ONE transaction:
--   0. Stage guard: the applying role bypasses RLS; B01-B07 and D04 are applied (post-image pins below:
--      md5(prosrc) for functions, md5 of the sorted column-dependency list for views); this file is not
--      already applied; events still closed to the API; every games/meetups row has its parent.
--   1. Drift pins: md5(prosrc) of the 22 repointed functions and of the three helpers the owner-only twins
--      copy (game_slots_left, meetup_slots_left, _user_hosted_game), pinned to the step-30 bodies recorded in
--      supabase/tests/events_p4/KAN792_PIN_AUDIT.md. Any drift aborts.
--   2. Pre-image capture into public.kan714_preimage_2 (RLS on, no API grants). ROLLBACK restores from that
--      table only, in one transaction: EXECUTE each kind='function' row's definition (pg_get_functiondef
--      output), re-assert its owner/ACL from the row, then remove the five created objects it lists.
--   3. Two OWNER-ONLY overlay views, public.kan714_games_read and public.kan714_meetups_read: exactly the
--      legacy table's columns, order and types, every SHARED column (the columns public.events owns) read from
--      public.events (meetups.rsvp_policy <- events.join_policy), every subtype-only column from the subtype,
--      ids stay subtype ids. No grant to PUBLIC/anon/authenticated/service_role: only SECURITY DEFINER
--      functions owned by an RLS-bypassing owner can use them. Built from pg_attribute so the shape is the
--      live table's, and asserted equal to it in post-conditions.
--      Three owner-only SECURITY INVOKER twins of the helpers (kan714_game_slots_left,
--      kan714_meetup_slots_left, kan714_user_hosted_game), search_path '', no API EXECUTE. The originals
--      stay as they are.
--   4. CREATE OR REPLACE of 22 SECURITY DEFINER functions from pg_get_functiondef(): only their READS of
--      public.games / public.meetups move to the overlays. Not moved: `... FOR UPDATE` row locks, DELETE
--      targets, INSERT/UPDATE targets. Owner, ACL, SECURITY DEFINER, search_path, volatility, arguments and
--      return types are unchanged.
--      Not in this file (KAN-858 X2): rpc_decide_join_request, rpc_invite_user, rpc_mint_join_link,
--      rpc_recreate_from_game, rpc_remove_player, rpc_meetup_decide_request, rpc_meetup_remove_attendee,
--      rpc_meetup_rsvp, rpc_join_game, active_stream, rpc_get_activity_feed, rpc_get_nearby_games (both),
--      rpc_rate_game, rpc_rate_user, rpc_rate_venue — blocker-owned. admin_cleanup_user_data is also out: its
--      step-30 body touches public.games only as a DELETE target, so it has no read to move.
--   5. Post-conditions.
-- No DROP TABLE, no DROP COLUMN, no CASCADE, no data mutation, no legacy column removal, no events grant.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE v boolean := false; r record; h text; bad text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-714/2: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.kan714_preimage_2') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan714_preimage_2)' INTO v;
  END IF;
  IF v OR to_regclass('public.kan714_games_read') IS NOT NULL OR to_regclass('public.kan714_meetups_read') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-714/2: already applied; roll back from public.kan714_preimage_2 first';
  END IF;
  -- B01-B07 / D04 post-images. Functions: md5(prosrc). Views: md5 of the sorted, schema-qualified
  -- schema.relation.column list the view's rewrite rule depends on (server-version independent, unlike
  -- pg_get_viewdef text). D04 is also held by the $pins$ rows get_games_needing_players,
  -- get_open_games_for_seeding, rpc_create_game, rpc_create_meetup and _user_hosted_game.
  FOR r IN SELECT * FROM (VALUES
      ('B01', 'v', 'public.v_game_card',                 'd7c7c59344e52fff6ace74bec48b048f'),
      ('B01', 'v', 'public.v_my_games',                  '3b765364c7aed6faaee98043190936db'),
      ('B02', 'v', 'public.v_meetup_list',               '8724655e4127d9a4c460daff4acb3517'),
      ('B02', 'v', 'public.v_meetup_counts',             '372835d5a4ea428c6d69e1ba5eef8e20'),
      ('B03', 'v', 'public.v_rateable_after_game',       '1eeadf5e589c8273f0d7b7f5c105862f'),
      ('B04', 'f', 'public.rpc_games_following_joined(uuid[])', '2ca02c52556f14c2872211cdf988ee34'),
      ('B05', 'f', 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)', '399680ac808bddb5a34ef081410dfbd4'),
      ('B06', 'f', 'public.rpc_meetup_card(uuid,text)',  'c63da3eae7caced992bca253b712067d'),
      ('B06', 'f', 'public.rpc_meetup_attendees(uuid,text,integer,integer)', '59bdc97a9667bdc60198eb506c4f8083'),
      ('B07', 'f', 'public.rpc_sport_overview(uuid,text)', 'e7eb361a30f342e9e98df7b944638787'),
      ('B07', 'v', 'public.v_host_weekly_metrics',       '6ad1f78dced6598211ae74e45d8ff83e'),
      ('D04', 'f', 'public.meetup_counts(uuid)',         'e5982fbdee8d94c8de2c827a370038c5')) AS t(src, k, o, want)
  LOOP
    h := NULL;
    IF r.k = 'f' THEN
      SELECT md5(p.prosrc) INTO h FROM pg_proc p WHERE p.oid = to_regprocedure(r.o);
    ELSIF EXISTS (SELECT 1 FROM pg_class c WHERE c.oid = to_regclass(r.o) AND c.relkind = 'v') THEN
      SELECT md5(coalesce(string_agg(x, ',' ORDER BY x), '')) INTO h FROM (
        SELECT DISTINCT format('%I.%I.%I', rn.nspname, rc.relname, a.attname) AS x
          FROM pg_rewrite rw
          JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
          JOIN pg_class rc ON rc.oid = d.refobjid
          JOIN pg_namespace rn ON rn.oid = rc.relnamespace
          JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
         WHERE rw.ev_class = to_regclass(r.o) AND d.refobjid <> to_regclass(r.o)) s;
    END IF;
    IF h IS DISTINCT FROM r.want THEN
      bad := bad || format(' %s %s (md5 %s expected %s);', r.src, r.o, coalesce(h, '<absent>'), r.want);
    END IF;
  END LOOP;
  IF bad <> '' THEN
    RAISE EXCEPTION 'KAN-714/2 prereq: B01-B07/D04 post-image not in place:%', bad;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-714/2: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL)
     OR EXISTS (SELECT 1 FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-714/2: a games/meetups row has no events parent of the matching event_type';
  END IF;
END
$guard$;


CREATE TEMP TABLE kan714_2_events_acl ON COMMIT DROP AS
  SELECT relacl::text AS acl FROM pg_class WHERE oid = 'public.events'::regclass;

-- Every repointed function is SECURITY DEFINER and its owner bypasses RLS on events (and owns the overlays).
DO $owners$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text AS f, p.prosecdef, p.proowner FROM pg_proc p WHERE p.oid IN (
    'public.admin_overview_row()'::regprocedure,
    'public.fn_game_roster_activity_sync()'::regprocedure,
    'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure,
    'public.fn_meetup_rsvps_activity_sync()'::regprocedure,
    'public.get_games_needing_players()'::regprocedure,
    'public.get_open_games_for_seeding()'::regprocedure,
    'public.msg_authorize(uuid,text)'::regprocedure,
    'public.msg_evaluate(uuid,uuid,text)'::regprocedure,
    'public.msg_my_conversations(integer)'::regprocedure,
    'public.nearby_games(double precision,double precision,integer,text,integer,integer)'::regprocedure,
    'public.rpc_autocomplete_entities(text,text[],text,integer)'::regprocedure,
    'public.rpc_booking_cancel(uuid)'::regprocedure,
    'public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
    'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
    'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure,
    'public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)'::regprocedure,
    'public.rpc_search_entities(text,text[],text,integer)'::regprocedure,
    'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure,
    'public.settle_game(uuid,boolean)'::regprocedure,
    'public.trg_game_join_request_notify()'::regprocedure,
    'public.trg_game_waitlist_promoted_notify()'::regprocedure,
    'public.trg_meetup_rsvps_notify()'::regprocedure)
  LOOP
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-714/2: % is not SECURITY DEFINER (overlays have no API grant)', r.f;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.proowner AND (rolsuper OR rolbypassrls))
       OR r.proowner <> (SELECT oid FROM pg_roles WHERE rolname = current_user) THEN
      RAISE EXCEPTION 'KAN-714/2: owner of % must be the applying role and bypass RLS', r.f;
    END IF;
  END LOOP;
END
$owners$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text; n int := 0;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.admin_overview_row()', '42573e04bc2aae0af755ded1f8eceb5a'),
      ('public.fn_game_roster_activity_sync()', '3274cca43042f67a81c9853dd82b4415'),
      ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)', '2c36c743e9b82699fea440e2c93aa976'),
      ('public.fn_meetup_rsvps_activity_sync()', 'ea879f6ac22b0e2a7e154201a7184a49'),
      ('public.get_games_needing_players()', 'c818c2082bf1a29e40202776869ad42b'),
      ('public.get_open_games_for_seeding()', '30333cbe1d77a6a5ca5b1e757e3e945f'),
      ('public.msg_authorize(uuid,text)', 'b55e059bcf494df887e48ebdf8139949'),
      ('public.msg_evaluate(uuid,uuid,text)', '3276466a3d192afd4ee4675135637859'),
      ('public.msg_my_conversations(integer)', '1297831ca8202108ba9001a750c8935d'),
      ('public.nearby_games(double precision,double precision,integer,text,integer,integer)', '19b0a6c0ce028c4273f46ece71713d9a'),
      ('public.rpc_autocomplete_entities(text,text[],text,integer)', '10369e0dba10ae05a27221a448eb5caf'),
      ('public.rpc_booking_cancel(uuid)', '574e008d904dbb4e40db298559a9192d'),
      ('public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)', 'df2359a7c9fb031cb350836139a13ab9'),
      ('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)', '0b7e53391b2a44007316d42036d95134'),
      ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)', '5b8883b2ab8b55f8d2119c6fbd023dcc'),
      ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)', '0f5ba02e7123f095436350842f229dae'),
      ('public.rpc_search_entities(text,text[],text,integer)', '802a43a24f290110b614aa1ff9c04570'),
      ('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)', '399680ac808bddb5a34ef081410dfbd4'),
      ('public.settle_game(uuid,boolean)', 'ee62121d87bee5c6dd1109e6ad11d8b4'),
      ('public.trg_game_join_request_notify()', '65f55b54654b9fe12ef5e6afef4ebe6f'),
      ('public.trg_game_waitlist_promoted_notify()', '263d03c2b3ac0a1ca281e40a1ae71c46'),
      ('public.trg_meetup_rsvps_notify()', 'a22ed63dec19a237b005e30e9c038dc1'),
      ('public.game_slots_left(uuid)', 'bd773c6f559b9692753fdfccd1eee959'),
      ('public.meetup_slots_left(uuid)', '17e5926db75031e80ffdf8aedbb803a5'),
      ('public._user_hosted_game(uuid,uuid)', '41a0f3b192055a68f7dbaea2807c9933')) AS t(f, h)
  LOOP
    IF to_regprocedure(r.f) IS NULL THEN
      RAISE EXCEPTION 'KAN-714/2 pin: % missing', r.f;
    END IF;
    SELECT md5(prosrc) INTO v FROM pg_proc WHERE oid = to_regprocedure(r.f);
    IF v <> r.h THEN
      RAISE EXCEPTION 'KAN-714/2 pin: % body drifted (md5 % expected %)', r.f, v, r.h;
    END IF;
    n := n + 1;
  END LOOP;
  IF n <> 22 + 3 THEN
    RAISE EXCEPTION 'KAN-714/2 pin: expected % pins, checked %', 22 + 3, n;
  END IF;
END
$pins$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Pre-image capture
-- ---------------------------------------------------------------------------------------------------------
SET LOCAL search_path TO public, extensions;
CREATE TABLE IF NOT EXISTS public.kan714_preimage_2 (
  object      text PRIMARY KEY,           -- regprocedure text, or regclass text for a created view
  kind        text NOT NULL CHECK (kind IN ('function', 'created_view', 'created_function')),
  definition  text,                       -- pg_get_functiondef() for kind = 'function'; NULL for created objects
  acl         text,
  owner       name NOT NULL,
  secdef      boolean,
  config      text[],
  volatility  "char",
  captured_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kan714_preimage_2 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kan714_preimage_2 FROM PUBLIC, anon, authenticated, service_role;

INSERT INTO public.kan714_preimage_2 (object, kind, definition, acl, owner, secdef, config, volatility)
SELECT p.oid::regprocedure::text, 'function', pg_get_functiondef(p.oid), p.proacl::text, pg_get_userbyid(p.proowner),
       p.prosecdef, p.proconfig, p.provolatile
  FROM pg_proc p
 WHERE p.oid IN (
    'public.admin_overview_row()'::regprocedure,
    'public.fn_game_roster_activity_sync()'::regprocedure,
    'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure,
    'public.fn_meetup_rsvps_activity_sync()'::regprocedure,
    'public.get_games_needing_players()'::regprocedure,
    'public.get_open_games_for_seeding()'::regprocedure,
    'public.msg_authorize(uuid,text)'::regprocedure,
    'public.msg_evaluate(uuid,uuid,text)'::regprocedure,
    'public.msg_my_conversations(integer)'::regprocedure,
    'public.nearby_games(double precision,double precision,integer,text,integer,integer)'::regprocedure,
    'public.rpc_autocomplete_entities(text,text[],text,integer)'::regprocedure,
    'public.rpc_booking_cancel(uuid)'::regprocedure,
    'public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
    'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
    'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure,
    'public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)'::regprocedure,
    'public.rpc_search_entities(text,text[],text,integer)'::regprocedure,
    'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure,
    'public.settle_game(uuid,boolean)'::regprocedure,
    'public.trg_game_join_request_notify()'::regprocedure,
    'public.trg_game_waitlist_promoted_notify()'::regprocedure,
    'public.trg_meetup_rsvps_notify()'::regprocedure);

INSERT INTO public.kan714_preimage_2 (object, kind, owner) VALUES
  ('public.kan714_games_read', 'created_view', current_user),
  ('public.kan714_meetups_read', 'created_view', current_user),
  ('public.kan714_game_slots_left(uuid)', 'created_function', current_user),
  ('public.kan714_meetup_slots_left(uuid)', 'created_function', current_user),
  ('public.kan714_user_hosted_game(uuid,uuid)', 'created_function', current_user);

DO $cnt$ BEGIN
  IF (SELECT count(*) FROM public.kan714_preimage_2 WHERE kind = 'function') <> 22 THEN
    RAISE EXCEPTION 'KAN-714/2: pre-image capture expected 22 functions, got %',
      (SELECT count(*) FROM public.kan714_preimage_2 WHERE kind = 'function');
  END IF;
END $cnt$;

-- ---------------------------------------------------------------------------------------------------------
-- 3a. Owner-only overlays (shape = the live legacy table; shared columns from public.events)
-- ---------------------------------------------------------------------------------------------------------
DO $overlay$
DECLARE
  r record; v_cols text;
BEGIN
  FOR r IN SELECT * FROM (VALUES ('games', 'g', 'game', 'kan714_games_read'),
                                 ('meetups', 'm', 'meetup', 'kan714_meetups_read')) AS t(tbl, al, et, vw)
  LOOP
    SELECT string_agg(
             CASE
               WHEN r.tbl = 'meetups' AND a.attname = 'rsvp_policy'
                 THEN format('e.join_policy::%s AS rsvp_policy', format_type(a.atttypid, a.atttypmod))
               WHEN ea.attname IS NOT NULL
                 THEN format('e.%I::%s AS %I', a.attname, format_type(a.atttypid, a.atttypmod), a.attname)
               ELSE format('%s.%I', r.al, a.attname)
             END, ', ' ORDER BY a.attnum)
      INTO v_cols
      FROM pg_attribute a
      LEFT JOIN pg_attribute ea ON ea.attrelid = 'public.events'::regclass AND ea.attnum > 0 AND NOT ea.attisdropped
                               AND ea.attname = a.attname AND ea.attname NOT IN ('id', 'event_type', 'search_tsv')
     WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
    EXECUTE format('CREATE VIEW public.%I AS SELECT %s FROM public.%I %s JOIN public.events e ON e.id = %s.event_id AND e.event_type = %L',
                   r.vw, v_cols, r.tbl, r.al, r.al, r.et);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated, service_role', r.vw);
    EXECUTE format('COMMENT ON VIEW public.%I IS %L', r.vw,
                   'KAN-714 owner-only overlay: ' || r.tbl || ' with shared columns from public.events. '
                   || 'No API grant by design; read only inside SECURITY DEFINER functions. Rollback: restore from public.kan714_preimage_2.');
  END LOOP;
END
$overlay$;

-- ---------------------------------------------------------------------------------------------------------
-- 3b. Owner-only INVOKER twins (bodies = the pinned originals, reads moved to the overlays; search_path '')
-- ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan714_game_slots_left(p_game uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
-- KAN-727: capacity from events (authoritative) for callers that may read events; pre-image read otherwise
-- (INVOKER, granted to clients; events has no client grant -- KAN-713's v_events pattern).
DECLARE
  v_capacity  integer;
  v_game_type text;
  v_active    integer;
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    SELECT e.capacity, g.game_type INTO v_capacity, v_game_type
      FROM public.kan714_games_read g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE g.id = p_game;
  ELSE
    SELECT g.capacity, g.game_type INTO v_capacity, v_game_type
      FROM public.kan714_games_read g
     WHERE g.id = p_game;
  END IF;
  IF NOT FOUND THEN
    RETURN 0;                                   -- pre-image: GREATEST(NULL - 0, 0) = 0 for an unknown game
  END IF;
  SELECT count(*)::int INTO v_active
    FROM public.game_roster r
   WHERE r.game_id = p_game AND r.status = 'active'
     AND (r.role = 'player' OR (r.role = 'host' AND v_game_type = 'hosted'));
  RETURN GREATEST(v_capacity - v_active, 0);
END
$function$;

CREATE FUNCTION public.kan714_meetup_slots_left(p_meetup uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  -- KAN-727: capacity from events e (authoritative); NULL = unlimited (999999) kept; unknown meetup -> NULL kept.
  select
    case when e.capacity is null then 999999
         else greatest(e.capacity - coalesce((select count(*) from public.meetup_rsvps r where r.meetup_id=m.id and r.status='going'),0), 0)
    end as slots_left
  from public.kan714_meetups_read m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  where m.id = p_meetup
$function$;

CREATE FUNCTION public.kan714_user_hosted_game(p_user_id uuid, p_game_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
-- KAN-772: creator from events for callers that may read events (rpc_rate_venue, SECURITY DEFINER);
-- pre-image read otherwise (INVOKER, granted to clients; events has no client grant -- KAN-727 pattern).
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    RETURN EXISTS (
      SELECT 1 FROM public.kan714_games_read g
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE g.id = p_game_id
         AND e.creator_user_id = p_user_id);
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.kan714_games_read g
     WHERE g.id = p_game_id
       AND g.creator_user_id = p_user_id);
END
$function$;

-- A DROP+CREATE / CREATE in public is granted to anon by name through pg_default_acl, so revoke by name.
REVOKE ALL ON FUNCTION public.kan714_game_slots_left(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan714_meetup_slots_left(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan714_user_hosted_game(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;


-- ---------------------------------------------------------------------------------------------------------
-- 4. Repointed function bodies (22). Each is pg_get_functiondef() of the step-30 body (KAN792_PIN_AUDIT.md) with only:
--    FROM/JOIN public.games|meetups (reads, not FOR UPDATE, not DELETE targets) -> the owner-only overlay;
--    the named extra edits listed per object in KAN714_CONTRACT.md section 9.
-- ---------------------------------------------------------------------------------------------------------

-- [manifest 10] public.admin_overview_row()
CREATE OR REPLACE FUNCTION public.admin_overview_row()
 RETURNS TABLE(snapshot_at timestamp with time zone, total_users bigint, frozen_users bigint, active_users bigint, games_created_this_week bigint, reports_open bigint, reports_resolved bigint, verified_profiles_total bigint, verified_players bigint, verified_organisers bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  wk_start timestamptz;
  wk_end   timestamptz;
begin
  -- Gate: admin only
  if not public.is_admin(auth.uid()) then
    raise exception using errcode = 'P0001', message = 'not_admin';
  end if;

  select week_start, week_end into wk_start, wk_end
  from public._week_bounds(now());

  -- Return single-row snapshot
  return query
  with
  -- Distinct humans inferred from profiles; avoids needing auth.users privileges
  users_distinct as (
    select count(distinct p.user_id)::bigint as c
    from public.profiles p
    where p.is_active = true
  ),
  frozen as (
    select count(distinct f.user_id)::bigint as c
    from public.user_freezes f
    where f.is_frozen = true
      and (f.until is null or now() < f.until)
      and f.lifted_at is null
  ),
  -- KAN-732 (KAN-714 B13): created_at is a SHARED fact, read from the game's events parent.
  games_week as (
    select count(*)::bigint as c
    from public.kan714_games_read g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
    where e.created_at >= wk_start
      and e.created_at <  wk_end
  ),
  reports as (
    select
      count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
      count(*) filter (where status = 'resolved')::bigint          as resolved_c
    from public.content_reports
  ),
  verif as (
    select
      count(*)::bigint                                                     as total_c,
      count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
      count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
    from public.profile_verifications v
    join public.profiles p on p.id = v.profile_id
    where v.verified = true
  )
  select
    now()                                              as snapshot_at,
    (select c from users_distinct)                     as total_users,
    (select c from frozen)                             as frozen_users,
    (select c from users_distinct) - (select c from frozen)  as active_users,
    (select c from games_week)                         as games_created_this_week,
    (select open_c from reports)                       as reports_open,
    (select resolved_c from reports)                   as reports_resolved,
    (select total_c from verif)                        as verified_profiles_total,
    (select players_c from verif)                      as verified_players,
    (select organisers_c from verif)                   as verified_organisers;
end;
$function$;

-- [manifest 16] public.fn_game_roster_activity_sync()
CREATE OR REPLACE FUNCTION public.fn_game_roster_activity_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT'
     AND NEW.role IN ('player', 'host')
     AND NEW.status = 'active' THEN

    INSERT INTO public.public_activities
      (id, activity_type, source_table,
       parent_activity_id,
       actor_user_id, actor_profile_id, target_profile_id,
       visibility,
       occurred_at, created_at, updated_at)
    VALUES (
      NEW.id, 'game_join', 'game_roster',
      NEW.game_id,   -- game_id = game's public_activities.id (shared UUID)
      NEW.user_id, NEW.profile_id,
      (SELECT creator_profile_id FROM public.kan714_games_read WHERE id = NEW.game_id),
      'public',
      COALESCE(NEW.joined_at, now()), COALESCE(NEW.joined_at, now()), COALESCE(NEW.joined_at, now())
    )
    ON CONFLICT (id) DO NOTHING;

    -- Bump the game's reply_count as a proxy for "participants"
    UPDATE public.public_activities
    SET reply_count = reply_count + 1, updated_at = now()
    WHERE id = NEW.game_id;

  ELSIF TG_OP = 'UPDATE' AND NEW.status IN ('left', 'kicked') AND OLD.status = 'active' THEN
    UPDATE public.public_activities
    SET is_deleted = true, updated_at = now()
    WHERE id = NEW.id;

    UPDATE public.public_activities
    SET reply_count = GREATEST(reply_count - 1, 0), updated_at = now()
    WHERE id = NEW.game_id;
  END IF;
  RETURN NEW;
END;
$function$;

-- [manifest 17] public.fn_generate_game_series_occurrences_kan712_inner(uuid)
CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences_kan712_inner(p_series_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
BEGIN
  FOR s IN
    SELECT * FROM public.game_series
     WHERE status = 'active' AND (p_series_id IS NULL OR id = p_series_id)
     ORDER BY id
       FOR UPDATE   -- serialises two generators on the same series
  LOOP
    SELECT persona_type INTO v_persona FROM public.profiles WHERE id = s.creator_profile_id;
    v_step := CASE WHEN s.rrule LIKE '%INTERVAL=2%' THEN 14 ELSE 7 END;

    SELECT count(*) INTO v_future FROM public.kan714_games_read g
     WHERE g.series_id = s.id AND g.start_at > now() AND NOT COALESCE(g.is_cancelled, false);

    v_n := 0;
    WHILE v_n < 52 AND v_future < s.occurrences_ahead LOOP   -- 52 = hard cap on occurrence slots per series
      v_day := s.starts_on + (v_n * v_step);
      EXIT WHEN s.ends_on IS NOT NULL AND v_day > s.ends_on;
      v_n := v_n + 1;   -- the slot is consumed even when its date is already held (counts once toward the cap)
      v_start := (v_day + s.start_time_local) AT TIME ZONE s.timezone;
      v_end := v_start + make_interval(mins => s.duration_minutes);
      CONTINUE WHEN v_start <= now();
      -- A kept row on this local date (any time) already counts in v_future; do not add a second one.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g WHERE g.series_id = s.id AND g.start_at = v_start);

      v_prev_sub := current_setting('request.jwt.claim.sub', true);
      PERFORM set_config('request.jwt.claim.sub', s.creator_user_id::text, true);
      v_gid := public.rpc_create_game(
        v_persona, s.sport_id, s.sport_variant_id, s.title, s.venue_space_id, v_start, v_end, 0,
        s.listing_visibility, s.join_policy, NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        s.geo_location_id, s.area_id, NULL, NULL, NULL, s.capacity, 0::numeric, NULL);
      PERFORM set_config('request.jwt.claim.sub', COALESCE(v_prev_sub, ''), true);
      UPDATE public.games SET series_id = s.id WHERE id = v_gid;
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
END;
$function$;

-- [manifest 18] public.fn_meetup_rsvps_activity_sync()
CREATE OR REPLACE FUNCTION public.fn_meetup_rsvps_activity_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'going' THEN
    INSERT INTO public.public_activities
      (id, activity_type, source_table,
       parent_activity_id,
       actor_user_id, actor_profile_id, target_profile_id,
       visibility,
       occurred_at, created_at, updated_at)
    VALUES (
      NEW.id, 'meetup_join', 'meetup_rsvps',
      NEW.meetup_id,
      NEW.user_id, NEW.profile_id,
      (SELECT creator_profile_id FROM public.kan714_meetups_read WHERE id = NEW.meetup_id),
      'public',
      NEW.created_at, NEW.created_at, NEW.created_at
    )
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.public_activities
    SET reply_count = reply_count + 1, updated_at = now()
    WHERE id = NEW.meetup_id;

  ELSIF TG_OP = 'UPDATE'
        AND NEW.status <> 'going'
        AND OLD.status = 'going' THEN
    UPDATE public.public_activities
    SET is_deleted = true, updated_at = now()
    WHERE id = NEW.id;

    UPDATE public.public_activities
    SET reply_count = GREATEST(reply_count - 1, 0), updated_at = now()
    WHERE id = NEW.meetup_id;
  END IF;
  RETURN NEW;
END;
$function$;

-- [manifest 22] public.get_games_needing_players()
CREATE OR REPLACE FUNCTION public.get_games_needing_players()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: shared fields from events (same JSON keys, same filters and order).
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT
      g.id                                      AS game_id,
      e.sport_id,
      e.area_id,
      e.capacity,
      s.sport_key,
      a.city,
      COUNT(gr.profile_id)                      AS current_players,
      e.capacity - COUNT(gr.profile_id)         AS spots_remaining,
      -- get all profile_ids already in this game as array
      ARRAY_AGG(gr.profile_id) FILTER (WHERE gr.profile_id IS NOT NULL) AS existing_profiles
    FROM public.kan714_games_read g
    JOIN public.events e       ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.sports s       ON s.id = e.sport_id
    JOIN public.areas a        ON a.id = e.area_id
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id AND gr.status = 'active'
    WHERE e.is_cancelled = false
      AND e.start_at > now()
    GROUP BY g.id, e.sport_id, e.area_id, e.capacity, s.sport_key, a.city
    HAVING e.capacity - COUNT(gr.profile_id) > 0
    ORDER BY spots_remaining DESC
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

-- [manifest 25] public.get_open_games_for_seeding()
CREATE OR REPLACE FUNCTION public.get_open_games_for_seeding()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: shared fields from events (same JSON keys, same filters, order and limit).
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT DISTINCT ON (g.id)
      g.id                    AS game_id,
      e.sport_id,
      e.area_id,
      e.capacity,
      e.start_at,
      s.sport_key,
      a.city,
      p.id                    AS profile_id,
      p.user_id,
      p.display_name
    FROM public.kan714_games_read g
    JOIN public.events e       ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.sports s       ON s.id = e.sport_id
    JOIN public.areas a        ON a.id = e.area_id
    JOIN public.profiles p     ON p.city = a.city
                               AND p.primary_sport = e.sport_id
                               AND p.is_original = false
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id
                               AND gr.profile_id = p.id
    WHERE e.is_cancelled = false
      AND e.start_at > now()
      AND gr.profile_id IS NULL
      AND (
        SELECT COUNT(*) FROM public.game_roster
        WHERE game_id = g.id AND status = 'active'
      ) < e.capacity
    ORDER BY g.id, random()
    LIMIT 10
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

-- [manifest 38] public.msg_authorize(uuid,text)
CREATE OR REPLACE FUNCTION public.msg_authorize(p_conversation_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(user_id uuid, allowed_action text, reason text, left_at_seq bigint, member_user_ids uuid[], hidden_sender_ids uuid[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_eval record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::text, v_eval.reason, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid,
         v_eval.allowed_action,
         v_eval.reason,
         v_eval.left_at_seq,
         -- CURRENT active members, for fan-out.
         CASE WHEN EXISTS (SELECT 1 FROM public.msg_conversations mc
                            WHERE mc.id = p_conversation_id AND mc.kind = 'meetup') THEN
           -- KAN-558: a meetup's members are its organiser and its 'going' RSVPs.
           COALESCE((SELECT array_agg(DISTINCT x.uid ORDER BY x.uid)
                       FROM (SELECT e.creator_user_id AS uid  -- KAN-730: organiser from the events parent
                               FROM public.msg_conversations mc
                               JOIN public.kan714_meetups_read mt ON mt.id = mc.meetup_id
                               JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
                              WHERE mc.id = p_conversation_id
                             UNION
                             SELECT r.user_id
                               FROM public.msg_conversations mc
                               JOIN public.meetup_rsvps r ON r.meetup_id = mc.meetup_id
                              WHERE mc.id = p_conversation_id
                                AND r.status = 'going') x), '{}'::uuid[])
         WHEN v_eval.game_id IS NULL THEN
           -- KAN-560: a DM has no roster; its members are the two registry rows.
           COALESCE((SELECT array_agg(DISTINCT m.user_id ORDER BY m.user_id)
                       FROM public.msg_conversation_members m
                      WHERE m.conversation_id = p_conversation_id), '{}'::uuid[])
         ELSE
         COALESCE((SELECT array_agg(DISTINCT r.user_id ORDER BY r.user_id)
                     FROM public.game_roster r
                    WHERE r.game_id = v_eval.game_id
                      AND r.status = 'active'
                      AND r.role IN ('host', 'player', 'sub')), '{}'::uuid[])
         END,
         -- D4 group rule: users the caller blocked; the Worker hides their messages.
         COALESCE((SELECT array_agg(DISTINCT b.blocked_user_id ORDER BY b.blocked_user_id)
                     FROM public.user_blocks b
                    WHERE b.blocker_user_id = v_uid), '{}'::uuid[]);
END;
$function$;

-- [manifest 39] public.msg_evaluate(uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.msg_evaluate(p_conversation_id uuid, p_user_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(allowed_action text, reason text, left_at_seq bigint, game_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_game_id   uuid;
  v_cancelled boolean;
  v_end_at    timestamptz;
  v_role      text;
  v_status    text;
  v_left_seq  bigint;
  v_kind      text;
  v_other     uuid;
  v_meetup_id uuid;
  v_m_cancel  boolean;
  v_m_end_at  timestamptz;
  v_m_owner   uuid;
  v_m_status  text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_authenticated'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode IS NULL OR p_access_mode NOT IN ('allowlist', 'all') THEN
    RETURN QUERY SELECT NULL::text, 'messaging_off'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode = 'allowlist'
     AND NOT EXISTS (SELECT 1 FROM public.msg_access_allowlist a WHERE a.user_id = p_user_id) THEN
    RETURN QUERY SELECT NULL::text, 'not_in_pilot'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- KAN-560: a one-to-one DM has no roster, no end time and no game state. Both members may read and send
  -- while neither has blocked the other; a block in either direction, or a counterpart who is deleted or
  -- banned, makes it read-only for BOTH (history stays readable, nothing is deleted). Game chats skip this branch.
  SELECT c.kind INTO v_kind FROM public.msg_conversations c WHERE c.id = p_conversation_id;
  IF v_kind = 'dm' THEN
    SELECT o.user_id INTO v_other
      FROM public.msg_conversation_members me
      JOIN public.msg_conversation_members o
        ON o.conversation_id = me.conversation_id AND o.user_id <> me.user_id
     WHERE me.conversation_id = p_conversation_id
       AND me.user_id = p_user_id;
    IF v_other IS NULL THEN
      RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_blocks b
                WHERE (b.blocker_user_id = p_user_id AND b.blocked_user_id = v_other)
                   OR (b.blocker_user_id = v_other AND b.blocked_user_id = p_user_id)) THEN
      RETURN QUERY SELECT 'read'::text, 'blocked'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF public.msg_user_unavailable(v_other) THEN
      RETURN QUERY SELECT 'read'::text, 'suspended'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- KAN-558: a meetup chat. Membership comes from the meetup, not a roster: the organiser (creator_user_id) is always
  -- a member; an RSVP with status 'going' is a member; an RSVP with status 'cancelled' is a voluntary leaver (read
  -- up to left_at_seq, exactly the game 'left' rule); any other RSVP status, or none, is not a member. Lifecycle is
  -- the game rule with the game's reason strings: cancelled wins (game_cancelled), then ended (game_ended). A meetup
  -- with no end_at ends at its start_at (fails closed). game_id is returned NULL: a meetup is not a game.
  IF v_kind = 'meetup' THEN
    -- KAN-730: the shared facts (cancelled, start/end, organiser) come from the events parent.
    SELECT c.meetup_id, e.is_cancelled, COALESCE(e.end_at, e.start_at), e.creator_user_id
      INTO v_meetup_id, v_m_cancel, v_m_end_at, v_m_owner
      FROM public.msg_conversations c
      JOIN public.kan714_meetups_read mt ON mt.id = c.meetup_id
      JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
     WHERE c.id = p_conversation_id;
    IF v_meetup_id IS NULL THEN
      RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF v_m_owner = p_user_id THEN
      v_m_status := 'going';
    ELSE
      SELECT r.status INTO v_m_status
        FROM public.meetup_rsvps r
       WHERE r.meetup_id = v_meetup_id
         AND r.user_id = p_user_id;
    END IF;
    IF v_m_status = 'going' THEN
      IF v_m_cancel THEN
        RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, NULL::uuid;
      ELSIF v_m_end_at >= now() THEN
        RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;
      ELSE
        RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, NULL::uuid;
      END IF;
      RETURN;
    END IF;
    IF v_m_status = 'cancelled' THEN
      SELECT m.left_at_seq INTO v_left_seq
        FROM public.msg_conversation_members m
       WHERE m.conversation_id = p_conversation_id
         AND m.user_id = p_user_id;
      RETURN QUERY SELECT 'read'::text, 'left'::text, COALESCE(v_left_seq, 0), NULL::uuid;
      RETURN;
    END IF;
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- KAN-730: the shared facts (cancelled, end) come from the events parent.
  SELECT c.game_id, e.is_cancelled, e.end_at
    INTO v_game_id, v_cancelled, v_end_at
    FROM public.msg_conversations c
    JOIN public.kan714_games_read g ON g.id = c.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE c.id = p_conversation_id;

  IF v_game_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- One user may hold more than one roster row (one per profile): an active row wins.
  SELECT r.role, r.status
    INTO v_role, v_status
    FROM public.game_roster r
   WHERE r.game_id = v_game_id
     AND r.user_id = p_user_id
     AND r.role IN ('host', 'player', 'sub')
   ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
   LIMIT 1;

  IF v_status IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF v_status = 'active' THEN
    IF v_cancelled THEN
      -- Cancelled wins over ended: a cancelled game past its end time is still game_cancelled.
      RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, v_game_id;
    ELSIF v_end_at >= now() THEN
      RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id;
    ELSE
      RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, v_game_id;
    END IF;
    RETURN;
  END IF;

  IF v_status = 'left' THEN
    SELECT m.left_at_seq INTO v_left_seq
      FROM public.msg_conversation_members m
     WHERE m.conversation_id = p_conversation_id
       AND m.user_id = p_user_id;
    -- No recorded left_at_seq fails closed: read up to 0, i.e. nothing.
    RETURN QUERY SELECT 'read'::text, 'left'::text, COALESCE(v_left_seq, 0), v_game_id;
    RETURN;
  END IF;

  -- 'kicked' and every other non-active status read nothing.
  RETURN QUERY SELECT NULL::text, 'removed'::text, NULL::bigint, NULL::uuid;
END;
$function$;

-- [manifest 41] public.msg_my_conversations(integer)
CREATE OR REPLACE FUNCTION public.msg_my_conversations(p_limit integer DEFAULT 50)
 RETURNS TABLE(conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamp with time zone, end_at timestamp with time zone, state text, last_activity_at timestamp with time zone, kind text, counterpart_user_id uuid, counterpart_name text, counterpart_avatar text, muted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT t.conversation_id, t.game_id, t.game_title, t.sport, t.start_at, t.end_at, t.state, t.last_activity_at,
         t.kind, t.counterpart_user_id, t.counterpart_name, t.counterpart_avatar, t.muted
    FROM (
      -- Game chats: the KAN-547 query, unchanged, plus the new columns.
      SELECT c.id AS conversation_id,
             g.id AS game_id,
             e.title AS game_title,
             s.name_en AS sport,
             e.start_at AS start_at,
             e.end_at AS end_at,
             CASE
               WHEN m.status = 'left' THEN 'left'
               WHEN e.is_cancelled OR e.end_at < now() THEN 'read_only'
               ELSE 'send'
             END AS state,
             c.last_activity_at AS last_activity_at,
             'game'::text AS kind,
             NULL::uuid AS counterpart_user_id,
             NULL::text AS counterpart_name,
             NULL::text AS counterpart_avatar,
             EXISTS (SELECT 1 FROM public.msg_conversation_members mm
                      WHERE mm.conversation_id = c.id AND mm.user_id = auth.uid() AND mm.muted_at IS NOT NULL) AS muted
        FROM public.msg_conversations c
        JOIN public.kan714_games_read g ON g.id = c.game_id
        -- KAN-730: title, sport, start, end, cancelled come from the events parent.
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
        LEFT JOIN public.sports s ON s.id = e.sport_id
        CROSS JOIN LATERAL (
          -- msg_evaluate's rule: one roster row per user and game, an active row wins, then a left row.
          SELECT r.status
            FROM public.game_roster r
           WHERE r.game_id = c.game_id
             AND r.user_id = auth.uid()
             AND r.role IN ('host', 'player', 'sub')
           ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
           LIMIT 1
        ) m
       WHERE c.kind = 'game'
         AND auth.uid() IS NOT NULL
         AND m.status IN ('active', 'left')

      UNION ALL

      -- Direct messages: the caller is a member; the starter sees it at once, the other member once a message exists.
      SELECT c.id,
             NULL::uuid,
             NULL::text,
             NULL::text,
             NULL::timestamptz,
             NULL::timestamptz,
             CASE
               WHEN EXISTS (SELECT 1 FROM public.user_blocks b
                             WHERE (b.blocker_user_id = auth.uid() AND b.blocked_user_id = o.user_id)
                                OR (b.blocker_user_id = o.user_id AND b.blocked_user_id = auth.uid()))
                 OR public.msg_user_unavailable(o.user_id) THEN 'read_only'
               ELSE 'send'
             END,
             c.last_activity_at,
             'dm'::text,
             o.user_id,
             pp.display_name,
             pp.avatar_url,
             me.muted_at IS NOT NULL
        FROM public.msg_conversations c
        JOIN public.msg_dm_pairs d ON d.conversation_id = c.id
        JOIN public.msg_conversation_members me ON me.conversation_id = c.id AND me.user_id = auth.uid()
        JOIN public.msg_conversation_members o ON o.conversation_id = c.id AND o.user_id <> auth.uid()
        LEFT JOIN LATERAL (
          -- the public profile only: the view hides benched and inactive users
          SELECT v.display_name, v.avatar_url
            FROM public.profiles p
            JOIN public.v_profile_public v ON v.id = p.id
           WHERE p.user_id = o.user_id
           ORDER BY (p.profile_type = 'personal') DESC, p.created_at ASC
           LIMIT 1
        ) pp ON true
       WHERE c.kind = 'dm'
         AND auth.uid() IS NOT NULL
         AND (d.started_by = auth.uid() OR c.last_activity_at > c.created_at)

      UNION ALL

      -- KAN-558: meetup chats. The organiser and 'going' RSVPs are members; a 'cancelled' RSVP is a leaver ('left');
      -- cancelled or ended (end_at, or start_at when there is no end_at) is read_only. The meetup's title, sport,
      -- start and end fill the same columns a game row uses; game_id and the counterpart columns are NULL.
      SELECT c.id,
             mt.id,
             e.title,
             ms.name_en,
             e.start_at,
             e.end_at,
             CASE
               WHEN e.creator_user_id <> auth.uid() AND mr.status = 'cancelled' THEN 'left'
               WHEN e.is_cancelled OR COALESCE(e.end_at, e.start_at) < now() THEN 'read_only'
               ELSE 'send'
             END,
             c.last_activity_at,
             'meetup'::text,
             NULL::uuid,
             NULL::text,
             NULL::text,
             EXISTS (SELECT 1 FROM public.msg_conversation_members mm
                      WHERE mm.conversation_id = c.id AND mm.user_id = auth.uid() AND mm.muted_at IS NOT NULL)
        FROM public.msg_conversations c
        JOIN public.kan714_meetups_read mt ON mt.id = c.meetup_id
        -- KAN-730: title, sport, start, end, cancelled, organiser come from the events parent.
        JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
        LEFT JOIN public.sports ms ON ms.id = e.sport_id
        LEFT JOIN public.meetup_rsvps mr ON mr.meetup_id = mt.id AND mr.user_id = auth.uid()
       WHERE c.kind = 'meetup'
         AND auth.uid() IS NOT NULL
         AND (e.creator_user_id = auth.uid() OR mr.status IN ('going', 'cancelled'))
    ) t
   ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$function$;

-- [manifest 42] public.nearby_games(double precision,double precision,integer,text,integer,integer)
CREATE OR REPLACE FUNCTION public.nearby_games(p_lat double precision, p_lng double precision, p_radius integer DEFAULT 10000, p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS TABLE(id uuid, sport text, title text, start_at timestamp with time zone, geo_location_id uuid, area_id uuid, lat double precision, lng double precision, district text, city text, capacity integer, slots_available integer, distance_m double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    g.id, g.sport, g.title, g.start_at,
    g.geo_location_id, g.area_id,
    ST_Y(gl.location::geometry) AS lat,
    ST_X(gl.location::geometry) AS lng,
    a.district, a.city,
    g.capacity,
    (g.capacity - COALESCE((
      SELECT COUNT(*)::integer FROM public.game_roster gr
      WHERE gr.game_id = g.id AND gr.status = 'confirmed'
    ), 0)) AS slots_available,
    ST_Distance(
      ST_MakePoint(p_lng, p_lat)::geography,
      gl.location
    ) AS distance_m
  FROM public.kan714_games_read g
  JOIN public.geo_locations gl ON gl.id = g.geo_location_id
  JOIN public.areas a ON a.id = g.area_id
  WHERE g.is_cancelled = false
    AND g.start_at > now()
    AND ST_DWithin(gl.location, ST_MakePoint(p_lng, p_lat)::geography, p_radius)
    AND (p_sport IS NULL OR g.sport = p_sport)
  ORDER BY distance_m ASC, g.start_at ASC
  LIMIT p_limit OFFSET p_offset;
$function$;

-- [manifest 43] public.rpc_autocomplete_entities(text,text[],text,integer)
CREATE OR REPLACE FUNCTION public.rpc_autocomplete_entities(p_prefix text, p_scope text[] DEFAULT ARRAY['venues'::text, 'squads'::text, 'games'::text, 'arenas'::text], p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 10)
 RETURNS TABLE(entity_type text, entity_id uuid, title text, subtitle text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me   uuid := auth.uid();
  pref text := public._norm_prefix(p_prefix);
  take int  := greatest(1, p_limit);
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  if pref is null or length(pref) < 2 then
    return;
  end if;

  -- VENUES
  if 'venues' = any(p_scope) then
    return query
    select
      'venue',
      v.id,
      v.name_en,
      coalesce(v.district,'') || 
        case 
          when v.city is not null and v.district is not null then ', '
          else ''
        end ||
        coalesce(v.city,'')
    from public.venues v
    where (p_sport is null or (v.sports is not null and p_sport = any(v.sports)))
      and (
        lower(unaccent_immutable(v.name_en)) like pref || '%' or
        lower(unaccent_immutable(coalesce(v.name_ar, ''))) like pref || '%'
      )
    order by v.created_at desc
    limit take;
  end if;

  -- SQUADS
  if 'squads' = any(p_scope) then
    return query
    select 
      'squad',
      s.id,
      coalesce(s.display_name, s.name),
      '@' || s.name || coalesce(' · ' || s.sport, '')
    from public.squads s
    where (p_sport is null or s.sport = p_sport)
      and (
        lower(unaccent_immutable(s.name)) like pref || '%' or
        lower(unaccent_immutable(coalesce(s.display_name,''))) like pref || '%'
      )
    order by s.created_at desc
    limit take;
  end if;

  -- GAMES (respect visibility)
  if 'games' = any(p_scope) then
    return query
    with g as (
      select g.id, g.title, g.sport, g.start_at
      from public.kan714_games_read g
      where (p_sport is null or g.sport = p_sport)
        and lower(unaccent_immutable(coalesce(g.title,''))) like pref || '%'
        and public.can_view_game(me, g.id)
      order by g.start_at desc
      limit take
    )
    select 
      'game',
      id,
      coalesce(title, initcap(sport) || ' game'),
      to_char(start_at at time zone 'UTC','YYYY-MM-DD HH24:MI UTC')
    from g;
  end if;

  -- ARENAS (if exist)
  if 'arenas' = any(p_scope)
     and exists (select 1 from information_schema.tables where table_schema='public' and table_name='arenas')
  then
    return query
    select
      'arena',
      a.id,
      a.title,
      a.name || coalesce(' · ' || a.sport, '')
    from public.arenas a
    where (p_sport is null or a.sport = p_sport)
      and (
        lower(unaccent_immutable(a.title)) like pref || '%' or
        lower(unaccent_immutable(a.name))  like pref || '%'
      )
    order by a.created_at desc
    limit take;
  end if;

end;
$function$;

-- [manifest 44] public.rpc_booking_cancel(uuid)
CREATE OR REPLACE FUNCTION public.rpc_booking_cancel(p_booking_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b          record;
  vid        uuid;
  owner_user uuid;
BEGIN
  SELECT * INTO b FROM public.venue_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='booking_not_found'; END IF;

  SELECT s.venue_id INTO vid FROM public.venue_spaces s WHERE s.id = b.venue_space_id;

  owner_user := CASE
    WHEN b.source_type = 'game'   THEN (SELECT creator_user_id FROM public.kan714_games_read   WHERE id = b.source_id)
    WHEN b.source_type = 'meetup' THEN (SELECT creator_user_id FROM public.kan714_meetups_read WHERE id = b.source_id)
    ELSE NULL
  END;

  IF NOT (public.is_venue_admin(auth.uid(), vid)
          OR public.is_admin(auth.uid())
          OR owner_user = auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  UPDATE public.venue_bookings SET status = 'cancelled'
  WHERE id = p_booking_id AND status <> 'cancelled';

  RETURN 'ok';
END;
$function$;

-- [manifest 45] public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)
CREATE OR REPLACE FUNCTION public.rpc_booking_hold_for_game_kan712_inner(p_game_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g   record;
  vid uuid;
  bid uuid;
BEGIN
  SELECT * INTO g FROM public.kan714_games_read WHERE id = p_game_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_found'; END IF;

  SELECT s.venue_id INTO vid FROM public.venue_spaces s WHERE s.id = p_space_id;
  IF vid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='space_not_found'; END IF;

  IF NOT (g.creator_user_id = auth.uid()
          OR public.is_venue_admin(auth.uid(), vid)
          OR public.is_admin(auth.uid())) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  INSERT INTO public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  VALUES (p_space_id, p_start, p_end, 'game', p_game_id, 'confirmed', auth.uid())
  RETURNING id INTO bid;

  UPDATE public.games SET venue_space_id = p_space_id WHERE id = p_game_id;

  RETURN bid;
END;
$function$;

-- [manifest 46] public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)
CREATE OR REPLACE FUNCTION public.rpc_booking_hold_for_meetup(p_meetup_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
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
  -- KAN-728: the creator comes from the events parent (pre-image read meetups.owner_user_id, which does not exist).
  select mt.id, e.creator_user_id into m
    from public.kan714_meetups_read mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.creator_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  -- (optional) store human location on meetup side already; no FK change here.
  return bid;
end;
$function$;

-- KAN-887 (CTO ruling dreq-9e4edd4c): rpc_create_game / rpc_create_meetup are the step-25 bodies
-- (20261105120000_kan794_d04_on_live_bodies.sql, post-image md5(prosrc) 5b8883b2 / 0f5ba02e) with only part 2's
-- own delta: the request_id replay lookup reads the overlay instead of public.games / public.meetups.
-- Post-image md5(prosrc) 1b3aa6f2b8033bdf64c5bc856d6c7f43 / f347168e1c1a6b424ebabea41ff3e85f, asserted in section 5.
-- [manifest 49] public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)
CREATE OR REPLACE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; gid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- choose_actor re-asserts the caller owns the acting profile; a replay is only ever served to the creator.
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_game:' || pid::text || ':' || p_request_id::text, 0));
  SELECT g.id INTO gid FROM public.kan714_games_read g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.creator_profile_id = pid AND e.request_id = p_request_id;  -- KAN-823: creator + request_id from events (KAN-772 D04)
  IF FOUND THEN RETURN gid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

-- [manifest 52] public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)
CREATE OR REPLACE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; mid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_meetup:' || pid::text || ':' || p_request_id::text, 0));
  SELECT m.id INTO mid FROM public.kan714_meetups_read m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.creator_profile_id = pid AND e.request_id = p_request_id;  -- KAN-823: creator + request_id from events (KAN-772 D04)
  IF FOUND THEN RETURN mid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

-- [manifest 81] public.rpc_search_entities(text,text[],text,integer)
CREATE OR REPLACE FUNCTION public.rpc_search_entities(p_q text, p_scope text[] DEFAULT ARRAY['people'::text, 'venues'::text, 'squads'::text, 'games'::text, 'arenas'::text], p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 40)
 RETURNS TABLE(entity_type text, entity_id uuid, title text, subtitle text, extra jsonb, rank_score numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  ts tsquery;
  qnorm text;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select t.ts, t.qnorm into ts, qnorm
  from public._normalize_query(p_q) as t;

  -- PEOPLE
  return query
  with src as (
    select pc.profile_id as id, pc.user_id, pc.profile_type, pc.username, pc.display_name,
           pc.sport_key, pc.avatar_url,
           p.search_tsv,
           greatest(coalesce(ts_rank(p.search_tsv, ts),0)::numeric,
                    case when qnorm is not null then
                      greatest(similarity(lower(pc.username), qnorm),
                               similarity(lower(pc.display_name), qnorm))::numeric
                    else 0 end) as text_score,
           case when pc.profile_type='organiser' then 0.10 else 0 end as role_boost,
           case when p_sport is not null and pc.sport_key = p_sport then 0.15 else 0 end as sport_boost,
           public._clamp01(public.potential_vibe_score(me, pc.user_id))*0.25 as vibe_boost
    from public.v_person_card pc
    join public.profiles p on p.id = pc.profile_id
    where ('people' = any(p_scope))
      and (p_sport is null or pc.sport_key = p_sport or pc.profile_type='organiser')
      and (ts is null or p.search_tsv @@ ts
           or (qnorm is not null and (similarity(lower(pc.username), qnorm) > 0.3
                                   or similarity(lower(pc.display_name), qnorm) > 0.3)))
  ),
  vis as (
    select * from src where public.can_view_profile(me, id)
  )
  select
    'person'::text, id,
    coalesce(display_name, username) as title,
    case when profile_type='organiser' then '@'||username||' · organiser'
         else '@'||username||coalesce(' · '||sport_key,'') end as subtitle,
    jsonb_build_object('profile_type',profile_type,'username',username,'sport_key',sport_key,'avatar_url',avatar_url) as extra,
    round(least(1.0, (text_score + role_boost + sport_boost + vibe_boost))::numeric, 6) as rank_score
  from vis
  limit greatest(0, coalesce(p_limit,40));

  -- VENUES (use the view's sports::text[] directly)
  return query
  with src as (
    select v.id, v.name, v.district, v.city, vn.search_tsv, v.sports,
           (coalesce(ts_rank(vn.search_tsv, ts),0))::numeric as text_score
    from public.v_venue_card v
    join public.venues vn on vn.id = v.id
    where ('venues' = any(p_scope))
      and (ts is null or vn.search_tsv @@ ts
           or (qnorm is not null and similarity(lower(v.name), qnorm) > 0.3))
      and (p_sport is null or (v.sports is not null and p_sport = any(v.sports)))
  )
  select
    'venue', id,
    name as title,
    coalesce(district,'') ||
    case when city is not null and district is not null then ', ' else '' end ||
    coalesce(city,'') as subtitle,
    jsonb_build_object('district',district,'city',city) as extra,
    round(least(1.0, text_score)::numeric,6) as rank_score
  from src
  limit greatest(0, coalesce(p_limit,40));

  -- SQUADS
  return query
  with src as (
    select s.id, s.display_name, s.handle, s.sport_key, sq.search_tsv,
           (coalesce(ts_rank(sq.search_tsv, ts),0))::numeric as text_score,
           case when p_sport is not null and s.sport_key = p_sport then 0.15 else 0 end as sport_boost
    from public.v_squad_card s
    join public.squads sq on sq.id = s.id
    where ('squads' = any(p_scope))
      and (ts is null or sq.search_tsv @@ ts
           or (qnorm is not null and (similarity(lower(s.handle), qnorm) > 0.3
                                   or similarity(lower(s.display_name), qnorm) > 0.3)))
      and (p_sport is null or s.sport_key = p_sport)
  )
  select
    'squad', id,
    coalesce(display_name, handle) as title,
    '@'||handle||' · '||coalesce(sport_key,'') as subtitle,
    jsonb_build_object('sport_key',sport_key,'handle',handle) as extra,
    round(least(1.0, (text_score + sport_boost))::numeric,6) as rank_score
  from src
  limit greatest(0, coalesce(p_limit,40));

  -- GAMES
  return query
  with src as (
    select g.id, g.title, g.sport, g.start_at, gm.search_tsv,
           (coalesce(ts_rank(gm.search_tsv, ts),0))::numeric as text_score
    from public.v_game_card g
    join public.kan714_games_read gm on gm.id = g.id
    where ('games' = any(p_scope))
      and (p_sport is null or g.sport = p_sport)
      and (ts is null or gm.search_tsv @@ ts
           or (qnorm is not null and similarity(lower(coalesce(g.title,'')), qnorm) > 0.3))
      and public.can_view_game(me, g.id)
  )
  select
    'game', id,
    coalesce(title, initcap(sport)||' game') as title,
    to_char(start_at at time zone 'UTC','YYYY-MM-DD HH24:MI UTC') as subtitle,
    jsonb_build_object('sport',sport,'start_at',start_at) as extra,
    round(least(1.0, text_score)::numeric,6) as rank_score
  from src
  limit greatest(0, coalesce(p_limit,40));

  -- ARENAS (optional)
  if 'arenas' = any(p_scope) and exists (
       select 1 from information_schema.tables where table_schema='public' and table_name='arenas'
     ) then
    return query
    with src as (
      select a.id, a.title, a.key, a.sport_key, a.search_tsv,
             (coalesce(ts_rank(a.search_tsv, ts),0))::numeric as text_score,
             case when p_sport is not null and a.sport_key = p_sport then 0.15 else 0 end as sport_boost
      from public.arenas a
      where (ts is null or a.search_tsv @@ ts
             or (qnorm is not null and (similarity(lower(a.title), qnorm) > 0.3
                                     or similarity(lower(a.key), qnorm) > 0.3)))
        and (p_sport is null or a.sport_key = p_sport)
    )
    select
      'arena', id,
      title as title,
      key||coalesce(' · '||sport_key,'') as subtitle,
      jsonb_build_object('sport_key',sport_key,'key',key) as extra,
      round(least(1.0, (text_score + sport_boost))::numeric,6) as rank_score
    from src
    limit greatest(0, coalesce(p_limit,40));
  end if;
end;
$function$;

-- [manifest 83] public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)
CREATE OR REPLACE FUNCTION public.rpc_unified_search_sectioned(p_query text, p_sport_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT NULL::double precision, p_limit_per_section integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tsquery tsquery;
  v_q       text;
BEGIN
  IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN jsonb_build_object(
      'profiles','[]'::jsonb,'games','[]'::jsonb,'venues','[]'::jsonb,
      'squads','[]'::jsonb,'posts','[]'::jsonb,'meetups','[]'::jsonb,
      'challenges','[]'::jsonb,'hashtags','[]'::jsonb);
  END IF;
  v_tsquery := plainto_tsquery('simple', unaccent(p_query));
  v_q       := '%' || lower(trim(p_query)) || '%';
  RETURN jsonb_build_object(
    'hashtags', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT h.id, h.tag AS slug, h.display_tag, h.usage_count
        FROM public.hashtags h
        WHERE lower(h.tag) LIKE v_q
          AND (h.is_banned IS NULL OR h.is_banned = false)
          AND (h.is_searchable IS NULL OR h.is_searchable = true)
          AND (h.is_approved IS NULL OR h.is_approved = true)
        ORDER BY h.usage_count DESC NULLS LAST LIMIT p_limit_per_section) t),
    'posts', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'post' AS entity_type, p.id AS entity_id, left(p.body,80) AS title,
          p.author_display_name AS subtitle, NULL::text AS image_url,
          '/post/' || p.id AS route,
          ts_rank(p.search_tsv, v_tsquery)
          + (COALESCE(p.priority_score,0) * 0.01)
          + (SELECT COUNT(*) * 0.05 FROM public.comments pc
             WHERE pc.parent_activity_id = p.id
               AND pc.search_tsv @@ v_tsquery
               AND pc.is_deleted = FALSE AND pc.is_hidden_admin = FALSE) AS score
        FROM public.posts p
        WHERE p.search_tsv @@ v_tsquery AND p.visibility = 'public'
          AND p.is_deleted = FALSE AND p.is_hidden_admin = FALSE AND p.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'profiles', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'profile' AS entity_type, p.user_id AS entity_id, p.id AS profile_id,
          p.display_name AS title, p.username AS subtitle, p.avatar_url AS image_url,
          p.persona_type AS profile_type, p.is_active, '/profile/' || p.username AS route,
          ts_rank(p.search_tsv, v_tsquery) AS score
        FROM public.profiles p WHERE p.search_tsv @@ v_tsquery
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'games', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'game' AS entity_type, e.id AS entity_id, e.title AS title,
          NULL::text AS subtitle, NULL::text AS image_url, '/game/' || e.id AS route,
          ts_rank(e.search_tsv, v_tsquery) + CASE WHEN e.start_at > NOW() THEN 0.2 ELSE 0 END AS score
        FROM public.events e
        JOIN public.kan714_games_read g ON g.event_id = e.id
        WHERE e.event_type = 'game' AND e.search_tsv @@ v_tsquery
          AND e.listing_visibility = 'public' AND e.is_cancelled = FALSE
          AND g.listing_visibility = 'public' AND g.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
    'venues', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'venue' AS entity_type, v.id AS entity_id, v.name_en AS title,
          v.area AS subtitle, NULL::text AS image_url, '/venue/' || v.id AS route,
          ts_rank(v.search_tsv, v_tsquery) + (COALESCE(v.rating,0) * 0.05) AS score
        FROM public.venues v WHERE v.search_tsv @@ v_tsquery AND v.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'squads', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'squad' AS entity_type, s.id AS entity_id, s.name AS title,
          s.city AS subtitle, s.logo_url AS image_url, '/squad/' || s.id AS route,
          ts_rank(s.search_tsv, v_tsquery) AS score
        FROM public.squads s WHERE s.search_tsv @@ v_tsquery AND s.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'meetups', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'meetup' AS entity_type, e.id AS entity_id, e.title AS title,
          m.location_name AS subtitle, NULL::text AS image_url, '/meetup/' || e.id AS route,
          ts_rank(m.search_tsv, v_tsquery) AS score
        FROM public.kan714_meetups_read m
        JOIN public.events e ON e.id = m.event_id
        WHERE e.event_type = 'meetup' AND m.search_tsv @@ v_tsquery
          AND e.listing_visibility = 'public' AND e.is_cancelled = FALSE
          AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
    'challenges', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'challenge' AS entity_type, c.id AS entity_id, c.title AS title,
          c.status AS subtitle, NULL::text AS image_url, '/challenge/' || c.id AS route,
          ts_rank(c.search_tsv, v_tsquery) AS score
        FROM public.challenges c WHERE c.search_tsv @@ v_tsquery AND c.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t)
  );
END;
$function$;

-- [manifest 86] public.settle_game(uuid,boolean)
CREATE OR REPLACE FUNCTION public.settle_game(p_game_id uuid, p_finalize boolean DEFAULT true)
 RETURNS game_settlements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  r record;
  v_organiser_user_id uuid;
  v_sport text;
  v_gross numeric(12,2);
  v_charge_count bigint;
  v_currency_count bigint;
  v_currency text;
  fee_rate numeric(5,2);
  min_fee numeric(12,2);
  max_fee numeric(12,2);
  fee numeric(12,2);
  earnings numeric(12,2);
  gs public.game_settlements;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  -- T-069 Q1: organiser and sport are DERIVED, never accepted. KAN-729 (KAN-714 B10): both are
  -- SHARED facts and are read from the game's events parent — events.creator_user_id is the
  -- authoritative identity (profiles.id is a surrogate and is not an auth uid); the sport text key
  -- is sports.sport_key, reached through events.sport_id (events_game_sport_required holds it
  -- NOT NULL for event_type='game', FK -> sports). games stays the lookup key: p_game_id is a
  -- games.id, games.event_id is NOT NULL + FK-validated (KAN-712), events.id is the PK.
  select e.creator_user_id, s.sport_key
    into v_organiser_user_id, v_sport
  from public.kan714_games_read g
  join public.events e on e.id = g.event_id and e.event_type = 'game'
  join public.sports s on s.id = e.sport_id
  where g.id = p_game_id;

  if not found then
    raise exception using errcode='P0001', message='game_not_found';
  end if;

  if v_organiser_user_id is null then
    -- games_creator_user_id_fkey is ON DELETE SET NULL while the column is declared NOT NULL, so
    -- this is unreachable today. It is checked anyway: settling a game with no organiser would
    -- otherwise credit wallet_ledger.user_id = null.
    raise exception using errcode='P0001', message='organiser_unresolved';
  end if;

  -- Gate, now against the DERIVED organiser. The old body compared auth.uid() to the caller's own
  -- p_organiser_user_id, which is satisfied by any authenticated caller for any game.
  if not (public.is_admin(me) or me = v_organiser_user_id) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  -- T-069 Q2: gross is an aggregate over the game's charges rows. Refunds are compensating rows
  -- with kind='refund' and a negative amount (KAN-171/T-049), so sum(amount) is the NET collected.
  -- charges_purpose_idx (purpose_type, purpose_id) serves this predicate exactly.
  select coalesce(sum(c.amount), 0), count(*), count(distinct c.currency), min(c.currency)
    into v_gross, v_charge_count, v_currency_count, v_currency
  from public.charges c
  where c.purpose_type = 'game'
    and c.purpose_id   = p_game_id
    and c.status       = 'succeeded';

  -- DECISION 2, enforced: detect, never sum across currencies into an AED-named column.
  if v_currency_count > 1 then
    raise exception using errcode='P0001', message='mixed_currency_charges';
  end if;

  if v_currency_count = 1 and v_currency <> 'AED' then
    raise exception using errcode='P0001', message='non_aed_charges';
  end if;

  -- Preserved error code. Refunds can drive the net below zero, and
  -- game_settlements_gross_collected_aed_check requires >= 0.
  if v_gross is null or v_gross < 0 then
    raise exception using errcode='P0001', message='invalid_gross';
  end if;

  -- fetch correct commission rule
  select * into r
  from public.resolve_commission(v_organiser_user_id, v_sport, now());

  fee_rate := coalesce(r.rate, 10.00);
  min_fee  := coalesce(r.min_fee, 0);
  max_fee  := coalesce(r.max_fee, null);

  fee := round(v_gross * (fee_rate/100.0), 2);
  if fee < min_fee then fee := min_fee; end if;
  if max_fee is not null and fee > max_fee then fee := max_fee; end if;

  earnings := round(v_gross - fee, 2);

  -- SITTING 2: min_app_fee_aed can exceed what the game collected. That is a debit, and this
  -- function has no authority to invent one. Raised before the settlement row is written.
  if earnings < 0 then
    raise exception using errcode='P0001', message='fee_exceeds_gross';
  end if;

  insert into public.game_settlements(
      game_id,
      organiser_user_id,
      sport,
      gross_collected_aed,
      app_fee_rate,
      app_fee_aed,
      organiser_earnings_aed,
      status,
      meta
  )
  values (
      p_game_id,
      v_organiser_user_id,
      v_sport,
      v_gross,
      fee_rate,
      fee,
      earnings,
      -- KAN-138: cast added. Both branches are untyped literals, so the bare CASE resolved to
      -- `text`, and there is no text -> settlement_status cast of any kind (pg_cast count 0).
      -- Every call raised 42804 here, before reaching the wallet_ledger credit below.
      (case when p_finalize then 'settled' else 'pending' end)::public.settlement_status,
      -- DECISION 1: the admin/organiser discriminator lives here (game_settlements has no column
      -- for it; `meta` IS on the row, satisfying T-069 without widening a money table).
      jsonb_build_object(
        'resolved_at',        now(),
        'settled_by',         me,
        'settled_via',        case when me = v_organiser_user_id then 'organiser' else 'admin' end,
        'gross_source',       'charges',
        'gross_charge_count', v_charge_count,
        'gross_currency',     coalesce(v_currency, 'AED')
      )
  )
  on conflict (game_id) do update
    set gross_collected_aed   = excluded.gross_collected_aed,
        app_fee_rate          = excluded.app_fee_rate,
        app_fee_aed           = excluded.app_fee_aed,
        organiser_earnings_aed = excluded.organiser_earnings_aed,
        status                 = excluded.status,
        meta                   = excluded.meta,
        settled_at             = case when excluded.status='settled' then now() else null end
  returning * into gs;

  -- finalize -> post wallet credit
  -- SITTING 2: `earnings > 0` guard. wallet_ledger_amount_aed_check is `amount_aed > 0`, so a
  -- zero-earnings settlement must post no credit rather than abort the settlement.
  if p_finalize and gs.organiser_earnings_aed > 0 then
    -- KAN-128: a re-settle returns the same gs.id from the upsert above, so before this clause a
    -- second finalize posted a second identical credit for ('game_settlement', gs.id, 'credit').
    -- Now it is absorbed.
    insert into public.wallet_ledger(
      user_id,
      direction,
      amount_aed,
      status,
      ref_type,
      ref_id,
      memo,
      meta
    )
    values (
      v_organiser_user_id,
      'credit',
      gs.organiser_earnings_aed,
      'posted',
      'game_settlement',
      gs.id,
      'Game settlement earnings',
      jsonb_build_object(
        'game_id', gs.game_id,
        'sport', gs.sport
      )
    )
    on conflict do nothing;
  end if;

  return gs;
end;
$function$;

-- [manifest 87] public.trg_game_join_request_notify()
CREATE OR REPLACE FUNCTION public.trg_game_join_request_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid;
BEGIN
  SELECT creator_user_id INTO v_host_uid FROM public.kan714_games_read WHERE id = NEW.game_id;
  IF v_host_uid IS NULL OR v_host_uid = NEW.from_user_id THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(v_host_uid, 'game.join_request', 'game', NEW.game_id, NEW.from_user_id);
  RETURN NEW;
END;
$function$;

-- [manifest 88] public.trg_game_waitlist_promoted_notify()
CREATE OR REPLACE FUNCTION public.trg_game_waitlist_promoted_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid; v_in_roster boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM public.game_roster WHERE game_id = OLD.game_id AND user_id = OLD.user_id) INTO v_in_roster;
  IF NOT v_in_roster THEN RETURN OLD; END IF;
  SELECT creator_user_id INTO v_host_uid FROM public.kan714_games_read WHERE id = OLD.game_id;
  PERFORM public.process_notification_event(OLD.user_id, 'game.waitlist_promoted', 'game', OLD.game_id, COALESCE(v_host_uid, OLD.user_id));
  RETURN OLD;
END;
$function$;

-- [manifest 89] public.trg_meetup_rsvps_notify()
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
    FROM public.kan714_meetups_read m
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

-- ---------------------------------------------------------------------------------------------------------
-- 5. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text; n int;
BEGIN
  -- Repointed functions: owner, ACL, SECURITY DEFINER, search_path, volatility unchanged; body changed and
  -- reads an overlay or a twin.
  FOR r IN SELECT pi.*, p.proacl::text AS acl_now, pg_get_userbyid(p.proowner) AS own_now, p.prosecdef AS sd_now,
                  p.proconfig AS cfg_now, p.provolatile AS vol_now, pg_get_functiondef(p.oid) AS def_now
             FROM public.kan714_preimage_2 pi JOIN pg_proc p ON p.oid = pi.object::regprocedure
            WHERE pi.kind = 'function'
  LOOP
    IF r.acl IS DISTINCT FROM r.acl_now OR r.owner <> r.own_now OR r.secdef IS DISTINCT FROM r.sd_now
       OR r.config IS DISTINCT FROM r.cfg_now OR r.volatility IS DISTINCT FROM r.vol_now THEN
      RAISE EXCEPTION 'KAN-714/2 post: % attributes changed (acl % -> %, owner % -> %, secdef % -> %, config % -> %, vol % -> %)',
        r.object, r.acl, r.acl_now, r.owner, r.own_now, r.secdef, r.sd_now, r.config, r.cfg_now, r.volatility, r.vol_now;
    END IF;
    IF r.definition = r.def_now THEN
      RAISE EXCEPTION 'KAN-714/2 post: % was not repointed', r.object;
    END IF;
    IF r.def_now !~ 'public\.kan714_(games_read|meetups_read|game_slots_left|meetup_slots_left|user_hosted_game)' THEN
      RAISE EXCEPTION 'KAN-714/2 post: % reads no overlay or twin', r.object;
    END IF;
  END LOOP;

  -- Overlays: same column names, order and types as the legacy table; depend on public.events; no API grant;
  -- owner bypasses RLS; not security_invoker (they must run as the owner).
  FOR r IN SELECT * FROM (VALUES ('kan714_games_read', 'games'), ('kan714_meetups_read', 'meetups')) AS t(vw, tbl)
  LOOP
    IF (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = ('public.' || r.vw)::regclass AND a.attnum > 0 AND NOT a.attisdropped)
       IS DISTINCT FROM
       (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attnum > 0 AND NOT a.attisdropped) THEN
      RAISE EXCEPTION 'KAN-714/2 post: public.% shape differs from public.%', r.vw, r.tbl;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_rewrite rw JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid
                    WHERE rw.ev_class = ('public.' || r.vw)::regclass AND d.refobjid = 'public.events'::regclass) THEN
      RAISE EXCEPTION 'KAN-714/2 post: public.% does not depend on public.events', r.vw;
    END IF;
    IF has_table_privilege('anon', 'public.' || r.vw, 'SELECT') OR has_table_privilege('authenticated', 'public.' || r.vw, 'SELECT')
       OR has_table_privilege('service_role', 'public.' || r.vw, 'SELECT')
       OR (SELECT relacl::text FROM pg_class WHERE oid = ('public.' || r.vw)::regclass) ~ '(^|[{,])(=|anon=|authenticated=|service_role=)' THEN
      RAISE EXCEPTION 'KAN-714/2 post: public.% reachable by an API role', r.vw;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_roles o ON o.oid = c.relowner
                    WHERE c.oid = ('public.' || r.vw)::regclass AND (o.rolsuper OR o.rolbypassrls))
       OR EXISTS (SELECT 1 FROM pg_class c WHERE c.oid = ('public.' || r.vw)::regclass
                     AND c.reloptions::text ~ 'security_invoker=(true|on|1)') THEN
      RAISE EXCEPTION 'KAN-714/2 post: public.% owner/security_invoker wrong', r.vw;
    END IF;
  END LOOP;

  -- Twins: SECURITY INVOKER, search_path '', no EXECUTE for PUBLIC/anon/authenticated/service_role (asserted on
  -- proacl itself, not on the REVOKE having run).
  FOR r IN SELECT p.oid::regprocedure::text AS f, p.prosecdef, p.proconfig, p.proacl::text AS acl FROM pg_proc p
            WHERE p.oid IN ('public.kan714_game_slots_left(uuid)'::regprocedure, 'public.kan714_meetup_slots_left(uuid)'::regprocedure,
                            'public.kan714_user_hosted_game(uuid,uuid)'::regprocedure)
  LOOP
    IF r.prosecdef OR r.proconfig IS DISTINCT FROM ARRAY['search_path=""'] THEN
      RAISE EXCEPTION 'KAN-714/2 post: twin % attributes wrong (secdef %, config %)', r.f, r.prosecdef, r.proconfig;
    END IF;
    IF r.acl IS NULL OR r.acl ~ '(^|[{,])(=|anon=|authenticated=|service_role=)'
       OR has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE')
       OR has_function_privilege('service_role', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-714/2 post: twin % executable by an API role (acl %)', r.f, r.acl;
    END IF;
  END LOOP;

  -- events still closed to the API, ACL byte-identical to before.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR (SELECT relacl::text FROM pg_class WHERE oid = 'public.events'::regclass)
        IS DISTINCT FROM (SELECT acl FROM pg_temp.kan714_2_events_acl) THEN
    RAISE EXCEPTION 'KAN-714/2 post: public.events ACL/policies changed';
  END IF;

  -- Pre-image table closed; complete.
  IF has_table_privilege('anon', 'public.kan714_preimage_2', 'SELECT')
     OR has_table_privilege('authenticated', 'public.kan714_preimage_2', 'SELECT')
     OR has_table_privilege('service_role', 'public.kan714_preimage_2', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-714/2 post: kan714_preimage_2 readable by an API role';
  END IF;
  -- KAN-887: the two rpc_create_* post-images (step-25 body + the overlay read only).
  SELECT string_agg(t.f || ' (' || coalesce(md5(p.prosrc), 'absent') || ')', '; ') INTO v
    FROM (VALUES
      ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)', '1b3aa6f2b8033bdf64c5bc856d6c7f43'),
      ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)', 'f347168e1c1a6b424ebabea41ff3e85f')) AS t(f, h)
    LEFT JOIN pg_proc p ON p.oid = to_regprocedure(t.f)
   WHERE p.oid IS NULL OR md5(p.prosrc) <> t.h;
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-714/2 post: rpc_create_* body is not the reviewed post-image: %', v;
  END IF;

  SELECT count(*) INTO n FROM public.kan714_preimage_2;
  IF n <> 22 + 5 THEN
    RAISE EXCEPTION 'KAN-714/2 post: kan714_preimage_2 has % rows, expected %', n, 22 + 5;
  END IF;
END
$post$;

COMMIT;
