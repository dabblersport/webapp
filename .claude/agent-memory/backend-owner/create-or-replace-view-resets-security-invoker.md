---
name: create-or-replace-view-resets-security-invoker
description: CREATE OR REPLACE VIEW silently resets the security_invoker reloption to off (grants survive, this option does not). Any migration that CREATE OR REPLACEs a view already flipped to security_invoker=on must re-ALTER it in the same migration, or it silently reopens the leak the flip closed.
metadata:
  type: feedback
---

**`CREATE OR REPLACE VIEW` does not preserve `security_invoker = on`.** Grants (SELECT to anon/
authenticated etc.) survive a `CREATE OR REPLACE VIEW`, per cto's own [[invoker-flip-join-trap]]
memory ("a regression check to run after any CREATE OR REPLACE VIEW: it can silently restore
default grants") — but the `security_invoker` reloption does not survive at all. It resets to the
default (`off`, i.e. `SECURITY DEFINER`-like owner-bypass behavior).

**Why it matters:** on KAN-56's follow-up fix (2026-08-29, `kan56b_v_circle_feed_members_count_fix.sql`),
I needed to `CREATE OR REPLACE VIEW public.v_circle_feed` to fix an unrelated column (a corrupted
`circle_members_count`) on a view that KAN-56's base migration had *already flipped* to
`security_invoker = on` in production. Verified empirically in a rolled-back transaction against
the real production view: immediately after the `CREATE OR REPLACE VIEW`, `security_invoker` read
back `false`. Without adding `ALTER VIEW public.v_circle_feed SET (security_invoker = on);`
*after* the replace, in the same migration, this "unrelated fix" would have silently reopened the
exact anon-readable leak that KAN-56 existed to close — a second regression on top of the first.

**How to apply:** whenever a migration issues `CREATE OR REPLACE VIEW` against a view that carries
`security_invoker = on` (or any other reloption) from a prior migration, always re-`ALTER VIEW ...
SET (security_invoker = on)` immediately after the replace, in the same transaction — don't assume
the flag rides along. Verify it empirically (`pg_options_to_table(reloptions)` on `pg_class`) in a
rolled-back transaction before trusting it, exactly the way cto's grant-survival check works — this
is the reloption analog of that same check, and just as easy to miss since the failure is silent
(no error, just a view that quietly reverts to bypassing RLS).

Related: [[invoker-flip-join-trap]] (cto's memory, the grant-survival half of this same class of
gotcha), [[rls-policy-count-is-not-permission]].
