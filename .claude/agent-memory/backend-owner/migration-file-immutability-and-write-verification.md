---
name: migration-file-immutability-and-write-verification
description: T-031 — never edit an already-applied migration file, even pre-commit; always ship a new file. Also prefer EXPLAIN over a real rolled-back write when proving a vulnerability.
metadata:
  type: feedback
---

**T-031 (cto, 2026-08-29): a migration file is immutable once applied — corrections ship as a NEW
file with a NEW name, never an edit to the applied file, even when the edit is correct and the
file isn't committed to git yet.**

**Why:** on KAN-27A, the CREATE-policy half of my migration was already applied to production
(20260828215203) before cto's T-030 ruling landed asking for a DROP POLICY addition. I added the
DROP to the *same file* rather than a new one. cto's collision pre-flight caught it before
applying — re-running the edited file would have failed outright on the first `CREATE POLICY` as a
duplicate, mid-way through a security migration. The harm isn't just the failed apply (recoverable)
— it's that the ledger entry named a file whose content had since changed, so neither the repo nor
the ledger could tell you what production actually held. `G-002` condition 4 verification can't
catch this, because it verifies the migration reviewer's own apply, not one someone else ran and
then had edited under it.

**How to apply, going forward:**
1. Before writing any `CREATE`-shaped migration, check whether the objects it creates already
   exist (e.g. `SELECT * FROM pg_policies WHERE policyname = '...'`, or the equivalent for the
   object type) — don't assume a file that hasn't been reviewed hasn't been applied.
2. Check `mcp__supabase__list_migrations` (or the ledger) for the migration's own name/version
   before ever touching its file again. Already there = do not edit; author a new file instead,
   named for what changed (e.g. `kan27a_followup_drop_open_dabbler_news_write.sql`, the pattern
   cto used).
3. Once a message confirms an apply happened (a ledger comment, a "APPLIED" Jira comment, or a
   live `pg_class`/`pg_policies` check), treat that file as closed. Any further correction is a new
   migration, full stop — this applies even to a file I authored myself and even before it's
   committed to git.

**Separately, a peer note worth keeping:** prefer a plan-level proof (`EXPLAIN`, no `ANALYZE`) over
an actual write inside a rolled-back transaction when demonstrating a vulnerability exists. A
rolled-back INSERT still fires triggers and consumes sequence values, and a transaction that
doesn't roll back the way expected is exactly the failure that can't be undone. I used a real
rolled-back `INSERT ... anon` to prove the `dabbler-news` open-write bug on KAN-27A — it worked,
but `EXPLAIN` would have proven the same permission gap without ever risking a real write reaching
production. Where a plan-level demonstration will do, use it; where it won't (e.g. proving a
computed value, not just a permission), say so explicitly rather than defaulting to a real write.

Related: [[create-or-replace-view-resets-security-invoker]] (a different "verify what actually
happens when a DDL statement runs" lesson from the same week).
