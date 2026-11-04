-- KAN-807 (supporting KAN-778 / KAN-719, a KAN-781 finding): D04 residual, part (b). These SECURITY DEFINER
-- functions still read games / meetups columns that KAN-719 Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql)
-- drops, so after Z01 they raise 42703. Each body stops reading those columns and reads them from public.events
-- (games.event_id / meetups.event_id -> events.id), which every body here already joins.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan807_d04_residual_test.sql (throwaway PG16, KAN-781 judge chain + D04).
-- Part (a) is the other file of this ticket; the two are independent and may be applied in either order.
--
--   function                                                                                     removed read
--   public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)                                          g0.creator_user_id, g0.start_at, g0.is_cancelled -> e.creator_user_id, e.start_at, e.is_cancelled
--   public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)                                         g0.creator_user_id, g0.is_cancelled -> e.creator_user_id, e.is_cancelled
--
-- WHY THE RESULT IS UNCHANGED. Every removed read was one half of a KAN-713/723/727/731 intersection (or union, for
-- the rating cancel flag) whose other half already reads the same field from events. Section 0 refuses unless the
-- removed columns equal their events counterparts on every row (KAN-711 parity, D09), so dropping the games/meetups
-- half selects exactly the same rows. No other byte of any body changes (bodies authored from pg_get_functiondef).
--
-- WHO CAN CALL. All of these are SECURITY DEFINER owned by postgres; they already read FORCE-RLS public.events as
-- their owner today, for anon and authenticated callers alike. No SECURITY INVOKER function is touched, so no API
-- caller gains a new events read (the KAN-803 42501 trap does not arise).
--
-- Replaced in place (CREATE OR REPLACE, same signature, same return type): SECURITY, volatility, search_path, owner
-- and ACL are kept and asserted in section 2. No table, column, policy, trigger, grant or row is touched.
--
-- T-058 SUBSTITUTE (as KAN-772 / KAN-799 / KAN-803): production is not read here. Section 0 pins md5(prosrc) of each
-- pre-image; any drift fails closed -- re-author from pg_get_functiondef on the live catalogue then. Section 2 pins
-- md5(prosrc) of each new body.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  r record;
  v_n bigint;
  c record;
  v_attr jsonb;
