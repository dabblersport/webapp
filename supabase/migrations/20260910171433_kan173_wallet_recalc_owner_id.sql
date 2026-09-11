-- KAN-173 — `_wallet_recalc` omits `owner_id` on the `wallets` insert (23502).
--
-- APPLIED to `wtncuzcskpigqpmnxwws` via `apply_migration` on 2026-09-10.
-- Returned version: 20260910171433. This file is committed at that exact version
-- (T-068 step 5: production-object truth first, ledger truth second; never re-execute
-- live DDL to tidy history).
--
-- Ruled by `cto` as T-071 (DECISIONS.md:9586): a SEPARATE forward-only fix, not riding
-- KAN-130/KAN-131. The defect predates KAN-130 — it traces to
-- 20260829080500_baseline_schema.sql:1813 — and KAN-131's Section B is a placeholder, so
-- riding it is an UNBOUNDED wait that would also carry `drop column user_id restrict` on a
-- live money table as freight. T-068's recovery step 1 authorises exactly this shape:
-- forward-only, authored fresh against live state, applied via `apply_migration`, never
-- `db push`.
--
-- THE DEFECT. `public.wallets.owner_id` is `uuid NOT NULL` with no default, and this
-- function's insert never supplied it. Postgres enforces NOT NULL at tuple formation,
-- BEFORE the ON CONFLICT arbiter is consulted, so it raised 23502 even when a row already
-- existed. `wallets` and `wallet_ledger` both hold 0 rows, so every write was a first
-- write and every one failed.
--
-- SCOPE. One change to one function. `settle_game`, `request_payout`,
-- `admin_cancel_payout` and `admin_wallet_adjust` all insert into `public.wallet_ledger`
-- and NONE calls `_wallet_recalc` directly; the sole route is `trg_wallet_ledger_recalc`
-- (AFTER INSERT OR DELETE OR UPDATE, enabled) -> `_wallet_after_ledger()` ->
-- `_wallet_recalc`. All four are fixed as a CONSEQUENCE of the shared trigger path, not
-- as four repairs. Verified live: `_wallet_after_ledger` is the only function in `public`
-- whose body calls `_wallet_recalc`.
--
-- BODY RESTATED FROM THE LIVE CATALOGUE (`pg_get_functiondef`), never from a repo file —
-- CONVENTIONS.md §6g / T-058. `CREATE OR REPLACE` replaces the whole object, so anything
-- not restated is lost. Live source md5 88efbd7bcc0609f47f3f169c6547f071, re-read
-- immediately before the apply and byte-identical to the Preflight read (no drift).
-- Only the INSERT statement differs from that text.
--
-- STAYS `SECURITY INVOKER` (live `prosecdef = false`) with `search_path=public, pg_temp`.
-- Deliberately NOT hardened to definer: it runs inside four SECURITY DEFINER callers and
-- already has the privilege it needs. Making it definer would be a privilege escalation
-- dressed as tidying.
--
-- `ON CONFLICT (user_id)` — safe, but for a NARROWER reason than "both unique indexes
-- identify the same row". The arbiter binds `wallets_pkey (user_id)` ONLY; a conflict on
-- `wallets_unique_idx (owner_type, owner_id, currency)` raises an UNHANDLED 23505.
-- It is safe because the map `p_user -> ('user', p_user, 'AED')` is injective AND this
-- function is the only writer producing it. NOTHING IN THE SCHEMA ENFORCES
-- `owner_id = user_id`: a row with `user_id = A, owner_id = B` misses the pkey arbiter
-- and raises 23505 on `wallets_unique_idx`. Unreachable today (0 rows, no writer produces
-- it). NOT theoretical — probe P4 constructed that row and reproduced the 23505 exactly:
--   ERROR: 23505 duplicate key value violates unique constraint "wallets_unique_idx"
--   DETAIL: Key (owner_type, owner_id, currency)=(user, ff8e1b42-..., AED) already exists.
--   CONTEXT: _wallet_recalc(uuid) line 20
-- KAN-130 touches this invariant and must not assume it holds for free.
--
-- `owner_type = 'user'` satisfies `wallets_owner_type_valid`
-- (CHECK owner_type IN ('user','venue','platform')). That constraint currently passes on
-- NULL; writing the value explicitly is what makes the row queryable under the `owner_*`
-- design and contains the T-052 nullability violation meanwhile.
--
-- NOT FIXED HERE, deliberately, both KAN-130's:
--   * `fn_get_wallet` has the MIRROR defect — it inserts (owner_type, owner_id, currency)
--     and omits `user_id`, raising 23502 from the other direction. This migration does NOT
--     close the wallet write path in general; it closes the ledger-recalc half. Probe P6
--     asserted `fn_get_wallet` fails IDENTICALLY before and after (23502 on `user_id`,
--     both runs), so nobody can read this as having fixed it.
--   * `owner_type` is NULLABLE while participating in `wallets_unique_idx` (T-052).
--
-- FORWARD-COMPATIBLE. KAN-130's Section A.8 restates this function owner-keyed with the
-- arbiter `(owner_type, owner_id, currency)`; it replaces this interim body wholesale when
-- it applies. Composes cleanly, no rework, no live double-application risk (AC-4, resolved
-- by cto's T-073 withdrawal).
--
-- `CREATE OR REPLACE` PRESERVES `proacl`. Unlike the DROP+CREATE in KAN-128 — where
-- `pg_default_acl` silently re-granted `anon` BY NAME and a REVOKE FROM PUBLIC was not
-- sufficient — no grant is re-derived here. `proacl` was asserted unchanged after applying.

CREATE OR REPLACE FUNCTION public._wallet_recalc(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  avail numeric(12,2);
  held  numeric(12,2);
begin
  select
    coalesce(sum(case when status='posted' and direction='credit' then amount_aed
                      when status='posted' and direction='debit'  then -amount_aed
                      else 0 end),0),
    coalesce(sum(case when status='pending' and direction='credit' then amount_aed
                      when status='pending' and direction='debit'  then -amount_aed
                      else 0 end),0)
  into avail, held
  from public.wallet_ledger
  where user_id = p_user;

  -- KAN-173 / T-071: `owner_type` and `owner_id` added. `wallets.owner_id` is NOT NULL
  -- with no default, and omitting it raised 23502 on every write. The balance is still a
  -- FULL RECOMPUTE from the ledger above and is never incremented — T-049 Invariant 3.
  insert into public.wallets (user_id, owner_type, owner_id, balance_aed, held_aed)
  values (p_user, 'user', p_user, avail, held)
  on conflict (user_id)
  do update set balance_aed = excluded.balance_aed,
                held_aed    = excluded.held_aed,
                updated_at  = now();
end;
$function$;
