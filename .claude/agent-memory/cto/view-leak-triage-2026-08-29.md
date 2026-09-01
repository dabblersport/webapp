---
name: view-leak-triage-2026-08-29
description: Post-KAN-67/37/38 live state of the anon definer-view leak, the 3/3 flip-vs-revoke split (T-029), and the two census queries that undercount
metadata:
  type: project
---

After KAN-67 + Migrations A/B, **six** anon-readable definer views remain, split 3/3 by one rule:
`security_invoker` applies the caller's RLS to EVERY joined relation, so **one zero-policy base
relation blanks the view for legitimate users**. FLIP `v_mod_queue_open`, `v_circle_feed`,
`v_circle_feed_visible`; REVOKE `v_safety_overview` (`safety_takedowns` 0 policies),
`v_hidden_list` (`user_hidden_modes` 0), `v_my_drafts` (`content_drafts` 0). See `T-029`.

**Why:** three tickets (KAN-25/36/56) described the same three still-leaking views while the board
read as "security work progressing"; `v_mod_queue_open` (9 rows), `v_safety_overview` (1),
`v_circle_feed` (6) were still live to `anon` two days after the migrations.

**How to apply:** all remaining read-side work is on KAN-56; the durable census is KAN-26. Before
ruling flip-vs-revoke on any view, resolve its base relations from `pg_depend`/`pg_rewrite` and
count policies on each — do not reason from names. See [[cto-own-ruling-corrections]] and
[[invoker-flip-join-trap]].

**Two census queries in circulation undercount. Both are wrong:**
- Supabase advisor finding count (25) — an advisor reports what it flags, not what exists.
- `WHERE c.reloptions IS NULL` (KAN-26/36's replacement query, 49) — silently excludes views
  carrying any *other* reloption. Undercounts by 16.
Correct: `NOT (array_to_string(reloptions,',') ILIKE '%security_invoker=on%')` → **65 of 71** definer,
45 anon-readable, 25 anon-readable definer with no `auth.uid()` (measured 2026-08-29).

**Still open and not view-scoped:** 184 base tables in `public` grant `anon` INSERT
(`relkind='r'`). KAN-67 closed 7 views, not the schema. The 2 PostGIS views stay anon-writable —
no `supabase_admin` membership (`T-025`).

---

**AMENDED 2026-08-29.** The closing line — "184 base tables in `public` grant `anon` INSERT" —
is now KAN-86 and is **LOW severity**: RLS is enabled on all 184 and no permissive policy
admits `anon` (`T-035`). Read it as defence-in-depth debt, not an open door.
See [[policy-role-vs-check-trap]].
