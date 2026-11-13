-- KAN-713 (Events P2), migration 1 of 2: ACCESS HELPERS AND POLICIES READ events, NO VISIBILITY CHANGE.
--
-- STATUS: authored, NOT applied to any Supabase project. Executed on a local throwaway PG 16 only
-- (supabase/tests/events_p2_kan713/KAN713_CONTRACT.md, "Local run").
--
-- STAGE GATE: requires KAN-712 stage A (20261103100000) AND stage B (20261103110000) applied and live:
-- the five trg_zz_kan712_* triggers present and enabled, kan712_wrapped_rpcs non-empty, the
-- events -> legacy compat mirror enabled. Refuses to run twice. Applying role must be superuser or
-- BYPASSRLS (every SECURITY DEFINER helper below reads public.events, which is FORCE RLS with zero
-- policies, and relies on its owner bypassing RLS -- the same assumption KAN-712 states).
--
-- THE RULE -- INTERSECTION, NEVER WIDEN. Every converted check is
--     (the original legacy predicate, unchanged)  AND  (the same predicate evaluated on public.events)
-- joined through the validated FK games.event_id / meetups.event_id -> events.id with the event_type
-- pinned. While the KAN-712 contract keeps the two in sync they are equal, so no answer changes (proved
-- by supabase/tests/events_p2_kan713/matrix_kan713.sql: before/after diff empty). If they ever diverge,
-- the NARROWER answer wins. Phase 4 removes the legacy conjunct when it drops the legacy columns.
-- Per-type vocabularies are untouched: events.listing_visibility / join_policy carry the same per-type
-- CHECK sets as games / meetups (KAN-710), and both sides go through the same unchanged
-- can_view_with_scope / can_view_owner / can_read_row / can_write_row.
--
-- public.events STAYS CLOSED to anon/authenticated: no grant, no policy. API-role invoker code never
-- reads it: policies reach it only through the SECURITY DEFINER kan713_meetup_* helpers, and the two
-- INVOKER helpers branch on has_table_privilege('public.events', 'SELECT') -- the events-intersected
-- branch runs for service_role and inside SECURITY DEFINER callers, the original branch otherwise.
--
-- Replaced functions keep owner, ACL, SECURITY DEFINER/INVOKER and search_path exactly: CREATE OR REPLACE
-- (never DROP + CREATE), attributes asserted equal before and after. T-058 substitute: the body each
-- replacement starts from is the repo definition named in the manifest, and the precondition pins
-- md5(prosrc) of the LIVE function to that body -- any drift fails closed instead of being overwritten.
-- Pre-images (pg_get_functiondef, ACL, owner, policy expressions) are saved in public.kan713_preimage
-- for the rollback (supabase/tests/events_p2_kan713/rollback_kan713.sql).

BEGIN;
SET LOCAL lock_timeout = '10s';
-- Policy expressions are deparsed / parsed relative to search_path; pin it so the saved pre-images and
-- the precondition text compare deterministically.
SET LOCAL search_path = public, pg_catalog;

LOCK TABLE public.events, public.games, public.meetups, public.meetup_attendees IN SHARE ROW EXCLUSIVE MODE;

