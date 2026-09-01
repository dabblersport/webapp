---
name: ci-db-credential-constraints
description: KAN-61/T-034 — never mint a prod DB password via MCP (transcript); direct host is IPv6-only so CI needs the pooler; zero-grant role suffices. RESOLVED 2026-08-29, plus how to prove a diff-shaped CI gate fails without touching prod
metadata:
  type: project
---

Three constraints established while unblocking KAN-61's `SUPABASE_DB_URL` (decision `T-034`).

**1. `cto` must not mint production DB passwords.** `G-002` grants the DDL authority
(`CREATE ROLE` is a privilege change, not data mutation), so authority is never the blocker.
The blocker is the *path*: the Supabase MCP takes SQL as a tool argument, so any password
lands in an agent transcript. There is no agent-side workaround — a pre-hashed SCRAM verifier
still requires knowing the password. **Why:** a production credential that has passed through
a transcript is not clean, and the PO pasting one `CREATE ROLE` in the SQL editor costs
seconds. **How to apply:** whenever a task asks you to create *and install* a credential,
split it — you specify the exact SQL and the exact secret format, the PO executes. This is a
path constraint, not a permission one; do not resolve it by asking for more authority.

**2. `db.wtncuzcskpigqpmnxwws.supabase.co` is IPv6-only** — `host` returns an AAAA record and
no A record (verified 2026-08-29). GitHub-hosted runners have no IPv6, so **any CI workflow
using the direct host will fail**. CI must use the Supavisor pooler with the
`<role>.wtncuzcskpigqpmnxwws` username form. **Do not infer the pooler host from DNS** —
every region's pooler hostname resolves regardless of project membership, so a successful
lookup proves nothing about which shard serves this project. Copy it from the dashboard.

**3. A zero-grant login role is enough for catalogue gates.** Verified read-only:
`pg_database.datacl` is `{=Tc/postgres,...}` so PUBLIC already holds `CONNECT`; and cross-role
privilege inquiry needs no membership — acting as `anon` with
`pg_has_role(...,'authenticated','MEMBER') = false`, `has_table_privilege('authenticated',...)`
still resolved (47 public views). So `has_table_privilege('anon', ...)` works from a role with
nothing granted. Never reach for `pg_read_all_data`, `service_role`, or a Supabase PAT for
this — a PAT is *wider* than a DB login (whole account, including the second unrelated
project). Accepted and unavoidable residual: any login role reads all of `pg_catalog`,
including function bodies via `pg_proc.prosrc`. Catalog read is PUBLIC and not practically
revocable, so full schema disclosure comes with every DB credential. No user data, though —
with no table grants, RLS is not even the binding constraint.



---

**Resolved 2026-08-29 — all three predictions held.** The PO created `dabbler_ci_readonly`
in the SQL editor and set `SUPABASE_DB_URL` via `gh secret set`. The gate connects from
GitHub-hosted runners over the pooler and reads `pg_catalog` with zero grants, confirming
constraints 2 and 3 empirically rather than by argument. `T-034` status updated in
`docs/DECISIONS.md`; KAN-61 moved to In Review.

**The reusable technique — proving a CI gate's failure path without staging the failure.**
KAN-61's last open criterion was "prove it fails, not just that it passes," and the obvious
reading (add a leaky view to production) is forbidden. Instead: **mutate the expectation, not
the world.** The gate's failure condition is `comm -23 <live> <allowlist>` — a live view
absent from the allowlist. Deleting one line (`v_game_card`) from between the
`ANON_ALLOWLIST_START/END` markers in `SCHEMA.md` §2f produces that exact condition through
a real pooler connection and a real `pg_class` read. Run `33259141446` went red with
`FAIL: ... - v_game_card`; `33259101405` and `33259167876` bracket it green.

**Why:** an allowlist gate is a diff between observed and expected. Either side can be
perturbed to exercise the diff, and perturbing the expectation is reversible, local, and
touches nothing shared. **How to apply:** any future "prove the gate fails" criterion on a
diff-shaped check — edit the expected set on a throwaway branch, never the production side.
Insist on one discriminator: the red run must fail *on the diff*, quoting the specific item.
A red run from a connection error, a missing binary, or an empty live set proves the gate
is broken, not that it works — and looks identical in a conclusion field. Read the log line.

**Corollary worth remembering:** a workflow's run history can be entirely uninformative. All
three KAN-61 runs before the secret existed were red on "SUPABASE_DB_URL is not set" — a
green-vs-red tally would have said the gate was failing, when it had never once executed.
Check that a run's *failure reason* is the one the gate is meant to detect.

Related: [[load-bearing-measurements]], [[qa-and-ci-gate-position]], [[g002-bypass-2026-08-29]]
