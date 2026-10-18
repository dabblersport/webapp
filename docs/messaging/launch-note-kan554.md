# Messaging launch note — KAN-554 (L1)

Status: **IN PROGRESS (API evidence complete; UI checks with the CEO; step 7 waits for his go-ahead). Steps 3 and 4 are done. Step 6 is partly verified at the API level (below); the UI checks, the game-chat round trip, step 5 confirmation and step 7 are not done.** This note is completed with timestamps as each step passes. No id, token or secret appears here; the Worker URL and the variables are named only.

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
### 2026-10-18 (Dubai morning; UTC times below), API-level pass as the two test accounts, no message text read

What this evidence is: calls to the production Worker and the live database as the two test accounts (Keychain `dabbler-test-user`, `dabbler-test-user-b`, each profile carries "test"), plus counts from read-only SQL. It is NOT a UI check: no screen was driven, and nothing here proves the Home icon, the Messages list rendering, the report sheet or the admin Reports screen. No id, token or message text is recorded.

| Item | Result | When (UTC) | Evidence |
|---|---|---|---|
| Fixture game is open for writable game chat | **FAIL (not available)** | 08:53:34 | The "Dabbler Chat Test" game ended at 2026-10-18 00:19 UTC (database time 08:53); the Worker answers `writable: false`, `read_only_reason: game_ended` for both accounts. A count of games that are not ended, not cancelled and have an active roster member returns 0. Game-chat send was therefore not tested. No new game was created (ruling: no duplicate fixture) |
| Worker answers both test accounts (mode is not `off`) | PASS | 08:54:53 | GET game conversation: 200 for both accounts. Both accounts are on the allowlist, so this cannot tell `all` from `allowlist`: **the value `all` is not confirmed by this evidence** |
| Two-account message round trip (DM, because DMs need no game) | PASS | 08:55:28 | A starts the DM (200), A sends (201), B lists and sees exactly 1 message with A's test marker (200) |
| Report can be filed | PASS | 08:55:29 | B reports A's message: 202; `moderation_reports` rows created in the last 15 minutes: 1 (read-only count) |
| Admin report list is admin-only | PASS (refusal side only) | 08:55:29 | Both non-admin test accounts calling `msg_list_message_reports` get P0001 `forbidden`. The admin success path and "Read this message" need the CEO's admin account: not tested |
| Realtime delivery | PASS | 08:56:08 | B subscribed to its private user topic (SUBSCRIBED); after A's send, B received 1 wake in 487 ms with keys `conversation_id, id, seq, type` only |
| Home icon, Messages list, report sheet, admin Reports screen (UI) | NOT RUN | n/a | Needs a signed-in UI session; entering account passwords into a hosted login form is not something automation does |

Side effects left in the live project by this pass (normal paths, test accounts only): one DM pair between the two test accounts with two test messages, and one message report from the second test account (open for the CEO to resolve). No row was deleted or edited.

### 2026-10-18 second fixture and game-chat pass (UTC; Dubai is UTC+4)

Fixture: the first test game ended, so ONE new game "Dabbler Chat Test 2" was created through the app's own `rpc_create_game` / `rpc_join_game` (owner Dabbler-Test, public, capacity 10, 2026-10-18 15:00-17:00 Dubai). Read back: 1 game, 5 active roster rows (1 host + 4 players, including the second test account "teat"), 4 notifications created since it was made (count only), no conversation row yet (the registry creates it when a member first opens the chat).

Live check script `supabase/tests/messaging/launchcheck/run.mjs` (README beside it; 4 unit tests with fakes). One run at 09:02:24-09:02:28 UTC as the two test accounts against the production Worker, which answered past the access gate:

| Item | Result |
|---|---|
| Both members get the game conversation (same one) | PASS 09:02:25 |
| Conversation writable (game not ended) | PASS |
| A sends one test message | PASS (201, 325 ms) |
| B lists it (game-chat round trip) | PASS (marker seen once) |
| B files a report on it | PASS (202) |
| Messages list of A and of B (`msg_my_conversations`) shows the game chat | PASS, 1 row each |

This closes the game-chat gap from the pass above at the API level. It is still not a UI check, and it cannot tell `all` from `allowlist` (both accounts are allowlisted). The script refuses to run while the Worker answers with the off signal (it prints "MESSAGING_ACCESS_MODE is not all yet" and exits 3).

