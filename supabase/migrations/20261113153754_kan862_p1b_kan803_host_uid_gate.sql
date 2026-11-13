-- KAN-862 P1b: close the kan803_game_host_uid leak (PEER review, KAN-862 comment 16219).
-- public.kan803_game_host_uid(uuid) is SECURITY DEFINER and returned events.creator_user_id for ANY game id to any
-- authenticated caller. It becomes postgres/service_role-only, as public.kan804_game_event_facts already is. Its three
-- direct callers (SECURITY INVOKER trigger functions) gate on games visibility as the calling role first (the KAN-804
-- pattern) and call the helper only for a caller that sees the game, so a client that cannot see the game still gets
-- P0001 game_not_found (never 42501) and the helper is never executed under the client role.
-- Bodies re-authored from live pg_get_functiondef (2026-11-13); pre-image md5(prosrc) guarded below.
-- Applied live on wtncuzcskpigqpmnxwws via apply_migration, recorded version 20261113153754.
-- Proof: supabase/tests/events_p4/kan803_p1b_live_test.sql.
DO $pre$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure) <> '3e6e858b0fb1d80d09e2db2a9bfe770b'
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trgfn_invite_block_frozen_guard()'::regprocedure) <> '81e302c646fd39c0c809009d4debc382'
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure) <> 'a883c3cb708111f5e52f441e3c9e26d3'
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure) <> '03296c42de73e93b4b5eefba9583e2ba'
  THEN
    RAISE EXCEPTION 'KAN-862 P1b: live pre-image drifted; re-author from pg_get_functiondef';
  END IF;
END $pre$;

CREATE OR REPLACE FUNCTION public.trgfn_invite_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
  game_visible boolean;
begin
  -- KAN-862 P1b: games RLS gate as the calling role; the host comes from events only for a caller that sees the game.
  perform 1 from public.games g where g.id = new.game_id;
  game_visible := found;
  if game_visible then
    host_uid := public.kan803_game_host_uid(new.game_id);
  end if;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  perform public.guard_user_not_frozen(new.to_user_id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_joinreq_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
  game_visible boolean;
begin
  -- KAN-862 P1b: games RLS gate as the calling role; the host comes from events only for a caller that sees the game.
  perform 1 from public.games g where g.id = new.game_id;
  game_visible := found;
  perform public.guard_user_not_frozen(new.from_user_id);
  if game_visible then
    host_uid := public.kan803_game_host_uid(new.game_id);
  end if;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_waitlist_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
  game_visible boolean;
begin
  -- KAN-862 P1b: games RLS gate as the calling role; the host comes from events only for a caller that sees the game.
  perform 1 from public.games g where g.id = new.game_id;
  game_visible := found;
  perform public.guard_user_not_frozen(new.user_id);
  if game_visible then
    host_uid := public.kan803_game_host_uid(new.game_id);
  end if;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.kan803_game_host_uid(uuid) FROM PUBLIC, anon, authenticated;

DO $post$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure;
  IF NOT (r.proowner = 'postgres'::regrole AND r.prosecdef AND r.provolatile = 's'
          AND r.proconfig::text = '{"search_path=public, pg_temp"}' AND md5(r.prosrc) = '3e6e858b0fb1d80d09e2db2a9bfe770b'
          AND r.proacl::text = '{postgres=X/postgres,service_role=X/postgres}') THEN
    RAISE EXCEPTION 'KAN-862 P1b: helper post-state wrong: %', r.proacl;
  END IF;
  FOR r IN SELECT * FROM pg_proc WHERE oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure,
      'public.trgfn_joinreq_block_frozen_guard()'::regprocedure, 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure) LOOP
    IF NOT (r.proowner = 'postgres'::regrole AND NOT r.prosecdef AND r.provolatile = 'v'
            AND r.proconfig::text = '{"search_path=public, pg_temp"}'
            AND r.proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
            AND position('game_visible := found' IN r.prosrc) > 0) THEN
      RAISE EXCEPTION 'KAN-862 P1b: % post-state wrong: %', r.proname, r.proacl;
    END IF;
  END LOOP;
END $post$;
