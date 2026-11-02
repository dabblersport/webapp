-- KAN-712 (Events P2), stage 1 of 2: the events write contract. INERT on its own.
--
-- STATUS: authored, NOT applied to any Supabase project. Executed on a local throwaway PG 16 only
-- (supabase/tests/events_p2/KAN712_CONTRACT.md, "Local verification").
--
-- This migration only creates functions and one bookkeeping table. It attaches NO trigger and
-- wraps NO RPC: KAN-711's legacy -> events mirror stays authoritative until stage 2
-- (20261103110000_kan712_cutover.sql) switches direction in one transaction.
--
-- What it creates (every function: SET search_path = '', EXECUTE revoked from PUBLIC, anon,
-- authenticated and service_role, except kan712_update_event_shared, which service_role keeps):
--   kan712_legacy_guard()          BEFORE INSERT OR UPDATE on games / meetups (attached in stage 2).
--                                  INSERT: writes the events parent FIRST, then lets the subtype row
--                                  in (same statement, so a failure leaves neither). UPDATE: routes the
--                                  shared values to events under the events-first lock, or refuses a
--                                  direct shared-field write from a non-contract role.
--   kan712_legacy_after_delete()   AFTER DELETE on games / meetups: removes the parent (replaces the
--                                  KAN-711 mirror's DELETE branch).
--   kan712_events_compat_mirror()  AFTER UPDATE on events: copies an events-originated change down to
--                                  the legacy compatibility columns (events -> legacy, one direction).
--   kan712_update_event_shared()   the admin/ops write contract: lock events, patch whitelisted shared
--                                  fields, the compat mirror carries it to legacy.
--   kan712_wrap_rpc() / kan712_unwrap_rpc() + table kan712_wrapped_rpcs: generate, from the LIVE
--                                  catalogue at apply time, a same-signature wrapper around an
--                                  existing RPC that takes the events row lock first. No RPC body is
--                                  copied from a migration file (T-058).
--
-- Loop analysis (no uncontrolled bidirectional sync):
--   legacy write  -> guard updates events with kan712.routing = <id>  -> compat mirror skips <id>.
--   events write  -> compat mirror updates legacy with kan712.compat = <id> -> guard copies the
--                    events values onto NEW and writes NOTHING to events.
--   legacy delete -> after_delete deletes events -> FK cascade finds no legacy row (already gone).
--   events delete -> FK cascade deletes legacy -> after_delete matches 0 events rows.
--
-- GUCs used (all transaction-local via set_config(..., true), rolled back with a failed statement):
--   kan712.contract  'on' while a wrapped RPC runs (function-level SET clause, auto-restored).
--   kan712.routing   '<uuid>' while the guard writes that events row (compat mirror skips it).
--   kan712.compat    '<uuid>' while the compat mirror writes that legacy row (guard copies down).
--   kan711.src_updated_at  KAN-711's keeper value: the parent keeps the legacy updated_at exactly.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-712: applying role % must be superuser or BYPASSRLS (meetups and events are FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL
     OR to_regprocedure('public.kan711_events_keep_updated_at()') IS NULL
     OR to_regclass('public.kan711_events_parity') IS NULL THEN
    RAISE EXCEPTION 'KAN-712: KAN-710 (20261101140000) and KAN-711 (20261102110000, 20261102120000) must be applied first';
  END IF;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-712: stage 1 already applied';
  END IF;
END $$;

-- 1. Bookkeeping for generated wrappers. New table; RLS on, no grants to any API role. ------------
CREATE TABLE public.kan712_wrapped_rpcs (
    name            text        NOT NULL,          -- public function name (wrapper keeps it)
    identity_args   text        NOT NULL,          -- pg_get_function_identity_arguments of the original
    inner_name      text        NOT NULL,          -- <name>_kan712_inner (the renamed original)
    original_acl    aclitem[],                     -- proacl before wrapping (NULL = default ACL)
    original_owner  oid         NOT NULL,
    lock_spec       text        NOT NULL,
    wrapped_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (name, identity_args)
);
ALTER TABLE public.kan712_wrapped_rpcs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.kan712_wrapped_rpcs FROM PUBLIC, anon, authenticated, service_role;

-- 2. The legacy guard. SECURITY INVOKER on purpose: current_user is then the role of the statement
-- that wrote the legacy row (postgres inside every SECURITY DEFINER RPC body; service_role for a
-- direct REST write), which is how a direct write is told apart from a contract write. Trigger
-- functions need no EXECUTE grant to fire. The mapping is inlined (KAN-711's map functions are not
-- executable by API roles) and is column-for-column KAN-711's kan711_events_map_game/_meetup.
CREATE FUNCTION public.kan712_legacy_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_type     text := CASE TG_TABLE_NAME WHEN 'games' THEN 'game' WHEN 'meetups' THEN 'meetup' END;
  v_contract boolean := coalesce(current_setting('kan712.contract', true), '') = 'on';
  v_trusted  boolean := current_user IN ('postgres', 'supabase_admin');
  m          public.events;
  e          public.events;
  v_shared   boolean;
  v_con      text;
BEGIN
  IF v_type IS NULL OR TG_WHEN <> 'BEFORE' OR TG_LEVEL <> 'ROW' THEN
    RAISE EXCEPTION 'kan712_legacy_guard: unsupported attachment %.% % %', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_WHEN, TG_LEVEL;
  END IF;

  -- 2a. Compat write (events -> legacy): events is authoritative; copy its values onto NEW, including
  -- updated_at (legacy touch triggers set now()). Nothing is written to events here. Honoured only when
  -- nested inside the compat mirror (trigger depth > 1): a session-level SET kan712.compat is ignored.
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('%s %s', TG_TABLE_NAME, NEW.id);
    END IF;
    NEW.creator_profile_id := e.creator_profile_id; NEW.creator_user_id := e.creator_user_id;
    NEW.title := e.title; NEW.start_at := e.start_at; NEW.end_at := e.end_at; NEW.capacity := e.capacity;
    NEW.listing_visibility := e.listing_visibility; NEW.is_cancelled := e.is_cancelled;
    NEW.sport_id := e.sport_id; NEW.area_id := e.area_id; NEW.geo_location_id := e.geo_location_id;
    NEW.venue_id := e.venue_id; NEW.min_skill := e.min_skill; NEW.max_skill := e.max_skill;
    NEW.joining_rule := e.joining_rule; NEW.cost_cover := e.cost_cover; NEW.request_id := e.request_id;
    NEW.created_at := e.created_at; NEW.updated_at := e.updated_at;
    IF v_type = 'game' THEN
      NEW.join_policy := e.join_policy; NEW.cancelled_at := e.cancelled_at; NEW.cancelled_reason := e.cancelled_reason;
    ELSE
      NEW.rsvp_policy := e.join_policy;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan712_id_immutable';
  END IF;
  IF NEW.event_id IS NULL THEN
    NEW.event_id := NEW.id;                -- KAN-711's assign trigger normally did this already
  END IF;

  -- 2b. Map NEW (final legacy values: this trigger sorts last among BEFORE triggers).
  m.id := NEW.id; m.event_type := v_type;
  m.creator_profile_id := NEW.creator_profile_id; m.creator_user_id := NEW.creator_user_id;
  m.title := NEW.title; m.start_at := NEW.start_at; m.end_at := NEW.end_at; m.capacity := NEW.capacity;
  m.listing_visibility := NEW.listing_visibility; m.is_cancelled := NEW.is_cancelled;
  m.sport_id := NEW.sport_id; m.area_id := NEW.area_id; m.geo_location_id := NEW.geo_location_id;
  m.venue_id := NEW.venue_id; m.min_skill := NEW.min_skill::smallint; m.max_skill := NEW.max_skill::smallint;
  m.joining_rule := NEW.joining_rule; m.cost_cover := NEW.cost_cover; m.request_id := NEW.request_id;
  m.created_at := NEW.created_at; m.updated_at := NEW.updated_at;
  IF v_type = 'game' THEN
    m.join_policy := NEW.join_policy; m.cancelled_at := NEW.cancelled_at; m.cancelled_reason := NEW.cancelled_reason;
  ELSE
    m.join_policy := NEW.rsvp_policy; m.cancelled_at := NULL; m.cancelled_reason := NULL;
  END IF;

  -- 2c. INSERT: parent first. A unique_violation on the parent's request key is re-raised under the
  -- legacy key name, so the KAN-611 create wrappers (which only catch
  -- <table>_creator_user_request_id_key) keep their replay semantics. Same creator profile implies
  -- the same creator user, so the legacy key would have collided too.
  IF TG_OP = 'INSERT' THEN
    BEGIN
      INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
             capacity, listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id,
             area_id, geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id,
             created_at, updated_at)
      VALUES (m.id, m.event_type, m.creator_profile_id, m.creator_user_id, m.title, m.start_at, m.end_at,
             m.capacity, m.listing_visibility, m.join_policy, m.is_cancelled, m.cancelled_at, m.cancelled_reason,
             m.sport_id, m.area_id, m.geo_location_id, m.venue_id, m.min_skill, m.max_skill, m.joining_rule,
             m.cost_cover, m.request_id, m.created_at, m.updated_at);
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      IF v_con = 'events_type_creator_request_id_key' THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
          CONSTRAINT = TG_TABLE_NAME || '_creator_user_request_id_key',
          MESSAGE = format('duplicate key value violates unique constraint "%s_creator_user_request_id_key"', TG_TABLE_NAME),
          DETAIL = format('kan712: events parent for request_id %s already exists', m.request_id);
      END IF;
      RAISE;
    END;
    RETURN NEW;
  END IF;

  -- 2d. UPDATE from a legacy write. Lock the parent: a wrapped RPC already holds it (events first),
  -- so the wait is a no-op; any other writer already holds the legacy row and must not wait on
  -- events (that is the deadlock shape), so it fails fast with 55P03 instead.
  IF v_contract THEN
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type FOR UPDATE;
  ELSE
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type FOR UPDATE NOWAIT;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('%s %s', TG_TABLE_NAME, NEW.id);
  END IF;

  v_shared := ROW(m.creator_profile_id, m.creator_user_id, m.title, m.start_at, m.end_at, m.capacity,
                  m.listing_visibility, m.join_policy, m.is_cancelled, m.cancelled_at, m.cancelled_reason,
                  m.sport_id, m.area_id, m.geo_location_id, m.venue_id, m.min_skill, m.max_skill,
                  m.joining_rule, m.cost_cover, m.request_id, m.created_at)
              IS DISTINCT FROM
              ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
                  e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
                  e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
                  e.joining_rule, e.cost_cover, e.request_id, e.created_at);

  IF v_shared AND NOT v_contract AND NOT v_trusted THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'kan712_direct_shared_write_refused',
      DETAIL = format('%s %s: shared fields are owned by public.events since KAN-712 (role %s)', TG_TABLE_NAME, NEW.id, current_user),
      HINT = 'Use the owning RPC, or public.kan712_update_event_shared(event_id, patch).';
  END IF;

  IF v_shared OR m.updated_at IS DISTINCT FROM e.updated_at THEN
    PERFORM set_config('kan712.routing', NEW.id::text, true);
    PERFORM set_config('kan711.src_updated_at', m.updated_at::text, true);   -- KAN-711 keeper semantics
    UPDATE public.events SET
      creator_profile_id = m.creator_profile_id, creator_user_id = m.creator_user_id, title = m.title,
      start_at = m.start_at, end_at = m.end_at, capacity = m.capacity, listing_visibility = m.listing_visibility,
      join_policy = m.join_policy, is_cancelled = m.is_cancelled, cancelled_at = m.cancelled_at,
      cancelled_reason = m.cancelled_reason, sport_id = m.sport_id, area_id = m.area_id,
      geo_location_id = m.geo_location_id, venue_id = m.venue_id, min_skill = m.min_skill,
      max_skill = m.max_skill, joining_rule = m.joining_rule, cost_cover = m.cost_cover,
      request_id = m.request_id, created_at = m.created_at, updated_at = m.updated_at
    WHERE id = NEW.id;
    PERFORM set_config('kan711.src_updated_at', '', true);
    PERFORM set_config('kan712.routing', '', true);
  END IF;
  RETURN NEW;
