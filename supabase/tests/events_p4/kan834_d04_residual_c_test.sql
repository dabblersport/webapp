-- KAN-834 (KAN-807 leftovers): behaviour + catalogue probe for the four functions that
-- 20261104112100_kan834_d04_residual_c.sql rewrites to stop reading games columns that KAN-719 Z01 drops.
--
--   public.can_current_user_join_game(uuid, text, uuid)
--   public._recent_activity_score(uuid, integer)
--   public._user_hosted_game(uuid, uuid)
--   public.game_is_joinable(uuid)
--
-- LOCAL THROWAWAY PG16 ONLY (the KAN-834 run834.sh chain). Never run against a hosted project: it creates the
-- scratch schema k834t and switches role. Run as a superuser:
--
--   psql -v mode=capture -f kan834_d04_residual_c_test.sql   on the PRE-fix, PRE-Z01 chain. Freezes the case set
--                                                             (seed games x viewers x roles) and records what the
--                                                             OLD bodies return, plus the pg_proc attributes.
--   psql -v mode=verify  -f kan834_d04_residual_c_test.sql   any time later (after the fix, after Z01). Re-runs
--                                                             every frozen case and raises on any difference,
--                                                             including any new error. Prints a per-function tally.
--   psql -v mode=attrs   -f kan834_d04_residual_c_test.sql   compares identity args, result, SECURITY, volatility,
--                                                             proconfig, owner, ACL, language, retset against the
--                                                             captured ones; raises on any difference. Prints md5.
--
-- Seams: the four functions' results as each real caller class sees them (anon, authenticated -- the INVOKER
-- fallback branch; postgres and service_role -- the events branch) and their pg_proc attributes. The expected
-- values are the old bodies' own outputs on identical fixtures, so a case passes only when the new body agrees.
-- Errors are recorded as ERR:<sqlstate>:<message>, so a pre-existing error (KAN-713 E-2, the invite branch's
-- i.to_profile_id) must recur with the same message and a NEW 42703 can never pass as the old one.
\set ON_ERROR_STOP 1
\pset pager off
select :'mode' = 'capture' as k834_capture, :'mode' = 'verify' as k834_verify, :'mode' = 'attrs' as k834_attrs \gset

create schema if not exists k834t;

create or replace function k834t.attrs() returns table(fn text, attr jsonb, body_md5 text)
language sql stable as $$
  select p.oid::regprocedure::text,
         jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef,
                           p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang::regproc::text,
                           p.proretset, p.proisstrict, p.proleakproof, p.proparallel, p.pronargdefaults),
         md5(p.prosrc)
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('can_current_user_join_game', '_recent_activity_score', '_user_hosted_game', 'game_is_joinable')
$$;

-- Runs every frozen case into k834t.actual. Each case runs in its own subtransaction under its own role and
-- auth.uid() (request.jwt.claim.sub), so one error never masks another.
create or replace function k834t.run_cases() returns void language plpgsql as $$
declare
  c record;
  r text;
begin
  drop table if exists k834t.actual;
  create table k834t.actual (case_id int primary key, result text not null);
  for c in select * from k834t.cases order by case_id loop
    begin
      execute format('set local role %I', c.role_name);
      perform set_config('request.jwt.claim.sub', coalesce(c.viewer::text, ''), true);
      execute 'select (' || c.call || ')::text' into r;
      r := coalesce(r, '<null>');
      reset role;
    exception when others then
      r := 'ERR:' || sqlstate || ':' || sqlerrm;
      -- the subtransaction rollback has already restored the role and the claim
    end;
    insert into k834t.actual values (c.case_id, r);
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

\if :k834_capture
drop table if exists k834t.cases, k834t.expect, k834t.attrs_before;
create table k834t.cases (case_id serial primary key, fn text not null, role_name text not null, viewer uuid,
                          call text not null, note text);

-- Games: one per (cancelled, future/past, join_policy, listing_visibility) class present in the seed, every
-- game with no free slot, every game a pending request/invite/active roster row points at, and an unknown id.
create temp table k834_games as
  select distinct on (e.is_cancelled, e.start_at > now(), e.join_policy, e.listing_visibility) g.id,
         format('cancelled=%s future=%s policy=%s vis=%s', e.is_cancelled, e.start_at > now(), e.join_policy, e.listing_visibility) note
    from public.games g join public.events e on e.id = g.event_id and e.event_type = 'game'
   order by e.is_cancelled, e.start_at > now(), e.join_policy, e.listing_visibility, g.id;
insert into k834_games
  select g.id, 'full (game_slots_left = 0)' from public.games g
   where public.game_slots_left(g.id) = 0 and g.id not in (select id from k834_games) order by g.id limit 6;
insert into k834_games
  select distinct x.game_id, 'has pending request/invite or active roster'
    from (select game_id from public.game_join_requests where status = 'pending'
          union select game_id from public.game_invites where status = 'pending'
          union (select game_id from public.game_roster where status = 'active' order by game_id limit 6)) x
   where x.game_id not in (select id from k834_games);
insert into k834_games values ('83400000-0000-0000-0000-00000000dead', 'unknown game id');

