-- KAN-427 WP1 -- Meetups backend hardening.
--
-- AUTHORED, NOT APPLIED. Applying is a CEO-approved step (G-002 / T-020). Nothing
-- here deletes, truncates or rewrites a meetups row (live: 1 meetups row, 0 rsvps);
-- it changes definitions, grants and policies only.
--
-- SOURCE OF THE BODIES. The live catalogue could not be read while authoring (no
-- live access was permitted). Bodies below are the Canary baseline
-- (20260829080500) bodies plus the KAN-180 corrections (20260912190747), changed
-- only where stated. BEFORE APPLYING, the apply step MUST diff each replaced
-- function against pg_get_functiondef() on the live catalogue (probe section A of
-- supabase/tests/kan427/meetups_hardening_probes.sql prints them) and stop if an
-- attribute or body differs from what is assumed here (T-058).
--
-- LIVE DEFECT (numbers from meetups-live-supabase-findings.md)      -> CHANGE
--   1  rpc_meetup_cancel checks m.owner_user_id (no such column)    -> (e) rewritten on creator_user_id
--   2  no working host approve/decline path for pending requests    -> (g) rpc_meetup_decide_request,
--      rpc_meetup_attendees / card / counts read legacy table          rpc_meetup_remove_attendee; (h)
--      (and the baseline bodies also reference owner_user_id /         attendees, card, meetup_counts,
--      visibility / owner_profile_id, which do not exist)              meetup_my_status, v_meetup_counts,
--                                                                      v_meetup_list read meetup_rsvps
--   3  anon can EXECUTE every meetup write RPC                      -> (a) REVOKE FROM PUBLIC, anon
--   4  rsvp_self_write lets a client bypass capacity/policy         -> (c) DROP POLICY (+ table grants)
--   5  v_meetup_list exposes creator_user_id to anon                -> (b) view rebuilt without it
--   6  legacy duplicate overloads still live                        -> (i) dropped (no callers found)
--   7  request state is 'pending', not 'requested'                  -> (l) used throughout
--   8  organisers only                                              -> (d) explicit can_create_meetup
--   -  no client edit path for a meetup                             -> (f) rpc_meetup_update
--   -  reports need target_type 'meetup'                            -> (j) mod_target enum value
--   (extra) meetup_counts() declared integer but summed bigint      -> rewritten with explicit ::int casts
--
-- ANON GRANTS DELIBERATELY KEPT (T-002 allowlist, docs/SCHEMA.md 2f/2g): the view
-- v_meetup_list (allowlisted, anon-readable pre-login surface, definer semantics
-- exactly as before), rpc_meetup_card (visibility-gated read of one public card),
-- meetup_counts (visibility-gated counts), getnearbymeetups and
-- can_current_user_rsvp_meetup (untouched; the latter answers 'anon' for anon).
-- REVOKED from anon although read-only: rpc_meetup_attendees (member names) and
-- meetup_my_status (caller-supplied identity argument, KAN-175 pattern).
-- v_meetup_counts loses anon: it cannot stay security_invoker once rsvp_self_write
-- is gone (invoker + no policy = zero rows), and a non-invoker anon-readable view
-- that is not on the 2f allowlist would fail the T-002 gate.
--
-- ROLLBACK NOTES. All function changes are CREATE OR REPLACE: rollback = re-create
-- the pre-image from the baseline file + KAN-180 migration. Dropped duplicates
-- (rpc_meetup_create x2, rpc_meetup_rsvp(uuid,text,text), rpc_meetup_unrsvp) can be
-- re-created from baseline lines 13672-13789 / 13849-13897 / 14013-14037. To
-- restore the policy: CREATE POLICY rsvp_self_write ON public.meetup_rsvps USING
-- (user_id = auth.uid()) WITH CHECK (user_id = auth.uid()); and re-GRANT. The
-- mod_target value 'meetup' cannot be removed (Postgres has no DROP VALUE); it is
-- additive and harmless. v_meetup_list pre-image: baseline lines 25731-25785.

BEGIN;

-- ============================================================================
-- (j) moderation reports: allow target_type 'meetup'.
--     moderation_reports.target_type is the enum public.mod_target, not a CHECK
--     (user, profile, post, comment, game, squad, venue, message, other).
--     Additive definition change. The new value is not USED in this transaction.
-- ============================================================================
ALTER TYPE public.mod_target ADD VALUE IF NOT EXISTS 'meetup';

