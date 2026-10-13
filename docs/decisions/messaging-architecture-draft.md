# Messaging architecture: decision entry (DRAFT for CTO adoption)

Ticket: KAN-502 (Messaging T3), epic KAN-494. Date drafted: 2026-10-13.
Status: **DRAFT. Not binding.** This file records decisions that are already made or already recommended. It decides nothing new. The CTO reviews it and adopts it into `Dabbler/dabbler-docs/DECISIONS.md`; until then it carries no authority. Where the source report is silent this file says "not decided".

Source of every finding: `KAN-496_CONSOLIDATED_REPORT.md` (sections 1, 3, 5, 6, 7) with `CPO_496.md` 6.1, `CTO_496.md`, `CXO_496.md` and `LIVE_EVIDENCE.md`, all in `/Users/moataz/Desktop/Dabbler-Alpha-Plan/kan496-messaging/`. The architecture brief is `Dabbler_Messaging_Architecture_Decision_Brief.md` v1.0 (9 Oct 2026). Nothing was re-measured for this entry; the live facts below are the reads supplied by the report (2026-10-13, catalog reads only).

## 0. How decisions are labelled

Every decision carries exactly one of two labels:

- **CEO-approved** (rulings of 2026-10-13, PM ledger ref messaging-rulings): D1, D13, D18.
- **report recommendation, not yet CEO-approved**: everything else. These must be confirmed by the CEO before P2 exposure. Building and unit-testing against them is allowed. Exposing any user to them is not.

| Id | Decision | Label |
|---|---|---|
| D1 | Scope: messaging enters MVP 1+ with game chat first; P-002 and P-020 otherwise stand | **CEO-approved** |
| D13 | The CEO is the first moderation reviewer; no agent reads message content; no "24 hours" promise anywhere | **CEO-approved** |
| D18 | Realtime: per-user private topics, polling fallback, no typing indicator, no revocation window accepted | **CEO-approved** |
| D24 | Worker authentication by bearer pass-through, no authorisation cache in MVP | report recommendation, not yet CEO-approved |
| D5 | Lifecycle derived at request time from `is_cancelled` and `end_at` | report recommendation, not yet CEO-approved |
| D21 | `moderation_reports.content_snapshot` is NULL for messages, enforced by a CHECK | report recommendation, not yet CEO-approved |
| D4 | Block semantics (direct and group) | report recommendation, not yet CEO-approved |
| D7 | Roster read rule (`active`, `left`, `kicked`) | report recommendation, not yet CEO-approved |
| D28 | No membership-change events in MVP | report recommendation, not yet CEO-approved |
| D29 | Design copy to strip | report recommendation, not yet CEO-approved |
| Flags | The canonical flag set (report 5.1) | report recommendation, not yet CEO-approved |
| Topology | Supabase registry, Worker API, D1 bodies, no R2 before P4 | report recommendation, not yet CEO-approved |

Scope wording that applies to everything below: **"MVP 1+ with game chat first" is CEO-approved (D1). P-002 (in-app chat out of Phase 1A) and P-020 (Messaging = MVP 1+) otherwise stand.** The committed flags stay false: `FeatureFlags.messaging` and every chat flag remain `false` in committed code. No user is exposed to messaging by this entry.

## 1. Topology (AC1)

Label: report recommendation, not yet CEO-approved (it follows the CEO's architecture brief v1.0, which names the Supabase, D1, R2 and Worker split; KAN-495's CTO accepted it conditionally; the CEO has not separately ruled on the Worker/D1 build in the 2026-10-13 rulings).

| Layer | Holds | Does not hold |
|---|---|---|
| **Supabase** (project `wtncuzcskpigqpmnxwws`) | identity and authorisation: the membership registry (`msg_conversations`, `msg_conversation_members`, `msg_access_allowlist`, as named in the KAN-495 CTO plan) and the authorisation functions `msg_can_*` and `msg_authorize` | **no message text, ever** |
| **Cloudflare Worker** (`messaging-api`) | the HTTP API; every read and write of message content goes through it | no authentication secret shared with Supabase (section 2) |
| **Cloudflare D1** | message bodies, sequence numbers, cursors, outbox | not the registry |
| **Cloudflare R2** | private attachment objects, **only from phase P4** | **no R2 and no object storage of any kind before P4** (section 6) |

Invariants carried from the brief and KAN-495: content never travels through Realtime (payload is content-free, section 3); push carries no content; previews are not stored anywhere in MVP. Table columns, function signatures and error reasons are the KAN-495 CTO plan's and are **not decided here**.

