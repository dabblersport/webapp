-- KAN-717 F2 (Events P3 verification; defect list KAN-766 comment 15476): public.rpc_leave_game guards with
-- IF NOT was_active, but UPDATE ... RETURNING true INTO was_active leaves was_active NULL when no active roster row
-- matches. NOT NULL is NULL, the IF is not taken, and a caller who is not on the roster falls through to the
-- waitlist promotion: the head of the waitlist is put on the roster and removed from the waitlist, and the caller is
-- told 'left_promoted_waitlist'. Any authenticated user could promote the waitlist of any game.
--
-- FIX. IF NOT coalesce(was_active, false): a caller with no active row gets 'not_on_roster' and nothing changes.
-- A real leaver is unchanged (was_active true): the head of the waitlist is still promoted.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058): pg_get_functiondef on wtncuzcskpigqpmnxwws, md5(prosrc) b03b0e3a7317b07cfa42969be0b748c1.
-- HOW. CREATE OR REPLACE with the same signature: keeps oid, owner postgres, ACL
-- {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}, SECURITY DEFINER,
-- VOLATILE, SET search_path TO 'public'. Pinned on the pre-image md5; asserts the post-image md5 855da1d72ca481856e3401c4f66a0aea and unchanged
-- attributes/ACL. Re-running at the post-image is a no-op. No BEGIN/COMMIT (the CLI wraps each migration).
--
-- Live proof: supabase/tests/events_p4/kan717_f2_rpc_leave_game_test.sql (BEGIN ... ROLLBACK).
--
-- ROLLBACK (verbatim live pre-image, md5(prosrc) b03b0e3a7317b07cfa42969be0b748c1). Run uncommented, as postgres:
-- CREATE OR REPLACE FUNCTION public.rpc_leave_game(p_actor_type text, p_game_id uuid)
--  RETURNS text
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- DECLARE
--   pid uuid := public.choose_actor(p_actor_type);
--   was_active boolean;
--   w_profile uuid;
--   upsert_ct int := 0;
-- BEGIN
--   UPDATE public.game_roster
--      SET status = 'left', left_at = now()
--    WHERE game_id = p_game_id AND profile_id = pid AND status = 'active'
--   RETURNING true INTO was_active;
--   IF NOT was_active THEN RETURN 'not_on_roster'; END IF;
--   SELECT wl.profile_id INTO w_profile
--   FROM public.game_waitlist wl WHERE wl.game_id = p_game_id
--   ORDER BY wl.position ASC LIMIT 1;
--   IF w_profile IS NULL THEN RETURN 'left'; END IF;
--   INSERT INTO public.game_roster (game_id, profile_id, role, status)
--   VALUES (p_game_id, w_profile, 'player', 'active')
--   ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
--   GET DIAGNOSTICS upsert_ct = ROW_COUNT;
--   DELETE FROM public.game_waitlist WHERE game_id = p_game_id AND profile_id = w_profile;
--   IF upsert_ct > 0 THEN RETURN 'left_promoted_waitlist'; ELSE RETURN 'left'; END IF;
-- END;
-- $function$;

do $kan717f2$
declare
  c_sig  constant text := 'public.rpc_leave_game(text,uuid)';
  c_pre  constant text := 'b03b0e3a7317b07cfa42969be0b748c1';
  c_post constant text := '855da1d72ca481856e3401c4f66a0aea';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise exception 'kan717f2 pre: % is absent', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 = c_post then
    raise notice 'kan717f2: % already fixed (md5(prosrc) %); nothing to do', c_sig, v_md5;
    return;
  end if;
  if v_md5 <> c_pre then
    raise exception 'kan717f2 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;

  execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_leave_game(p_actor_type text, p_game_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  pid uuid := public.choose_actor(p_actor_type);
  was_active boolean;
  w_profile uuid;
  upsert_ct int := 0;
BEGIN
  UPDATE public.game_roster
     SET status = 'left', left_at = now()
   WHERE game_id = p_game_id AND profile_id = pid AND status = 'active'
  RETURNING true INTO was_active;
  IF NOT coalesce(was_active, false) THEN RETURN 'not_on_roster'; END IF;   -- KAN-717 F2: no row updated leaves was_active NULL
  SELECT wl.profile_id INTO w_profile
  FROM public.game_waitlist wl WHERE wl.game_id = p_game_id
  ORDER BY wl.position ASC LIMIT 1;
  IF w_profile IS NULL THEN RETURN 'left'; END IF;
  INSERT INTO public.game_roster (game_id, profile_id, role, status)
  VALUES (p_game_id, w_profile, 'player', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  GET DIAGNOSTICS upsert_ct = ROW_COUNT;
  DELETE FROM public.game_waitlist WHERE game_id = p_game_id AND profile_id = w_profile;
  IF upsert_ct > 0 THEN RETURN 'left_promoted_waitlist'; ELSE RETURN 'left'; END IF;
END;
$function$
$ddl$;

  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'kan717f2 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_post then
    raise exception 'kan717f2 post: % body md5 is %, expected %', c_sig, v_md5, c_post;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'kan717f2 post: % attributes or ACL changed: % -> %', c_sig, v_before, v_after;
  end if;
end
$kan717f2$;