END $$;

-- 3. AFTER DELETE on games / meetups: remove the parent. SECURITY DEFINER: the deleting role may have
-- no privilege on events (admin_cleanup_user_data runs as its owner anyway).
CREATE FUNCTION public.kan712_legacy_after_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_TABLE_NAME = 'games' THEN
    DELETE FROM public.events WHERE id = OLD.id AND event_type = 'game';
  ELSIF TG_TABLE_NAME = 'meetups' THEN
    DELETE FROM public.events WHERE id = OLD.id AND event_type = 'meetup';
  ELSE
    RAISE EXCEPTION 'kan712_legacy_after_delete: unsupported table %', TG_TABLE_NAME;
  END IF;
  RETURN OLD;
END $$;

-- 4. AFTER UPDATE on events: events -> legacy compatibility mirror. Skips the row the guard is
-- routing (that write came FROM legacy). Writes only when a mirrored value differs, so legacy
-- side-effect triggers (activity sync, cancel notifications, system lines, outbox) fire exactly once,
-- from this one legacy UPDATE. SECURITY DEFINER: legacy tables are FORCE RLS / grant-restricted.
CREATE FUNCTION public.kan712_events_compat_mirror()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Skip only the row the guard is routing right now. The guard is a trigger, so its events UPDATE fires
  -- this one at depth > 1; a session-level SET kan712.routing followed by a direct events write runs
  -- at depth 1 and is mirrored normally (no spoofed divergence).
  IF pg_trigger_depth() > 1 AND coalesce(current_setting('kan712.routing', true), '') = NEW.id::text THEN
    RETURN NULL;
  END IF;
  PERFORM set_config('kan712.compat', NEW.id::text, true);
  IF NEW.event_type = 'game' THEN
    UPDATE public.games g SET
      creator_profile_id = NEW.creator_profile_id, creator_user_id = NEW.creator_user_id, title = NEW.title,
      start_at = NEW.start_at, end_at = NEW.end_at, capacity = NEW.capacity,
      listing_visibility = NEW.listing_visibility, join_policy = NEW.join_policy,
      is_cancelled = NEW.is_cancelled, cancelled_at = NEW.cancelled_at, cancelled_reason = NEW.cancelled_reason,
      sport_id = NEW.sport_id, area_id = NEW.area_id, geo_location_id = NEW.geo_location_id,
      venue_id = NEW.venue_id, min_skill = NEW.min_skill, max_skill = NEW.max_skill,
      joining_rule = NEW.joining_rule, cost_cover = NEW.cost_cover, request_id = NEW.request_id,
      created_at = NEW.created_at, updated_at = NEW.updated_at
    WHERE g.id = NEW.id
      AND ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
              g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
              g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill, g.max_skill,
              g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
          IS DISTINCT FROM
          ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
              NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled, NEW.cancelled_at, NEW.cancelled_reason,
              NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer,
              NEW.max_skill::integer, NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at,
              NEW.updated_at);
  ELSE
    UPDATE public.meetups mt SET
      creator_profile_id = NEW.creator_profile_id, creator_user_id = NEW.creator_user_id, title = NEW.title,
      start_at = NEW.start_at, end_at = NEW.end_at, capacity = NEW.capacity,
      listing_visibility = NEW.listing_visibility, rsvp_policy = NEW.join_policy,
      is_cancelled = NEW.is_cancelled,
      sport_id = NEW.sport_id, area_id = NEW.area_id, geo_location_id = NEW.geo_location_id,
      venue_id = NEW.venue_id, min_skill = NEW.min_skill, max_skill = NEW.max_skill,
      joining_rule = NEW.joining_rule, cost_cover = NEW.cost_cover, request_id = NEW.request_id,
      created_at = NEW.created_at, updated_at = NEW.updated_at
    WHERE mt.id = NEW.id
      AND ROW(mt.creator_profile_id, mt.creator_user_id, mt.title, mt.start_at, mt.end_at, mt.capacity,
              mt.listing_visibility, mt.rsvp_policy, mt.is_cancelled,
              mt.sport_id, mt.area_id, mt.geo_location_id, mt.venue_id, mt.min_skill, mt.max_skill,
              mt.joining_rule, mt.cost_cover, mt.request_id, mt.created_at, mt.updated_at)
          IS DISTINCT FROM
          ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
              NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled,
              NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer,
              NEW.max_skill::integer, NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at,
              NEW.updated_at);
  END IF;
  PERFORM set_config('kan712.compat', '', true);
  RETURN NULL;
