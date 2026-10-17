-- KAN-558 (Messaging meetup chat) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws (a non-production branch first), after
-- 20261017130000_kan558_msg_meetup_chat.sql is applied. Every block is WRITE-IN-TRANSACTION-ROLLBACK (or READ-ONLY),
-- begins with BEGIN and ends with ROLLBACK. Every fixture is created inside the block and rolled back with it. Blocks
-- print booleans only: no message content. Writes to meetups / meetup_rsvps may fire their existing triggers
-- (activity sync, touch); they are rolled back with the block.
--
-- WHAT CREATES A MEETUP ROW: no RPC does (out of scope for KAN-558). The blocks insert
-- msg_conversations (kind 'meetup', meetup_id) as the runner (an owner role) after `reset role`.
--
-- Variables (supplied by the runner, no secrets; all are existing TEST users and test data):
--   :user_org          the organiser: meetups.creator_user_id of :meetup_id
--   :user_go, :user_cx, :user_out   three other adults with no meetup_rsvps row on :meetup_id
--   :meetup_id         a test meetup with no msg_conversations row
--   :game_live, :profile_go   a future, not cancelled test game with no msg_conversations row on which :user_go has
--                      no roster row; :profile_go is :user_go's profile
-- e.g. psql -v user_org=... -v user_go=... -v user_cx=... -v user_out=... -v meetup_id=... -v game_live=...
--      -v profile_go=... -f meetup_probes.sql
-- Game and DM probe packs of earlier tickets (probes.sql, dm_probes.sql, game_conversation_probes.sql,
-- my_conversations_dm_probes.sql) must still pass unchanged.

-- M1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A 'going' RSVP is a member and can send; the member list is
-- the organiser plus the 'going' RSVPs only.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values
  (:'meetup_id', :'user_go', 'going'), (:'meetup_id', :'user_cx', 'cancelled'), (:'meetup_id', :'user_out', 'interested');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m1 as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action = 'send' and reason is null from kan558_m1) as pass_going_member_can_send,
  (select member_user_ids from kan558_m1)
     = (select array_agg(u order by u) from unnest(array[:'user_org'::uuid, :'user_go'::uuid]) u) as pass_members_are_organiser_and_going,
  (select kind = 'meetup' and game_id is null and meetup_id = :'meetup_id' from public.msg_conversations where id = :'conv') as pass_meetup_row_shape;
ROLLBACK;

-- M2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. The organiser is a member with no RSVP row at all.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
delete from public.meetup_rsvps where meetup_id = :'meetup_id' and user_id = :'user_org';
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_org', 'role', 'authenticated')::text, true);
create temp table kan558_m2 as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action = 'send' and reason is null from kan558_m2) as pass_organiser_is_member,
  :'user_org'::uuid = any ((select member_user_ids from kan558_m2)) as pass_organiser_in_member_list;
ROLLBACK;

-- M3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A cancelled RSVP is a voluntary leaver: read only, reason
-- 'left', up to left_at_seq; with no recorded left_at_seq it reads up to 0 (fails closed). Not in the member list.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values
  (:'meetup_id', :'user_cx', 'cancelled'), (:'meetup_id', :'user_out', 'cancelled');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
insert into public.msg_conversation_members (conversation_id, user_id, left_at_seq) values (:'conv', :'user_cx', 7);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_cx', 'role', 'authenticated')::text, true);
create temp table kan558_m3a as select * from public.msg_authorize(:'conv', 'all');
select set_config('request.jwt.claims', json_build_object('sub', :'user_out', 'role', 'authenticated')::text, true);
create temp table kan558_m3b as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action = 'read' and reason = 'left' and left_at_seq = 7 from kan558_m3a) as pass_cancelled_rsvp_reads_to_boundary,
  (select allowed_action = 'read' and reason = 'left' and left_at_seq = 0 from kan558_m3b) as pass_missing_boundary_reads_nothing,
  not (:'user_cx'::uuid = any ((select member_user_ids from kan558_m3a))) as pass_leaver_not_in_member_list;
ROLLBACK;