Nothing in this entry is provisioned. At the time of the report (2026-10-13 09:06 UTC) the Cloudflare account held 0 R2 buckets, 0 D1 databases and 0 Workers, and this ticket creates none.

## 2. Authentication: D24 (AC2)

Label: report recommendation, not yet CEO-approved. Source: report 3.2, 3.3 and section 1 row 1 and row 7.

**Decision.** The Worker forwards the user's bearer token **unchanged** to `rpc/msg_authorize`. PostgREST verifies the token with the project's own key, and `auth.uid()` comes from the verified token. **The Worker trusts only the `user_id` returned by the RPC and never any claim it decodes itself.** There is **no authorisation cache in MVP**: each request calls `msg_authorize` once, so a revocation takes effect on the next call. Acceptance criterion for the Worker and threat-model tickets: a token with forged claims must still make the Worker act only on the RPC result.

Rejected alternatives and why:

| Option | Verdict | Reason |
|---|---|---|
| JWKS verification in the Worker (the KAN-495 CTO primary option) | **rejected as it stands** | the project's public key set is empty (`{"keys": []}`, read 2026-10-13 09:05:57 UTC) and the project signs with the legacy HS256 secret (anon key header `alg: HS256`), so there are no published keys to verify against. A migration to asymmetric signing keys is project-wide, may break anything relying on the legacy secret, and is a separate hygiene item, not a messaging prerequisite. Never revoke the legacy secret while rollback is wanted |
| Share the HS256 secret with the Worker | **rejected** | the Worker could mint a token for any user and any role, including `service_role`; a Worker or Cloudflare-account compromise would become a full Supabase compromise, and the secret would be copied to a second provider |
| Call `/auth/v1/user` on every request | fallback only | it detects signed-out sessions but adds a hop (30 to 120 ms, unmeasured) and puts the Auth server on the hot path |
| Authorisation cache keyed by `(user, conversation, membership_version)` for up to 30 s (the KAN-495 CTO plan) | **removed** | the cache key needs a fresh `membership_version`, which is the same call the cache was meant to save; keyed without it, the cache is up to 30 s stale |

Facts that bound this decision: access-token lifetime is `app.settings.jwt_exp` = 3600 in the database mirror only; the Auth-source value is **UNVERIFIED** (Dashboard, Authentication, Sessions). Verification of the pass-through behaviour is authored, not run (section 7).

## 3. Realtime: D18 (AC3)

Label: **CEO-approved** (2026-10-13).

**Decision.**
- **Per-user private Realtime topics**: the topic is `user:` followed by the user id, with a policy of the form `realtime.topic() = 'user:' || auth.uid()::text`. The Worker sends one batched broadcast to the **current** members it just read from `msg_authorize`. A removed or blocked member is simply no longer addressed, so there is no exposure window for new events after the membership change commits.
- **Content-free payload**: `{type, conversation_id, message_id, seq}` and nothing else. Never text, sender or attachment.
- **Polling fallback** (`after_seq`) for when broadcast fails or a load ceiling is hit; clients already reconcile on reconnect.
- **No typing indicator** in MVP (typing on a shared topic would leak who is typing; the flag name is reserved and not created).
- **No revocation window is accepted.** Had the CEO chosen (a), the written acceptance would have had to read: a removed or blocked member's still-open app can receive, for up to about 1 hour, that a message was sent, its id, its sequence number and its timing; this was not accepted.

Why a decision was needed: the provider evaluates a channel policy when the connection joins and caches it for the life of the connection; a revoked user keeps receiving until the token expires or a new token is sent (Supabase Realtime Authorization documentation, retrieved 2026-10-13 by the CTO; re-read the wording before quoting it). With the 3600 s lifetime assumed (UNVERIFIED at source) the window on a shared conversation topic would be up to about 3,570 s for an honest client.

Rejected alternatives (listed so a reader of KAN-495 is not misled):

| Option | Why rejected |
|---|---|
| (a) accept shared conversation topics `msg:{conversation_id}` | leaves up to about 1 hour of metadata exposure (that a message was sent, its id, its sequence number, timing); the CEO did not accept a window |
| (c) shorten the project-wide JWT lifetime | project-wide side effects for every feature, and it shortens the window without removing it; the provider's own guidance warns against very short lifetimes |
| (d) membership-versioned topics `msg:{id}:v{n}` | same guarantee as the chosen option for new events, with more moving parts: every membership change forces every member to rejoin |

