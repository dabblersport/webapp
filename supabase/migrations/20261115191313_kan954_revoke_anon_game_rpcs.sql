-- KAN-954 (security): anon and PUBLIC could EXECUTE four game RPCs whose owner guards compare against auth.uid(),
-- which is NULL for anon, so the guard evaluates to NULL and is skipped (anon could spawn a game from any challenge
-- fixture). CEO option 1: REVOKE EXECUTE FROM PUBLIC, anon. authenticated and service_role keep EXECUTE, postgres
-- keeps ownership. No function body changes. Applied under G-002 by backend-3.
-- Callers: no lib/, workers/ or supabase/functions/ call site. The only SQL caller is rpc_join_game (SECURITY DEFINER,
-- owner postgres) -> can_current_user_join_game, which runs as postgres and is unaffected.
DO $pre$
DECLARE r record; v_bad text := '';
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig, p.proacl::text AS acl FROM pg_proc p
            WHERE p.oid IN ('public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)'::regprocedure,
                            'public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)'::regprocedure,
                            'public.rpc_reschedule_game(uuid,timestamptz,timestamptz)'::regprocedure,
                            'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure)
  LOOP
    IF (SELECT array_agg(x ORDER BY x) FROM unnest(r.acl::aclitem[]::text[]) x)
       IS DISTINCT FROM ARRAY['=X/postgres','anon=X/postgres','authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
       OR pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid = r.sig)) <> 'postgres' THEN
      v_bad := v_bad || format('%s %s; ', r.sig, r.acl);
    END IF;
  END LOOP;
  IF v_bad <> '' THEN RAISE EXCEPTION 'KAN-954 pre-image ACL mismatch: %', v_bad; END IF;
END
$pre$;

REVOKE EXECUTE ON FUNCTION public.rpc_challenge_spawn_game(uuid, timestamptz, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_booking_hold_for_game(uuid, uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_reschedule_game(uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.can_current_user_join_game(uuid, text, uuid) FROM PUBLIC, anon;

-- idempotent: the explicit grants already exist; restated so the post-image does not depend on it
GRANT EXECUTE ON FUNCTION public.rpc_challenge_spawn_game(uuid, timestamptz, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_booking_hold_for_game(uuid, uuid, timestamptz, timestamptz) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_reschedule_game(uuid, timestamptz, timestamptz) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_current_user_join_game(uuid, text, uuid) TO authenticated, service_role;

DO $post$
DECLARE r record; v_bad text := '';
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig, p.proacl::text AS acl FROM pg_proc p
            WHERE p.oid IN ('public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)'::regprocedure,
                            'public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)'::regprocedure,
                            'public.rpc_reschedule_game(uuid,timestamptz,timestamptz)'::regprocedure,
                            'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure)
  LOOP
    IF (SELECT array_agg(x ORDER BY x) FROM unnest(r.acl::aclitem[]::text[]) x)
       IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
       OR has_function_privilege('anon', r.sig, 'EXECUTE') THEN
      v_bad := v_bad || format('%s %s; ', r.sig, r.acl);
    END IF;
  END LOOP;
  IF v_bad <> '' THEN RAISE EXCEPTION 'KAN-954 post-image ACL mismatch: %', v_bad; END IF;
END
$post$;
