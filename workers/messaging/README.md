# Messaging Worker — skeleton (KAN-506, T10)

**Status: skeleton; nothing deployed; no Cloudflare resource created.** No D1 database, Worker, route, R2 bucket or
secret exists for this code. `wrangler.toml` has no `database_id` and no account id. `FeatureFlags.messaging` stays false.

## Purpose
The first code of the game-chat Worker (D1, CEO-approved): the authorisation pipeline, the local D1 message schema
with a gap-free per-conversation `seq`, and a load script for the D26 bar. Contract: `docs/messaging/openapi.yaml`,
`docs/messaging/README.md`, `docs/decisions/messaging-architecture-draft.md` (T7).

## Architecture (D24 auth flow)
```
client --(Authorization: Bearer <token>)--> Worker
  Worker: no/malformed Authorization header -> 401 (no reason), NO RPC, NO DB
  Worker --(same header, byte-identical; apikey = SUPABASE_ANON_KEY)--> POST {SUPABASE_URL}/rest/v1/rpc/msg_authorize
            PostgREST verifies the token; auth.uid() comes from the verified token
  RPC 401/403            -> 401 (no reason)            NO DB
  RPC 5XX / network /
  malformed result       -> 502 (no reason)            NO DB
  allowed=false + reason -> T7 typed reason + status   NO DB
  allowed=true           -> act ONLY on the returned user_id (may touch D1)
```
The Worker never decodes the token, never reads claims, keeps no authorisation cache: every request makes exactly one
`msg_authorize` call. Per request: at most 1 subrequest + 1 D1 batch.

**Assumed `msg_authorize` shape** (T8 builds the function; it is not in `supabase/migrations` at this commit):
body `{ "p_conversation_id": uuid, "p_action": "read" | "send" }`, result `{ "user_id", "allowed", "reason"? }`
(an object or a one-element array). Isolated in `src/auth.ts` `authorize()` so T8 can change it in one place.

## Routes (skeleton only)
| Route | Auth | Purpose |
|---|---|---|
| `GET /health` | none | `{ ok: true, version }`; no DB |
| `GET /v1/whoami?conversation_id=<uuid>` | yes (`read`) | returns only the RPC's `user_id`; proves the pipeline |
| `POST /v1/_probe` | yes (`send`) | **off unless `SKELETON_PROBE=1`**; writes one row via `src/db.ts` as the RPC's `user_id`; test-only |

## Files
`src/index.ts` (routes), `src/auth.ts` (D24 pipeline), `src/db.ts` (seq insert), `src/errors.ts` (T7 typed reasons),
`src/env.d.ts`, `migrations/0001_messages.sql`, `scripts/load/load.mjs`, `test/*`.

## Run (local only)
```
npm --prefix workers/messaging ci
npm --prefix workers/messaging test
```
Tests run in Node with vitest; D1 is the **local Miniflare emulator** (in-memory). `fetch` is stubbed: only the mock
`https://example.invalid/rest/v1/rpc/msg_authorize` answers, any other URL fails the test. No network call is made.

## Environment variable NAMES (never values in this repository)
- `SUPABASE_URL` — placeholder `https://example.invalid` in `wrangler.toml`; the real project is `wtncuzcskpigqpmnxwws`.
- `SUPABASE_ANON_KEY` — name only; supplied by the environment.
- `SKELETON_PROBE` — `1` enables `/v1/_probe` (tests only).
- Load script: `MESSAGING_LOAD_BASE_URL`, `MESSAGING_LOAD_TOKEN`, `MESSAGING_LOAD_ALLOW_HOST`, `MESSAGING_LOAD_PATH`,
  `PILOT_PEAK_RPS`, `DURATION_S`, `STEP_PCT`, `STEP_DURATION_S`, `MAX_STEPS`, `MAX_ERROR_RATE`, `P95_BUDGET_MS`, `TIMEOUT_MS`.

