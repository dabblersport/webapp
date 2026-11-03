-- KAN-727 (KAN-714 B08, Epic KAN-708): the capacity checks behind join, and the rating-eligibility checks,
-- read capacity, end time and cancel state from public.events instead of the legacy games/meetups columns.
-- AUTHORED, NOT APPLIED. Review + apply through the normal Thebes path (PEER route, backend-N reviewer).
-- No DROP, no table/column/grant/policy change, no row written. Five function bodies are replaced in place.
--
-- WHAT CHANGES (5 functions):
--   game_slots_left(uuid)            capacity      <- events.capacity                 (was games.capacity)
--   meetup_slots_left(uuid)          capacity      <- events.capacity                 (was meetups.capacity)
--   rpc_rate_game(4 args)            end_at        <- events.end_at                   (was games.end_at)
--   rpc_rate_user(5 args)            is_cancelled  <- games.is_cancelled OR events.is_cancelled
--   rpc_rate_venue(5 args)
-- Each reads its parent through public.events e ON e.id = <subtype>.event_id AND e.event_type = '<type>'
-- (KAN-710's validated FK + NOT NULL check: exactly one parent per row, so the join neither drops nor doubles;
-- the precondition refuses if any game or meetup lacks its parent). Subtype-only fields stay on the subtype:
-- games.game_type (the hosted-host seat), games.creator_user_id (ratee_is_host), games.venue_space_id.
--   * capacity: games NOT NULL 2..64 on events (events_game_capacity_check); meetups NULL = unlimited on both
--     sides (KAN-711 copies it, never defaults it). The 999999 "unlimited" sentinel is kept. No nullability
--     conflict blocks an equivalent read.
--   * end_at: NOT NULL for games on both sides (events_game_end_required). No end time is invented.
--   * cancel state: a DENIAL, so it is the UNION of the two flags (KAN-713's rule, 20261104100000:12-20):
--     either side cancelled refuses. Never widened. cancelled_at / cancelled_reason are not read.
--   * last-slot behaviour: unchanged. rpc_join_game still takes games FOR UPDATE before calling
--     game_slots_left, which serialises concurrent joins on the same game exactly as before; slots > 0 joins,
--     0 waitlists (or requests). Error codes and result shapes are byte-identical: no RAISE was edited.
--
-- game_slots_left IS SECURITY INVOKER and is granted to PUBLIC/anon/authenticated (baseline:35346-35348).
-- public.events is FORCE RLS with no client grant (KAN-710), so a plain events read would make every direct
-- client call raise 42501. It therefore follows KAN-713's INVOKER pattern (20261104100000, v_events):
-- has_table_privilege('public.events','SELECT') picks the events read for callers that may see events
-- (SECURITY DEFINER callers such as rpc_join_game / rpc_decide_join_request, service_role) and the
-- pre-image read otherwise. That needs per-statement planning, so the body moves from LANGUAGE sql to
-- plpgsql (a SQL function with SET search_path is never inlined, so no plan is lost). Volatility (STABLE),
-- owner, ACL, SECURITY INVOKER and search_path are kept and asserted below. meetup_slots_left and the three
-- rpc_rate_* are SECURITY DEFINER (owner postgres): they read events directly.
--
-- DELIBERATELY NOT CHANGED (read no capacity / join_policy / cancel / end field themselves, or already done):
--   can_current_user_join_game, can_current_user_rsvp_meetup  KAN-713 already reads events (cancel/start union,
--       join_policy mismatch fails closed 'policy_mismatch'); their capacity comes from the two *_slots_left.
--   rpc_join_game, rpc_decide_join_request                    capacity only via game_slots_left; no own read.
--   rpc_meetup_rsvp (4 args)                                  capacity via meetup_slots_left; its
--       rsvp_policy = 'link' read is covered by KAN-713's join_policy equality check (fails closed).
--   rpc_leave_game, can_rate_user, can_rate_venue             no capacity/cancel/end read.
--   rpc_meetup_decide_request (m.is_cancelled), rpc_remove_player (is_cancelled = false)  REPORTED, not changed
--       here: host-side decision RPCs outside the planned test surface; the legacy flag is the KAN-712 mirror.
--
-- KAN-712 INTERACTION: none of the five writes events, and none is on the KAN-712 wrap list
-- (supabase/tests/events_p2/KAN712_CONTRACT.md); the precondition refuses if one has been wrapped.
--
-- T-058 SUBSTITUTE (as KAN-713/KAN-723): production is not read here. Each replacement starts from the repo body
-- named below; the precondition pins md5(prosrc) of the LIVE function to it, plus SECURITY DEFINER and
-- search_path. Any drift fails closed -- re-author from pg_get_functiondef on the live catalogue in that case.
--   game_slots_left(uuid)                      baseline 20260829080500:6904-6917                   1f6418851fd9c18d36165f111a4b1f5f
--   meetup_slots_left(uuid)                    baseline :8974-8983 + 20260915120000:80-87 (DEFINER) e80d0677a9a6fee5fb507efe93c2d158
--   rpc_rate_game(uuid,uuid,jsonb,text)        baseline :14585-14633                               195bf3e5b9bc14165fe0feba89635b3b
--   rpc_rate_user(uuid,uuid,uuid,jsonb,text)   baseline :14639-14713 (+ KAN-672 grants)             12cb3bf4c0fa33a6a8f11aec94da1e96
--   rpc_rate_venue(uuid,uuid,uuid,jsonb,text)  baseline :14719-14777                               2bce0cd675ee5865731d05adb90883e9
--
-- ROLLBACK (data-neutral, one transaction): re-run the five pre-image definitions -- the repo bodies above with
-- their live attributes, exactly as pg_get_functiondef emits them. They are reproduced verbatim at the END of this
-- file inside a comment block (section 9). CREATE OR REPLACE keeps owner and ACL. Proven locally in
-- supabase/tests/events_p2/kan714_b08_capacity_join.sql probes R1-R4.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_unlinked bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-727 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  -- KAN-710 / KAN-711
  if to_regclass('public.events') is null
     or not exists (select 1 from pg_constraint where conrelid = 'public.games'::regclass
                     and conname = 'games_event_id_fkey')
     or not exists (select 1 from pg_constraint where conrelid = 'public.games'::regclass
                     and conname = 'games_event_id_not_null' and convalidated)
     or not exists (select 1 from pg_constraint where conrelid = 'public.meetups'::regclass
                     and conname = 'meetups_event_id_fkey')
     or not exists (select 1 from pg_constraint where conrelid = 'public.meetups'::regclass
                     and conname = 'meetups_event_id_not_null' and convalidated) then
    raise exception 'KAN-727 pre: KAN-710/KAN-711 not applied (events, games/meetups event_id FK + validated NOT NULL)';
  end if;
  -- KAN-712 stage B live
  if (select count(*) from pg_trigger where tgname like 'trg\_zz\_kan712\_%' and tgenabled = 'O') <> 5
     or to_regclass('public.kan712_wrapped_rpcs') is null then
    raise exception 'KAN-727 pre: KAN-712 stage B (20261103110000) not live';
  end if;
  -- KAN-713 (the join/rsvp helpers these capacity reads sit under): both migrations' objects present, and the
  -- two join-check helpers already read events (so cancel/start/join_policy are not this migration's job).
  if to_regprocedure('public.kan713_meetup_visible(uuid)') is null
     or to_regclass('public.kan713_preimage') is null
     or to_regprocedure('public.kan713_games_location()') is null
     or not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                     and tgname = 'trg_kan713_events_location' and tgenabled = 'O')
     or (select prosrc from pg_proc where oid = to_regprocedure('public.can_current_user_join_game(uuid,text,uuid)'))
          not like '%v_events boolean := has_table_privilege(''public.events'', ''SELECT'')%'
     or (select prosrc from pg_proc where oid = to_regprocedure('public.can_current_user_rsvp_meetup(uuid,uuid)'))
          not like '%e.is_cancelled%' then
    raise exception 'KAN-727 pre: KAN-713 (20261104100000 + 20261104110000) not applied';
  end if;
  -- Not wrapped by KAN-712
  if exists (select 1 from public.kan712_wrapped_rpcs w
              where w::text ~ '(game_slots_left|meetup_slots_left|rpc_rate_game|rpc_rate_user|rpc_rate_venue)')
     or exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
                 and proname in ('game_slots_left_kan712_inner', 'meetup_slots_left_kan712_inner',
                                 'rpc_rate_game_kan712_inner', 'rpc_rate_user_kan712_inner', 'rpc_rate_venue_kan712_inner')) then
    raise exception 'KAN-727 pre: a target function is KAN-712-wrapped; change it through kan712_unwrap_rpc / kan712_wrap_rpc';
  end if;
  -- Already applied?
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
              and proname in ('game_slots_left', 'meetup_slots_left', 'rpc_rate_game', 'rpc_rate_user', 'rpc_rate_venue')
              and prosrc like '%KAN-727%') then
    raise exception 'KAN-727 pre: already applied';
  end if;
  -- Every game / meetup has exactly its typed parent (the inner join must not drop a row)
  select (select count(*) from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null)
       + (select count(*) from public.meetups m left join public.events e on e.id = m.event_id and e.event_type = 'meetup' where e.id is null)
    into v_unlinked;
  if v_unlinked > 0 then
    raise exception 'KAN-727 pre: % game/meetup row(s) without a typed events parent; reconcile first', v_unlinked;
  end if;
  -- Live bodies are exactly the repo bodies these replacements were authored from (T-058 substitute)
  select string_agg(x.sig || ' expected ' || x.md5 || ' live ' || coalesce(md5(p.prosrc), '<absent>')
                    || ' secdef ' || coalesce(p.prosecdef::text, '?') || ' config ' || coalesce(p.proconfig::text, '-'), '; ')
    into v_bad
    from (values
      ('public.game_slots_left(uuid)',                     '1f6418851fd9c18d36165f111a4b1f5f', false, '{"search_path=public, pg_temp"}'),
      ('public.meetup_slots_left(uuid)',                   'e80d0677a9a6fee5fb507efe93c2d158', true,  '{search_path=public}'),
      ('public.rpc_rate_game(uuid,uuid,jsonb,text)',       '195bf3e5b9bc14165fe0feba89635b3b', true,  '{search_path=public}'),
      ('public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)',  '12cb3bf4c0fa33a6a8f11aec94da1e96', true,  '{search_path=public}'),
      ('public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', '2bce0cd675ee5865731d05adb90883e9', true,  '{search_path=public}')
    ) as x(sig, md5, secdef, cfg)
    left join pg_proc p on p.oid = to_regprocedure(x.sig)
   where p.oid is null or md5(p.prosrc) <> x.md5 or p.prosecdef <> x.secdef or p.proconfig::text is distinct from x.cfg;
  if v_bad is not null then
    raise exception 'KAN-727 pre: live function differs from the reviewed pre-image (re-author from pg_get_functiondef): %', v_bad;
  end if;