END $$;

-- 5. Admin / ops write contract. Events first (row lock), then the compat mirror writes the subtype.
-- Whitelisted shared keys only; identity, creator, request_id and timestamps are not patchable.
-- No persona/host/fee rule is evaluated here: this is the service_role ops path, not a client RPC.
CREATE FUNCTION public.kan712_update_event_shared(p_event_id uuid, p_patch jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_allowed constant text[] := ARRAY['title', 'start_at', 'end_at', 'capacity', 'listing_visibility',
    'join_policy', 'is_cancelled', 'cancelled_at', 'cancelled_reason', 'sport_id', 'area_id',
    'geo_location_id', 'venue_id', 'min_skill', 'max_skill', 'joining_rule', 'cost_cover'];
  v_bad text[];
  e public.events;
  n public.events;
BEGIN
  -- Fail closed unless the cutover is live: without the compat mirror an events-only write would leave
  -- the legacy row behind (stage 1 before cutover, or after rollback_kan712.sql keeps stage 1).
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                  WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
    RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'kan712_not_cut_over',
      DETAIL = 'public.events has no enabled trg_zz_kan712_events_compat_mirror; the ops path is closed.';
  END IF;
  IF p_event_id IS NULL OR p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'kan712_patch_invalid';
  END IF;
  SELECT array_agg(k ORDER BY k) INTO v_bad FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'kan712_patch_key_not_allowed', DETAIL = array_to_string(v_bad, ',');
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'kan712_event_not_found';
  END IF;
  n := jsonb_populate_record(e, p_patch);
  UPDATE public.events SET
    title = n.title, start_at = n.start_at, end_at = n.end_at, capacity = n.capacity,
    listing_visibility = n.listing_visibility, join_policy = n.join_policy, is_cancelled = n.is_cancelled,
    cancelled_at = n.cancelled_at, cancelled_reason = n.cancelled_reason, sport_id = n.sport_id,
    area_id = n.area_id, geo_location_id = n.geo_location_id, venue_id = n.venue_id,
    min_skill = n.min_skill, max_skill = n.max_skill, joining_rule = n.joining_rule, cost_cover = n.cost_cover
  WHERE id = p_event_id
  RETURNING * INTO e;
  RETURN to_jsonb(e) - 'search_tsv';
END $$;

-- 6. Wrapper generator. Reads the LIVE function from pg_proc, renames it to <name>_kan712_inner,
-- creates a same-name/same-arguments/same-result wrapper that takes the events row lock(s) first and
-- runs with kan712.contract = 'on', then re-grants exactly the original ACL and owner and strips
-- every API grant from the inner. p_lock: 'game:<param>' | 'meetup:<param>' | 'series:<param>' | 'none'.
CREATE FUNCTION public.kan712_wrap_rpc(p_target regprocedure, p_lock text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  p          record;
  v_inner    text;
  v_call     text;
  v_pos      int;
  v_lockstmt text;
  v_body     text;
  v_kind     text := split_part(p_lock, ':', 1);
  v_param    text := split_part(p_lock, ':', 2);
  a          record;
  v_vol      text;
BEGIN
  SELECT pr.oid, pr.proname, pr.pronargs, pr.proargnames, pr.proargmodes, pr.proretset, pr.prokind,
         pr.provariadic, pr.prorettype, pr.proisstrict, pr.provolatile, pr.proacl, pr.proowner,
         pg_catalog.pg_get_function_arguments(pr.oid) AS args,
         pg_catalog.pg_get_function_identity_arguments(pr.oid) AS idargs,
         pg_catalog.pg_get_function_result(pr.oid) AS res
    INTO p
    FROM pg_catalog.pg_proc pr
   WHERE pr.oid = p_target AND pr.pronamespace = 'public'::regnamespace;
  IF NOT FOUND THEN RAISE EXCEPTION 'kan712_wrap_rpc: % is not a public function', p_target; END IF;
  IF p.proname LIKE '%\_kan712\_inner' OR EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs w
                                                    WHERE w.name = p.proname AND w.identity_args = p.idargs) THEN
    RAISE EXCEPTION 'kan712_wrap_rpc: % is already wrapped', p_target;
  END IF;
  IF p.prokind <> 'f' OR p.proretset OR p.provariadic <> 0
     OR (p.proargmodes IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(p.proargmodes) md WHERE md <> 'i')) THEN
    RAISE EXCEPTION 'kan712_wrap_rpc: % has an unsupported shape (set/OUT/variadic/procedure)', p_target;
  END IF;
  -- A SECURITY DEFINER wrapper around an INVOKER body would run that body as the owner instead of
  -- the caller (privilege change). Every KAN-712 target is DEFINER today; refuse anything else.
  IF NOT (SELECT prosecdef FROM pg_catalog.pg_proc WHERE oid = p.oid) THEN
    RAISE EXCEPTION 'kan712_wrap_rpc: % is SECURITY INVOKER; wrapping would change its privileges', p_target;
  END IF;
  IF length(p.proname || '_kan712_inner') > 63 THEN
    RAISE EXCEPTION 'kan712_wrap_rpc: inner name for % exceeds 63 bytes', p_target;
  END IF;
  v_inner := p.proname || '_kan712_inner';
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc x WHERE x.pronamespace = 'public'::regnamespace AND x.proname = v_inner
              AND pg_catalog.pg_get_function_identity_arguments(x.oid) = p.idargs) THEN
    RAISE EXCEPTION 'kan712_wrap_rpc: % already exists', v_inner;
  END IF;

  SELECT string_agg(format('$%s', i), ', ' ORDER BY i) INTO v_call FROM generate_series(1, p.pronargs) i;
  v_call := coalesce(v_call, '');

  IF v_kind = 'none' THEN
    v_lockstmt := '';
  ELSIF v_kind IN ('game', 'meetup', 'series') THEN
    SELECT o INTO v_pos FROM unnest(p.proargnames) WITH ORDINALITY u(n, o) WHERE u.n = v_param;
    IF v_pos IS NULL THEN RAISE EXCEPTION 'kan712_wrap_rpc: % has no parameter %', p_target, v_param; END IF;
    IF v_kind = 'series' THEN
      v_lockstmt := format(
        'IF $%1$s IS NOT NULL THEN PERFORM 1 FROM public.events e WHERE e.event_type = %2$L AND e.id IN '
        '(SELECT g.id FROM public.games g WHERE g.series_id = $%1$s) ORDER BY e.id FOR UPDATE OF e; END IF;',
        v_pos, 'game');
    ELSE
      v_lockstmt := format('PERFORM 1 FROM public.events e WHERE e.id = $%s AND e.event_type = %L FOR UPDATE;',
                           v_pos, v_kind);
    END IF;
  ELSE
    RAISE EXCEPTION 'kan712_wrap_rpc: bad lock spec %', p_lock;
  END IF;

  IF p.prorettype = 'pg_catalog.void'::regtype THEN
    v_body := format(E'BEGIN\n  %s\n  PERFORM public.%I(%s);\nEND', v_lockstmt, v_inner, v_call);
  ELSE
    v_body := format(E'BEGIN\n  %s\n  RETURN public.%I(%s);\nEND', v_lockstmt, v_inner, v_call);
  END IF;
  v_vol := CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' ELSE 'VOLATILE' END;

  INSERT INTO public.kan712_wrapped_rpcs (name, identity_args, inner_name, original_acl, original_owner, lock_spec)
  VALUES (p.proname, p.idargs, v_inner, p.proacl, p.proowner, p_lock);

  EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', p.proname, p.idargs, v_inner);
  EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated, service_role', v_inner, p.idargs);
  FOR a IN SELECT DISTINCT x.grantee FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
            WHERE x.grantee <> 0 AND x.grantee <> p.proowner LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM %I', v_inner, p.idargs, a.grantee::regrole::text);
  END LOOP;

  EXECUTE format('CREATE FUNCTION public.%I(%s) RETURNS %s LANGUAGE plpgsql %s %s SECURITY DEFINER'
                 ' SET search_path = '''' SET kan712.contract = ''on'' AS %L',
                 p.proname, p.args, p.res, v_vol, CASE WHEN p.proisstrict THEN 'STRICT' ELSE '' END, v_body);
  EXECUTE format('ALTER FUNCTION public.%I(%s) OWNER TO %I', p.proname, p.idargs, p.proowner::regrole::text);
  EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated, service_role', p.proname, p.idargs);
  FOR a IN SELECT x.grantee, x.privilege_type, x.is_grantable
             FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
            WHERE x.grantee <> p.proowner LOOP
    EXECUTE format('GRANT %s ON FUNCTION public.%I(%s) TO %s%s', a.privilege_type, p.proname, p.idargs,
                   CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(a.grantee::regrole::text) END,
                   CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
  END LOOP;
END $$;

-- 7. Inverse of kan712_wrap_rpc, used by rollback_kan712.sql. Drops the wrapper, renames the inner
-- back, restores the recorded ACL and owner, forgets the record.
CREATE FUNCTION public.kan712_unwrap_rpc(p_name text, p_identity_args text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  w record;
  a record;
BEGIN
  SELECT * INTO w FROM public.kan712_wrapped_rpcs WHERE name = p_name AND identity_args = p_identity_args;
  IF NOT FOUND THEN RAISE EXCEPTION 'kan712_unwrap_rpc: %(%) is not recorded as wrapped', p_name, p_identity_args; END IF;
  EXECUTE format('DROP FUNCTION public.%I(%s)', w.name, w.identity_args);
  EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', w.inner_name, w.identity_args, w.name);
  EXECUTE format('ALTER FUNCTION public.%I(%s) OWNER TO %I', w.name, w.identity_args, w.original_owner::regrole::text);
  EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated, service_role', w.name, w.identity_args);
  FOR a IN SELECT x.grantee, x.privilege_type, x.is_grantable
             FROM aclexplode(coalesce(w.original_acl, acldefault('f', w.original_owner))) x
            WHERE x.grantee <> w.original_owner LOOP
    EXECUTE format('GRANT %s ON FUNCTION public.%I(%s) TO %s%s', a.privilege_type, w.name, w.identity_args,
                   CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(a.grantee::regrole::text) END,
                   CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
  END LOOP;
  DELETE FROM public.kan712_wrapped_rpcs WHERE name = p_name AND identity_args = p_identity_args;
END $$;

-- 8. Privileges. pg_default_acl grants anon/authenticated BY NAME, so PUBLIC alone is not enough.
REVOKE ALL ON FUNCTION public.kan712_legacy_guard()                     FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan712_legacy_after_delete()              FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan712_events_compat_mirror()             FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan712_update_event_shared(uuid, jsonb)   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan712_wrap_rpc(regprocedure, text)       FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan712_unwrap_rpc(text, text)             FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.kan712_update_event_shared(uuid, jsonb) TO service_role;

-- 9. Post-conditions: assert proacl / proconfig / prosecdef, not that the statements ran. ---------
DO $$
DECLARE
  r record;
BEGIN
  IF (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan712\_%') <> 6 THEN
    RAISE EXCEPTION 'KAN-712 stage 1 post: expected 6 kan712 functions';
  END IF;
  FOR r IN SELECT p.oid::regprocedure AS f, p.proname, p.prosecdef, p.proconfig FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan712\_%' LOOP
    IF NOT ('search_path=""' = ANY (coalesce(r.proconfig, '{}'))) THEN
      RAISE EXCEPTION 'KAN-712 stage 1 post: % lacks SET search_path = ''''', r.f;
    END IF;
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-712 stage 1 post: % is executable by anon/authenticated', r.f;
    END IF;
    IF has_function_privilege('service_role', r.f, 'EXECUTE') <> (r.proname = 'kan712_update_event_shared') THEN
      RAISE EXCEPTION 'KAN-712 stage 1 post: service_role EXECUTE on % is wrong', r.f;
    END IF;
    IF EXISTS (SELECT 1 FROM aclexplode(coalesce((SELECT proacl FROM pg_proc WHERE oid = r.f),
                                                 acldefault('f', 10))) a WHERE a.grantee = 0) THEN
      RAISE EXCEPTION 'KAN-712 stage 1 post: % is executable by PUBLIC', r.f;
    END IF;
    IF r.prosecdef = (r.proname = 'kan712_legacy_guard') THEN
      RAISE EXCEPTION 'KAN-712 stage 1 post: % has the wrong SECURITY mode', r.f;
    END IF;
  END LOOP;
  IF has_table_privilege('anon', 'public.kan712_wrapped_rpcs', 'SELECT')
     OR has_table_privilege('authenticated', 'public.kan712_wrapped_rpcs', 'SELECT')
     OR has_table_privilege('service_role', 'public.kan712_wrapped_rpcs', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-712 stage 1 post: kan712_wrapped_rpcs is readable by an API role';
  END IF;
  -- Inert: nothing attached yet.
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE '%kan712%') THEN
    RAISE EXCEPTION 'KAN-712 stage 1 post: a kan712 trigger exists before the cutover';
  END IF;
END $$;

COMMIT;
