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

## Non-goals
Send/list/paginate endpoints and the D5 lifecycle checks (T14), system lines (T15), Realtime broadcast/outbox (P3,
T21), R2/attachments (P4), any deployment or Cloudflare resource.