Polling-only (e) is not a rejected option; it is the fallback above. Facts still open: the Realtime "Allow public access" tenant setting is **UNVERIFIED** (Dashboard, Project Settings, Realtime) and the load ceiling of the broadcast path is **not measured**; both are covered by authored, not run, tests (section 7). Counted Realtime messages at the report's assumptions (100 users, 15,000 messages a month, groups of 10) are about 300,000 a month against the 2,000,000 Free allowance; these are assumptions, not measurements.

## 4. Lifecycle, roster, reports, blocks, events, copy, flags (AC4)

### 4.1 D5 Lifecycle
Label: report recommendation, not yet CEO-approved. Source: report 1 row 4, 6 D5, 2.1 row 7.

`games` has **no status column**. A game chat is **writable if and only if** `not is_cancelled and end_at >= now()`, **derived at request time**. It becomes read-only from `end_at` or from cancellation, with no timer, because no trigger can fire on the passage of time. `msg_conversations.state` holds manual states only (suspended, archived). **Nothing is deleted**; retention and deletion jobs stay off until a written CEO ruling. A "game finished" line is rendered by the client from `end_at`, not stored as a message.

### 4.2 D7 Roster read rule
Label: report recommendation, not yet CEO-approved. Source: report 6 D7, 2.1 row 8, 1 row 10.

| `game_roster.status` | Read | Send |
|---|---|---|
| `active` (host, player, sub) | yes | yes (while writable, D5) |
| `left` (voluntary) | up to `left_at_seq` | no |
| `kicked` (organiser removal; `rpc_remove_player` writes it) | **nothing** | no |
| any other non-active status | **nothing** (fail closed) | no |

Live data holds `active` 603, `left` 3, `kicked` 0 (2026-10-13 09:05:43 UTC). **Tests must create `kicked` rows explicitly**; the path has never run in production.

### 4.3 D21 Report storage
Label: report recommendation, not yet CEO-approved. Source: report 1 row 5, 6 D21, 2.1 row 10.

Reports reuse the existing `moderation_reports` table (`target_type = 'message'`, which its enum already contains; `target_id` is the message id). **`content_snapshot` is NULL for message targets, enforced by a CHECK** (`target_type <> 'message' or content_snapshot is null`). The Worker sets a **legal hold** on the stored D1 message so that expiry or deletion cannot destroy evidence. A moderator reads message text **only through an audited Worker endpoint**. No separate `msg_reports` table is built. Combined with D13 (CEO-approved): the CEO is the first reviewer through the existing admin path plus that audited read; no agent reads content; no response-time promise appears in copy.

### 4.4 D4 Block semantics
Label: report recommendation, not yet CEO-approved. Source: report 6 D4.

A **direct** block hides both ways and neither side can send. In **groups** the blocker does not see the blocked user's messages and both remain game members. Blocks are read from `user_blocks` only; the second block store `restrictions` is to be collapsed onto it by separate security work (report 7, T0c), which is not part of this entry.

### 4.5 D28 Events
Label: report recommendation, not yet CEO-approved. Source: report 6 D28.

No membership-change events in MVP (they would leak metadata on the broadcast path). Roster changes appear only as system lines emitted through the Worker.

### 4.6 D29 Design copy to strip
Label: report recommendation, not yet CEO-approved. Source: report 6 D29, 4.

Strip from the design scope: any "chat stays open for 7 days" retention line (frame 11); the refund notice and every price or settlement line (frames 10, 11, 14, 15, 20); "within 24 hours"; read and delivered ticks (frames 06, 14, 15); the typing bubble; online presence; message search; and the block-sheet line "or see the games you organise" until every game read path is confirmed.

### 4.7 Flag set
Label: report recommendation, not yet CEO-approved. Source: report 5.1. Flags are compile-time `static const bool` in `lib/core/config/feature_flags.dart` and **all stay `false` in committed code**; every new flag needs a call site.

`messaging` (exists, master) · `enableMessagingGameChat` (P2) · `enableMessagingReporting` (P2; must be true whenever any chat flag is true; enforce with a unit test or `assert`) · `enableMessagingInbox` (P3) · `enableMessagingRealtime` (P3) · `enableMessagingTyping` (not in MVP; name reserved, not created) · `enableMessagingAttachments` (P4, optional) · `enableMessagingDirect`, `enableMessagingReadReceipts`, `enableMessagingReactions`, `enableMessagingSquads` (P5) · `enableMessagingExport` (messages category inside the data export; the export entry stays behind the existing `enableDataExport`, currently false). Huddles get no flag. Server settings: `MESSAGING_ACCESS_MODE` (`off`, `allowlist`, `all`) with an allowlist table, and `MESSAGING_UPLOADS` kill switch (off until P4); retention and deletion jobs hard off.

