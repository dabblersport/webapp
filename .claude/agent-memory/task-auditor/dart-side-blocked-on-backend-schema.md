---
name: dart-side-blocked-on-backend-schema
description: A flutter-feature-agent ticket that wires UI correctly but depends on a missing table/migration or backend-only event cannot pass, even when the Dart half is done well and the gap is honestly self-reported
metadata:
  type: feedback
---

When a Flutter-scope ticket's AC literally requires something only a migration or a
server-side call can provide (a table that must exist, an event that must fire on a
DB-side status transition), a correct and honest "UI wired, backend piece missing,
routed to backend-owner" report is still a FAIL, not a partial-Done.

**Why:** seen twice in one review pass (KAN-51 "games confirmed" needs a trigger/RPC-side
`rpc_track_event` call; KAN-52 needs the `data_export_requests` table before the request
can persist). Both agents did the right thing — didn't touch schema, named the exact
shape needed, routed it to `backend-owner`. That correctness is worth crediting in
"WHAT IS ALREADY FINE," but the literal AC ("reaches `data_export_requests`", "games
confirmed queryable end to end", "verified in production") is still unmet. [[decisions-amend-silently]]

**How to apply:** when a report says "X is done, Y needs backend-owner," verify Y
independently (query production directly, don't trust the report) and check whether any
AC is worded to require Y. If so, fail the ticket even though the Dart work is good —
but write the rework brief to explicitly protect the good half and recommend a
companion backend ticket rather than implying the whole thing needs a redo. This is
the same shape as [[sql-verified-app-not]]: a criterion demanding an end state that
does not exist yet fails regardless of how well-reasoned the partial work is.
