-- KAN-585 probes. AUTHORED, NOT RUN. Each block is BEGIN .. ROLLBACK.

-- P1 [seed count]: 18 ids x 6 regions, all enabled (expect 108, 108). AUTHORED, NOT RUN.
BEGIN;
select count(*), count(*) filter (where enabled) from public.feature_availability;
ROLLBACK;

-- P2 [none disabled]: (expect 0). AUTHORED, NOT RUN.
BEGIN;
select count(*) from public.feature_availability where not enabled;
ROLLBACK;

-- P3 [RLS on]: (expect true). AUTHORED, NOT RUN.
BEGIN;
select relrowsecurity from pg_class where oid = 'public.feature_availability'::regclass;
ROLLBACK;

-- P4 [anon cannot select or execute]: (expect false, false). AUTHORED, NOT RUN.
BEGIN;
select has_table_privilege('anon', 'public.feature_availability', 'select'),
       has_function_privilege('anon', 'public.get_feature_availability()', 'execute');
ROLLBACK;

-- P5 [authenticated cannot write]: (expect false, false, false, true). AUTHORED, NOT RUN.
BEGIN;
select has_table_privilege('authenticated', 'public.feature_availability', 'insert'),
       has_table_privilege('authenticated', 'public.feature_availability', 'update'),
       has_table_privilege('authenticated', 'public.feature_availability', 'delete'),
       has_table_privilege('authenticated', 'public.feature_availability', 'select');
ROLLBACK;

-- P6 [authenticated insert refused at runtime]: expect insufficient_privilege. AUTHORED, NOT RUN.
BEGIN;
set local role authenticated;
insert into public.feature_availability (feature_id, region) values ('probe_x', 'Global');
ROLLBACK;

-- P7 [Egypt account gets Egypt rows]: expect 18 rows, all true. AUTHORED, NOT RUN.
-- Seeds a temporary region row for an existing user, inside the rolled-back txn.
BEGIN;
insert into public.account_service_region (user_id, region)
select id, 'Egypt' from auth.users limit 1
on conflict (user_id) do update set region = 'Egypt';
select set_config('request.jwt.claims',
  json_build_object('sub', (select user_id from public.account_service_region where region = 'Egypt' limit 1), 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*), bool_and(enabled) from public.get_feature_availability();
ROLLBACK;

-- P8 [no account row falls back to Global]: expect 18 rows, all true. AUTHORED, NOT RUN.
BEGIN;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*), bool_and(enabled) from public.get_feature_availability();
ROLLBACK;

-- P9 [failure demo]: an unsupported region is refused (expect check_violation). AUTHORED, NOT RUN.
BEGIN;
insert into public.feature_availability (feature_id, region) values ('meetups', 'United Kingdom');
ROLLBACK;
