---
name: kan67-migration-facts
description: KAN-67 final migration — measured view/grant population, the supabase_admin membership blocker, and what the migration deliberately leaves open
metadata:
  type: project
---

**The final KAN-67 SQL lives as a Jira comment on KAN-67 (posted 2026-08-28). It is the
only signed-off copy** — the draft in `docs/PLAN.md` was wrong and has been replaced with
a pointer.

**Measured 2026-08-28 against `wtncuzcskpigqpmnxwws`, all read-only:**

| Fact | Value |
|---|---|
| views in `public` | 71 |
| grant `anon` write / `authenticated` write | 70 / 70 |
| auto-updatable | 19 |
| definer + auto-updatable + anon-writable | 8 (7 app + `geometry_columns`) |
| `anon`-readable views | 48 — unchanged by the migration |
| base tables granting `anon`/`auth` write | **184 — the whole schema, still open** |

**The blocker that will not go away by trying harder:**
`pg_has_role('postgres','supabase_admin','MEMBER') = false`. So `postgres` cannot run
`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin …`, and cannot REVOKE on the
`supabase_admin`-owned PostGIS views. Both are excluded by design, not oversight. The
`postgres` grantor covers everything Dabbler's own migrations create.

**Nothing in this app writes through a view** — verified across `lib/` and
`supabase/functions/` by constant and by literal. That is why the revoke is safe and why
the sweep can cover all 70 rather than only the 8.

**How to apply:** when anyone reports KAN-67 as done, the test is the five-step
verification block in the ticket comment, not a re-run of the original Query A. And do not
let "KAN-67 applied" be read as "the wide grant is closed" — 184 base tables still grant
write, and that remainder needs the re-grant set established first.
See [[force-rls-is-inert-here]].

---

**APPLIED 2026-08-28** under decision `G-002` (PO grant of standing migration authority to
`cto`). Ledger entry `20260828160122` — `kan67_revoke_anon_view_write_grants`. Verification
posted as KAN-67 comment **10100**; ticket moved to **In Review** for `task-auditor` — `cto`
applied it, so `cto` does not sign it off.

Post-apply, verified: `anon_write_views = 0` / `auth_write_views = 0` (postgres-owned views);
all seven named views false on every write flag; `anon_readable_views = 48` **unchanged**;
`pg_default_acl` postgres grantor now `anon=rxtm` / `authenticated=rxtm`.

**Still open after this migration** — do not read KAN-67 as "the wide grant is closed":
184 base tables still grant write · the `supabase_admin` default-privilege rule still carries
`arwdDxtm` · `TRIGGER`/`REFERENCES` still granted on the views.

**Harness lesson worth keeping.** The ticket's Step 5 probe (`BEGIN; SET LOCAL ROLE anon;
INSERT …; ROLLBACK;`) is unsafe to paste into an MCP `execute_sql` call: if the harness
autocommits each statement separately, `SET LOCAL ROLE` is discarded and the INSERT runs as
`postgres` — succeeding, and firing `trg_push_on_notification_insert` over `pg_net`, which no
rollback undoes. Run role-switching probes inside a single `DO $$ … $$` block, which cannot
be split, trapping `insufficient_privilege` as the pass condition.

---

**AMENDED 2026-08-29 — successor filed as KAN-86; severity of the remainder is LOW.**
The "184 base tables still grant write" line above is still true and was being read as an
open write surface. It is not: all 184 have RLS enabled and no permissive policy admits
`anon` (`T-035`, evidence on KAN-86). Redundant privilege, not a live path — do not sequence
KAN-86 ahead of KAN-56/59/57. The `supabase_admin` default-privilege rule and
`spatial_ref_sys` are recorded on KAN-86 as permanent exclusions, not as open work.
See [[policy-role-vs-check-trap]].
