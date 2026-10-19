-- KAN-559 (Messaging meetup list id) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws (a non-production branch first), after
-- 20261017140000_kan559_msg_my_conversations_meetup_id.sql is applied. For kind meetup, game_id carries the meetup id.
-- Every block begins with BEGIN and ends with ROLLBACK; fixtures are created inside it and rolled back with it.
-- Blocks print booleans only: no message content.
--
-- Variables (supplied by the runner, no secrets; existing TEST users and test data), as in meetup_probes.sql:
--   :user_org          the organiser: meetups.creator_user_id of :meetup_id
--   :user_go, :user_out   two other adults with no meetup_rsvps row on :meetup_id
--   :meetup_id         a test meetup with no msg_conversations row
--   :game_live, :profile_go   a future, not cancelled test game with no msg_conversations row on which :user_go has
--                      no roster row; :profile_go is :user_go's profile

-- M1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A meetup row returns the meetup id in game_id for a going member
-- and for the organiser; an outsider gets no meetup row.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values (:'meetup_id', :'user_go', 'going');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan559_m1_go as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_org', 'role', 'authenticated')::text, true);
create temp table kan559_m1_org as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_out', 'role', 'authenticated')::text, true);
create temp table kan559_m1_out as select * from public.msg_my_conversations();
reset role;
select
  (select kind = 'meetup' and game_id = :'meetup_id'::uuid from kan559_m1_go where conversation_id = :'conv') as pass_going_member_gets_meetup_id,
  (select kind = 'meetup' and game_id = :'meetup_id'::uuid from kan559_m1_org where conversation_id = :'conv') as pass_organiser_gets_meetup_id,
  not exists (select 1 from kan559_m1_out where conversation_id = :'conv') as pass_outsider_sees_no_meetup_row;
ROLLBACK;

-- M2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A game row still returns its game id and a DM row still
-- returns NULL in game_id, next to a meetup row.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values (:'meetup_id', :'user_go', 'going');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
insert into public.msg_conversations (game_id) values (:'game_live') returning id as gconv \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_live', :'profile_go', :'user_go', 'player', 'active');
insert into public.msg_access_allowlist (user_id) values (:'user_go'), (:'user_out')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_out') as dconv \gset
create temp table kan559_m2 as select * from public.msg_my_conversations();
reset role;
select
  (select kind = 'game' and game_id = :'game_live'::uuid from kan559_m2 where conversation_id = :'gconv') as pass_game_row_keeps_game_id,
  (select kind = 'dm' and game_id is null from kan559_m2 where conversation_id = :'dconv') as pass_dm_row_game_id_null,
  (select kind = 'meetup' and game_id = :'meetup_id'::uuid from kan559_m2 where conversation_id = :'conv') as pass_meetup_row_alongside;
ROLLBACK;

-- M3 [READ-ONLY] AUTHORED, NOT RUN. ACL and attributes unchanged.
BEGIN;
select
  has_function_privilege('authenticated', 'public.msg_my_conversations(int)', 'execute')
    and not has_function_privilege('anon', 'public.msg_my_conversations(int)', 'execute') as pass_list_acl,
  (select p.prosecdef and p.proconfig = array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure) as pass_list_definer_search_path;
ROLLBACK;
