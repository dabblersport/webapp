-- KAN-646 (Personas S3): server capability and actor compatibility for Contributor and Partner.
-- Depends on KAN-644 (20261026100000) ONLY: persona CHECK incl. contributor/partner and the extension
-- tables' v2 guards. It does NOT depend on KAN-645's RPC (S2) and neither calls nor replaces it.
-- AUTHORED, NOT APPLIED. Ops (Memphis) applies it; probes: supabase/tests/kan646_personas_s3/probes.sql.
--
-- Capability truth table (never set true blindly; the legacy predicate is kept verbatim and OR-ed):
--   player    = legacy predicate  OR (persona_type = 'contributor' AND a public.player row on the SAME id)
--   organiser = legacy predicate  OR (persona_type = 'contributor' AND a public.organiser row on the SAME id)
--   host      = legacy predicate  OR (persona_type = 'partner'     AND a public.host row on the SAME id)
-- Authorization is persona_type + extension row only. profile_type / intention / is_player (the legacy
-- carriers) and JWT user_metadata are never read as Contributor/Partner authorization. No GUC-only path.
--
-- HOW EVERY REPLACEMENT IS AUTHORED (T-058): no function body is typed from a migration file. Each
-- existing function is re-created from pg_get_functiondef() on the LIVE catalogue with exactly one
-- textual fragment swapped. If the live body has drifted (old fragment not present exactly once) the
-- migration raises kan646_drift and nothing is applied. CREATE OR REPLACE keeps oid, owner,
-- SECURITY DEFINER/INVOKER, search_path and ACL; the ACL is still asserted unchanged after each swap.
--
-- Touched (signature, grants and attributes unchanged):
--   choose_actor(text)                      same-id fallback for contributor/partner AFTER the legacy exact match
--   actor_is_player(uuid)                   + contributor with player row
--   actor_is_organiser(uuid)                + contributor with organiser row (legacy branch kept as is: finding F1)
--   can_create_meetup(uuid)                 + contributor with player or organiser row
--   rpc_create_game_legacy_v2(...25 args)   persona gate + contributor with the row matching p_actor_type
--   rpc_create_sport_profile(uuid,uuid,text,integer)  + OWNED active contributor with player row
-- New: actor_is_host(uuid) (host truth table). EXECUTE: authenticated, service_role. Never PUBLIC/anon.
--
-- NOT touched, deliberately: rpc_onboard_unified_profile, rpc_onboard_profile, trgfn_*_v2,
-- trgfn_unified_persona_guard, trgfn_contributor_sports_check (S1/S2); every squad RPC (blocker B1 in
-- docs/personas/kan646_operation_matrix.md); trgfn_block_hoster_social (blocker B3); RLS policies; grants.
-- Unchanged by construction: gtype from p_actor_type, price/free-meetup/commission rules, block/frozen
-- checks, lifecycle/capacity rules, squad caps (all live outside the swapped fragments).

CREATE FUNCTION pg_temp.kan646_patch(p_sig regprocedure, p_old text, p_new text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v_def  text := pg_get_functiondef(p_sig);
  v_acl  text := (SELECT proacl::text FROM pg_proc WHERE oid = p_sig);
  v_n    int;
BEGIN
  v_n := (length(v_def) - length(replace(v_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'kan646_drift: % expected the old fragment exactly once, found %', p_sig, v_n;
  END IF;
  EXECUTE replace(v_def, p_old, p_new);
  IF strpos(pg_get_functiondef(p_sig), p_new) = 0 THEN
    RAISE EXCEPTION 'kan646_patch_not_applied: %', p_sig;
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = p_sig) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'kan646_acl_changed: %', p_sig;
  END IF;
END $f$;

-- 1. choose_actor: the legacy exact match runs first and is unchanged. Only when it finds nothing does a
--    unified account's single profile answer player/organiser (Contributor) or host (Partner), on the SAME
--    profiles.id, owned (user_id = effective_actor_uid()), active, and only with the matching extension
--    row. Default 'player' and the error code are unchanged. SECURITY DEFINER reads extension rows past RLS.
SELECT pg_temp.kan646_patch('public.choose_actor(text)'::regprocedure,
$o$  IF v_pid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='no_profile_of_requested_type'; END IF;$o$,
$n$  -- KAN-646: unified-account fallback (same profiles.id, extension row required).
  IF v_pid IS NULL AND p_profile_type IN ('player', 'organiser', 'host') THEN
    SELECT p.id INTO v_pid FROM public.profiles p
    WHERE p.user_id = v_uid AND p.is_active = true
      AND (
           (p_profile_type = 'player' AND p.persona_type = 'contributor'
              AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = p.id))
        OR (p_profile_type = 'organiser' AND p.persona_type = 'contributor'
              AND EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = p.id))
        OR (p_profile_type = 'host' AND p.persona_type = 'partner'
              AND EXISTS (SELECT 1 FROM public.host x WHERE x.profile_id = p.id))
      )
    ORDER BY p.created_at LIMIT 1;
  END IF;
  IF v_pid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='no_profile_of_requested_type'; END IF;$n$);

-- 2. actor_is_player (SQL, invoker). From definer callers it reads public.player past RLS; from the one
--    invoker caller (can_current_user_join_game) it is asked about the caller's own actor, which
--    player_profiles_select_own lets the caller read. Asked about ANOTHER user's contributor under an
--    invoker role it returns false: fails closed (matrix note N2).
SELECT pg_temp.kan646_patch('public.actor_is_player(uuid)'::regprocedure,
$o$      AND persona_type = 'player'
      AND is_active = true
  )$o$,
$n$      AND is_active = true
      AND (persona_type = 'player'
           OR (persona_type = 'contributor'
               AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = p_profile_id)))
  )$n$);