-- 1. Stage gate + preconditions ----------------------------------------------------------------------
DO $$
DECLARE
  v_missing text;
  v_bad text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-713: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: already applied (public.kan713_meetup_visible exists)';
  END IF;
  -- KAN-712 stage A
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL OR to_regprocedure('public.kan712_legacy_guard()') IS NULL
     OR to_regprocedure('public.kan712_update_event_shared(uuid,jsonb)') IS NULL THEN
    RAISE EXCEPTION 'KAN-713: KAN-712 stage A (20261103100000) not applied';
  END IF;
  -- KAN-712 stage B markers
  SELECT string_agg(n, ',') INTO v_missing
    FROM unnest(ARRAY['events.trg_zz_kan712_events_compat_mirror', 'games.trg_zz_kan712_games_guard',
                      'games.trg_zz_kan712_games_after_delete', 'meetups.trg_zz_kan712_meetups_guard',
                      'meetups.trg_zz_kan712_meetups_after_delete']) n
   WHERE NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
                      WHERE c.relnamespace = 'public'::regnamespace AND c.relname || '.' || t.tgname = n AND t.tgenabled = 'O');
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: KAN-712 stage B (20261103110000) not live; missing or disabled: %', v_missing;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs) THEN
    RAISE EXCEPTION 'KAN-713: KAN-712 stage B (20261103110000) not applied: kan712_wrapped_rpcs is empty';
  END IF;
  -- events is still closed to the API roles
  IF has_table_privilege('anon', 'public.events', 'SELECT,INSERT,UPDATE,DELETE')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT,INSERT,UPDATE,DELETE')
     OR EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'events')
     OR NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'KAN-713: public.events is not in the KAN-710 closed state (grants/policies/RLS changed)';
  END IF;
  -- Live bodies must be exactly the repo bodies these replacements were authored from (T-058 substitute).
  SELECT string_agg(x.sig || ' expected ' || x.md5 || ' live ' || coalesce(md5(p.prosrc), '<absent>')
                    || ' secdef ' || coalesce(p.prosecdef::text, '?') || ' config ' || coalesce(p.proconfig::text, '-'), '; ')
    INTO v_bad
    FROM (VALUES
      ('public._can_view_game(uuid)',                     '0f80b8965fc13670e85f9bb71b6fe7fd', true,  '{search_path=public}'),
      ('public._can_view_game_for_join(uuid)',            '29fad565fe63edb044a5164c84dd79e0', false, '{"search_path=public, pg_temp"}'),
      ('public._is_game_host(uuid)',                      '88fa1dbb194cd42065065a26f60c9f9b', true,  '{search_path=public}'),
      ('public.can_current_user_join_game(uuid,text,uuid)','83c99ff70e3890022aeb46048f5cf8ac', false, '{search_path=public}'),
      ('public.can_current_user_rsvp_meetup(uuid,uuid)',  '98088d0ad24fb9b806be02979646aefe', true,  '{search_path=public}')
    ) AS x(sig, md5, secdef, config)
    LEFT JOIN pg_proc p ON p.oid = to_regprocedure(x.sig)
   WHERE p.oid IS NULL OR md5(p.prosrc) <> x.md5 OR p.prosecdef <> x.secdef OR p.proconfig::text <> x.config;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: live helper differs from the reviewed pre-image (re-author from pg_get_functiondef): %', v_bad;
  END IF;
  -- Live policy expressions must be exactly the baseline ones being extended.
  SELECT string_agg(x.tbl || '.' || x.pol, ', ') INTO v_bad
    FROM (VALUES
      ('meetups', 'meetups_select_visible', 'a6f92d6ce7f532392784bdef5f764c7d', NULL),
      ('meetup_attendees', 'meetup_attendees_select', 'f576ac2e4447fa468d02460bb6b37739', NULL),
      ('meetup_attendees', 'meetup_attendees_select_visible', '0a0fa28994e249f6a8f05e79365a7108', NULL),
      ('meetup_attendees', 'meetup_attendees_write', '9e34efc1e569dec2b5e0d58af7730067', '9e34efc1e569dec2b5e0d58af7730067')
    ) AS x(tbl, pol, q, wc)
    LEFT JOIN pg_policies p ON p.schemaname = 'public' AND p.tablename = x.tbl AND p.policyname = x.pol
   WHERE p.policyname IS NULL OR md5(p.qual) IS DISTINCT FROM x.q OR md5(p.with_check) IS DISTINCT FROM x.wc;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-713: live policy differs from the reviewed baseline expression: %', v_bad;
  END IF;
END $$;

