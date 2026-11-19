-- KAN-1014: organiser bans (remove only / ban event / ban all my events).
-- [WRITE-IN-TRANSACTION-ROLLBACK] Borrows three live future public open meetups of three organisers
-- and reassigns the second to organiser A inside the transaction, plus one open future game.
begin;
create temp table _t(n serial, ok boolean, label text) on commit drop;
grant all on _t to authenticated; grant all on sequence _t_n_seq to authenticated;
create temp table _m on commit drop as
select mt.id mid, mt.event_id eid, e.creator_user_id host, row_number() over (order by mt.id) rn
from meetups mt join events e on e.id=mt.event_id
where e.join_policy='open' and not e.is_cancelled and e.start_at>now() and e.listing_visibility='public'
  and public.meetup_slots_left(mt.id) >= 2
order by mt.id limit 3;
update events set creator_user_id=(select host from _m where rn=1) where id=(select eid from _m where rn=2);
create temp table _ctx on commit drop as
select (select mid from _m where rn=1) m1, (select mid from _m where rn=2) m2, (select mid from _m where rn=3) m3,
       (select host from _m where rn=1) a, (select host from _m where rn=3) c,
       (select p.user_id from profiles p
         where p.is_active and not public.is_frozen(p.user_id)
           and p.user_id not in (select host from _m)
           and not exists (select 1 from meetup_rsvps r where r.meetup_id in (select mid from _m) and r.user_id=p.user_id)
           and not exists (select 1 from events e where e.creator_user_id=p.user_id)
         order by p.created_at limit 1) j;
grant select on _ctx to authenticated;

create or replace function pg_temp.as_user(u uuid) returns void language sql as
$$ select set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true) $$;
-- try(sql) -> result text or 'ERR:<message>'
create or replace function pg_temp.try(q text) returns text language plpgsql as
$$ declare r text; begin execute q into r; return r; exception when others then return 'ERR:'||sqlerrm; end $$;
grant execute on function pg_temp.try(text), pg_temp.as_user(uuid) to authenticated;

-- 1. remove only -> can rejoin
select pg_temp.as_user((select j from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m1 from _ctx)))='going', 'J going M1';
reset role; select pg_temp.as_user((select a from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_remove_attendee(%L,%L,null)',(select m1 from _ctx),(select j from _ctx)))='removed', 'A removes J (legacy 3-arg call, no ban)';
reset role; select pg_temp.as_user((select j from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m1 from _ctx)))='going', 'remove only: J can rejoin M1';

-- 2. ban event
reset role; select pg_temp.as_user((select a from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_remove_attendee(%L,%L,null,''bogus'')',(select m1 from _ctx),(select j from _ctx)))='ERR:invalid_ban_scope', 'invalid scope refused';
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_remove_attendee(%L,%L,null,''event'')',(select m1 from _ctx),(select j from _ctx)))='removed', 'A removes J with ban event';
reset role; select pg_temp.as_user((select j from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m1 from _ctx)))='ERR:banned', 'ban event: going M1 refused banned';
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''interested'')',(select m1 from _ctx)))='ERR:banned', 'ban event: interested M1 refused banned';
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m2 from _ctx)))='going', 'ban event: other event M2 of same organiser allowed';

-- 3. ban organiser
reset role; select pg_temp.as_user((select a from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_remove_attendee(%L,%L,null,''organiser'')',(select m2 from _ctx),(select j from _ctx)))='removed', 'A removes J from M2 with ban organiser';
reset role; select pg_temp.as_user((select j from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m2 from _ctx)))='ERR:banned', 'ban organiser: M2 refused';
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m3 from _ctx)))='going', 'ban organiser: different organiser M3 allowed';

-- 4. RLS: J cannot read or insert bans
insert into _t(ok,label) select (select count(*) from organiser_bans)=0, 'non-organiser J reads 0 bans';
insert into _t(ok,label) select pg_temp.try(format('insert into organiser_bans(organiser_user_id,banned_user_id,scope) values (%L,%L,''organiser'') returning id::text',(select a from _ctx),(select c from _ctx))) like 'ERR:%row-level security%', 'J cannot insert a ban for A';
insert into _t(ok,label) select (select jsonb_array_length(rpc_list_my_bans()))=0, 'J list_my_bans empty';
insert into _t(ok,label) select pg_temp.try(format('select rpc_lift_ban(%L)',(select id from organiser_bans limit 1)))<>'lifted', 'J cannot lift';
reset role;

