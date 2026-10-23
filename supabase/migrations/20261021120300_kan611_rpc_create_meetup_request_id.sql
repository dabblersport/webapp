-- KAN-611 (4 of 4): rpc_create_meetup gains p_request_id.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it after 20261021120200 (execute_sql only, never apply_migration).
-- Project wtncuzcskpigqpmnxwws only.
--
-- The 20-argument rpc_create_meetup (20261008140000) is renamed rpc_create_meetup_legacy_v2 and closed to clients. The
-- new 21-argument rpc_create_meetup is a thin wrapper:
--   * no p_request_id: calls the legacy body unchanged (today's behaviour);
--   * with p_request_id: FIRST (before every guard and limit) looks up (creator_user_id = effective_actor_uid(),
--     request_id) and returns that meetup's uuid, consuming nothing; otherwise sets the stamping setting, calls the
--     legacy body (all guards run), clears the setting;
--   * a concurrent twin that loses on meetups_creator_user_request_id_key gets the winner's uuid; anything else re-raises.
--
-- ACL (orchestrator ruling): EXECUTE for authenticated and service_role only; PUBLIC and anon revoked and asserted.

DO $pre$
BEGIN
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'rpc_create_meetup') <> 1 THEN
    RAISE EXCEPTION 'KAN611 pre-check: expected exactly one public.rpc_create_meetup overload';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'rpc_create_meetup_legacy_v2') THEN
    RAISE EXCEPTION 'KAN611 pre-check: public.rpc_create_meetup_legacy_v2 already exists';
  END IF;
END
$pre$;

ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) RENAME TO rpc_create_meetup_legacy_v2;

REVOKE ALL ON FUNCTION public.rpc_create_meetup_legacy_v2(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; mid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_user_id = v_uid AND m.request_id = p_request_id;
    IF mid IS NOT NULL THEN RETURN mid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'meetups_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_user_id = v_uid AND m.request_id = p_request_id;
    IF mid IS NULL THEN RAISE; END IF;
    RETURN mid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) TO authenticated, service_role;

DO $post$
DECLARE f regprocedure := 'public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)'::regprocedure;
BEGIN
  IF (SELECT proacl FROM pg_proc WHERE oid = f) IS NULL
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                 WHERE p.oid = f AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN611 post-check: rpc_create_meetup is executable by PUBLIC or anon';
  END IF;
END
$post$;
