-- KAN-584 probes. AUTHORED, NOT RUN. Each block is BEGIN .. ROLLBACK.

-- P1: the table exists with RLS on.
BEGIN;
select relrowsecurity from pg_class where oid = 'public.account_service_region'::regclass;
ROLLBACK;

-- P2: anon has no privilege (expect false).
BEGIN;
select has_table_privilege('anon', 'public.account_service_region', 'select');
ROLLBACK;

-- P3: an unsupported value is refused (expect a check_violation).
BEGIN;
insert into public.account_service_region (user_id, region)
select id, 'United Kingdom' from auth.users limit 1;
ROLLBACK;

-- P4: three own-row policies exist (expect 3).
BEGIN;
select count(*) from pg_policies
where schemaname = 'public' and tablename = 'account_service_region';
ROLLBACK;