-- ============================================================================
-- (c) RSVP writes only through rpc_meetup_rsvp.
--     With the ALL policy gone the table has no policy at all (RLS stays ON), so
--     no client role can read or write rows directly; SECURITY DEFINER RPCs and
--     definer views read it as the owner. Table grants are revoked as well so the
--     intent does not depend on RLS alone.
-- ============================================================================
DROP POLICY IF EXISTS rsvp_self_write ON public.meetup_rsvps;
ALTER TABLE public.meetup_rsvps ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.meetup_rsvps FROM anon, authenticated;

-- The table grants are gone, so every function that reads meetup_rsvps must run
-- as its owner. can_current_user_rsvp_meetup (called directly by the app) and
-- meetup_slots_left (called by rpc_meetup_rsvp) were SECURITY INVOKER: with the
-- grants revoked they would fail for the caller. Their EXECUTE grants (anon keeps
-- can_current_user_rsvp_meetup, which answers 'anon' for anon) are unchanged.
ALTER FUNCTION public.can_current_user_rsvp_meetup(uuid, uuid) SECURITY DEFINER;
ALTER FUNCTION public.can_current_user_rsvp_meetup(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.meetup_slots_left(uuid) SECURITY DEFINER;
ALTER FUNCTION public.meetup_slots_left(uuid) SET search_path = public;
-- meetup_slots_left must not be callable by clients (as a definer function it
-- would leak the existence and capacity of private meetups). Its only callers,
-- rpc_meetup_rsvp and rpc_meetup_decide_request, are SECURITY DEFINER themselves;
-- nothing in lib/, supabase/functions or test/ calls it.
REVOKE ALL ON FUNCTION public.meetup_slots_left(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.meetup_slots_left(uuid) TO service_role;

-- ============================================================================
-- (i) Retire duplicates. git grep over Canary, Alpha, the KAN-428 branch (lib,
--     supabase/functions, test) found no caller; migrations contain no function
--     that calls them. Plain DROP (no CASCADE): a dependent object aborts the
--     whole migration instead of being silently removed.
-- ============================================================================
DROP FUNCTION IF EXISTS public.rpc_meetup_create(text, text, timestamp with time zone, text);
DROP FUNCTION IF EXISTS public.rpc_meetup_create(uuid, text, text, timestamp with time zone, timestamp with time zone, text, double precision, double precision, text, text, integer, text, jsonb);
DROP FUNCTION IF EXISTS public.rpc_meetup_rsvp(uuid, text, text);
DROP FUNCTION IF EXISTS public.rpc_meetup_unrsvp(uuid, text);

-- ============================================================================
-- (h) Counts / my-status helpers read meetup_rsvps (the table rpc_meetup_rsvp
--     writes), not the legacy meetup_attendees.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.meetup_counts(p_meetup_id uuid)
 RETURNS TABLE(going integer, interested integer, declined integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int
  from public.meetups m
  left join public.meetup_rsvps r on r.meetup_id = m.id
  where m.id = p_meetup_id
    and public.can_view_owner(m.creator_user_id, m.listing_visibility)
$function$;

CREATE OR REPLACE FUNCTION public.meetup_my_status(p_meetup_id uuid, p_actor uuid)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select r.status
  from public.meetup_rsvps r
  where r.meetup_id = p_meetup_id
    and r.profile_id = p_actor
    and r.user_id = auth.uid()
  limit 1
$function$;

-- v_meetup_counts: same three columns and types as before, now over meetup_rsvps,
-- limited to meetups the caller may see. Not security_invoker (see header).
CREATE OR REPLACE VIEW public.v_meetup_counts AS
 SELECT r.meetup_id,
    sum((r.status = 'going')::integer) AS going_count,
    sum((r.status = 'interested')::integer) AS interested_count,
    sum((r.status = 'declined')::integer) AS declined_count
   FROM public.meetup_rsvps r
     JOIN public.meetups m ON m.id = r.meetup_id
  WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
  GROUP BY r.meetup_id;
ALTER VIEW public.v_meetup_counts SET (security_invoker = off);

-- ============================================================================
-- (b) v_meetup_list rebuilt WITHOUT creator_user_id.
--     CREATE OR REPLACE VIEW cannot drop a column, so DROP + CREATE. Semantics are
--     preserved exactly: NOT security_invoker (allowlisted anon-readable surface,
--     T-002 / docs/SCHEMA.md 2f, same as v_game_card), same WHERE visibility gate,
--     same columns minus creator_user_id. counts and my_rsvp_status now come from
--     meetup_rsvps; my_rsvp_status keys on auth.uid() directly (the old `me` CTE
--     called assert_profile_exists_for_user, which raises for a user with no
--     player profile).
-- ============================================================================
DROP VIEW IF EXISTS public.v_meetup_list;

CREATE VIEW public.v_meetup_list AS
 SELECT m.id,
    m.title,
    m.description,
    m.start_at,
    m.end_at,
    m.capacity,
    m.members_only,
    m.listing_visibility,
    m.rsvp_policy,
    m.is_cancelled,
    m.vibe_key,
    m.created_at,
    m.updated_at,
    m.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    m.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    m.area_id,
    a.name AS area_name,
    m.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    m.geo_location_id,
    m.min_skill,
    m.max_skill,
    m.joining_rule,
    m.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status
   FROM public.meetups m
     LEFT JOIN public.profiles cp ON cp.id = m.creator_profile_id
     LEFT JOIN public.sports s ON s.id = m.sport_id
     LEFT JOIN public.areas a ON a.id = m.area_id
     LEFT JOIN public.venues v ON v.id = m.venue_id
     LEFT JOIN public.v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN public.meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
  ORDER BY COALESCE(m.updated_at, m.created_at) DESC;

ALTER VIEW public.v_meetup_list OWNER TO postgres;
-- preserve the baseline grants (anon + authenticated read, service_role all)
REVOKE ALL ON TABLE public.v_meetup_list FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO anon;
GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO authenticated;
GRANT ALL ON TABLE public.v_meetup_list TO service_role;

-- v_meetup_counts is not on the T-002 allowlist: authenticated + service_role only.
REVOKE ALL ON TABLE public.v_meetup_counts FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.v_meetup_counts TO authenticated;
GRANT ALL ON TABLE public.v_meetup_counts TO service_role;

-- ============================================================================
-- (d) rpc_create_meetup: free-only + public-only v1 guards as RPC checks (not
--     CHECK constraints), organiser-only via can_create_meetup. Body = baseline
--     (11753-11868) with: the three guards, host recorded in meetup_rsvps as
--     'going' (was the legacy meetup_attendees), nothing else changed.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid               uuid;
  uid               uuid;
  mid               uuid;
  v_sport           record;
  v_variant         record;
  v_required        integer;
  v_final_capacity  integer;
  v_joining_rule    text;
  v_cost_cover      text;
BEGIN
  pid := public.choose_actor(p_actor_type);

  -- Organisers only (can_create_meetup = actor_is_organiser).
  IF NOT public.can_create_meetup(pid) THEN
    RAISE EXCEPTION USING errcode='P0001', message='organiser_required';
  END IF;

  -- v1 guard: public listings only (RPC check, not a CHECK constraint).
  IF COALESCE(p_listing_visibility, 'public') <> 'public' THEN
    RAISE EXCEPTION USING errcode='P0001', message='visibility_not_supported';
  END IF;

  -- v1 guard: free meetups only. joining_rule / cost_cover are not parameters;
  -- reject any non-free value smuggled through p_meta, and re-check the stored
  -- values after the insert (fn_meetups_sync_joining_rule can derive a paid rule
  -- from a venue space).
  IF p_meta IS NOT NULL AND (
       COALESCE(p_meta->>'joining_rule', 'free') <> 'free'
    OR COALESCE(p_meta->>'cost_cover',   'free') <> 'free'
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  IF p_location_name IS NULL OR trim(p_location_name) = '' THEN
    RAISE EXCEPTION USING errcode='P0001', message='location_name_required';
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION USING errcode='P0001', message='title_required';
  END IF;

  IF p_start_at IS NOT NULL AND p_end_at IS NOT NULL
     AND p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range';
  END IF;

  SELECT * INTO v_sport
    FROM public.sports
   WHERE id = p_sport_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_sport';
  END IF;

  SELECT * INTO v_variant
    FROM public.sport_variants
   WHERE id = p_sport_variant_id
     AND sport_id = p_sport_id
     AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant';
  END IF;

  v_required := v_variant.required_players;

  IF p_capacity IS NOT NULL THEN
    IF p_capacity < v_required THEN
      RAISE EXCEPTION USING errcode='P0001', message='capacity_below_required_players';
    END IF;
    v_final_capacity := p_capacity;
  ELSE
    v_final_capacity := NULL;
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found';
  END IF;

  INSERT INTO public.meetups (
    creator_profile_id,
    creator_user_id,
    sport_id,
    title,
    description,
    venue_id,
    location_name,
    geo_location_id,
    area_id,
    start_at,
    end_at,
    capacity,
    listing_visibility,
    rsvp_policy,
    members_only,
    min_skill,
    max_skill,
    vibe_key,
    meta
  )
  VALUES (
    pid,
    uid,
    p_sport_id,
    p_title,
    p_description,
    p_venue_id,
    p_location_name,
    p_geo_location_id,
    p_area_id,
    p_start_at,
    p_end_at,
    v_final_capacity,
    'public',
    p_rsvp_policy,
    p_members_only,
    p_min_skill,
    p_max_skill,
    p_vibe_key,
    COALESCE(p_meta, '{}')
  )
  RETURNING id, joining_rule, cost_cover INTO mid, v_joining_rule, v_cost_cover;

  IF v_joining_rule <> 'free' OR v_cost_cover <> 'free' THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  -- The host is the first 'going' RSVP (meetup_rsvps is the source of truth).
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  VALUES (mid, uid, pid, 'going')
  ON CONFLICT (meetup_id, user_id) DO UPDATE
    SET status = 'going', profile_id = EXCLUDED.profile_id, updated_at = now();

  RETURN mid;
END;
$function$;

-- ============================================================================
-- (e) rpc_meetup_cancel: identity column is creator_user_id (owner_user_id does
--     not exist). Host or admin; idempotent; event only when a row changed.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_cancel(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if not exists (
    select 1 from public.meetups m
    where m.id = p_meetup_id
      and (m.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  ) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  update public.meetups
     set is_cancelled = true, updated_at = now()
   where id = p_meetup_id and is_cancelled = false;
  if found then
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

-- ============================================================================
-- (h) rpc_meetup_attendees: reads meetup_rsvps. Same four return columns. The
--     baseline body referenced m.owner_user_id / m.visibility (neither exists).
--     The host (creator or admin) sees every status; everyone else sees only
--     going / interested (pending requests and cancelled rows are host-only).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
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

-- ============================================================================
-- (h) rpc_meetup_card: baseline body referenced owner_user_id / visibility /
--     owner_profile_id (none exist) and the legacy table. Rewritten on
--     meetups + meetup_rsvps. p_profile_type is accepted for signature
--     compatibility and ignored (my status is derived from auth.uid()).
--     No creator_user_id is returned. counts.pending is host-only.
--     This is also the "card-compatible shape" returned by rpc_meetup_update.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
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

  select hp.display_name, hp.username into hp_name, hp_user
  from public.profiles hp where hp.id = m.host_actor_id;

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
      'username',         hp_user
    ),
    'counts',    counts_,
    'my_status', my_status_,
    'is_host',   v_host
  );
end;
$function$;

-- ============================================================================
-- (f) rpc_meetup_update (new): host-only edit. NULL parameter = leave unchanged
--     (so end_at / capacity / description cannot be cleared through this RPC).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_update(p_meetup_id uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location_name text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me        uuid := auth.uid();
  m         public.meetups%rowtype;
  v_start   timestamptz;
  v_end     timestamptz;
  v_going   integer;
  v_changed jsonb := '[]'::jsonb;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if m.creator_user_id <> me then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if m.is_cancelled then
    raise exception using errcode='P0001', message='meetup_cancelled';
  end if;

  if p_title is not null then
    if char_length(trim(p_title)) < 3 or char_length(trim(p_title)) > 80 then
      raise exception using errcode='P0001', message='title_invalid';
    end if;
  end if;

  if p_location_name is not null and trim(p_location_name) = '' then
    raise exception using errcode='P0001', message='location_name_required';
  end if;

  v_start := coalesce(p_start_at, m.start_at);
  v_end   := coalesce(p_end_at, m.end_at);
  if v_end is not null and v_end <= v_start then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;

  if p_capacity is not null then
    if p_capacity <= 0 then
      raise exception using errcode='P0001', message='invalid_capacity';
    end if;
    select count(*)::int into v_going
      from public.meetup_rsvps r
     where r.meetup_id = p_meetup_id and r.status = 'going';
    if p_capacity < v_going then
      raise exception using errcode='P0001', message='capacity_below_going_count';
    end if;
  end if;

  if p_title         is not null then v_changed := v_changed || to_jsonb('title'::text); end if;
  if p_description   is not null then v_changed := v_changed || to_jsonb('description'::text); end if;
  if p_start_at      is not null then v_changed := v_changed || to_jsonb('start_at'::text); end if;
  if p_end_at        is not null then v_changed := v_changed || to_jsonb('end_at'::text); end if;
  if p_location_name is not null then v_changed := v_changed || to_jsonb('location_name'::text); end if;
  if p_capacity      is not null then v_changed := v_changed || to_jsonb('capacity'::text); end if;

  update public.meetups
     set title         = coalesce(p_title, title),
         description   = coalesce(p_description, description),
         start_at      = v_start,
         end_at        = v_end,
         location_name = coalesce(p_location_name, location_name),
         capacity      = coalesce(p_capacity, capacity),
         updated_at    = now()
   where id = p_meetup_id;

  perform public.emit_event('meetup.updated','meetup', p_meetup_id, me,
                            jsonb_build_object('fields', v_changed));

  return public.rpc_meetup_card(p_meetup_id);
end;
$function$;

-- ============================================================================
-- (g) rpc_meetup_decide_request (new): host approves / declines a pending request
--     on meetup_rsvps. Approve respects capacity (full -> 'interested').
--     Decline -> 'cancelled'. Returns the resulting status.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_decide_request(p_meetup_id uuid, p_user_id uuid, p_decision text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_cur   text;
  v_new   text;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  if p_decision is null or p_decision not in ('approve','decline') then
    raise exception using errcode='P0001', message='invalid_decision';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if m.is_cancelled then
    raise exception using errcode='P0001', message='meetup_cancelled';
  end if;

  select r.status into v_cur
    from public.meetup_rsvps r
   where r.meetup_id = p_meetup_id and r.user_id = p_user_id
   for update;
  if not found or v_cur <> 'pending' then
    raise exception using errcode='P0001', message='no_pending_request';
  end if;

  if p_decision = 'approve' then
    if public.meetup_slots_left(p_meetup_id) <= 0 then
      v_new := 'interested';
    else
      v_new := 'going';
    end if;
    update public.meetup_rsvps
       set status = v_new, updated_at = now()
     where meetup_id = p_meetup_id and user_id = p_user_id;
    perform public.emit_event('meetup.request_approved','meetup', p_meetup_id, me,
              jsonb_build_object('user_id', p_user_id, 'status', v_new));
  else
    v_new := 'cancelled';
    update public.meetup_rsvps
       set status = v_new, updated_at = now()
     where meetup_id = p_meetup_id and user_id = p_user_id;
    perform public.emit_event('meetup.request_declined','meetup', p_meetup_id, me,
              jsonb_build_object('user_id', p_user_id));
  end if;

  return v_new;
end;
$function$;

-- ============================================================================
-- (g, cheap) rpc_meetup_remove_attendee (new): host removes an attendee
--     (going / interested / pending -> cancelled). The host cannot remove self.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me  uuid := auth.uid();
  m   public.meetups%rowtype;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if p_user_id = m.creator_user_id then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  update public.meetup_rsvps
     set status = 'cancelled', updated_at = now()
   where meetup_id = p_meetup_id and user_id = p_user_id
     and status in ('going','interested','pending');
  if not found then
    raise exception using errcode='P0001', message='attendee_not_found';
  end if;

  perform public.emit_event('meetup.attendee_removed','meetup', p_meetup_id, me,
            jsonb_build_object('user_id', p_user_id));
  return 'cancelled';
end;
$function$;

-- ============================================================================
-- (a) Grants. Every meetup WRITE function: no PUBLIC, no anon; authenticated and
--     service_role only. Explicit signatures; asserting the result is the
--     post-condition block below (proacl, not "the revoke ran").
-- ============================================================================
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_rsvp(uuid, text, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_rsvp(uuid, text, uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_cancel(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_cancel(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_set_attendee(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_set_attendee(uuid, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_update(uuid, text, text, timestamp with time zone, timestamp with time zone, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_update(uuid, text, text, timestamp with time zone, timestamp with time zone, text, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_decide_request(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_decide_request(uuid, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_meetup_remove_attendee(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_remove_attendee(uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_draft_publish_meetup(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_meetup(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone) TO authenticated, service_role;

-- Read helpers that stay authenticated-only (see header).
REVOKE ALL ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.meetup_my_status(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.meetup_my_status(uuid, uuid) TO authenticated, service_role;

-- Read helpers that stay anon-callable (visibility-gated inside): re-assert so the
-- intent survives the KAN-189 default-privilege change and any earlier REVOKE.
REVOKE ALL ON FUNCTION public.rpc_meetup_card(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_card(uuid, text) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.meetup_counts(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.meetup_counts(uuid) TO anon, authenticated, service_role;

-- ============================================================================
-- Post-conditions: any failure aborts the whole transaction (nothing is applied).
-- ============================================================================
DO $$
DECLARE
  v_sig text;
  v_oid oid;
BEGIN
  FOREACH v_sig IN ARRAY ARRAY[
    'public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb)',
    'public.rpc_meetup_rsvp(uuid, text, uuid, uuid)',
    'public.rpc_meetup_cancel(uuid)',
    'public.rpc_meetup_set_attendee(uuid, uuid, text)',
    'public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)',
    'public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)',
    'public.rpc_meetup_update(uuid, text, text, timestamp with time zone, timestamp with time zone, text, integer)',
    'public.rpc_meetup_decide_request(uuid, uuid, text)',
    'public.rpc_meetup_remove_attendee(uuid, uuid)',
    'public.rpc_draft_publish_meetup(uuid)',
    'public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone)',
    'public.rpc_meetup_attendees(uuid, text, integer, integer)',
    'public.meetup_my_status(uuid, uuid)'
  ] LOOP
    v_oid := v_sig::regprocedure;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: anon can still EXECUTE %', v_sig;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_proc p,
             aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
       WHERE p.oid = v_oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: PUBLIC can still EXECUTE %', v_sig;
    END IF;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated cannot EXECUTE %', v_sig;
    END IF;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % is not SECURITY DEFINER', v_sig;
    END IF;
    IF (SELECT proconfig FROM pg_proc WHERE oid = v_oid) IS NULL THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % has no search_path', v_sig;
    END IF;
  END LOOP;

  -- Readers of meetup_rsvps must be definer functions now that the table grants
  -- are revoked; anon keeps EXECUTE on can_current_user_rsvp_meetup by design.
  FOREACH v_sig IN ARRAY ARRAY[
    'public.can_current_user_rsvp_meetup(uuid, uuid)',
    'public.meetup_slots_left(uuid)'
  ] LOOP
    v_oid := v_sig::regprocedure;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % is not SECURITY DEFINER', v_sig;
    END IF;
    IF (SELECT proconfig FROM pg_proc WHERE oid = v_oid) IS NULL THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % has no search_path', v_sig;
    END IF;
  END LOOP;

  -- meetup_slots_left is closed to clients (see the grants after section (c)).
  v_oid := 'public.meetup_slots_left(uuid)'::regprocedure;
  IF has_function_privilege('anon', v_oid, 'EXECUTE')
     OR has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: anon/authenticated can EXECUTE meetup_slots_left(uuid)';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_proc p,
           aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
     WHERE p.oid = v_oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: PUBLIC can EXECUTE meetup_slots_left(uuid)';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_policy
              WHERE polrelid = 'public.meetup_rsvps'::regclass AND polname = 'rsvp_self_write') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: rsvp_self_write still present';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'v_meetup_list'
                AND column_name = 'creator_user_id') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: v_meetup_list still exposes creator_user_id';
  END IF;

  IF NOT has_table_privilege('anon', 'public.v_meetup_list', 'SELECT') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: anon lost SELECT on v_meetup_list (T-002 allowlist surface)';
  END IF;

  IF has_table_privilege('anon', 'public.v_meetup_counts', 'SELECT') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: anon can read v_meetup_counts';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public'
                AND p.proname IN ('rpc_meetup_create', 'rpc_meetup_unrsvp')) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: a retired duplicate still exists';
  END IF;

  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_meetup_cancel(uuid)'::regprocedure) ~ 'owner_user_id' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: rpc_meetup_cancel still references owner_user_id';
  END IF;
END $$;

COMMIT;