begin
  if to_regclass('public.events') is null then
    raise exception 'KAN-807 pre: public.events missing (KAN-710 not applied)';
  end if;
  for r in select * from (values
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'KAN-807 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pre_md5 then
      raise exception 'KAN-807 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pre_md5;
    end if;
    if not (select prosecdef from pg_proc where oid = to_regprocedure(r.fn)) then
      raise exception 'KAN-807 pre: % is no longer SECURITY DEFINER; an events read would change who can call it', r.fn;
    end if;
  end loop;
  -- KAN-711 parity on every column whose read is removed. Checked only where the column still exists, so the
  -- migration is also safe to re-check after Z01 (it then has nothing to compare).
  for c in select * from (values ('games','game','creator_user_id'), ('games','game','listing_visibility'),
                                 ('games','game','is_cancelled'), ('games','game','start_at'),
                                 ('meetups','meetup','creator_user_id'), ('meetups','meetup','listing_visibility'),
                                 ('meetups','meetup','is_cancelled')) v(tbl, etype, col) loop
    if exists (select 1 from pg_attribute where attrelid = ('public.' || c.tbl)::regclass and attname = c.col and not attisdropped) then
      execute format('select count(*) from public.%I x left join public.events e on e.id = x.event_id and e.event_type = %L
                       where e.id is null or x.%I is distinct from e.%I', c.tbl, c.etype, c.col, c.col) into v_n;
      if v_n <> 0 then
        raise exception 'KAN-807 pre: % row(s) of public.% lack their typed events parent or differ on % (KAN-711 parity)', v_n, c.tbl, c.col;
      end if;
    end if;
  end loop;
  -- Attribute snapshot for section 2, kept in a transaction-local setting (no helper object is created).
  select jsonb_object_agg(k.fn, jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
           p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset))
    into v_attr
    from (values
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) join pg_proc p on p.oid = to_regprocedure(k.fn);
  perform set_config('kan807.b_attr', v_attr::text, true);
end $pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. New bodies (pg_get_functiondef of the pre-image; only the reads listed above change).
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_rate_user(p_game_id uuid, p_rater_profile_id uuid, p_ratee_user_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g              record;
  rater_user     uuid;
  rprof          record;
  ratee_is_host  boolean;
  window_ok      boolean;
  d              record;
  k text; v numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-727 / KAN-807: creator, start_at, end_at and cancelled from events.
  SELECT g0.id, e.creator_user_id, e.start_at, e.end_at, e.is_cancelled AS is_cancelled INTO g
    FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  window_ok := (now() <= g.end_at + interval '7 days');
  IF NOT window_ok THEN RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed'; END IF;

  SELECT id, user_id, profile_type INTO rprof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR rprof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  IF rprof.profile_type <> 'player' THEN
    RAISE EXCEPTION USING errcode='P0001', message='organiser_cannot_rate_user';
  END IF;

  rater_user := rprof.user_id;

  IF NOT EXISTS (SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = rater_user AND status = 'active') THEN
    RAISE EXCEPTION USING errcode='P0001', message='rater_not_in_game';
  END IF;

  ratee_is_host := (p_ratee_user_id = g.creator_user_id);
  IF NOT ratee_is_host AND NOT EXISTS (
    SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = p_ratee_user_id AND status = 'active'
  ) THEN RAISE EXCEPTION USING errcode='P0001', message='ratee_not_in_game'; END IF;

  IF p_ratee_user_id = rater_user THEN
    RAISE EXCEPTION USING errcode='P0001', message='cannot_rate_self';
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_reputation_events WHERE game_id = p_game_id AND rater_user_id = rater_user AND ratee_user_id = p_ratee_user_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN
    SELECT key FROM public.reputation_dimensions
    WHERE is_active = true
      AND (
        (ratee_is_host     AND 'rate_organiser' = ANY(applicable_to)) OR
        (NOT ratee_is_host AND 'rate_player'    = ANY(applicable_to))
      )
  LOOP
    k := d.key;
    IF p_scores ? k THEN
      v := (p_scores ->> k)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.user_reputation_events(game_id, rater_user_id, rater_profile_id, ratee_user_id, scores, comment)
  VALUES (p_game_id, rater_user, p_rater_profile_id, p_ratee_user_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.reputation_recompute(p_ratee_user_id);
  RETURN 'ok';
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_rate_venue(p_game_id uuid, p_venue_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g      record;
  prof   record;
  r_user uuid;
  d record; v numeric;
  tied boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-727 / KAN-807: creator, end_at and cancelled from events.
  SELECT g0.id, e.creator_user_id, e.end_at, e.is_cancelled AS is_cancelled INTO g
    FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  IF NOT public._game_belongs_to_venue(p_game_id, p_venue_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='venue_mismatch';
  END IF;
  IF now() > g.end_at + interval '7 days' THEN
    RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed';
  END IF;

  SELECT id, user_id, profile_type INTO prof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR prof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  r_user := prof.user_id;

  IF prof.profile_type = 'player' THEN
    tied := public._user_played_in_game(r_user, p_game_id);
  ELSE
    tied := public._user_hosted_game(r_user, p_game_id);
  END IF;
  IF NOT tied THEN RAISE EXCEPTION USING errcode='P0001', message='rater_not_tied_to_game'; END IF;

  IF EXISTS (SELECT 1 FROM public.venue_rating_events WHERE game_id = p_game_id AND venue_id = p_venue_id AND rater_user_id = r_user) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN SELECT key FROM public.venue_rating_dimensions WHERE is_active LOOP
    IF p_scores ? d.key THEN
      v := (p_scores ->> d.key)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.venue_rating_events(game_id, venue_id, rater_user_id, rater_profile_id, scores, comment)
  VALUES (p_game_id, p_venue_id, r_user, p_rater_profile_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.venue_rating_recompute(p_venue_id);
  RETURN 'ok';
END;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Postconditions: new body pinned; signature, result, SECURITY, volatility, search_path, owner, ACL unchanged.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  r record;
  v_attr jsonb := current_setting('kan807.b_attr')::jsonb;
  v_now jsonb;
begin
  for r in select * from (values
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post_md5 then
      raise exception 'KAN-807 post: % body is not the authored one', r.fn;
    end if;
    select jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
             p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset)
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'KAN-807 post: % changed signature/result/SECURITY/volatility/search_path/owner/ACL: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end $post$;

commit;
