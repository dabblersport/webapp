# Messaging API contract (KAN-504, phase P2: game chat, text)

**Status: DRAFT CONTRACT, interface only.** Nothing here is implemented, deployed or exposed: no Worker, no
network code, no migration, no Cloudflare or Supabase resource. `FeatureFlags.messaging` and every chat flag stay
`false`. Source: `KAN-496_CONSOLIDATED_REPORT.md` sections 5, 6, 7 and the CPO/CTO/CXO notes of KAN-496; nothing was
re-measured live. Only project `wtncuzcskpigqpmnxwws` is ever referenced.

Files:

| File | What |
|---|---|
| `docs/messaging/openapi.yaml` | The wire contract the Worker implements (OpenAPI 3.0.3). |
| `lib/features/messaging/domain/messaging_repository.dart` | The Dart interface the app calls. |
| `lib/features/messaging/domain/typed_reason.dart` | `MessagingReason` (typed reasons, `unknown` fallback) and `MessagingFailure`. |
| `lib/features/messaging/domain/models/` | `Conversation`, `Message`, `MessagePage`, `ViewBoundary`, `ReportCategory` (the ten values of the existing `report_reason` enum). |
| `test/features/messaging/domain/` | Tests that keep the yaml and the Dart in agreement. |

## Status of the rulings this contract rests on

CEO-approved (2026-10-13): **D1** messaging enters MVP 1+ with game chat first; **D13** the CEO is the first moderation
reviewer, no agent reads message content, no "24 hours" promise anywhere; **D18** per-user private Realtime topics
(`user:` followed by the user id) with a polling fallback, no typing indicator, no revocation window accepted.

**Report recommendations, NOT YET CEO-APPROVED.** Building and unit-testing against them is allowed; exposing any user
to them is not (no user sees any of this before the CEO confirms them at P2 exposure): **D24, D5, D7, D4, D8, D16** (below).

## Operations (P2 only)

| operationId | Method and path | Returns |
|---|---|---|
| `getGameConversation` | `GET /games/{gameId}/conversation` | `Conversation` |
| `listMessages` | `GET /conversations/{conversationId}/messages?cursor&direction&limit` | `MessagePage` |
| `sendTextMessage` | `POST /conversations/{conversationId}/messages` (header `Idempotency-Key`) | `Message` (201 first, 200 duplicate) |
| `reportMessage` | `POST /messages/{messageId}/report` | 202, no body |
| `muteConversation` | `PUT /conversations/{conversationId}/mute` | 204 |
| `unmuteConversation` | `DELETE /conversations/{conversationId}/mute` | 204 |

Nothing else is in this contract: no typing, presence, previews, search, receipts, attachments or reactions. A later phase
adds an operation by changing the yaml and the interface together.

## Authentication (D24, a report recommendation, NOT YET CEO-APPROVED)

* The app sends the signed-in user's **bearer token unchanged** (`Authorization: Bearer ...`), the user's own session token.
* The Worker forwards that token unchanged to `rpc/msg_authorize`. PostgREST verifies it (the project is HS256, its JWKS is
  empty). The Worker **trusts only the `user_id` that RPC returns**, never a claim it decodes itself.
* No JWKS, no HS256 secret shared with the Worker, no authorisation cache in the MVP: each request calls `msg_authorize`
  once, so revocation takes effect on the next call. Acceptance for the Worker (later tickets): a token with forged claims
  still acts only on what the RPC returned.
* Secrets are named only by variable name in any file of this work; none is written here.

## Idempotency (AC3)

`sendTextMessage` takes a client-generated key (`idempotencyKey`, sent as the `Idempotency-Key` header, a random UUID).
The app creates it once per message and reuses it on every retry of that message. **A duplicate send with the same key by
the same user in the same conversation returns the same message (same id and same `seq`) with status 200 and creates one
row, never two;** the first send returns 201. The app can therefore retry after a timeout or while offline without risking a
double message.

## Pagination by `seq` cursor (AC4)

* `seq` is the message position in the conversation, strictly increasing. Pages are ordered ascending by `seq`.
* No `cursor`: the newest page. `direction=older` with `cursor`: messages below it. `direction=newer` with `cursor`: above it.
* Page size: default **30**, maximum **50** (`MessagingLimits`; proposed, confirm with the Worker owner).
* The page returns `older_cursor`, `newer_cursor`, `has_older`, `has_newer` and `page_size`; pass a cursor back with its
  direction for the next page.
