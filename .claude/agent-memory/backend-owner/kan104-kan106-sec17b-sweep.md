---
name: kan104-kan106-sec17b-sweep
description: KAN-106 (profiles.user_id anon leak, 154 uids) migration authored and In Review; KAN-104 (v_space_slots_today grant + is_booked) blocked on cto's AC2 decision, In Progress.
metadata:
  type: project
---

2026-09-01, dispatched by team-lead, EFFORT high.

**KAN-106** — column-level `REVOKE SELECT (user_id) ON public.profiles FROM anon`
authored (`supabase/migrations/20260901100000_kan106_revoke_profiles_user_id_anon.sql`),
not applied, moved In Review. Full reachability sweep is in the migration header:
Dart callers are all post-auth-gate (router sends unauthenticated users to landing
before any profile fetch), views selecting `user_id` are either self-filtered
invoker views (0 rows to anon regardless) or ungranted, `whois` and five other
anon-executable definer functions also return `user_id` but need their own ticket
— see [[security-definer-rpc-census]].

**KAN-104 — UPDATE 2026-09-01: cto ruled T-044, option (a).** Migration authored
(`supabase/migrations/20260901120000_kan104_find_slots_security_definer.sql`,
must apply after KAN-74's, restates its body in full + SECURITY DEFINER +
`row_security=off`, plus `security_invoker=true` on the view). Moved In Review.
AC1's live regression check still needs KAN-74 applied + a seeded test booking
— that step is documented in the migration's verification block, not done yet.

Original analysis, still relevant background: the ticket reserved the (a)/(b)/(c)
decision for `cto` (mark `find_slots` SECURITY DEFINER / narrow policy on
`venue_bookings` / revoke the view's anon+authenticated grant). Two things worth
remembering from that phase:

1. **KAN-74's migration (`20260831130000_kan74_fix_find_slots_opening_hours.sql`)
   is authored but was still not applied as of 2026-09-01** — `find_slots` still
   raises 42P01 live (`venue_opening_hours` doesn't exist, superseded by
   `opening_hours` — see [[opening-hours-renamed-and-reshaped]]). Check
   `supabase_migrations.schema_migrations` before assuming an authored-and-correct
   migration is live; it wasn't, and this ticket's AC1 literally can't run until
   it is.
2. **`venue_bookings` has 0 rows project-wide** — even once KAN-74 lands there's
   no booking to observe `is_booked` flip. The mechanism proof (RLS on
   `venue_bookings_select` denies anon/non-privileged-authenticated all rows via
   `can_view_venue_bookings`, so `find_slots`'s internal EXISTS always finds
   nothing for those callers) holds without live data — a static policy read is
   sufficient here, row-count experiments aren't always necessary or possible.