## 5. Corrections to KAN-495 that affect the design (AC5)

A reader of KAN-495 must use these corrections (report section 1, rows 1, 4, 5, 7, 8, 10):

| Row | KAN-495 said | Fact | Correction |
|---|---|---|---|
| 1 | The Worker verifies the JWT via JWKS | JWKS is `{"keys": []}`; the project is legacy HS256 | bearer pass-through to `rpc/msg_authorize`; trust only the returned `user_id` (section 2) |
| 4 | `games` has a status column; completion fires a trigger | no status column: completed is `end_at < now()`, cancelled is `is_cancelled` | derive per request; no trigger can fire on the passage of time (section 4.1) |
| 5 | build a `msg_reports` table | `moderation_reports` exists and its enum already contains `message` | reuse it; `content_snapshot` NULL for messages by CHECK (section 4.3) |
| 7 | Worker authorisation cache for up to 30 s | the cache key needs a fresh `membership_version`, the call it would save | no cache in MVP (section 2) |
| 8 | Realtime on shared conversation topics; accept up to the token lifetime | the provider caches channel authorisation until the token expires or a new one is sent | per-user private topics (CEO-approved D18, section 3) |
| 10 | organiser removal versus leaving unknown | `rpc_remove_player` writes `status='kicked'` (code and live definition) | `left` is voluntary, `kicked` is removed (section 4.2) |

The other rows of report section 1 (2, 3, 6, 9) concern the block-function security fix, `message_preference` and a design-system gap; they are outside this entry.

## 6. Cost statement (AC6)

Label: report recommendation, not yet CEO-approved for the spend controls; the billing facts are provider facts as retrieved by the CTO on 2026-10-13 (re-read the pages before relying on the wording). Source: report 3.1.

- **Workers Free and D1 Free fail closed.** At the limit operations fail with an error (Workers: 100,000 requests a day; D1: 5,000,000 rows read and 100,000 rows written a day). That is an outage risk, not a billing risk.
- **R2 is the only product that can bill automatically.** Above 10 GB-month, 1,000,000 Class A and 10,000,000 Class B operations a month it bills ($0.015 per GB-month, $4.50 per million Class A, $0.36 per million Class B), and no hard cap is documented. **R2 is not provisioned before P4**, and nothing here provisions it.
- **A "$0 target with alerts" is not an enforced cap.** Budget alerts only notify and do not pause or cap usage. $0 is not promised. The CEO activated R2 with a payment card, so it can bill automatically; billing, payment method, alert policies and whether Pages project `webapp` shares the account are **UNVERIFIED** (the read token has no such scope).
- At P4, with the first upload, the proposed controls ship together: private bucket, presign only after `msg_authorize` with size and type bound, per-user and per-conversation quotas, a global daily kill switch (`MESSAGING_UPLOADS`), per-user rate limits, a bucket-scoped token, and a $1 budget alert (a warning, not a stop). Worst case without quotas is about $450 a month; with quotas about $22 (assumptions, not measurements). A card limit, a separate account and a deletion rule for abandoned uploads are CEO decisions; Cloudinary is not required.
- Not decided here: any plan change, new account or paid resource. None is created by this entry.

## 7. Verification status: authored, not run

No test for this design has been run. **T1 to T9** (token lifetime, revocation under shared and per-user topics, forced refresh, modified client, API revocation on the first call, public-access toggle, load, payload fields) and **T-A1 to T-A4** (anon RPC refused after the security fix, app block flows, public views, trigger still fires) are **AUTHORED, NOT RUN**. No non-production database is approved, and no document, comment or report may claim a test was run. Live access for this entry was catalog reads only, performed earlier by the report; no live write, no migration and no deployment is part of this ticket.

## 8. Not decided here

The report leaves these to the CEO or later tickets; this entry records no position: who may start a 1:1 (D3), Leave behaviour (D6), receipts beyond the stated direction (D8), export timing (D11), push content (D12), moderation API (D14), reaction glyphs versus emoji (D15), previews (D16), the `message_preference` remap (D22), the Worker "Allow public access" toggle (D27), search, presence and quick replies (D20), R2 spend posture (D17), the abandoned-upload deletion rule (D25), media types (D9). Phase estimates and the delivery order P0 to P6 are in report 5.2 and 5.3 and are a proposal under D1; they are not restated here.