-- 2. Pre-images ---------------------------------------------------------------------------------------
-- Kept by the rollback (it is the rollback's input). Never readable by the API roles.
CREATE TABLE IF NOT EXISTS public.kan713_preimage (
  kind        text NOT NULL CHECK (kind IN ('function', 'policy', 'trigger')),
  object      text NOT NULL,
  definition  text,
  acl         aclitem[],
  owner       text,
  pol_table   text,
  pol_qual    text,
  pol_check   text,
  tg_enabled  "char",
  saved_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (kind, object)
);
ALTER TABLE public.kan713_preimage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kan713_preimage FROM PUBLIC, anon, authenticated, service_role;
DELETE FROM public.kan713_preimage WHERE kind IN ('function', 'policy');

INSERT INTO public.kan713_preimage (kind, object, definition, acl, owner)
SELECT 'function', p.oid::regprocedure::text, pg_get_functiondef(p.oid), p.proacl, p.proowner::regrole::text
  FROM pg_proc p
 WHERE p.oid IN ('public._can_view_game(uuid)'::regprocedure, 'public._can_view_game_for_join(uuid)'::regprocedure,
                 'public._is_game_host(uuid)'::regprocedure, 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure,
                 'public.can_current_user_rsvp_meetup(uuid,uuid)'::regprocedure);
INSERT INTO public.kan713_preimage (kind, object, pol_table, pol_qual, pol_check)
SELECT 'policy', p.tablename || '.' || p.policyname, p.tablename, p.qual, p.with_check
  FROM pg_policies p
 WHERE p.schemaname = 'public'
   AND (p.tablename, p.policyname) IN (('meetups', 'meetups_select_visible'), ('meetup_attendees', 'meetup_attendees_select'),
                                       ('meetup_attendees', 'meetup_attendees_select_visible'), ('meetup_attendees', 'meetup_attendees_write'));

-- 3. Games helpers (bodies: manifest rows G-1..G-4) ----------------------------------------------------
-- G-1  baseline 20260829080500:784-810. SECURITY DEFINER, search_path public -- kept.
CREATE OR REPLACE FUNCTION "public"."_can_view_game"("p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      and (
        g.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
           )
      )
      -- KAN-713: the same predicate on the events fields; intersection, never wider.
      and (
        e.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
           )
      )
  );
$$;

-- G-2  baseline 20260829080500:816-829. INVOKER, search_path public, pg_temp -- kept. sql -> plpgsql only
-- so the events branch can be taken where the caller may read events.
CREATE OR REPLACE FUNCTION "public"."_can_view_game_for_join"("p_game" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    RETURN EXISTS (
      SELECT 1 FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
      WHERE g.id = p_game
        AND (
          public.is_admin(auth.uid())
          OR g.creator_user_id = auth.uid()
          OR public.can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, NULL::uuid)
        )
        AND (
          public.is_admin(auth.uid())
          OR e.creator_user_id = auth.uid()
          OR public.can_view_with_scope(auth.uid(), e.creator_user_id, e.listing_visibility, NULL::uuid)
        )
    );
  END IF;
  -- Caller cannot read events (anon / authenticated invoker): the original predicate, unchanged.
  RETURN EXISTS (
    SELECT 1 FROM public.games g
    WHERE g.id = p_game
      AND (
        public.is_admin(auth.uid())
        OR g.creator_user_id = auth.uid()
        OR public.can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, NULL::uuid)
      )
  );
END;
$$;

-- G-3  baseline 20260829080500:1139-1148. SECURITY DEFINER, search_path public -- kept.
CREATE OR REPLACE FUNCTION "public"."_is_game_host"("p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      and g.creator_user_id = auth.uid()
      and e.creator_user_id = auth.uid()                                  -- KAN-713: both must agree
  );
$$;

