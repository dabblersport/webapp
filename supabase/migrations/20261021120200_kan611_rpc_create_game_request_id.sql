-- KAN-611 (3 of 4): rpc_create_game gains p_request_id.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it after 20261021120100 (execute_sql only, never apply_migration).
-- Project wtncuzcskpigqpmnxwws only.
--
-- The 25-argument rpc_create_game (20261008140000) is renamed rpc_create_game_legacy_v2 and closed to clients. The new
-- 26-argument rpc_create_game is a thin wrapper:
--   * no p_request_id: calls the legacy body unchanged (today's behaviour);
--   * with p_request_id: FIRST (before every guard and limit) looks up (creator_user_id = effective_actor_uid(),
--     request_id) and returns that game's uuid, same shape as the first success, consuming nothing; otherwise sets the
--     stamping setting, calls the legacy body (all guards run), clears the setting;
--   * a concurrent twin that loses on games_creator_user_request_id_key gets the winner's uuid; anything else re-raises.
--
-- ACL (orchestrator ruling): EXECUTE for authenticated and service_role only; PUBLIC and anon revoked and asserted.
-- This is a TIGHTENING: 20261008140000 recorded rpc_create_game as granted to anon. Memphis confirms the live ACL
-- before apply (supabase/tests/idempotency/README.md).

DO $pre$
BEGIN
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'rpc_create_game') <> 1 THEN
    RAISE EXCEPTION 'KAN611 pre-check: expected exactly one public.rpc_create_game overload';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'rpc_create_game_legacy_v2') THEN
    RAISE EXCEPTION 'KAN611 pre-check: public.rpc_create_game_legacy_v2 already exists';
  END IF;
END
$pre$;

ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) RENAME TO rpc_create_game_legacy_v2;

REVOKE ALL ON FUNCTION public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; gid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT g.id INTO gid FROM public.games g WHERE g.creator_user_id = v_uid AND g.request_id = p_request_id;
    IF gid IS NOT NULL THEN RETURN gid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'games_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT g.id INTO gid FROM public.games g WHERE g.creator_user_id = v_uid AND g.request_id = p_request_id;
    IF gid IS NULL THEN RAISE; END IF;
    RETURN gid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) TO authenticated, service_role;

DO $post$
DECLARE f regprocedure := 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure;
BEGIN
  IF (SELECT proacl FROM pg_proc WHERE oid = f) IS NULL
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                 WHERE p.oid = f AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN611 post-check: rpc_create_game is executable by PUBLIC or anon';
  END IF;
END
$post$;