### 2026-10-18 09:30 UTC, game-chat realtime pass (same two test accounts, "Dabbler Chat Test 2", `MESSAGING_ACCESS_MODE` = `all`)

| Item | Result |
|---|---|
| Open the game conversation | PASS 09:30:30: 200 for both accounts, the same conversation, writable (before the game start) |
| A sends in the game chat | PASS 09:30:31: 201 |
| Realtime wake to B | PASS: 1 wake 996 ms after the send, keys `conversation_id, id, seq, type` only |
| B lists the message | PASS: marker seen once (200) |
| B files a report | PASS: 202 |

With the 09:02 UTC run (conversation, send, list, report, Messages list for both) the API-level game-chat checks are complete. No new game was created in this pass: "Dabbler Chat Test 2" from the earlier pass is open until 2026-10-18 17:00 Dubai.

### UI checks pending for the CEO on https://alpha.dabbler.pro (the validation stage; nothing is verified here until you do them)
Sign in as the CEO's admin account for steps 5-6 and as any member of "Dabbler Chat Test 2" (for example the owner, Dabbler-Test) for steps 1-4.
1. Home: the Messages entry point (icon) is visible on Home. Tap it: the Messages screen (`/messaging`) opens and lists "Dabbler Chat Test 2".
2. Tap the chat: the Game chat screen opens with the earlier test messages ("Write a message" composer visible; the game is open until 17:00 Dubai).
3. Type a message and tap Send: it appears in the thread; on a second device or window signed in as another member it arrives without refreshing (realtime).
4. Long-press (or open the menu on) a message from someone else and choose "Report message": pick a reason, tap "Send report"; you should see "Thanks. We received your report."
5. As the admin account, open Admin, then Reports, then "Message reports" (`/admin/message-reports`): the report you just filed is listed.
6. On that report tap "Read this message": the "Reported message" panel opens with the text. A non-admin account must not see this screen or the action.
If any step fails, set the Worker variable `MESSAGING_ACCESS_MODE` to `off` (one step, seconds) and tell the orchestrator which step. Step 7 (main) waits for your go-ahead in the moment.

### Orchestrator ruling after the second pass (2026-10-18)
- `MESSAGING_ACCESS_MODE` = `all` is **confirmed by the CEO's dashboard screenshot** (PM ledger 2026-10-18, ref `messaging-launch`). The API pass above therefore ran with the mode at `all`; the test accounts being on the allowlist no longer leaves the mode in doubt.
- The 09:02 UTC run (7 of 7 PASS on the game chat) is the step-6 API evidence; the CEO does not need to run the script.
- The validation stage is **alpha.dabbler.pro** (decided); Canary and main are untouched.
- The UI checks (Home icon, Messages list, report sheet, admin Reports screen and Read this message) are with the CEO. Step 7 (main) waits for his explicit go-ahead in the moment.

### Deployed state read on 2026-10-18 (read-only)
| Site | Carries the Worker URL (messaging configured) |
|---|---|
| alpha.dabbler.pro | yes |
| canary.dabbler.pro | **no** |
| app.dabbler.pro | no |

`origin/Canary` is at `5e602aa4` and does NOT contain the flag commit `cb653cd0`; `origin/Alpha` is 705 commits ahead of Canary. So the flags are not live on canary, step 5 ("after the flags are live on the canary build") has not been satisfied, and the canary and production checks cannot run until Canary carries the Alpha work. Promoting Alpha to Canary is the CEO's.

### What remains and who
1. CEO: decide how Alpha reaches the validation stage (promote to Canary, or accept alpha.dabbler.pro as the stage for step 6). 705 commits are in that promotion, not only messaging.
2. CEO: confirm in the Cloudflare dashboard that `MESSAGING_ACCESS_MODE` is `all` (this evidence cannot tell).
3. Fixture: done. "Dabbler Chat Test 2" is open until 2026-10-18 17:00 Dubai; after that the live check needs another game.
4. CEO, signed in on the validation site: Home icon, Messages list, game chat send, report sheet, admin Reports list and Read this message (admin account), realtime.
5. Step 7: main merge needs the CEO's explicit go-ahead in the moment; then repeat the round trip on app.dabbler.pro.
Rollback is unchanged: set `MESSAGING_ACCESS_MODE` to `off`.