## What ran, and what did not
- **Ran, local emulator only:** migration apply, concurrent-seq test, idempotency test — on Miniflare's local D1, **not a real D1**.
- **Ran, mocked:** every auth test (Supabase RPC mocked).
- **AUTHORED, NOT RUN: the load script** (`scripts/load/load.mjs`) — not run against any real stack. Only its dry-run
  and refusal paths are tested; they send no request.
- No test here needs a real database; none was run against one.

## D1 seq: assumption and limits
`insertMessage` runs one D1 `batch` (a single transaction): advance `conversation_seq.last_seq` and insert the row,
both only if `(conversation_id, sender_id, client_key)` is new; then read the row. A repeat `client_key` advances
nothing and returns the existing row, so no seq is consumed. `UNIQUE(conversation_id, seq)` is the backstop: a
violation aborts the batch so the counter never advances without a row.
**Assumption:** D1 serialises writes per database and runs a batch atomically (Cloudflare documentation). **Not proven:**
behaviour on a real, remote D1 (including replicas/read-your-writes) — only the local emulator, which is single-process
SQLite, was exercised. A real-D1 check belongs to a later ticket with a non-production database.

## Load script (D26)
Refuses unless `MESSAGING_LOAD_BASE_URL` is set and its host is localhost/127.0.0.1/::1 or listed exactly in
`MESSAGING_LOAD_ALLOW_HOST`; never defaults to a host. Host AND path are validated (`MESSAGING_LOAD_PATH` must be a plain
absolute path), the resolved target is re-checked against the base origin, and redirects are never followed. Phase 1 sustains `2 × PILOT_PEAK_RPS` for `DURATION_S`, then
steps up by `STEP_PCT` until the error-rate or p95 budget is breached and records the ceiling. Results go to
`scripts/load/results/` (gitignored). `--dry-run` validates and prints the plan without sending.

## Decisions: approved vs recommended
| Item | Status |
|---|---|
| D1 game chat first | **CEO-approved** |
| D13 CEO first moderation reviewer; no agent reads content; no "24 hours" promise | **CEO-approved** |
| D18 per-user private Realtime topics `user:<id>`, polling fallback, no typing indicator | **CEO-approved** (not built here: P3) |
| D24 bearer pass-through to `msg_authorize`, trust only returned `user_id`, no cache, no JWKS/shared secret | **Recommended, NOT YET APPROVED** (built and unit-tested against) |
| D26 load bar: sustain 2× pilot peak, then step up and record the ceiling | **Recommended, NOT YET APPROVED** |
| D5 lifecycle: writable iff not cancelled and `end_at >= now()`, derived per request; nothing deleted | **Recommended, NOT YET APPROVED** (enforced by `msg_authorize`/T14, not here) |

## Free-plan limits and how the skeleton stays inside them
100k requests/day, 10 ms CPU per request, 50 subrequests per request. The skeleton does at most **1 subrequest**
(`msg_authorize`) and **1 D1 batch** per request, no crypto, no token parsing, small JSON only. CPU per request was
not measured here (no deploy).

## Rate limits (KAN-548)
A launch blocker (Orchestrator ruling 7): on the Workers Free plan one abusive account could exhaust the daily request or
D1 allowance and the Worker would then fail closed for everyone. `src/rate_limit.ts`; table in
`migrations/0004_rate_limits.sql` (**authored, not applied to any live D1**; Memphis applies it after review).

| Constant (exported from `src/rate_limit.ts`) | Default | Window | Key |
|---|---|---|---|
| `SEND_PER_USER_PER_CONVERSATION_PER_MINUTE` | 20 | 60 s fixed | verified user + conversation |
| `SEND_PER_USER_PER_HOUR` | 120 | 3600 s fixed | verified user, across conversations |
| `REPORT_PER_USER_PER_HOUR` | 10 | 3600 s fixed | verified user |

