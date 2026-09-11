-- KAN-52: 14-day PDPL data-subject SLA tracking for data_export_requests.
-- Author only — not applied (G-002 / decision 019). Hand off to cto.
--
-- data_export_requests already has requested_at and a 30-day expires_at
-- (post-completion retention window, matches DataExportService's
-- _exportExpiration constant). Neither tracks the separate 14-day
-- *response* SLA named in `08 <internal governance doc>` Part 2 §I.2 R2.
--
-- Verified live before writing (wtncuzcskpigqpmnxwws, 2026-09-01):
-- data_export_requests has requested_at/expires_at/status but no
-- sla_due_at/is_overdue column, and no existing SLA view.
--
-- Adds:
--   1. sla_due_at — generated column, requested_at + 14 days. The SLA
--      deadline itself, always in sync with requested_at, no app-side
--      write path needed.
--   2. v_data_export_sla_status — a security_invoker view exposing
--      is_overdue (still pending/processing, past sla_due_at). Delegates
--      to the base table's existing owner-scoped RLS (T-020: a user sees
--      whether their own request is overdue, nothing more — this is not
--      an ops-wide overdue dashboard).

alter table public.data_export_requests
  add column if not exists sla_due_at timestamptz
    generated always as (requested_at + interval '14 days') stored;

comment on column public.data_export_requests.sla_due_at is
  'PDPL 14-day data-subject response deadline. Distinct from expires_at, '
  'which is the 30-day post-completion retention window.';

create or replace view public.v_data_export_sla_status
with (security_invoker = true) as
select
  id,
  user_id,
  status,
  requested_at,
  sla_due_at,
  (status in ('pending', 'processing') and now() > sla_due_at) as is_overdue
from public.data_export_requests;

comment on view public.v_data_export_sla_status is
  'Per-request PDPL 14-day SLA status. security_invoker delegates to '
  'data_export_requests RLS: a caller sees only their own request(s).';

-- This project auto-grants anon SELECT/REFERENCES/TRIGGER/MAINTAIN on every
-- new relation via ALTER DEFAULT PRIVILEGES (confirmed live by the
-- 20260901160000 migration, independent of KAN-67's write-privilege
-- revocation — that default-ACL rule is read-side and untouched by KAN-67).
-- Lock the new view down explicitly rather than relying on the default.
revoke all on public.v_data_export_sla_status from public, anon;
grant select on public.v_data_export_sla_status to authenticated;

-- === Verification (run against a rolled-back transaction, before AND
-- after apply — do not leave residue on the live table) ===
--
-- 1. Column computes correctly for existing rows:
--    select id, requested_at, sla_due_at,
--           sla_due_at = requested_at + interval '14 days' as matches
--    from public.data_export_requests limit 5;
--    -- expect matches = true for every row
--
-- 2. View reflects RLS isolation, same simulate-JWT pattern used to verify
--    this table's own RLS on 2026-08-31:
--    begin;
--      select set_config('request.jwt.claims',
--        json_build_object('sub', '<user-a-id>')::text, true);
--      set local role authenticated;
--      select * from public.v_data_export_sla_status; -- only user A's rows
--    rollback;
--
-- 3. anon denied:
--    set local role anon;
--    select * from public.v_data_export_sla_status; -- expect permission denied
--    reset role;
--
-- 4. authenticated retains SELECT:
--    select has_table_privilege('authenticated',
--      'public.v_data_export_sla_status', 'SELECT'); -- expect true
--
-- 5. Population check — count rows the view exposes vs. the base table,
--    per T-020/decision 020 (count, never infer from a tool's finding
--    count):
--    select count(*) from public.data_export_requests;
--    select count(*) from public.v_data_export_sla_status; -- as postgres/service_role, should match