-- G-4  baseline 20260829080500:3630-3686. INVOKER, search_path public -- kept. Where the caller may read
-- events: the events row is required, visibility is the intersection, cancelled/started are the union of
-- the denials, a join_policy disagreement fails closed. Otherwise the original body, unchanged.
-- Known pre-existing defect kept byte-for-byte (named exception E-2): game_invites has no to_profile_id,
-- so an 'invite' game that reaches the invite branch raises 42703, before and after KAN-713.
CREATE OR REPLACE FUNCTION "public"."can_current_user_join_game"("p_game_id" "uuid", "p_actor_type" "text" DEFAULT 'player'::"text", "p_link_token" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
  slots int; visible boolean; cta text;
  e public.events%rowtype; v_events boolean := has_table_privilege('public.events', 'SELECT');   -- KAN-713
BEGIN
  IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
  IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
  actor_id := public.choose_actor(p_actor_type);
  IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  IF v_events THEN                                                                                    -- KAN-713
    SELECT * INTO e FROM public.events WHERE id = g.event_id AND event_type = 'game';
    IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  END IF;
  IF g.creator_user_id = viewer OR (v_events AND e.creator_user_id = viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
  visible := public.can_view_with_scope(viewer, g.creator_user_id, g.listing_visibility, g.squad_id);
  IF visible AND v_events THEN                                                                        -- KAN-713
    visible := public.can_view_with_scope(viewer, e.creator_user_id, e.listing_visibility, g.squad_id);
  END IF;
  IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
  IF g.is_cancelled OR (v_events AND e.is_cancelled) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
  IF g.start_at <= now() OR (v_events AND e.start_at <= now()) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
  IF v_events AND e.join_policy IS DISTINCT FROM g.join_policy THEN                                   -- KAN-713: fail closed
    RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'policy_mismatch');
  END IF;
  IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
    RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
  END IF;
  CASE g.join_policy
    WHEN 'open' THEN cta := 'join';
    WHEN 'request' THEN
      IF EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = p_game_id AND q.status = 'pending' AND (q.from_user_id = viewer OR q.from_profile_id = actor_id)) THEN
        RETURN jsonb_build_object('allowed', false, 'cta', 'requested', 'reason', 'pending_request');
      END IF;
      cta := 'request';
    WHEN 'invite' THEN
      IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND (i.to_user_id = viewer OR i.to_profile_id = actor_id)) THEN
        cta := 'accept_invite';
      ELSE
        RETURN jsonb_build_object('allowed', false, 'cta', 'invite_only', 'reason', 'invite_required');
      END IF;
    WHEN 'link' THEN
      IF p_link_token IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_required', 'reason', 'missing_link'); END IF;
      IF NOT public._link_token_valid(p_game_id, p_link_token) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_invalid', 'reason', 'invalid_link'); END IF;
      cta := 'join_with_link';
    WHEN 'circle' THEN
      IF NOT public.are_synced(viewer, g.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
      IF v_events AND NOT public.are_synced(viewer, e.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
      cta := 'join';
    WHEN 'squad' THEN
      IF g.squad_id IS NULL OR NOT public.is_in_squad(viewer, g.squad_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'squad_only', 'reason', 'not_in_squad'); END IF;
      cta := 'join';
    WHEN 'closed' THEN RETURN jsonb_build_object('allowed', false, 'cta', 'closed', 'reason', 'closed');
    ELSE RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'unknown_policy');
  END CASE;
  slots := public.game_slots_left(p_game_id);
  IF slots = 0 THEN
    RETURN jsonb_build_object('allowed', true,
      'cta', CASE WHEN g.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
      'reason', 'full');
  END IF;
  RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
END;
$$;

-- 4. Meetup helpers -------------------------------------------------------------------------------------
-- M-1  20260912190747_kan180:33-109 + 20260915120000_meetups_hardening:78-79 (SECURITY DEFINER,
-- search_path public) -- kept. The events row is required; visibility is the intersection;
-- cancelled/started are the union of the denials; e.join_policy is the events counterpart of
-- m.rsvp_policy and a disagreement fails closed.
CREATE OR REPLACE FUNCTION public.can_current_user_rsvp_meetup(p_meetup_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  u uuid := auth.uid();
  m public.meetups%rowtype;
  visible boolean;
  e public.events%rowtype;   -- KAN-713
begin
  if u is null then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','anon');
  end if;
  if public.is_frozen(u) then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','frozen');
  end if;

  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','not_found');
  end if;
  select * into e from public.events where id = m.event_id and event_type = 'meetup';   -- KAN-713
  if not found then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','not_found');
  end if;

  visible := public.can_view_with_scope(u, m.creator_user_id, m.listing_visibility, null)
         and public.can_view_with_scope(u, e.creator_user_id, e.listing_visibility, null);   -- KAN-713
  if not visible then
    return jsonb_build_object('allowed', false, 'cta','not_visible','reason','visibility_denied');
  end if;

  if m.is_cancelled or e.is_cancelled then
    return jsonb_build_object('allowed', false, 'cta','cancelled','reason','cancelled');
  end if;
  if m.start_at <= now() or e.start_at <= now() then
    return jsonb_build_object('allowed', false, 'cta','started','reason','started');
  end if;
  if e.join_policy is distinct from m.rsvp_policy then                                    -- KAN-713: fail closed
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','policy_mismatch');
  end if;

  if exists (select 1 from public.meetup_rsvps r where r.meetup_id=m.id and r.user_id=u and r.status in ('going','interested','pending')) then
    return jsonb_build_object('allowed', false, 'cta','already','reason','already');
  end if;

  case m.rsvp_policy
    when 'open' then
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'request' then
      return jsonb_build_object('allowed', true, 'cta','request');

    when 'invite' then
      if exists (select 1 from public.meetup_invites i where i.meetup_id=m.id and i.to_user_id=u and i.status='pending') then
        return jsonb_build_object('allowed', true, 'cta','accept_invite');
      else
        return jsonb_build_object('allowed', false, 'cta','invite_only','reason','invite_required');
      end if;

    when 'link' then
      if p_link_token is null then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','missing_link');
      end if;
      if not public._meetup_link_valid(m.id, p_link_token) then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','invalid_link');
      end if;
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'closed' then
      return jsonb_build_object('allowed', false, 'cta','closed','reason','closed');

    when 'circle' then
      if public.are_synced(u, m.creator_user_id) and public.are_synced(u, e.creator_user_id) then   -- KAN-713
        return jsonb_build_object('allowed', true, 'cta','rsvp_going');
      else
        return jsonb_build_object('allowed', false, 'cta','circle_only','reason','not_in_circle');
      end if;

    else
      return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','unknown_policy');
  end case;
end;
$function$;

-- New SECURITY DEFINER policy helpers: the ONLY way a policy reaches public.events. Each evaluates, on the
-- events row of type 'meetup', exactly the predicate the policy already evaluates on the meetups row.
-- Missing / wrong-type event -> false (fail closed). search_path '' (fully qualified bodies). They read
-- only public.events, which has no policies, so they cannot recurse into any policy.
CREATE FUNCTION public.kan713_meetup_visible(p_event_id uuid) RETURNS boolean
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN coalesce((SELECT public.can_view_owner(e.creator_user_id, e.listing_visibility)
                     FROM public.events e WHERE e.id = p_event_id AND e.event_type = 'meetup'), false);
END $$;
CREATE FUNCTION public.kan713_meetup_can_read_row(p_event_id uuid) RETURNS boolean
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN coalesce((SELECT public.can_read_row(e.creator_user_id, e.listing_visibility)
                     FROM public.events e WHERE e.id = p_event_id AND e.event_type = 'meetup'), false);
END $$;
CREATE FUNCTION public.kan713_meetup_attendee_visible(p_event_id uuid) RETURNS boolean
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN coalesce((SELECT (e.listing_visibility = 'public'::text)
                          OR ((e.listing_visibility = 'circle'::text) AND public.are_synced(auth.uid(), e.creator_user_id))
                          OR ((e.listing_visibility = 'hidden'::text) AND (auth.uid() = e.creator_user_id))
                     FROM public.events e WHERE e.id = p_event_id AND e.event_type = 'meetup'), false);
END $$;
CREATE FUNCTION public.kan713_meetup_can_write_row(p_event_id uuid) RETURNS boolean
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN coalesce((SELECT public.can_write_row(e.creator_user_id)
                     FROM public.events e WHERE e.id = p_event_id AND e.event_type = 'meetup'), false);
END $$;
-- A DROP/CREATE-free create still inherits pg_default_acl, which grants anon BY NAME: revoke PUBLIC and
-- set the exact grant set the policies need (policy expressions execute as the querying role).
REVOKE ALL ON FUNCTION public.kan713_meetup_visible(uuid), public.kan713_meetup_can_read_row(uuid),
  public.kan713_meetup_attendee_visible(uuid), public.kan713_meetup_can_write_row(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.kan713_meetup_visible(uuid), public.kan713_meetup_can_read_row(uuid),
  public.kan713_meetup_attendee_visible(uuid), public.kan713_meetup_can_write_row(uuid) TO anon, authenticated, service_role;

-- 5. Policies: original expression AND the events counterpart (manifest rows P-1..P-4) -----------------
ALTER POLICY "meetups_select_visible" ON public.meetups
  USING (can_view_owner(creator_user_id, listing_visibility) AND public.kan713_meetup_visible(event_id));

ALTER POLICY "meetup_attendees_select" ON public.meetup_attendees
  USING (EXISTS ( SELECT 1
   FROM meetups m
  WHERE ((m.id = meetup_attendees.meetup_id) AND can_read_row(m.creator_user_id, m.listing_visibility)
         AND public.kan713_meetup_can_read_row(m.event_id))));

ALTER POLICY "meetup_attendees_select_visible" ON public.meetup_attendees
  USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM meetups m
  WHERE ((m.id = meetup_attendees.meetup_id) AND ((m.listing_visibility = 'public'::text) OR ((m.listing_visibility = 'circle'::text) AND are_synced(auth.uid(), m.creator_user_id)) OR ((m.listing_visibility = 'hidden'::text) AND (auth.uid() = m.creator_user_id)))
         AND public.kan713_meetup_attendee_visible(m.event_id))))));

