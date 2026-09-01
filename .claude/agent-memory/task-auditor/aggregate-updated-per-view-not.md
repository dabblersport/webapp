---
name: aggregate-updated-per-view-not
description: A doc's summary/aggregate numbers can be updated while its per-item detail table is left stale — check both, not just the count
metadata:
  type: feedback
---

When an AC requires a document to "record the position for every X," don't just grep for
whether the topic is mentioned or whether the file's headline numbers moved — check the
literal per-item list.

**Why:** KAN-38 (2026-08-28). backend-owner triaged 17 views and cto applied two migrations
fixing most of them, all correctly recorded in Jira comments and in DECISIONS.md (T-027,
P-019). But `docs/SCHEMA.md` §2d's aggregate counts (71 total / 28 invoker / 45 anon-readable)
*were* updated to reflect the same migrations, which made it easy to assume the file was
current. §2a's per-view table was not — it still listed 9 of those views as "not yet probed"
and deferred to a different ticket. The aggregate arithmetic reconciled; the detail didn't.
This is exactly the failure mode [[decisions-amend-silently]] describes but for a schema
census file instead of DECISIONS.md: a document with both a summary and a detail section can
drift internally, and checking only the summary gives a false pass.

**How to apply:** When an AC/gate asks a governance doc to name every item in a set
(views, tables, findings), grep for the *specific identifiers* the ticket lists, not just
the section's aggregate numbers or a topic keyword. If a doc has both an aggregate and a
per-item breakdown, check that they still agree — a moved aggregate does not prove the
detail moved with it. Also worth noting: the agent who did the SQL work (backend-owner)
correctly declined to write the census file itself, per CONTRACT.md's file-ownership split
(master-analyst owns SCHEMA.md §§1-8/§10), and explicitly flagged the gap in its handoff
comment — the failure was that nobody picked up the flagged follow-up, not that anyone wrote
outside their lane. Worth checking Jira comments for "I don't own this file, leaving it for
X" flags that may have gone unactioned.