-- 5. organiser lists and lifts
select pg_temp.as_user((select a from _ctx)); set local role authenticated;
insert into _t(ok,label) select (select count(*) from organiser_bans)=2, 'A reads own 2 bans';
insert into _t(ok,label) select (select jsonb_array_length(rpc_list_my_bans()))=2
  and (select bool_and(x ? 'display_name' and x ? 'event_title' and x->>'scope' in ('event','organiser')) from jsonb_array_elements(rpc_list_my_bans()) x), 'A list_my_bans: 2 rows with name/scope/title';
insert into _t(ok,label) select bool_and(pg_temp.try(format('select rpc_lift_ban(%L)',x->>'ban_id'))='lifted'), 'A lifts both bans' from jsonb_array_elements(rpc_list_my_bans()) x;
reset role; select pg_temp.as_user((select j from _ctx)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_meetup_rsvp(%L,''going'')',(select m1 from _ctx)))='going', 'lift ban: J can rejoin M1';
reset role;

-- 6. removal notification carries no scope
insert into _t(ok,label) select bool_and(split_part(pg_get_functiondef(f::regprocedure),'kan982_notify',2) !~* 'scope'),
  'removal notification payload never references the ban scope'
  from unnest(array['public.rpc_meetup_remove_attendee(uuid,uuid,text,text)','public.rpc_remove_player(uuid,uuid,text,text)']) f;

-- 7. game path: rpc_remove_player with ban event refuses rpc_join_game and a direct waitlist insert.
-- No live future game exists, so one open public game is moved into the future inside the transaction.
create temp table _g0 on commit drop as
select g.id gid, e.id eid, e.creator_user_id host
from games g join events e on e.id=g.event_id
where e.event_type='game' and not e.is_cancelled and e.join_policy='open' and e.listing_visibility='public'
  and public.game_slots_left(g.id)>0
order by e.start_at desc limit 1;
create temp table _g on commit drop as
select g0.*, 'player'::text jp, p.id jpid, p.user_id ju
from _g0 g0, lateral (select p.id, p.user_id from profiles p
   where p.is_active and p.persona_type='player' and not public.is_frozen(p.user_id) and p.user_id <> g0.host
     and not exists (select 1 from game_roster r where r.game_id=g0.gid and r.user_id=p.user_id)
     and not exists (select 1 from game_waitlist w where w.game_id=g0.gid and w.user_id=p.user_id)
   order by p.created_at limit 1) p;
update events set start_at=now()+interval '2 days', end_at=now()+interval '2 days 2 hours' where id=(select eid from _g);
grant select on _g to authenticated;
select pg_temp.as_user((select ju from _g)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select result from rpc_join_game(%L,%L)',(select jp from _g),(select gid from _g)))='joined', 'game: J joins (no ban)';
reset role; select pg_temp.as_user((select host from _g)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select rpc_remove_player(%L,%L,null,''event'')',(select gid from _g),(select jpid from _g))) like 'removed%', 'game: host removes J with ban event';
reset role; select pg_temp.as_user((select ju from _g)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select result from rpc_join_game(%L,%L)',(select jp from _g),(select gid from _g)))='ERR:banned', 'game: banned J refused by rpc_join_game';
reset role;
insert into _t(ok,label) select pg_temp.try(format('insert into game_waitlist(game_id,profile_id,user_id,position) values (%L,%L,%L,999) returning 1',(select gid from _g),(select jpid from _g),(select ju from _g)))='ERR:banned', 'game: direct waitlist insert refused (even as table owner)';
delete from organiser_bans where banned_user_id=(select ju from _g);
select pg_temp.as_user((select ju from _g)); set local role authenticated;
insert into _t(ok,label) select pg_temp.try(format('select result from rpc_join_game(%L,%L)',(select jp from _g),(select gid from _g)))='joined', 'game: ban lifted -> J rejoins';
reset role;

insert into _t(ok,label) select (select proacl::text from pg_proc where oid='public.rpc_remove_player(uuid,uuid,text,text)'::regprocedure)='{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  and (select proacl::text from pg_proc where oid='public.rpc_meetup_remove_attendee(uuid,uuid,text,text)'::regprocedure)='{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  and (select bool_and(prosecdef) from pg_proc where proname in ('rpc_remove_player','rpc_meetup_remove_attendee','rpc_list_my_bans','rpc_lift_ban')), 'acl + security definer on removal RPCs';

-- Report through an exception, which also rolls the transaction back.
do $$ begin
  raise exception E'TAP\n%', (select '1..'||count(*) from _t) || E'\n' ||
    (select string_agg((case when ok then 'ok ' else 'not ok ' end)||n||' - '||label, E'\n' order by n) from _t);
end $$;
rollback;