end
$pre$;

-- Attributes before, for the post-condition (temp: dropped at commit).
create temp table kan727_attr on commit drop as
select p.oid, p.oid::regprocedure::text as sig, p.proowner, p.proacl, p.prosecdef, p.proconfig, p.provolatile,
       p.prolang, pg_get_function_result(p.oid) as res, pg_get_function_arguments(p.oid) as args
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname in ('game_slots_left', 'meetup_slots_left', 'rpc_rate_game', 'rpc_rate_user', 'rpc_rate_venue');

-- ---------------------------------------------------------------------------------------------------------
-- 1. game_slots_left -- from baseline 20260829080500:6904-6917 (SECURITY INVOKER, search_path public, pg_temp)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.game_slots_left(p_game uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-727: capacity from events (authoritative) for callers that may read events; pre-image read otherwise
-- (INVOKER, granted to clients; events has no client grant -- KAN-713's v_events pattern).
DECLARE
  v_capacity  integer;
  v_game_type text;
  v_active    integer;
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    SELECT e.capacity, g.game_type INTO v_capacity, v_game_type
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE g.id = p_game;
  ELSE
    SELECT g.capacity, g.game_type INTO v_capacity, v_game_type
      FROM public.games g
     WHERE g.id = p_game;
  END IF;
  IF NOT FOUND THEN
    RETURN 0;                                   -- pre-image: GREATEST(NULL - 0, 0) = 0 for an unknown game
  END IF;
  SELECT count(*)::int INTO v_active
    FROM public.game_roster r
   WHERE r.game_id = p_game AND r.status = 'active'
     AND (r.role = 'player' OR (r.role = 'host' AND v_game_type = 'hosted'));
  RETURN GREATEST(v_capacity - v_active, 0);
END
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. meetup_slots_left -- from baseline :8974-8983 + 20260915120000_meetups_hardening:80-81 (DEFINER, public)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.meetup_slots_left(p_meetup uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- KAN-727: capacity from events e (authoritative); NULL = unlimited (999999) kept; unknown meetup -> NULL kept.
  select
    case when e.capacity is null then 999999
         else greatest(e.capacity - coalesce((select count(*) from public.meetup_rsvps r where r.meetup_id=m.id and r.status='going'),0), 0)
    end as slots_left
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  where m.id = p_meetup
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. rpc_rate_game -- from baseline :14585-14633. Only the game read changed.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened).
  select g0.id, e.end_at, (g0.is_cancelled or e.is_cancelled) as is_cancelled into g
    from public.games g0 join public.events e on e.id = g0.event_id and e.event_type = 'game'
   where g0.id=p_game_id;
  if not found or g.is_cancelled then raise exception using errcode='P0001', message='game_not_ratable'; end if;
  if now() > g.end_at + interval '7 days' then raise exception using errcode='P0001', message='rating_window_closed'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_rater_profile_id;
  if not found or prof.user_id <> auth.uid() then raise exception using errcode='P0001', message='not_profile_owner'; end if;
  if prof.profile_type <> 'player' then raise exception using errcode='P0001', message='organiser_cannot_rate_game'; end if;
  r_user := prof.user_id;

  if not public._user_played_in_game(r_user, p_game_id) then
    raise exception using errcode='P0001', message='rater_not_in_game';
  end if;

  if exists (select 1 from public.game_rating_events where game_id=p_game_id and rater_user_id=r_user) then
    raise exception using errcode='P0001', message='already_rated';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode='P0001', message='invalid_scores';
  end if;

  for d in select key from public.game_rating_dimensions where is_active loop
    if p_scores ? d.key then
      v := (p_scores ->> d.key)::numeric;
      if v is null then raise exception using errcode='P0001', message='score_not_numeric'; end if;
      if v < 0 or v > 5 then raise exception using errcode='P0001', message='score_out_of_range'; end if;
    end if;
  end loop;

  insert into public.game_rating_events(game_id, rater_user_id, rater_profile_id, scores, comment)
  values (p_game_id, r_user, p_rater_profile_id, p_scores, left(p_comment, 280));

  perform public.game_rating_recompute(p_game_id);

  return 'ok';
end;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 4. rpc_rate_user -- from baseline :14639-14713. Only the game read changed.
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

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened); creator stays on games.
  SELECT g0.id, g0.creator_user_id, g0.start_at, e.end_at, (g0.is_cancelled OR e.is_cancelled) AS is_cancelled INTO g
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

-- ---------------------------------------------------------------------------------------------------------
-- 5. rpc_rate_venue -- from baseline :14719-14777. Only the game read changed.
-- ---------------------------------------------------------------------------------------------------------
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

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened); creator stays on games.
  SELECT g0.id, g0.creator_user_id, e.end_at, (g0.is_cancelled OR e.is_cancelled) AS is_cancelled INTO g
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
-- 8. Post-conditions: signature, result, owner, ACL, SECURITY DEFINER, search_path, volatility unchanged;
--    language unchanged except game_slots_left (sql -> plpgsql, stated above); every body carries KAN-727.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare v_bad text;
begin
  select string_agg(a.sig, ', ') into v_bad
    from kan727_attr a
    left join pg_proc p on p.oid = a.oid
   where p.oid is null
      or p.proowner <> a.proowner or p.proacl is distinct from a.proacl or p.prosecdef <> a.prosecdef
      or p.proconfig is distinct from a.proconfig or p.provolatile <> a.provolatile
      or pg_get_function_result(p.oid) <> a.res or pg_get_function_arguments(p.oid) <> a.args
      or (p.prolang <> a.prolang and not (p.proname = 'game_slots_left'
                                          and p.prolang = (select oid from pg_language where lanname = 'plpgsql')))
      or p.prosrc not like '%KAN-727%';
  if v_bad is not null or (select count(*) from kan727_attr) <> 5 then
    raise exception 'KAN-727 post: attributes changed or body not replaced: %', coalesce(v_bad, 'count <> 5');
  end if;
