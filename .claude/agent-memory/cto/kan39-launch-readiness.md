---
name: kan39-launch-readiness
description: The CTO launch-readiness verdict of 2026-08-27 — do not promote until KAN-56/57/58 land; what was deliberately excluded and why.
metadata:
  type: project
---

**Verdict (2026-08-27, KAN-64):** do not promote. Gate re-sorted after `master-analyst`
challenged it — verdict unchanged, grounds corrected.

**Blockers, harm occurring or executable today:** **KAN-67** revoke `anon` write grants (FIRST — 8 live unauthenticated write paths) · **KAN-56** anon definer-view read leak ·
**KAN-58** logout clears nothing / FCM token never revoked · **KAN-59** any account can push
arbitrary title+body as a trusted first-party push (promoted from "strong fourth" — passwordless
signup makes accounts free, and promotion scales targets AND attackers together).

**Pre-promotion requirement, different grounds:** **KAN-57** Play upload key. **No user is
harmed today** — verified across all refs and all history that the keystore was never committed
in any form, no encoded blob, and Android signing never runs in CI. The password alone signs
nothing. It goes first because the disclosure is permanent and unrecoverable and the fix is an
afternoon. **Say "a credential is exposed, the signing artifact is not"** — the stronger
phrasing is untrue.

**The test that caught the misclassification:** *if this fix took three weeks instead of an
afternoon, would I still hold launch?* If no, cheapness — not danger — is driving the blocker
label. Apply it to every item before calling it a blocker.

Decisions **T-001..T-011** in `docs/DECISIONS.md`; security architecture in
`docs/ARCHITECTURE.md` §10. Tickets KAN-56..KAN-63, each naming its owning agent.

**Why:** the governing distinction is *would harm a user* vs *would embarrass us*. 143
oversized files, 317 colour literals, three error conventions, 20,545 lines of dead rewards
code, 113 flags of which 10 gate anything — all real, **none can hurt an installed user.**
They are why the product feels immature, which is a **product** judgement (cpo's half).

**Two facts argue for promotability once the three land:** the app compiles clean (0 errors,
66 tests pass) and authorization is deferred to RLS with no client-side auth decisions, admin
routes fail *closed*, and deep links do not bypass the gate. **The leak is a failure of a view
layer built on a correct model, not a failure of the model.**

**Ordering constraint that bit:** flipping views to `security_invoker` makes caller RLS apply,
so a view over a table with no usable policy returns 0 rows and blanks a live screen.
`public.games` has RLS enabled with **zero policies**. Base-table policies land first.

**How to apply:** if asked whether Dabbler can be promoted, this is the standing answer until
KAN-56/57/58 close. If asked to fix any of it directly against production — no (decision `019`).

See [[load-bearing-measurements]], [[confirmed-false-positives]], [[analyst-reconciliation]].

**ESCALATION 2026-08-28 — KAN-56 is not a read leak.** It is **unauthenticated destructive write
access to production**. Demonstrated without writing, via `EXPLAIN` (no `ANALYZE` — plans and
ACL-checks, executes nothing), with a control:

```sql
SET LOCAL ROLE anon;
EXPLAIN DELETE FROM public.v_notifications_feed WHERE id='…'::uuid;  -- NO RLS filter in plan
EXPLAIN DELETE FROM public.notifications        WHERE id='…'::uuid;  -- RLS filter PRESENT
```

Views are owned by `postgres`, whose `rolbypassrls` is **true** — with `security_invoker=false`,
base-table access is checked as the owner, so **RLS is definitionally not consulted**. No
residual protection.

**Drift, not five bad views:** 70 of 71 views grant `anon` INSERT/UPDATE/DELETE · 49 definer ·
**8 auto-updatable = live write paths** (`v_notifications_feed`, `v_notifications_ranked`,
`v_posts_time_preview`, `v_user_reputation`, `v_my_drafts`, `v_hidden_list`,
`v_needs_organiser`, `geometry_columns`).

**Fix order changed: the schema-wide `REVOKE` on `anon` comes FIRST**, ahead of all
`security_invoker` work — destructive beats confidential. It is behaviourally free: the app never
writes through a view (`grep -rnE "\.from\('v_|\.from\(\"v_" lib` returns nothing).

See [[load-bearing-measurements]], [[confirmed-false-positives]], [[analyst-reconciliation]].
