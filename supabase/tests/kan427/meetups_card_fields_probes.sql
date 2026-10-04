-- KAN-429 -- probe pack for 20260915130000_meetups_card_fields.sql
-- AUTHORED, NOT RUN. Run BEFORE applying (post-apply assertions must FAIL) and
-- AFTER (all must pass). Blocks are marked [READ-ONLY] or
-- [WRITE-IN-TRANSACTION-ROLLBACK] (BEGIN ... ROLLBACK; nothing persists).
-- Run role probes with SET LOCAL ROLE and request.jwt.claims set.

-- A1 [READ-ONLY] the view still has every earlier column and the new one is last.
select column_name, ordinal_position from information_schema.columns
where table_schema='public' and table_name='v_meetup_list'
order by ordinal_position desc limit 3;   -- expect attendee_avatars first

-- A2 [READ-ONLY] view grants unchanged (anon + authenticated read).
select grantee, privilege_type from information_schema.role_table_grants
where table_schema='public' and table_name='v_meetup_list'
  and grantee in ('anon','authenticated') and privilege_type='SELECT';  -- 2 rows

-- A3 [READ-ONLY] rpc_meetup_card is still definer with the same search_path and
-- is executable by anon.
select p.prosecdef, p.proconfig, has_function_privilege('anon', p.oid, 'EXECUTE')
from pg_proc p where p.oid = 'public.rpc_meetup_card(uuid,text)'::regprocedure;

-- B1 [WRITE-IN-TRANSACTION-ROLLBACK] as anon the view hides member faces.
-- begin; set local role anon;
-- select bool_and(attendee_avatars = '[]'::jsonb) from public.v_meetup_list;  -- true
-- rollback;

-- B2 [WRITE-IN-TRANSACTION-ROLLBACK] as authenticated, create a meetup and a going
-- RSVP inside the transaction; the card returns sport_key, min_skill, host.avatar_url
-- and attendees[0].display_name; the list row's attendee_avatars has the same face.
-- begin; set local role authenticated; set local request.jwt.claims = '{"sub":"<uid>"}';
-- select public.rpc_meetup_card('<new meetup id>') -> 'attendees';
-- rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] as anon the card returns attendees = [].
-- begin; set local role anon;
-- select public.rpc_meetup_card('<public meetup id>') -> 'attendees';  -- []
-- rollback;