-- M4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. An ended meetup is read only (reason game_ended) for a going
-- member and for the organiser; a meetup with no end_at is ended once start_at has passed.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() - interval '3 hours', end_at = now() - interval '1 minute'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values (:'meetup_id', :'user_go', 'going');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m4a as select * from public.msg_authorize(:'conv', 'all');
select set_config('request.jwt.claims', json_build_object('sub', :'user_org', 'role', 'authenticated')::text, true);
create temp table kan558_m4b as select * from public.msg_authorize(:'conv', 'all');
reset role;
update public.meetups set end_at = null where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m4c as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action = 'read' and reason = 'game_ended' from kan558_m4a) as pass_ended_meetup_read_only,
  (select allowed_action = 'read' and reason = 'game_ended' from kan558_m4b) as pass_ended_meetup_read_only_for_organiser,
  (select allowed_action = 'read' and reason = 'game_ended' from kan558_m4c) as pass_no_end_at_ends_at_start;
ROLLBACK;

-- M5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A cancelled meetup is read only (reason game_cancelled), and
-- cancelled wins over ended.
BEGIN;
update public.meetups set is_cancelled = true, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values (:'meetup_id', :'user_go', 'going');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m5a as select * from public.msg_authorize(:'conv', 'all');
reset role;
update public.meetups set start_at = now() - interval '3 hours', end_at = now() - interval '1 minute' where id = :'meetup_id';
set local role authenticated;
create temp table kan558_m5b as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action = 'read' and reason = 'game_cancelled' from kan558_m5a) as pass_cancelled_meetup_read_only,
  (select allowed_action = 'read' and reason = 'game_cancelled' from kan558_m5b) as pass_cancelled_wins_over_ended;
ROLLBACK;

-- M6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A non-member is refused with not_member: no RSVP, an
-- 'interested' RSVP, and a 'declined' RSVP. A refused caller gets no member list.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values
  (:'meetup_id', :'user_cx', 'interested'), (:'meetup_id', :'user_go', 'declined');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_out', 'role', 'authenticated')::text, true);
create temp table kan558_m6a as select * from public.msg_authorize(:'conv', 'all');
select set_config('request.jwt.claims', json_build_object('sub', :'user_cx', 'role', 'authenticated')::text, true);
create temp table kan558_m6b as select * from public.msg_authorize(:'conv', 'all');
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m6c as select * from public.msg_authorize(:'conv', 'all');
reset role;
select
  (select allowed_action is null and reason = 'not_member' and member_user_ids is null from kan558_m6a) as pass_non_member_refused,
  (select allowed_action is null and reason = 'not_member' from kan558_m6b) as pass_interested_refused,
  (select allowed_action is null and reason = 'not_member' from kan558_m6c) as pass_declined_refused;
ROLLBACK;

-- M7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. msg_my_conversations lists meetup rows with the meetup's
-- title, start and end, kind 'meetup', NULL game_id and counterpart columns; going and organiser see 'send', a cancelled
-- RSVP sees 'left', an outsider sees nothing; an ended meetup is 'read_only'.
BEGIN;
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values
  (:'meetup_id', :'user_go', 'going'), (:'meetup_id', :'user_cx', 'cancelled');
insert into public.msg_conversations (kind, meetup_id) values ('meetup', :'meetup_id') returning id as conv \gset
create temp table kan558_m7_meetup as select title, start_at, end_at from public.meetups where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m7_go as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_org', 'role', 'authenticated')::text, true);
create temp table kan558_m7_org as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_cx', 'role', 'authenticated')::text, true);
create temp table kan558_m7_cx as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_out', 'role', 'authenticated')::text, true);
create temp table kan558_m7_out as select * from public.msg_my_conversations();
reset role;
update public.meetups set start_at = now() - interval '3 hours', end_at = now() - interval '1 minute' where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
create temp table kan558_m7_ended as select * from public.msg_my_conversations();
reset role;
select
  (select r.kind = 'meetup' and r.game_id is null and r.state = 'send'
          and r.game_title = m.title and r.start_at = m.start_at and r.end_at is not distinct from m.end_at
          and r.counterpart_user_id is null and r.counterpart_name is null and r.counterpart_avatar is null
     from kan558_m7_go r cross join kan558_m7_meetup m
    where r.conversation_id = :'conv') as pass_meetup_row_has_title_start_end,
  (select start_at > now() and end_at > start_at from kan558_m7_go where conversation_id = :'conv') as pass_meetup_row_start_end_from_meetup,
  (select state = 'send' from kan558_m7_org where conversation_id = :'conv') as pass_organiser_row_send,
  (select state = 'left' from kan558_m7_cx where conversation_id = :'conv') as pass_cancelled_rsvp_row_left,
  not exists (select 1 from kan558_m7_out where conversation_id = :'conv') as pass_outsider_sees_no_meetup_row,
  (select state = 'read_only' from kan558_m7_ended where conversation_id = :'conv') as pass_ended_meetup_row_read_only;