* **The view boundary is a typed field, not a client rule (D7).** A member who left the game (`status = 'left'`) gets
  `boundary = { kind: left_at_seq, seq: N }` on the conversation and on each page, and the server returns nothing above
  `N`. A `kicked` or other non-active member gets the typed reason `removed` and views nothing. The client applies no
  boundary logic and ignores a boundary kind it does not know.

## Typed reasons

Every failure body is `{ "error": { "reason", "message", "retry_after_seconds" } }`. The reasons and their HTTP status:

| Reason | HTTP | Meaning |
|---|---|---|
| `not_in_pilot` | 403 | The user is not in the pilot allowlist (the app shows "unavailable"). |
| `not_a_member` | 403 | Not an active, left or invited member of this game's chat. |
| `removed` | 403 | Removed by the organiser (`kicked` or another non-active status): nothing may be viewed. |
| `left_read_only` | 403 | The member left: history only, up to the boundary; sending refused. |
| `game_ended` | 409 | `end_at` has passed: read-only. |
| `game_cancelled` | 409 | The game is cancelled: read-only. pending KAN follow-up: msg_authorize distinguishes cancelled |
| `blocked` | 403 | A direct block between the two users (reserved: game chat does not return it in P2). |
| `suspended` | 403 | The user's account is suspended. |
| `rate_limited` | 429 | Too many requests; `retry_after_seconds` says when. |
| `not_found` | 404 | Unknown game, conversation or message (or none the caller may know about). |
| `invalid_request` | 400 | Malformed or out-of-range input (body length, page size, key format). |
| `offline` | none | **Client side only**: the request could not be made. The server never sends it. |
| `unknown` | none | **Client side only**: the fallback for a reason this build does not recognise, for no reason at all, a 401 and a 5XX. |

Which operation can return which reasons is listed in each operation's `x-reasons` in the yaml and in the interface's
doc comments; the test keeps the two in agreement. A new server reason is mapped to `unknown` by an older app and must not
crash it. **Renaming a reason later is a contract change.** The reason names are the proposed ones; T3 and the CTO confirm.

Open for T3/CTO (no name invented here): a typed reason for a 401 (token missing or rejected). The contract currently sends
none and the app maps it to `unknown` with an unauthorized category.

## Rules the contract expresses (report recommendations, NOT YET CEO-APPROVED)

* **D5 lifecycle:** a game chat is writable iff the game is not cancelled and `end_at >= now()`, derived at request time (no
  timer, no deletion). It becomes read-only at `end_at` or on cancellation: `writable = false` with
  `read_only_reason = game_ended | game_cancelled`, and a send returns that reason.
* **D7 roster read rule:** host, player and sub with status `active` view and send; `left` views up to `left_at_seq`;
  `kicked` and any other non-active status view nothing. Tests that need a `kicked` member must create one explicitly
  (live data has none).
* **D4 blocks:** a direct block hides both ways and neither can send (`blocked`, direct chats only, not P2); in groups the
  blocker does not see the blocked user's messages and both stay members.
* **D8:** the message payload carries no delivery or view state. "sending" and "failed" are local states of the app for a
  message that has not come back yet.
* **D16:** the contract has no previews.
* **D13 / D21 report:** the report is **the ten `report_reason` reasons only: no free-text note (D13, D21; revisit only with a CEO decision)**. The CEO is the first reviewer and no agent reads message content (D13); a free-text field would carry message content into the reports table, which D21 keeps out (`content_snapshot` stays NULL), and no details column has been approved. The response promises no review time and the report carries no copy of the message text. (This matches the KAN-503 report-reason sheet spec, which has no free-text field.)

## What is not here, and the tests that will exist later

Backend conformance is checked in T8 (registry, `msg_can_*`, `msg_authorize`), T10 (Worker) and T14. Any of those tests
that need a database are **AUTHORED, NOT RUN** until the CEO approves a non-production database; none exists today, and
no document here claims any such test was run. The tests in this ticket are static: they run no SQL and no network.