ALTER POLICY "meetup_attendees_write" ON public.meetup_attendees
  USING ((EXISTS ( SELECT 1
   FROM meetups m
  WHERE ((m.id = meetup_attendees.meetup_id) AND (can_write_row(m.creator_user_id) OR (auth.uid() = meetup_attendees.user_id))
         AND (public.kan713_meetup_can_write_row(m.event_id) OR (auth.uid() = meetup_attendees.user_id))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM meetups m
  WHERE ((m.id = meetup_attendees.meetup_id) AND (can_write_row(m.creator_user_id) OR (auth.uid() = meetup_attendees.user_id))
         AND (public.kan713_meetup_can_write_row(m.event_id) OR (auth.uid() = meetup_attendees.user_id))))));

-- Games-side policies (roster_select_visible, waitlist_select_visible, joinreq_select_requester_or_host)
-- are textually unchanged: they reach events through _can_view_game / _is_game_host above.

-- 6. Postconditions -------------------------------------------------------------------------------------
DO $$
DECLARE
  v_bad text;
BEGIN
  -- replaced functions: owner, ACL, SECURITY DEFINER flag and search_path exactly as saved
  SELECT string_agg(s.object, ', ') INTO v_bad
    FROM public.kan713_preimage s
    JOIN pg_proc p ON p.oid = s.object::regprocedure
   WHERE s.kind = 'function'
     AND (p.proacl IS DISTINCT FROM s.acl OR p.proowner::regrole::text <> s.owner
          OR p.prosecdef <> (s.definition LIKE '%SECURITY DEFINER%'));
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 postcondition: owner/ACL/secdef changed on %', v_bad; END IF;
  IF (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'function') <> 5
     OR (SELECT count(*) FROM public.kan713_preimage WHERE kind = 'policy') <> 4 THEN
    RAISE EXCEPTION 'KAN-713 postcondition: pre-images incomplete';
  END IF;
  -- secdef / search_path per function, asserted literally
  SELECT string_agg(x.sig, ', ') INTO v_bad
    FROM (VALUES
      ('public._can_view_game(uuid)', true, '{search_path=public}'),
      ('public._can_view_game_for_join(uuid)', false, '{"search_path=public, pg_temp"}'),
      ('public._is_game_host(uuid)', true, '{search_path=public}'),
      ('public.can_current_user_join_game(uuid,text,uuid)', false, '{search_path=public}'),
      ('public.can_current_user_rsvp_meetup(uuid,uuid)', true, '{search_path=public}'),
      ('public.kan713_meetup_visible(uuid)', true, '{"search_path=\"\""}'),
      ('public.kan713_meetup_can_read_row(uuid)', true, '{"search_path=\"\""}'),
      ('public.kan713_meetup_attendee_visible(uuid)', true, '{"search_path=\"\""}'),
      ('public.kan713_meetup_can_write_row(uuid)', true, '{"search_path=\"\""}')
    ) AS x(sig, secdef, config)
    JOIN pg_proc p ON p.oid = x.sig::regprocedure
   WHERE p.prosecdef <> x.secdef OR p.proconfig::text <> x.config;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 postcondition: secdef/search_path wrong on %', v_bad; END IF;
  -- new helpers: exactly EXECUTE to anon, authenticated, service_role (+ owner); no PUBLIC
  SELECT string_agg(p.proname, ', ') INTO v_bad
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan713\_meetup\_%'
     AND (SELECT array_agg(g ORDER BY g)
            FROM (SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END AS g
                    FROM aclexplode(p.proacl) a WHERE a.privilege_type = 'EXECUTE') q)
         IS DISTINCT FROM (SELECT array_agg(r ORDER BY r) FROM unnest(ARRAY[p.proowner::regrole::text, 'anon', 'authenticated', 'service_role']) r);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'KAN-713 postcondition: helper ACL wrong on %', v_bad; END IF;
  -- events still closed
  IF has_table_privilege('anon', 'public.events', 'SELECT,INSERT,UPDATE,DELETE')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT,INSERT,UPDATE,DELETE')
     OR EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'events') THEN
    RAISE EXCEPTION 'KAN-713 postcondition: public.events opened to an API role';
  END IF;
  -- pre-image table closed
  IF has_table_privilege('anon', 'public.kan713_preimage', 'SELECT') OR has_table_privilege('authenticated', 'public.kan713_preimage', 'SELECT')
     OR has_table_privilege('service_role', 'public.kan713_preimage', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-713 postcondition: kan713_preimage readable by an API role';
  END IF;
END $$;

COMMIT;
