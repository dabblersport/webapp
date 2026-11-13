# Typing indicators go-live — KAN-579

Status 2026-10-20: **the app code is on Alpha (`8b0905c9`, the build the CEO tested); the two backend parts are NOT live.** Typing therefore reaches nobody on alpha.dabbler.pro. Nothing here was applied or deployed by the author; this is the list for the orchestrator to put to the CEO and for Memphis to apply.

## What was observed (read-only)
| Part | Check | Result |
|---|---|---|
| Worker `dabbler-messaging-staging` (public URL in `live-worker-kan566.md`) | `POST /v1/conversations/{uuid}/typing` with `{"typing":true}`, no auth | **404** (the route is absent from the deployed code; it was deployed from Alpha `ba5fd4ee`, before KAN-579). A route that exists answers 400/401 before auth, as `/mute` does (400 for the same probe). |
| Worker health | `GET /health` | 200 `messaging-skeleton/0.0.1` |
| Supabase `public.msg_typing` | not readable from this lane (the ops guard refuses `execute_sql`); the migration `20261020140000_kan579_msg_typing.sql` was never applied per the orchestrator's 2026-10-20 ruling | treated as **absent** |
| Realtime private channel `user:<uid>` | the same channel carries the KAN-541 message wake-up, which worked on Alpha (KAN-554 launch note); policy `msg_user_topic_receive` (KAN-505) already lets a user receive on their own topic | **no Realtime configuration change needed** |

## Cause of the CEO's failed test
The client sends `POST .../typing` to the Worker; the deployed Worker answers 404, the client (by design) drops the failure, so no signal is ever fanned out. Even with the Worker deployed, `msg_typing` must exist or the Worker's background call to it fails silently. Both are missing.

## Apply list (order matters)
1. **Supabase migration (Memphis, project `wtncuzcskpigqpmnxwws` only):** `supabase/migrations/20261020140000_kan579_msg_typing.sql`.
   - One statement: `CREATE OR REPLACE FUNCTION public.msg_typing(uuid, boolean, text)` (SECURITY DEFINER), plus `REVOKE ALL ... FROM PUBLIC, anon` and `GRANT EXECUTE ... TO authenticated`.
   - Additive: no table, no row, no policy, no DROP. Writes nothing durable (it calls `realtime.send` to `user:<member>` only).
   - Before: read-only `supabase/tests/messaging/notify_realtime_send_check.sql`. After: `supabase/tests/messaging/typing_probes.sql`. Rollback (revoke only): `supabase/tests/messaging/typing_rollback.sql`.
2. **Worker deploy (the CEO runs it, as for KAN-566):** `wrangler deploy --env production` from `workers/messaging` on a tree that contains this branch's Alpha merge (the route is `src/typing.ts`, wired in `src/index.ts`).
   - No new binding, secret, route, D1 migration or paid resource: it reuses `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `MESSAGING_ACCESS_MODE` already deployed.
   - Verify afterwards (no auth, no data): `POST /v1/conversations/00000000-0000-0000-0000-000000000000/typing` with `{"typing":true}` must answer **401**, not 404.
3. **App:** nothing to deploy; the web build the CEO tested already carries the client. Reload the page after step 2 (a client that met a 404 stops sending until the app restarts, see below).
4. **Realtime config:** none.

Order: step 1 can precede step 2 safely (nothing calls the function until the Worker route exists). Step 2 before step 1 is also safe (the Worker answers 204 and the failed RPC is swallowed), but typing still shows nothing until step 1 is applied.

## If the backend part is missing (what the client does)
`WorkerTypingTransport` (`lib/features/messaging/data/typing_transport.dart`): on 404, 405 or 501 it marks typing unsupported and sends nothing more until the app restarts, so a Worker without the route costs one request, not one every three seconds. Any other failure (403, network, timeout) is dropped and the next signal is tried. Receiving is independent: with no signals nothing shows, no error appears, chat and sending are untouched. Covered by `test/features/messaging/typing/typing_transport_test.dart`.

## Click-by-click test for the CEO on alpha.dabbler.pro (after steps 1 and 2)
Needs two signed-in test accounts, A (phone) and B (second phone or a desktop browser), both members of the same chat. Run once in English + Light, once in Arabic + Dark.
1. Reload alpha.dabbler.pro on both devices (fresh load, so the new Worker is used).
2. On both: Messages → open the same 1:1 chat.
3. On A: tap the message box and type one letter. **On B, within about 2 seconds:** the header under the name reads "typing…" and a small dots bubble appears as the last item in the thread.
4. On A: delete the text. **On B:** both disappear within about 2 seconds.
5. On A: type again, then tap Send. **On B:** the dots disappear as A's message arrives.
6. On A: type, then close the tab or switch to another app. **On B:** the dots disappear by themselves within about 6 seconds.
7. Open a game group chat with A, B and a third member C (or only A and B): A types. **On B:** the dots row shows A's avatar, with "A is typing" above the bubble. With two typers the label names both; with three or more it names two and "N others".
8. Arabic + Dark: repeat steps 3 and 7. The indicator sits on the start side, text reads right to left, nothing overlaps the message box.
9. If nothing shows in step 3, tell the orchestrator which of steps 1 and 2 of the apply list is not done; do not retry.