- **Applies to** `POST /v1/conversations/{id}/messages` and `POST /v1/messages/{id}/report`. Reads (GET) are not limited.
- **Subject** is the user id returned by `msg_authorize` (the Worker's only identity); never a header, body field or IP.
  The check runs after authorisation and before anything is written. A read-only grant (`left`, closed game) is refused
  with its own reason first and does not count.
- **Refusal:** HTTP 429, body `{"error":{"reason":"rate_limited"}}`, and `Retry-After` in whole seconds until the window
  ends (also exposed through CORS so the web app can read it). The app already maps `messaging_reason_rate_limited`.
- **Why D1, not isolate memory:** a Worker runs as many isolates at once and recycles them, so a memory counter is per
  isolate, can reset at any time and is bypassed by landing on another isolate. D1 serialises writes per database.
- **One row, one write:** a user's send limits live in ONE row (scope `send`): the hour window in `window_start`/`count`
  and the current minute window in `sub_window_start`/`sub_counts`, a small JSON object of per-conversation counts
  (`{"<conversation id>": n}`, reset each minute). A report is its own row (scope `report_hour`). One row per subject and
  scope, so no stale-row growth and no prune job.
- **Atomic check-and-increment:** ONE upsert per request that tests and increments BOTH send limits together. Its
  `DO UPDATE ... WHERE` is false once either window is full, and the request is admitted only if the statement returns a
  row. Two parallel requests at the limit cannot both pass (tested), an admitted request counts against both windows
  at once, and a refused request performs no write at all (tested with D1's `rows_written`: 1 admitted, 0 refused).
  On a refusal only, one extra READ says which window is full, so `Retry-After` is the wait for the longer full window.
- **Fixed windows:** a user can send up to the limit at the end of one window and again at the start of the next
  (up to 2x the limit across a boundary). A retry with the same `Idempotency-Key` counts as a request, because the
  counter runs before the insert can tell it is a repeat.

**D1 rows written per request (limiter only): send = 1, report = 1, a refused request = 0.** The table is
`WITHOUT ROWID`, so a counter write is exactly one written row (no separate index row), and a send's two limits share
the user's single row. Refusals add one cheap read, not a write.

**Free-tier arithmetic** (D1 free plan: **100,000 rows written per day**, 5 million rows read per day; index writes count
as written rows. Source: Cloudflare D1 pricing, https://developers.cloudflare.com/d1/platform/pricing/, read 2026-10-15.
The Workers Free daily request allowance was not re-read for this ticket: **unverified** here.)
- Existing send writes, counted from the schema (migrations 0001 and 0003), not measured: 1 sequence row + 1 message
  row + 4 index rows (the `id` primary key, the two UNIQUE constraints, the `legal_hold` index) = 6. With the limiter's
  1 a send is about 7 written rows, so the free tier carries roughly 100,000 / 7 = ~14,000 sends a day in total.
- One account at the maximum the limits allow: 120 sends/hour x 24 = 2,880 sends/day x 7 rows = 20,160 rows/day, about
  20% of the allowance. Reports at 10/hour = 240/day: 240 limiter rows + a legal-hold update (2 rows with its index)
  each = 720 rows/day, under 1%.
- So the limits cap **one** account; about five accounts abusing at the maximum would still reach 100,000 rows in a day.
  The limiter is necessary but not sufficient on the Free plan; moving to Workers Paid is a CEO cost decision and is not
  part of this ticket.

**Rollback:** revert the commit and redeploy the previous one. The unused `rate_limits` table is harmless and stays (no
DROP). To loosen a limit that proves too tight, change only the constant and redeploy; no data migration is needed.

## Non-goals
Send/list/paginate endpoints and the D5 lifecycle checks (T14), system lines (T15), Realtime broadcast/outbox (P3,
T21), R2/attachments (P4), any deployment or Cloudflare resource.

## Production environment (KAN-546)

The wrangler environment formerly named `staging` (KAN-534) is now `production` (`[env.production]` in
`wrangler.toml`). Only the environment key changed: the Worker name stays `dabbler-messaging-staging` (renaming it
would orphan its secrets and change the app's base URL), and the D1 binding/database are unchanged.

Deploy (run from `workers/messaging`; not run by KAN-546):

```
npx wrangler deploy --env production
```

### CORS allowlist

Exactly three origins, exact string match only (no wildcard, pattern or subdomain rule), defined in `src/cors.ts`:

- `https://canary.dabbler.pro`
- `https://alpha.dabbler.pro`
- `https://app.dabbler.pro`

Only `/v1` and `/v1/*` get CORS handling. `/health` and `/internal/*` get none, from any origin.

### Kill switch: dashboard edit vs redeploy (`MESSAGING_ACCESS_MODE`)

Source read 2026-10-15: Wrangler configuration, https://developers.cloudflare.com/workers/wrangler/configuration/
("Source of truth" and the `keep_vars` key):

- "If you change your environment variables in the Cloudflare dashboard, Wrangler will override them the next time
  you deploy." "If you want to disable this behavior, add `keep_vars = true` to your Wrangler configuration file."
- `keep_vars` is a **top-level-only** key ("Whether Wrangler should keep variables configured in the dashboard on
  deploy"); it cannot be set inside `[env.production]`. `vars` is **non-inheritable** and must be set per environment.

What this means today: `keep_vars` is **not** set, so a dashboard edit of `MESSAGING_ACCESS_MODE` is **lost on the
next `wrangler deploy --env production`**, which restores the committed value (`"off"`).

Not settled by the docs: the page does not say whether `keep_vars = true` preserves a dashboard value for a
variable that is **also** defined in the committed `[env.production.vars]` (it does not address that case). Until
that is verified, do not rely on `keep_vars` for the kill switch. Recommended options (a decision, not made here):
remove `MESSAGING_ACCESS_MODE` from the committed vars and manage it only in the dashboard together with top-level
`keep_vars = true`, or re-check the committed value before every deploy. `keep_vars` has not been added to
`wrangler.toml`.

## Direct messages (KAN-561)
Authorisation stays the database's: a DM is a conversation id like any other, so `POST/GET .../messages` and the report
route work unchanged (`msg_authorize` returns `kind dm` memberships; KAN-560). Route code changed in one place only:
`src/auth.ts` now also maps the two read-only reasons a DM can return, `blocked` and `suspended` (a block in either
direction, or a deleted or banned counterpart: sending is refused with that reason for BOTH users, history stays readable).
Game chats never return them.

| Route | What it does | Subrequests | D1 |
|---|---|---|---|
| `POST /v1/dm` `{other_user_id}` | verified id via `msg_authorize` (nil conversation), self check, existing-pair check (`msg_dm_exists`), the new-DM limit (new pairs only), then `msg_start_dm` with the caller's own bearer; `200 {conversation_id}` (the existing id for an existing pair) | 3 (`msg_authorize`, `msg_dm_exists`, `msg_start_dm`; 2 on an early refusal) | 1 write for a NEW pair, 0 for a re-open or a refusal |
| `POST /v1/conversations/{id}/mute` `{muted}` | `msg_set_muted` with the caller's own bearer; `200 {muted}` | 1 | none |
| `GET /v1/conversations/summary?ids=<up to 50>` | per readable id: `conversation_id`, `last_message_at`, `last_message_from_me` and nothing else | 2 + at most `MAX_BLOCK_LOOKUPS` (30) | 1 bounded read, no write |

(The `/v1` prefix keeps them on the CORS allowlist and the public-API rules of KAN-538.)

- **Identity** is the verified user id only (`resolveCaller` in `src/auth.ts`: the bearer goes unchanged to
  `msg_authorize`, which derives the id from the verified token). The only client-supplied user id is `other_user_id`;
  every other field of the body is ignored and never relayed. Starting a DM with yourself is `400 invalid_request`
  before the database is asked.
- **Typed reasons from the database** (the exception message of `msg_start_dm` / `msg_set_muted`): `blocked` -> 403
  `blocked`; `age_restricted` -> 403 `not_in_pilot` (no existing reason names an age rule, and `not_in_pilot` is the
  "unavailable" screen that tells nothing about age); `not_found` (target deleted or banned) -> 404 `not_found`;
  `rate_limited` (the database's cap of 20 new DMs per rolling day) -> 429 **`dm_cap_reached`**, a NEW reason added to
  `src/errors.ts` (the app maps it in its own ticket); `invalid_request` -> 400; `not_member` (mute) -> 403
  `not_a_member`; anything else -> 502 with no reason.
- **New-DM limit (second line):** `NEW_DM_PER_USER_PER_HOUR = 10` in `src/rate_limit.ts`, fixed 3600 s window, key = the
  verified user, scope `new_dm_hour` in the existing `rate_limits` table (no new migration: `scope` is free text).
  Refusal is `429 rate_limited` with `Retry-After`. **Only a NEW pair counts, with no exception**: before limiting, the
  Worker asks the database itself, `msg_dm_exists(p_other_user)` (migration `20261015120000_kan561_msg_dm_exists.sql`,
  the caller's bearer, a boolean from the UNIQUE pair row). It sees an empty pair the OTHER user started and a pair of any
  age, so every re-open passes without touching the limiter (the database applies every block, age and cap rule and does
  not count a re-open either). **Until operations applies that migration** (needs-ops), or when the call fails, the Worker
  does not charge the start (the second-line limiter fails open) and the database's daily cap of 20 is the only limit.
  **The hourly 429 for new pairs is therefore proven only after the apply**, and not before it. The apply is an ordered execute_sql by the operations team, with `supabase/tests/messaging/dm_exists_rollback.sql` to undo it (EXECUTE revoked, nothing dropped).
  DM sends use the existing send limits (20 a minute per conversation, 120 an hour per user).
- **Summary:** the readable set is the database's own list (limit 100, one call): an id that is not in it is omitted
  silently, and so is a conversation the caller has left. A **blocked counterpart is hidden from the blocker (D4)**: for a
  DM whose list state is `read_only` (a block in either direction, or an unavailable counterpart) the Worker asks
  `msg_authorize` for the caller's `hidden_sender_ids` and, if the caller blocked the counterpart, leaves that person's
  messages out of the conversation's "last message" (the blocker sees only their own last message, or null). At most 30
  such lookups per request (the 50-subrequest limit of the Free plan); a read-only DM past the budget, or whose lookup
  fails, is omitted. The blocked side and everyone else see the newest message. System lines never count.
  `last_message_from_me` compares the stored sender with the verified id. No text, no sender id, no counts, no previews.
- **Bounded read (`summarySql` in `src/conversations.ts`):** one statement. For each id it reads one `conversation_seq` row
  (primary key: the newest seq) and then an index range scan on `UNIQUE (conversation_id, seq)` over only the newest
  `LOOKBACK_MESSAGES` (100) sequence numbers, keeping the newest qualifying message. `EXPLAIN QUERY PLAN` is asserted in a
  test: `SEARCH cs USING INDEX ... (conversation_id=?)` and `SEARCH m USING INDEX ... (conversation_id=? AND seq>?)`, no
  `SCAN` of either table. So a request reads at most about 50 x 101 rows whatever the history length; a conversation with
  nothing qualifying in the window has a null time. The ids and exclusions travel as two JSON parameters because D1 allows
  100 bound parameters and only a few terms in a compound SELECT (a one-sub-select-per-id form failed at 30 ids in the
  emulator and is not used).
- **No logging** anywhere in the new code (the KAN-513 guard forbids any console call in `src/`).

**D1 rows written per request: start-DM = 1 for a new pair (0 for a re-open and for a refused start), mute = 0,
summary = 0.** **Free-tier arithmetic** (D1 free plan: 100,000 rows written and 5 million rows read per day, Workers
Free: 50 subrequests per request; source: Cloudflare D1 pricing, https://developers.cloudflare.com/d1/platform/pricing/ as
cited in the KAN-548 section above, **not re-read for this ticket: unverified here**; the compound-SELECT and
bound-parameter limits above were observed in the local emulator, also unverified against the live service):
- One account at the maximum the Worker limit allows: 10 new DMs/hour x 24 = 240 limiter rows/day, 0.24% of the
  allowance. Supabase, not D1, stores the conversation, the pair and the members.
- A summary of 50 ids reads at most about 50 x 101 = 5,050 rows (the look-back window), typically about 100 (the
  newest message plus its sequence row per conversation): at the maximum it would take about 1,000 summaries a day to use
  the 5 million read allowance.
- Subrequests per request: start-DM 3, mute 1, summary at most 32 of the 50 allowed.

**Rollback:** revert the commit and redeploy the previous one; unused `new_dm_hour` counter rows are harmless.

## Game conversation, mute and unmute (KAN-563)
The three operations of `docs/messaging/openapi.yaml` that were missing: `getGameConversation`, `muteConversation`,
`unmuteConversation`. KAN-561's `POST /v1/conversations/{id}/mute` (`200 {muted}`) is unchanged and stays.

| Route | Answer | Database calls | D1 |
|---|---|---|---|
| `GET /v1/games/{gameId}/conversation` | `200` the contract `Conversation`: `{id, kind:"game", game_id, writable, read_only_reason, boundary, muted, last_seq}` | 1 (`msg_game_conversation`) | 1 limiter write, 1 read of `conversation_seq` |
| `PUT /v1/conversations/{id}/mute` | `204`, no body, idempotent | 2 (`msg_authorize`, `msg_set_muted`) | 1 limiter write |
| `DELETE /v1/conversations/{id}/mute` | `204`, no body, idempotent | 2 (same) | 1 limiter write |

- **Authorisation is the database's, with the caller's bearer unchanged.** The game route calls `msg_game_conversation(p_game_id,
  p_access_mode)` (`supabase/migrations/20261015130000_kan563_msg_game_conversation.sql`): it resolves the game's conversation,
  creates the `msg_conversations` row on first use for an eligible member only (mode/pilot gate and a host/player/sub roster row in
  `active` or `left` first, so a stranger creates nothing), then answers with `msg_evaluate`, the evaluator `msg_authorize`
  uses. The Worker maps the verdict: `send` -> `writable true`; `read` + `left` -> `left_read_only` with
  `boundary {kind:"left_at_seq", seq}`; `game_ended` / `game_cancelled` -> `writable false` with that reason; denials ->
  `not_in_pilot`, `not_a_member`, `removed` (403), `suspended` (403, passed through if the database ever says it), `not_found`
  (404, unknown game). The user is `auth.uid()`; the only client value is the game id. A non-uuid id is `400 invalid_request`
  before any call; no bearer is `401` before any call.
- **`last_seq`** comes from D1 `conversation_seq` (0 when no message yet): the highest seq the caller may view, cut at
  `left_at_seq` for a member who left. No message text is read.
- **Mute/unmute** take the verified user and the typed reasons from `msg_authorize` (so the pilot rule applies, and the limiter is
  keyed by the verified id), then write with the same `msg_set_muted` call the POST route uses. A read-only grant (ended game,
  left member) may still mute.
- **Rate limits (D1, same one-row upsert as report):** game conversation 60 a minute per user (scope `game_conv_minute`), mute
  and unmute 30 a minute per user (scope `mute_minute`), `429 rate_limited` + `Retry-After`. A refusal by the database writes
  nothing. No new table or migration on the D1 side.
- **CORS:** the preflight now allows `GET, POST, PUT, DELETE, OPTIONS`.
- **needs-ops:** the game route needs `20261015130000_kan563_msg_game_conversation.sql` applied (after KAN-505/KAN-560); until then it
  answers `502` (no reason). Probes: `supabase/tests/messaging/game_conversation_probes.sql` (authored, not run); rollback:
  `game_conversation_rollback.sql` (revokes EXECUTE, nothing dropped). Mute/unmute need KAN-560's `msg_set_muted` applied.
- **Contract notes (no contract change):** (1) an unknown conversation id on mute answers `403 not_a_member`, not `404`: `msg_authorize`
  deliberately returns one reason for a guessed id and a non-member; `not_found` is returned for an unknown GAME on the game route.
  (2) The contract gives no numbers for `rate_limited`; the two limits above are this build's. (3) Mute makes two database calls, not
  one, because the pilot rule and the limiter key both need the verified user before the write.
