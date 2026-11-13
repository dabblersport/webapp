-- KAN-717 F6: rpc_create_meetup fails 23502 null value in column "host_actor_id" of relation "meetups".
--
-- Raising frame (reproduced live as user a3ba3271, role authenticated, BEGIN ... ROLLBACK):
--   rpc_create_meetup -> rpc_create_meetup_legacy_v2, INSERT INTO public.meetups.
-- Cause: meetups.host_actor_id (FK profiles.id ON DELETE CASCADE) has been NOT NULL with no default since the
-- baseline (20260829080500_baseline_schema.sql line 23100), and no trigger assigns it. Every version of the app
-- create path has omitted it from its INSERT: baseline line 11815 (rpc_create_meetup), 20260915120000_meetups_hardening
-- line 311, 20261008140000_game_price_meetup_setting line 543, carried into rpc_create_meetup_legacy_v2 since.
-- No user-created meetup exists on the project: of 32 rows, 28 are run_seed_meetup_template rows and 4 are direct
-- demo inserts (request_id NULL); run_seed_meetup_template sets host_actor_id = creator_profile_id, and all 32 rows
-- have host_actor_id = creator_profile_id. rpc_meetup_card exposes it as actor_profile_id (the host's profile).
-- Fix: the INSERT writes host_actor_id = pid, the acting creator profile (the same value as creator_profile_id),
-- matching run_seed_meetup_template and every existing row. Nothing else in the body changes.
--
-- Re-authored from live pg_get_functiondef (2026-11-13). Signature, SECURITY DEFINER, search_path, owner and grants
-- unchanged (CREATE OR REPLACE keeps proacl {postgres=X/postgres,service_role=X/postgres}). rpc_create_meetup itself
-- (md5 f347168e1c1a6b424ebabea41ff3e85f) is not touched.

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure)
     IS DISTINCT FROM 'c407d08bdcfcf1f9cce621bf82fd1017' THEN
    RAISE EXCEPTION 'KAN-717 F6: pre-image md5 of rpc_create_meetup_legacy_v2 differs; refusing';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.rpc_create_meetup_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean)
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

  -- KAN-439 (CEO ruling 2026-10-06): player and organiser personas may create; socialiser and
  -- host may not.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles pr
    WHERE pr.id = pid AND pr.user_id = public.effective_actor_uid() AND pr.is_active = true
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_owned';
  END IF;
  IF NOT public.can_create_meetup(pid) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;

  IF COALESCE(p_listing_visibility, 'public') <> 'public' THEN
    RAISE EXCEPTION USING errcode='P0001', message='visibility_not_supported';
  END IF;

  IF p_meta IS NOT NULL AND (
       COALESCE(p_meta->>'joining_rule', 'free') <> 'free'
    OR COALESCE(p_meta->>'cost_cover',   'free') <> 'free'
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  IF p_location_name IS NULL OR trim(p_location_name) = '' THEN
    RAISE EXCEPTION USING errcode='P0001', message='location_name_required';
  END IF;

  -- CEO 2026-10-08: with no venue the host must say Indoor or Outdoor.
  IF p_venue_id IS NULL AND p_is_indoor IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='setting_required';
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
    host_actor_id,  -- KAN-717 F6: NOT NULL, no default; the host is the acting creator profile
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
    meta,
    is_indoor
  )
  VALUES (
    pid,
    uid,
    pid,
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
    COALESCE(p_meta, '{}'),
    CASE WHEN p_venue_id IS NULL THEN p_is_indoor ELSE NULL END
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

DO $post$
BEGIN
  IF (SELECT proacl::text || '|' || prosecdef || '|' || array_to_string(proconfig, ',') || '|' || pg_get_userbyid(proowner)
        FROM pg_proc WHERE oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure)
     IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}|true|search_path=public, pg_temp|postgres' THEN
    RAISE EXCEPTION 'KAN-717 F6: post-image attributes or ACL changed; refusing';
  END IF;
END
$post$;