-- 3. actor_is_organiser (legacy branch kept verbatim; it matches no live row: finding F1)
SELECT pg_temp.kan646_patch('public.actor_is_organiser(uuid)'::regprocedure,
$o$    where id = p_profile_id and profile_type = 'organiser' and is_active = true
$o$,
$n$    where id = p_profile_id and is_active = true
      and (profile_type = 'organiser'
           or (persona_type = 'contributor'
               and exists (select 1 from public.organiser x where x.profile_id = p_profile_id)))
$n$);

-- 4. can_create_meetup: ownership/active check above it is unchanged; persona clause gains contributor.
SELECT pg_temp.kan646_patch('public.can_create_meetup(uuid)'::regprocedure,
$o$         and pp.persona_type in ('player', 'organiser')
$o$,
$n$         and (pp.persona_type in ('player', 'organiser')
              or (pp.persona_type = 'contributor'
                  and (exists (select 1 from public.player x where x.profile_id = pp.id)
                       or exists (select 1 from public.organiser x where x.profile_id = pp.id))))
$n$);

-- 5. rpc_create_game_legacy_v2 persona gate (KAN-440). Owner/active/effective_actor_uid lines unchanged.
--    A contributor passes only with the extension row matching the REQUESTED role; gtype is still
--    derived from p_actor_type further down (organiser -> hosted, otherwise casual). Price rule untouched.
SELECT pg_temp.kan646_patch('public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)'::regprocedure,
$o$      AND persona_type IN ('player', 'organiser')
$o$,
$n$      AND (persona_type IN ('player', 'organiser')
           OR (persona_type = 'contributor' AND (
                 (p_actor_type = 'player' AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pid))
              OR (p_actor_type = 'organiser' AND EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = pid)))))
$n$);

-- 6. rpc_create_sport_profile: the legacy branch (persona_type = 'player', no ownership test) is kept
--    exactly as it is (finding F2). The contributor branch is stricter: owned by the caller, active, with
--    a player row. KAN-644's deferred contributor_sports_check still requires the sport to be in Following.
SELECT pg_temp.kan646_patch('public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure,
$o$  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND persona_type = 'player') THEN
$o$,
$n$  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND persona_type = 'player')
     AND NOT EXISTS (SELECT 1 FROM public.profiles pc
                     WHERE pc.id = p_profile_id AND pc.persona_type = 'contributor' AND pc.is_active = true
                       AND pc.user_id = public.effective_actor_uid()
                       AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pc.id)) THEN
$n$);

-- 7. actor_is_host: host truth table. New function, so its ACL is set explicitly (pg_default_acl grants
--    anon by name on public; revoking PUBLIC alone would leave anon able to execute).
CREATE FUNCTION public.actor_is_host(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_profile_id
      AND p.is_active = true
      AND (p.persona_type = 'host'
           OR (p.persona_type = 'partner'
               AND EXISTS (SELECT 1 FROM public.host x WHERE x.profile_id = p.id)))
  )
$function$;
REVOKE ALL ON FUNCTION public.actor_is_host(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.actor_is_host(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.actor_is_host(uuid) TO authenticated, service_role;

-- 8. Post-conditions: assert the resulting ACL, not that the statements ran.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
             WHERE p.oid = 'public.actor_is_host(uuid)'::regprocedure
               AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'kan646_acl: actor_is_host is executable by PUBLIC or anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.actor_is_host(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.actor_is_host(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan646_acl: actor_is_host missing authenticated/service_role EXECUTE';
  END IF;
  IF has_function_privilege('anon', 'public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan646_acl: rpc_create_game_legacy_v2 became client-executable';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.choose_actor(text)'::regprocedure)
     IS DISTINCT FROM '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan646_acl: choose_actor ACL differs from the pre-migration live value';
  END IF;
END $$;
