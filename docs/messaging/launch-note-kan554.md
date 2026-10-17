# Messaging launch note — KAN-554 (L1)

Status: **IN PROGRESS. Steps 3 and 4 are done; steps 5, 6 and 7 are the CEO's and the orchestrator's and are not done.** This note is completed with timestamps as each step passes. No id, token or secret appears here; the Worker URL and the variables are named only.

## Go-live reference (C5)
The CEO's go-live is recorded in the PM ledger, ref `messaging-launch`, 2026-10-15 ("افتح الان", open it now), and was cited by the orchestrator in its 2026-10-17 23:19 go-live ruling before any step ran. Blockers were Done before step 2: KAN-565 (live DB has every launch migration), KAN-566 (production Worker deployed from Alpha with D1 0001-0004 applied), KAN-553 (kill-switch drill passed, under 2 s each way).

## What this launch turns on
| Layer | Value after launch |
|---|---|
| App flags (compile-time, one reviewed commit) | `FeatureFlags.messaging`, `enableMessagingGameChat`, `enableMessagingReporting`, `messagingRealtime` = true, plus `enableMessagingDirect` = true (DMs and the Home list are in the launch per the CEO ruling of 2026-10-15) |
| Worker variable `MESSAGING_ACCESS_MODE` | `all` (set by the CEO in the Cloudflare dashboard, after the flags are live on the canary build) |
| Pages build variable `MESSAGING_API_BASE_URL` | the production Worker's public URL, in BOTH Pages variable environments, Production and Preview (set by the CEO) |

## Rollback (one step, no release)
Set the Worker variable **`MESSAGING_ACCESS_MODE` to `off`** in the Cloudflare dashboard (Workers -> dabbler-messaging-staging -> Settings -> Variables). It takes about a second (KAN-553 drill: refused after 0.6-1.7 s), chat becomes unavailable for everyone and the app shows the unavailable state. The four app flags are compile-time and are NOT the kill switch. If the app itself must be withdrawn, revert the KAN-554 flag commit and redeploy. The database objects and the Worker stay in place. `keep_vars = true` is set in `workers/messaging/wrangler.toml` so a later Worker deploy does not undo a dashboard value (verify once on the first deploy; see the Worker README).

## Steps
| Step | Owner | State |
|---|---|---|
| 2. Blockers Done, migrations and Worker live | Memphis (verified in KAN-565, KAN-566, KAN-553) | done |
| 3. `MESSAGING_API_BASE_URL` in Pages Production and Preview | CEO | **done** (C7): the build variable `MESSAGING_API_BASE_URL` exists in the Pages project `webapp`, in BOTH variable environments, Production and Preview (PM ledger 2026-10-17); recorded by name only, no value here |
| 4. Flag commit + `keep_vars = true` | Memphis | done: flag commit `cb653cd07e79c75f25efe4410a1212b0e49e70fe` (lib/ changes only in `lib/core/config/feature_flags.dart`: the four launch flags plus `enableMessagingDirect` set true; consistency checks pass), `keep_vars` commit `f710d05ea114d26d476b39d345888dd2b23fc4f1`. C1 `flutter test test/core/config` exit 0; C2 `flutter analyze --no-pub --no-fatal-infos` exit 0; C3 full `flutter test` exit 0 (2980 passed, same count as the base). No Worker deploy. |
| 5. `MESSAGING_ACCESS_MODE` = `all` | CEO, after the flags are live on canary | **pending** |
| 6. Canary verification (two test accounts: message round trip, Home icon and Messages list, report filed, admin Reports lists it and Read this message works for the CEO's admin account only, realtime delivery) | orchestrator with the CEO | **pending**, each item to be recorded pass/fail with a timestamp |
| 7. Production app (same round trip on https://app.dabbler.pro) | merge into `main` needs the CEO's explicit go-ahead in the moment | **pending** |

## Known gaps carried into the launch
- The test game fixture is over, so a stored message round trip cannot be shown with it; the canary round trip needs an open game with two active test members.
- `app_admins` has no rows (one `is_admin()` user), so a message report notifies nobody; the admin Reports screen still lists it through `is_admin()`. The one-line INSERT for the CEO is in `docs/messaging/live-migrations-kan565.md` once that report is committed.
- Pending-step evidence (timestamps, pass/fail per item, the production round trip) is to be appended below by whoever runs steps 6 and 7.

## Evidence log
(append here)