end
$post$;

commit;

-- ---------------------------------------------------------------------------------------------------------
-- 9. ROLLBACK SQL (do not run as part of this migration). One transaction; data-neutral; owner/ACL kept.
--    The five pre-image definitions exactly as pg_get_functiondef emitted them from the pinned repo bodies (local harness).
-- ---------------------------------------------------------------------------------------------------------
/*
begin;
CREATE OR REPLACE FUNCTION public.game_slots_left(p_game uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH g AS (SELECT capacity, game_type FROM public.games WHERE id = p_game),
  active AS (
    SELECT count(*)::int AS c
    FROM public.game_roster r
    JOIN g ON true
    WHERE r.game_id = p_game AND r.status = 'active'
      AND (r.role = 'player' OR (r.role = 'host' AND g.game_type = 'hosted'))
  )
  SELECT GREATEST((SELECT capacity FROM g) - (SELECT c FROM active), 0)
$function$
;

CREATE OR REPLACE FUNCTION public.meetup_slots_left(p_meetup uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    case when m.capacity is null then 999999
         else greatest(m.capacity - coalesce((select count(*) from public.meetup_rsvps r where r.meetup_id=m.id and r.status='going'),0), 0)
    end as slots_left
  from public.meetups m where m.id = p_meetup
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  select id, end_at, is_cancelled into g from public.games where id=p_game_id;
  if not found or g.is_cancelled then raise exception using errcode='P0001', message='game_not_ratable'; end if;
  if now() > g.end_at + interval '7 days' then raise exception using errcode='P0001', message='rating_window_closed'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_rater_profile_id;
  if not found or prof.user_id <> auth.uid() then raise exception using errcode='P0001', message='not_profile_owner'; end if;
  if prof.profile_type <> 'player' then raise exception using errcode='P0001', message='organiser_cannot_rate_game'; end if;
  r_user := prof.user_id;

  if not public._user_played_in_game(r_user, p_game_id) then
    raise exception using errcode='P0001', message='rater_not_in_game';
  end if;

  if exists (select 1 from public.game_rating_events where game_id=p_game_id and rater_user_id=r_user) then
    raise exception using errcode='P0001', message='already_rated';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode='P0001', message='invalid_scores';
  end if;

  for d in select key from public.game_rating_dimensions where is_active loop
    if p_scores ? d.key then
      v := (p_scores ->> d.key)::numeric;
      if v is null then raise exception using errcode='P0001', message='score_not_numeric'; end if;
      if v < 0 or v > 5 then raise exception using errcode='P0001', message='score_out_of_range'; end if;
    end if;
  end loop;

  insert into public.game_rating_events(game_id, rater_user_id, rater_profile_id, scores, comment)
  values (p_game_id, r_user, p_rater_profile_id, p_scores, left(p_comment, 280));

  perform public.game_rating_recompute(p_game_id);

  return 'ok';
end;
$function$
;

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

  SELECT id, creator_user_id, start_at, end_at, is_cancelled INTO g FROM public.games WHERE id = p_game_id;
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
$function$
;

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

  SELECT id, creator_user_id, end_at, is_cancelled INTO g FROM public.games WHERE id = p_game_id;
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
$function$
;

-- After running: md5(prosrc) of each must equal the pins in the header; ACLs are kept by CREATE OR REPLACE.
commit;
*/
