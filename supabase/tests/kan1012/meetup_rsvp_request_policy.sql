-- KAN-1012: rpc_meetup_rsvp('going') must respect join_policy='request'.
-- [WRITE-IN-TRANSACTION-ROLLBACK] Borrows a live future public open meetup, a non-host user
-- with an active profile and no RSVP on it; flips policy to 'request' inside the transaction.
begin;
create temp table _t(n serial, ok boolean, label text) on commit drop;
grant all on _t to authenticated; grant all on sequence _t_n_seq to authenticated;
create temp table _ctx on commit drop as
select mt.id mid, mt.event_id eid, e.creator_user_id host,
       (select p.user_id from profiles p
         where p.is_active and p.user_id <> e.creator_user_id and not public.is_frozen(p.user_id)
           and not exists (select 1 from meetup_rsvps r where r.meetup_id=mt.id and r.user_id=p.user_id)
         order by p.created_at limit 1) joiner,
       (select p.user_id from profiles p
         where p.is_active and p.user_id <> e.creator_user_id and not public.is_frozen(p.user_id)
           and not exists (select 1 from meetup_rsvps r where r.meetup_id=mt.id and r.user_id=p.user_id)
         order by p.created_at offset 1 limit 1) joiner2
from meetups mt join events e on e.id=mt.event_id
where e.join_policy='open' and not e.is_cancelled and e.start_at>now() and e.listing_visibility='public'
  and public.meetup_slots_left(mt.id) >= 2
limit 1;
grant select on _ctx to authenticated;

-- 1. open meetup: going works
select set_config('request.jwt.claims', json_build_object('sub',(select joiner2 from _ctx),'role','authenticated')::text, true);
set local role authenticated;
insert into _t(ok,label) select public.rpc_meetup_rsvp((select mid from _ctx),'going')='going', 'open meetup: going -> going';
reset role;

-- 2. request meetup: non-host going -> pending, not going
update events set join_policy='request' where id=(select eid from _ctx);
select set_config('request.jwt.claims', json_build_object('sub',(select joiner from _ctx),'role','authenticated')::text, true);
set local role authenticated;
insert into _t(ok,label) select public.rpc_meetup_rsvp((select mid from _ctx),'going')='pending', 'request meetup: going returns pending';
reset role;
insert into _t(ok,label) select (select status from meetup_rsvps where meetup_id=(select mid from _ctx) and user_id=(select joiner from _ctx))='pending', 'request meetup: stored status pending';
insert into _t(ok,label) select not exists(select 1 from meetup_rsvps where meetup_id=(select mid from _ctx) and user_id=(select joiner from _ctx) and status='going'), 'negative control: joiner is not going';
insert into _t(ok,label) select (select status from meetup_rsvps where meetup_id=(select mid from _ctx) and user_id=(select joiner2 from _ctx))='going', 'existing RSVP untouched by policy change';

-- 3. host approves -> going
select set_config('request.jwt.claims', json_build_object('sub',(select host from _ctx),'role','authenticated')::text, true);
set local role authenticated;
insert into _t(ok,label) select public.rpc_meetup_decide_request((select mid from _ctx),(select joiner from _ctx),'approve')='going', 'host approve -> going';
reset role;
insert into _t(ok,label) select (select status from meetup_rsvps where meetup_id=(select mid from _ctx) and user_id=(select joiner from _ctx))='going', 'stored status going after approval';

insert into _t(ok,label) select (select proacl::text from pg_proc where oid='public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure)='{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' and (select prosecdef from pg_proc where oid='public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure), 'acl + security definer preserved';

select '1..'||count(*) as tap from _t
union all
select * from (select (case when ok then 'ok ' else 'not ok ' end)||n||' - '||label from _t order by n) s;
rollback;
