---
name: kan-59-authz-fix
description: KAN-59 send-push-notification authz+rate-limit fix — authored in repo, NOT yet deployed to production
metadata:
  type: project
---

2026-08-28: `send-push-notification` had no authorization check on the per-user
lane — any authenticated caller could push arbitrary title/body to any other
user (KAN-59, phishing/harassment primitive). Fixed in
`supabase/functions/send-push-notification/index.ts`, added two functions,
both scoped strictly inside `if (!trusted)` so the trusted `x-trigger-secret`
server lane (see [[db-triggers-functions]]) is untouched:

- `callerMayNotify(supabase, callerId, targetUserId)` — caller must have one
  of: mutual follow (`profile_follows`, resolved via `profiles.id`/`user_id`
  since follows key off profile id and a user can hold player+organiser
  profiles), shared circle (`circle_members`), shared active squad
  (`squad_members` status='active'), shared active game roster
  (`game_roster` status='active'), shared meetup attendance
  (`meetup_attendees`). No match → 403. Self-notify exempt (same as existing
  block check).
- `isRateLimited(supabase, callerId, targetUserId)` — 20 direct sends/hour/
  caller, backed by existing `audit_events` table (`actor_user_id`,
  `action='push.direct_send'`) — no new table. Counts+records every direct
  call regardless of outcome (also bounds probing). Fails closed on DB error.

**STATUS: repo-only, NOT deployed.** Per decision 019 I cannot
`deploy_edge_function` / apply to production — only the PO can. Until
deployed, the live `wtncuzcskpigqpmnxwws` function is still the vulnerable
version. [[edge-functions]] describes the OLD (currently-live) behavior —
do not treat this file as describing prod until confirmed deployed (check
`get_edge_function` version/updated_at against this file's date).

Full writeup + verification steps: Jira KAN-59 comment (2026-08-28).

Also flagged in the ticket but explicitly NOT done by me: `detect-country`
(unowned, CONTRACT.md row 118) and a repo-wide audit of every other edge
function for the same authn-vs-authz gap.
