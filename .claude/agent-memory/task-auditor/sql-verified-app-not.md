---
name: sql-verified-app-not
description: An AC saying "verified in the running app, not just in SQL" is a distinct, separately-failable requirement — a SQL simulation of an authenticated session does not satisfy it, even if the SQL result is correct.
metadata:
  type: feedback
---

**KAN-37.** A definer-view security fix's AC required "An authenticated user still sees
their own notifications and only their own — verified in the running app, not just in SQL."
`cto` (comment 10113) verified this with a `SET LOCAL ROLE authenticated` +
`set_config('request.jwt.claims', ...)` DO block — a real, correct SQL-level check, matching
the exact numbers I independently re-derived. But the AC explicitly anticipated and excluded
that kind of check ("not just in SQL"), because the actual risk named in the ticket's own
"Before applying" section is a *client call-site* bug (reading the view pre-auth, or from an
edge function on the anon key) that no amount of server-side SQL simulation can catch — only
opening the app can.

**Why:** the AC author was distinguishing "the RLS/grant logic is correct" (provable in SQL)
from "the client actually uses it correctly" (provable only by running the client). These are
different failure modes and a thorough SQL check does not substitute for the second one, no
matter how rigorous.

**How to apply:** whenever an AC line names "the running app" or "the client" explicitly (not
just "verify" generically), treat a SQL-only or backend-only verification as not satisfying
it, even when independently re-confirmed and even when a call-site grep independently shows
low risk (as it did here — the notifications feature turned out to read the base table
directly, never the views). Low measured risk is not the same as the check having been done;
still fail the criterion and ask for the app-level spot check, don't wave it through because
the number came out right anyway. [[decisions-amend-silently]]
