# Messaging production Worker — KAN-566 (O2)

Worker `dabbler-messaging-staging` (name pinned in `workers/messaging/wrangler.toml` `[env.production]`; free tier, `workers_dev`, no route, no R2, no custom domain). Public URL, by name: **`https://dabbler-messaging-staging.dabbler-sport.workers.dev`** (the value for `MESSAGING_API_BASE_URL`; the CEO adds it to Pages himself, Pages was not touched). No secret, account id or token appears here.

Status 2026-10-17: **D1 0001-0004 applied, Worker deployed, access mode `off`, health 200, unauthenticated requests refused.** The D1 `0004` apply and the `wrangler deploy --env production` were run by the CEO (the permission classifier denied them to the ops session); Memphis ran the read-only verification below.

## D1 migrations (remote database `dabbler-messaging-staging`, binding `DB`)
| Migration | State |
|---|---|
| `0001_messages.sql` | applied (not pending in `d1 migrations list`) |
| `0002_moderator_reads.sql` | applied |
| `0003_legal_hold_guard.sql` | applied |
| `0004_rate_limits.sql` | applied by the CEO (additive: `CREATE TABLE IF NOT EXISTS rate_limits`); `d1 migrations list` now says "No migrations to apply" (before: only `0004` pending) |

## Deploy
- Source: Alpha `ba5fd4ee707099f3840c1aaa47a1c961fa2e9cc1` (contains KAN-550 `22798050`, KAN-557 `1f8a4b1e`, KAN-563 `87c74def`, KAN-559, KAN-565).
- Latest deployment created 2026-10-17T16:43Z, seven minutes after the Alpha push (16:36Z). The KAN-563 route answers (see below), so the deployed code includes it. Wrangler does not record a commit sha on a deployment, so "deployed from `ba5fd4ee`" rests on the CEO running it from the Alpha tree at that head.
- Deployed bindings (names and plain-text values only): `DB` (d1), `MESSAGING_ACCESS_MODE` = `off`, `SUPABASE_URL` = the public project URL, `SUPABASE_ANON_KEY` and `MSG_SYSTEM_HMAC_SECRET` (secret bindings, values not shown or read).

## Checks run (no authentication, no secret)
| Request | Result |
|---|---|
| `GET /health` | 200 `{"ok":true,"version":"messaging-skeleton/0.0.1"}` |
| `GET /v1/conversations/summary?ids=...` | 401 |
| `GET /v1/games/{id}/conversation` (KAN-563) | 401 (route exists, refuses) |
| `POST /v1/dm` with a well-formed body | 401 `unauthenticated` |
| `POST /v1/conversations/{id}/messages` with a valid Idempotency-Key | 401 `unauthenticated` |
| `POST /v1/conversations/{id}/mute`, `PUT /v1/conversations/{id}/mute` | 401 `unauthenticated` |
| Malformed bodies (empty `{}`, bad Idempotency-Key) | 400 `invalid_request` before auth, no data touched |

`MESSAGING_ACCESS_MODE` stays `off`. Cost $0: free-tier Worker and D1 only; no resource created beyond the existing Worker environment.
