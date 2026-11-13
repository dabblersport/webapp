-- KAN-646 rollback. Code/exposure only; no data is touched and no persona is rewritten. No DROP:
-- every patched function is restored from the LIVE body by swapping the KAN-646 fragment back to the
-- original (inverse of the migration; raises kan646_rollback_drift if the live body is not the KAN-646
-- one). actor_is_host is made inert (EXECUTE revoked from every client role) instead of dropped.
SELECT 'aggregate counts (informational)' AS note,
       (SELECT count(*) FROM public.profiles WHERE persona_type = 'contributor') AS contributors,
       (SELECT count(*) FROM public.profiles WHERE persona_type = 'partner')     AS partners;

CREATE FUNCTION pg_temp.kan646_unpatch(p_sig regprocedure, p_new text, p_old text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v_def text := pg_get_functiondef(p_sig);
  v_acl text := (SELECT proacl::text FROM pg_proc WHERE oid = p_sig);
  v_n   int;
BEGIN
  v_n := (length(v_def) - length(replace(v_def, p_new, ''))) / length(p_new);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'kan646_rollback_drift: % expected the KAN-646 fragment exactly once, found %', p_sig, v_n;
  END IF;
  EXECUTE replace(v_def, p_new, p_old);
  IF (SELECT proacl::text FROM pg_proc WHERE oid = p_sig) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'kan646_rollback_acl_changed: %', p_sig;
  END IF;
END $f$;

SELECT pg_temp.kan646_unpatch('public.choose_actor(text)'::regprocedure,
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
  IF v_pid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='no_profile_of_requested_type'; END IF;$n$,
$o$  IF v_pid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='no_profile_of_requested_type'; END IF;$o$);

SELECT pg_temp.kan646_unpatch('public.actor_is_player(uuid)'::regprocedure,
$n$      AND is_active = true
      AND (persona_type = 'player'
           OR (persona_type = 'contributor'
               AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = p_profile_id)))
  )$n$,
$o$      AND persona_type = 'player'
      AND is_active = true
  )$o$);

SELECT pg_temp.kan646_unpatch('public.actor_is_organiser(uuid)'::regprocedure,
$n$    where id = p_profile_id and is_active = true
      and (profile_type = 'organiser'
           or (persona_type = 'contributor'
               and exists (select 1 from public.organiser x where x.profile_id = p_profile_id)))
$n$,
$o$    where id = p_profile_id and profile_type = 'organiser' and is_active = true
$o$);

SELECT pg_temp.kan646_unpatch('public.can_create_meetup(uuid)'::regprocedure,
$n$         and (pp.persona_type in ('player', 'organiser')
              or (pp.persona_type = 'contributor'
                  and (exists (select 1 from public.player x where x.profile_id = pp.id)
                       or exists (select 1 from public.organiser x where x.profile_id = pp.id))))
$n$,
$o$         and pp.persona_type in ('player', 'organiser')
$o$);

SELECT pg_temp.kan646_unpatch('public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)'::regprocedure,
$n$      AND (persona_type IN ('player', 'organiser')
           OR (persona_type = 'contributor' AND (
                 (p_actor_type = 'player' AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pid))
              OR (p_actor_type = 'organiser' AND EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = pid)))))
$n$,
$o$      AND persona_type IN ('player', 'organiser')
$o$);

SELECT pg_temp.kan646_unpatch('public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure,
$n$  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND persona_type = 'player')
     AND NOT EXISTS (SELECT 1 FROM public.profiles pc
                     WHERE pc.id = p_profile_id AND pc.persona_type = 'contributor' AND pc.is_active = true
                       AND pc.user_id = public.effective_actor_uid()
                       AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pc.id)) THEN
$n$,
$o$  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND persona_type = 'player') THEN
$o$);

REVOKE ALL ON FUNCTION public.actor_is_host(uuid) FROM authenticated, service_role;
