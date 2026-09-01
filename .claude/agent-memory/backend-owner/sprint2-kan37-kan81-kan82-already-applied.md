---
name: sprint2-kan37-kan81-kan82-already-applied
description: KAN-37, KAN-81, KAN-82, and KAN-76 were already fixed/applied to production before being picked up — verified live, don't re-author without checking first.
metadata:
  type: project
---

As of 2026-08-30: KAN-37 (`v_notifications_feed`/`v_notifications_ranked` security_invoker),
KAN-81 (drop `get_user_fcm_tokens`), and KAN-82 (authorize `get_profile_by_id`) were all already
applied to production in a prior session (migrations exist in `supabase/migrations/`, cto's
G-002 apply-and-verify comments are on the tickets). KAN-38 is Jira-status Done.

**Why this matters:** KAN-37's Jira ticket was still sitting in "To Do" despite the fix being
live — nobody had closed the loop with a verification comment. Don't assume a ticket's Jira
status reflects whether the migration was applied; check `supabase/migrations/` and the live
schema first. KAN-81/82 still have open sub-items not mine to close (AC2/AC4 confirmations from
notifications-specialist/flutter-feature-agent, and a Part-2 follow-up ticket for KAN-82 that
was never filed).

**How to apply:** Before authoring a migration for any KAN ticket, check `supabase/migrations/`
for an existing file matching the ticket number, and check the live schema/grants directly —
a "To Do" Jira status is not evidence the work wasn't already done.

**2026-08-31 recurrence — KAN-76:** ticket described `v_circle_feed` as joining
`circle_members` directly (fanout bug, wrong `circle_members_count`). Live `pg_views` definition
showed it already computed `circle_members_count` via a `circle_member_count(uuid)`
`SECURITY DEFINER` scalar function with no `circle_members` join at all — introduced by
`kan56b_v_circle_feed_members_count_fix.sql`, predating this ticket, then hardened again by two
already-applied `kan77_*` migrations (in `supabase/schema/migrations/`, the old pre-KAN-33 dir —
still worth checking even though new migrations go in `supabase/migrations/`). Verified 3/3/3
rows and caller-independent count=2 for postgres/member/owner against the ticket's own test
circle before concluding no fix was needed. Lesson: search **both** migration directories
(`supabase/migrations/` and the archived `supabase/schema/migrations/`) and read the live view
definition before assuming a ticket's description of "current" behavior is still accurate —
tickets get filed and then overtaken by other work before anyone picks them up.