ROLLBACK;

-- M8 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Game and DM rows are still returned and unchanged next to a
-- meetup row; the shape check refuses a meetup row without meetup_id and a game row carrying a meetup_id.
BEGIN;
select set_config('kan558.meetup_id', :'meetup_id', true), set_config('kan558.game_live', :'game_live', true); -- psql does not substitute variables inside dollar-quoted bodies
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = now() + interval '1 day 2 hours'
 where id = :'meetup_id';
insert into public.meetup_rsvps (meetup_id, user_id, status) values (:'meetup_id', :'user_go', 'going');
insert into public.msg_conversations (kind, meetup_id, last_activity_at) values ('meetup', :'meetup_id', now() - interval '1 hour')
  returning id as conv \gset
insert into public.msg_conversations (game_id, last_activity_at) values (:'game_live', now() - interval '2 hours')
  returning id as gconv \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_live', :'profile_go', :'user_go', 'player', 'active');
insert into public.msg_access_allowlist (user_id) values (:'user_go'), (:'user_out')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_go', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_out') as dconv \gset
create temp table kan558_m8 as select * from public.msg_my_conversations();
create temp table kan558_m8_game as select * from public.msg_authorize(:'gconv', 'all');
create temp table kan558_m8_dm as select * from public.msg_authorize(:'dconv', 'all');
reset role;
select
  (select kind = 'game' and game_id = :'game_live' and state = 'send' and counterpart_user_id is null from kan558_m8 where conversation_id = :'gconv') as pass_game_row_unchanged,
  (select kind = 'dm' and game_id is null and game_title is null and counterpart_user_id = :'user_out' from kan558_m8 where conversation_id = :'dconv') as pass_dm_row_unchanged,
  (select kind = 'meetup' from kan558_m8 where conversation_id = :'conv') as pass_meetup_row_alongside,
  (select allowed_action = 'send' and :'user_go'::uuid = any (member_user_ids) from kan558_m8_game) as pass_game_authorize_unchanged,
  (select allowed_action = 'send' and member_user_ids = (select array_agg(u order by u) from unnest(array[:'user_go'::uuid, :'user_out'::uuid]) u) from kan558_m8_dm) as pass_dm_authorize_unchanged;
do $$
begin
  insert into public.msg_conversations (kind) values ('meetup');
  raise exception 'FAIL pass_meetup_without_meetup_id_refused: the insert was accepted';
exception when check_violation then
  raise notice 'pass_meetup_without_meetup_id_refused = true';
end;
$$;
do $$
begin
  insert into public.msg_conversations (kind, game_id, meetup_id)
  values ('game', current_setting('kan558.game_live')::uuid, current_setting('kan558.meetup_id')::uuid);
  raise exception 'FAIL pass_game_with_meetup_id_refused: the insert was accepted';
exception when check_violation or unique_violation then
  raise notice 'pass_game_with_meetup_id_refused = true';
end;
$$;
ROLLBACK;

-- M9 [READ-ONLY] AUTHORED, NOT RUN. ACL and attributes are those of the previous definitions.
BEGIN;
select
  not has_function_privilege('anon', 'public.msg_evaluate(uuid, uuid, text)', 'execute')
    and not has_function_privilege('authenticated', 'public.msg_evaluate(uuid, uuid, text)', 'execute') as pass_evaluate_internal,
  has_function_privilege('authenticated', 'public.msg_authorize(uuid, text)', 'execute')
    and not has_function_privilege('anon', 'public.msg_authorize(uuid, text)', 'execute') as pass_authorize_acl,
  has_function_privilege('authenticated', 'public.msg_my_conversations(int)', 'execute')
    and not has_function_privilege('anon', 'public.msg_my_conversations(int)', 'execute') as pass_my_conversations_acl,
  (select bool_and(p.prosecdef and p.proconfig @> array['search_path=public, pg_temp'])
     from pg_proc p where p.oid in ('public.msg_evaluate(uuid, uuid, text)'::regprocedure,
                                    'public.msg_authorize(uuid, text)'::regprocedure,
                                    'public.msg_my_conversations(int)'::regprocedure)) as pass_definer_pinned_path;
ROLLBACK;
