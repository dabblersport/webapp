# KAN-68 — Report/block actually blocks — re-verification story

Status per docs: flagged as STILL GENUINELY OPEN — fails open twice over (locale
predicate in the content blocklist never matches; RLS returns zero rows for
`safety_blocklist_terms` even when it should return terms). Per `cto` status doc,
nothing in the app currently calls `contentHitsBlocklist`, so this defect has no
live UI trigger today — it's a latent wiring risk, not an active silent-failure path.

Distinguish TWO different things under this ticket's name:
(a) the user-facing "block a user" / "report a user or post" feature
    (`block_repository_impl.dart`, `report_dialog.dart`) — a real, separate feature
    that should work regardless of the content-blocklist bug.
(b) the backend content-term blocklist (`safety_blocklist_terms` / moderation_service
    `contentHitsBlocklist`) — the actual KAN-68 defect, which is a DB/RLS issue with
    no reachable UI surface to click through per current wiring.

## Steps — (a) user-facing block/report, UI-testable
1. Sign in with QA account. Navigate to another user's profile (need a second
   account or any visible user card — check nearby/social screens for a target).
2. Click "Report" on their profile. State expected outcome: report dialog opens,
   category selection, submit button. Arm network requests, submit a report.
   Verify request succeeds (2xx), dialog closes/confirms, reload and re-check
   nothing crashes.
3. Click "Block" on the same or another user. Expected: confirmation dialog,
   then a state change (button becomes "Unblock", snackbar confirms).
4. Verify blocking has a real effect: attempt to message the blocked user (should
   be gated per `user_profile_cannot_message_blocked` string found in code) or
   check their content disappears from feeds/search if that's wired.
5. Reload the page — confirm blocked status persists (re-fetches `isBlockedProvider`
   correctly, not just local UI state).
6. Unblock, confirm reverses cleanly.

## Steps — (b) content blocklist defect, doc-verification only
7. Do NOT attempt to craft a live exploit against production data. Instead:
   confirm via repo state (already known, not to be re-derived) that
   `contentHitsBlocklist` still has no callers (i.e. the defect is still present
   and still unreachable) — this is a code-grep check, not a browser action.
   If time allows, ask `backend-owner`/`cto` for current status rather than
   guessing from a stale memory of the doc.

## Result — executed 2026-08-29 — PASS (user-facing block/report)

- **Report post: PASS.** Opened "..." menu on another user's (Youssef El Khatib)
  post → "Report post" → selected a category (Spam, then Harassment on a clean
  retest) → "Submit Report". Confirmed a real `POST .../rpc/report_content` →
  200, snackbar "Report submitted. Thank you." First attempt's POST wasn't
  captured by the network-read tool (only its OPTIONS preflight showed) — this
  turned out to be a tool-timing artifact, not a bug: a clean retest from a
  fresh profile load captured the actual 200 POST cleanly.
- **Block user: PASS, verified by actual effect, not just the toast.** Clicked
  "Block user" on the same user → toast "User blocked. Their content is now
  hidden." Verified for real: navigated to the home feed and confirmed all of
  that user's posts (previously visible, 4 posts) were completely gone from the
  feed immediately, no reload needed. This is a genuine content-hiding effect,
  not just a UI label change.
- (b) Backend content-blocklist defect (`safety_blocklist_terms` fails open via
  locale predicate + RLS): NOT independently reproduced via UI this pass — per
  `cto` status doc, nothing in the app currently calls `contentHitsBlocklist`,
  so there is no UI path to trigger it. Deferred to docs/backend-owner per the
  story's own instruction; not re-derived from scratch.

## Pass/fail criteria
- (a) FAIL (HIGH) if report submission is a silent failure (looks successful, no
  request or a failed request).
- (a) FAIL (CRITICAL) if "Block" does not actually gate messaging/visibility —
  this is the literal "report/block actually blocks" promise.
- (b) Report as "still open, confirmed via docs/code, not independently
  UI-reproducible" rather than inventing a UI reproduction that doesn't exist —
  do not mark this fixed without a real code/doc check showing it changed.