-- Viewers per game: its creator (host), an active roster member, a pending requester, a pending invitee, the seed
-- users a1..a7 (each hosts some games and not others), a8 (no profile, frozen -> 'frozen') and a9 (no profile ->
-- choose_actor raises P0001, a pre-existing error that must recur unchanged). The a8 freeze is a scratch-only row.
insert into public.user_freezes (user_id, reason) values ('00000000-0000-0000-0000-0000000000a8', 'KAN-834 local test fixture');
create temp table k834_viewers as
  select kg.id game_id, v.viewer
    from k834_games kg
    left join public.games g on g.id = kg.id
    left join public.events e on e.id = g.event_id
    cross join lateral (
      select e.creator_user_id
      union select (select r.user_id from public.game_roster r where r.game_id = kg.id and r.status = 'active' and r.user_id is not null order by r.user_id limit 1)
      union select (select q.from_user_id from public.game_join_requests q where q.game_id = kg.id and q.status = 'pending' order by 1 limit 1)
      union select (select i.to_user_id from public.game_invites i where i.game_id = kg.id and i.status = 'pending' order by 1 limit 1)
      union select ('00000000-0000-0000-0000-0000000000a' || n)::uuid from generate_series(1, 9) n) v(viewer)
   where v.viewer is not null;

create temp table k834_roles (role_name text, events_branch boolean);
insert into k834_roles values ('postgres', true), ('service_role', true), ('authenticated', false), ('anon', false);

-- game_is_joinable(game): every game, every role.
insert into k834t.cases (fn, role_name, viewer, call, note)
  select 'game_is_joinable', r.role_name, null, format('public.game_is_joinable(%L::uuid)', kg.id), kg.note
    from k834_games kg cross join k834_roles r;

-- _user_hosted_game(user, game): every (viewer, game), every role.
insert into k834t.cases (fn, role_name, viewer, call, note)
  select '_user_hosted_game', r.role_name, null, format('public._user_hosted_game(%L::uuid, %L::uuid)', v.viewer, v.game_id), null
    from k834_viewers v cross join k834_roles r;

-- _recent_activity_score(user, days): every viewer, three windows (includes past games and no-game users).
insert into k834t.cases (fn, role_name, viewer, call, note)
  select '_recent_activity_score', r.role_name, null, format('public._recent_activity_score(%L::uuid, %s)', u.viewer, d.days), null
    from (select distinct viewer from k834_viewers
          union select '83400000-0000-0000-0000-0000000000ff'::uuid) u
    cross join (values (1), (30), (36500)) d(days) cross join k834_roles r;

-- can_current_user_join_game(game, actor, link): every (viewer, game) and a signed-out caller; no token and a
-- bogus token; every role. auth.uid() is the viewer.
insert into k834t.cases (fn, role_name, viewer, call, note)
  select 'can_current_user_join_game', r.role_name, v.viewer,
         format('public.can_current_user_join_game(%L::uuid, %L, %s)', v.game_id, 'player', t.tok), null
    from (select game_id, viewer from k834_viewers union select id, null from k834_games) v
    cross join (values ('NULL'), ('''83400000-0000-0000-0000-00000000beef''::uuid')) t(tok)
    cross join k834_roles r
   where r.role_name <> 'anon' or v.viewer is null;

select k834t.run_cases();
create table k834t.expect as select * from k834t.actual;
create table k834t.attrs_before as select * from k834t.attrs();

select c.fn, count(*) cases, count(distinct a.result) distinct_results,
       count(*) filter (where a.result like 'ERR:%') errors
  from k834t.cases c join k834t.expect a using (case_id) group by c.fn order by c.fn;
select c.fn, c.role_name, a.result, count(*) from k834t.cases c join k834t.expect a using (case_id)
 group by 1, 2, 3 order by 1, 2, 3;
\endif

\if :k834_verify
select k834t.run_cases();
select c.fn, count(*) cases, count(*) filter (where a.result = x.result) same,
       count(*) filter (where a.result is distinct from x.result) differ,
       count(*) filter (where a.result like 'ERR:%') errors_now
  from k834t.cases c join k834t.expect x using (case_id) join k834t.actual a using (case_id)
 group by c.fn order by c.fn;
-- every difference, grouped (the first 40)
select c.fn, c.role_name, x.result as expected, a.result as actual, count(*) n
  from k834t.cases c join k834t.expect x using (case_id) join k834t.actual a using (case_id)
 where a.result is distinct from x.result group by 1, 2, 3, 4 order by 1, 2, 3, 4 limit 40;
do $v$
declare n int;
begin
  select count(*) into n from k834t.expect x join k834t.actual a using (case_id) where a.result is distinct from x.result;
  if n > 0 then
    raise exception 'KAN-834 verify FAIL: % case(s) differ from the pre-Z01 old-body results', n;
  end if;
  raise notice 'KAN-834 verify PASS: % cases identical to the pre-Z01 old-body results', (select count(*) from k834t.expect);
end $v$;
\endif

\if :k834_attrs
select b.fn, b.body_md5 as md5_before, a.body_md5 as md5_now, (a.attr = b.attr) as attrs_identical,
       b.attr as attrs_before, a.attr as attrs_now
  from k834t.attrs_before b full join k834t.attrs() a using (fn) order by 1;
do $a$
declare n int;
begin
  select count(*) into n from k834t.attrs_before b full join k834t.attrs() a using (fn) where a.attr is distinct from b.attr;
  if n > 0 then
    raise exception 'KAN-834 attrs FAIL: % function(s) changed identity/result/SECURITY/volatility/config/owner/ACL', n;
  end if;
  raise notice 'KAN-834 attrs PASS: identity args, result, prosecdef, provolatile, proconfig, owner, proacl identical';
end $a$;
\endif
