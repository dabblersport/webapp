-- KAN-911 (Epic KAN-714): public.rpc_create_game -- verbatim record of the live body; a no-op on apply.
--
-- The live body already reads the KAN-866 facts from events: the idempotency lookup is
-- kan714_games_read g JOIN events e ... WHERE e.creator_profile_id = pid AND e.request_id = p_request_id (KAN-823).
-- Every other path delegates to public.rpc_create_game_legacy_v2 (a separate object, not in this ticket).
-- It never names public.games. This migration records the live body in the repo and changes nothing.
--
-- The CREATE OR REPLACE below is pg_get_functiondef of the live function on 2026-11-13 (T-058), byte-exact:
-- md5(prosrc) 1b3aa6f2b8033bdf64c5bc856d6c7f43, md5(pg_get_functiondef) 58605023253923f46847ad106c724df3. CREATE OR REPLACE keeps oid, owner and ACL
-- ({postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}). The guard refuses on drift; the post check asserts the functiondef md5 and ACL unchanged.
-- ROLLBACK: none needed (the body is unchanged).
-- Test: supabase/tests/events_p4/kan714_w_rpc_create_game_live_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)');
begin
  if v_oid is null then raise exception 'KAN-911 pre: rpc_create_game absent'; end if;
  if (select md5(prosrc) from pg_proc where oid = v_oid) <> '1b3aa6f2b8033bdf64c5bc856d6c7f43' then
    raise exception 'KAN-911 pre: pre-image drift on rpc_create_game; re-author from pg_get_functiondef';
  end if;
end
$guard$;

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

do $post$
declare v_oid oid := to_regprocedure('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)');
begin
  if md5(pg_get_functiondef(v_oid)) <> '58605023253923f46847ad106c724df3' then
    raise exception 'KAN-911 post: functiondef md5 changed';
  end if;
  if (select proacl::text from pg_proc where oid = v_oid) <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
    raise exception 'KAN-911 post: ACL changed';
  end if;
end
$post$;
