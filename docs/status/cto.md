# docs/status/cto.md — CTO status

**Last run:** 2026-08-27 · **Branch:** `Canary` · **Epic:** KAN-39

## Standing verdict

**Dabbler is not promotable today.** Re-sorted 2026-08-27 after `master-analyst` caught the
criterion being applied loosely — the verdict is unchanged, the grounds are now precise.

**Promotion blockers — harm occurring or executable today:**

| | Ticket | Owner | Needs DB access |
|---|---|---|---|
| 1 | **KAN-56** — anon definer-view leak (609 private notifications, 49 users) | `notifications-specialist` | yes |
| 2 | **KAN-58** — logout clears nothing, FCM token never revoked | `notifications-specialist` | no |
| 3 | **KAN-59** — any account can push arbitrary title/body to any user (**promoted from fourth**) | `notifications-specialist` | no |

**Pre-promotion requirement, different grounds:**

| | Ticket | Owner | Needs DB access |
|---|---|---|---|
| 4 | **KAN-57** — Play upload key credential public 9 months | `version-control` + PO | no |

**KAN-57 harms no user today.** The password alone signs nothing: the keystore has never been
in the repository in any form (verified across all refs and all history, including encoded
blobs), and Android signing never runs in CI. It goes before promotion because the disclosure
is **permanent and unrecoverable** and the fix costs an afternoon — not because anyone is at
risk. **Argue it to the PO as "a credential is exposed, the signing artifact is not."** The
stronger phrasing is not true, and an overstated blocker is how a real one gets discounted.

Full reasoning, with rejected alternatives, in `DECISIONS.md` **T-011** and **T-003**.

## Open tickets raised this run

| Ticket | Summary | Owner | Blocker? |
|---|---|---|---|
| KAN-56 | Close the anon definer-view leak | `notifications-specialist` | **yes** |
| KAN-57 | Rotate the Play upload key | `version-control` | **yes** |
| KAN-58 | Logout teardown + FCM revocation | `notifications-specialist` | **yes** |
| KAN-59 | Edge-function authorization scope | `notifications-specialist` | no (but abusable today) |
| KAN-60 | Android backup exclusion rules | `app-store-submission-fixer` | no |
| KAN-61 | Anon-reachability allowlist in CI | `version-control` | no (depends on KAN-56) |
| KAN-62 | Re-scope KAN-27 and KAN-28 | `master-analyst` | no |
| KAN-63 | Four broken-but-not-leaky surfaces | mixed | no |
| KAN-64 | This assessment | `cto` | **In Review** |

## Decisions landed

`DECISIONS.md` **T-001 .. T-011**. `ARCHITECTURE.md` **§10 — the security architecture**.

Load-bearing positions: views default to `security_invoker = true` (T-001) · anon reachability
is a CI-enforced allowlist (T-002) · no credential literal in a tracked file (T-003) · logout is
a teardown contract (T-004) · session stays in SharedPreferences, backup exclusion is the control
(T-005) · **no certificate pinning** (T-006) · dead-but-wired code is deleted, not implemented
(T-007) · `Either` converts on touch, no migration project (T-008) · edge functions verify
authorization scope, not just authentication (T-009) · line count and colour literals are budgets,
not defects (T-010).

## Deliberately not blockers

143 files over 500 lines · 317 hardcoded colours across 43 files · three error-handling
conventions · 20,545 lines of unreachable rewards code · 113 feature flags of which 10 gate
anything · 13 `MaterialPageRoute` sites bypassing GoRouter.

All real. **None can harm somebody who installs the app.** They are why the product feels
immature — a product judgement, and the `cpo`'s half of KAN-39. Attacking them instead of the
leak and the signing key would be a serious misallocation of the pre-launch window.

## What the assessment confirmed is sound

`flutter analyze` → **0 errors** (55 warnings, 102 infos) · `flutter test` → **66 pass** ·
authorization deferred to RLS with **no client-side authorization decisions anywhere** · admin
routes server-authoritative and fail **closed** · deep links do **not** bypass the auth gate ·
transport clean, ATS correct, no cleartext · **no service-role key ever committed** (full
object-database sweep, 8,301/8,301 blobs).

The database leak is a failure of a **view layer built on a correct model**, not a failure of
the model.

## Next

1. `master-analyst` re-scopes KAN-27/28 (KAN-62) before any agent works them.
2. Migration for KAN-56 drafted and reviewed — **base-table policies before the invoker flip**, or live screens go blank (`public.games` has RLS with zero policies).
3. KAN-57 and KAN-58 can proceed in parallel; neither needs database access.

**No agent writes to production** (decision `019`). Everything ships `Canary` → verify → PR.
