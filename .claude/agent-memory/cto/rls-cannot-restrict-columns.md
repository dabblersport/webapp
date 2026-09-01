---
name: rls-cannot-restrict-columns
description: An RLS policy is a row filter and cannot restrict columns; "a narrow policy exposing only the columns X needs" is not implementable without a second mechanism (column GRANT)
metadata:
  type: feedback
---

**An RLS policy cannot restrict columns.** Any proposal shaped "add a narrow policy
exposing only the columns feature X needs" is not implementable as written — it requires
a separate column-level `GRANT`, i.e. two mechanisms, and the policy still widens the
base table on *every* access path including the raw PostgREST endpoint.

**Why:** it read as the moderate middle option among KAN-104's three (`T-044`), and it
was the one that could not actually be built. A proposal that sounds like a compromise
deserves a feasibility check before a preference check.

**How to apply:** when weighing a definer-function boundary against "just add a policy",
reject the policy on implementability first, blast radius second. Related:
[[definer-rpc-exposure]] — and remember to check the function's own EXECUTE grants, since
revoking a *view* grant leaves the RPC path open ([[anon-grant-two-sources]]).
