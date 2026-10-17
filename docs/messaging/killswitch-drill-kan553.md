# Kill-switch drill on the live Worker — KAN-553 (Q1)

Worker `dabbler-messaging-staging` (production environment). Variable `MESSAGING_ACCESS_MODE`, flipped by the CEO in the Cloudflare dashboard (Workers -> dabbler-messaging-staging -> Settings -> Variables) at the prompts of `supabase/tests/messaging/killswitch/run.mjs`; Memphis changed no variable and deployed nothing. Requests were made as the two test accounts (credentials read from the macOS Keychain into memory only). No id, token or credential appears in this report or in `kan553-drill-result.json`.

Date: 2026-10-17 (run 2; run 1 was stopped by the CEO because the script looked for a typed `messaging_off` reason that the Worker does not send, see below). Timings are wall-clock from the Enter press right after the variable save to the first matching answer.

## Verdict
**The kill switch works: with `MESSAGING_ACCESS_MODE` = `off`, both a GET (list) and a POST (send) are refused in under 2 s, and with `allowlist` both are let through again in under 2 s. Six of six timings, plus the final off, are far inside the 60 s limit. The final value is `off`, equal to the starting value.**

| | Result |
|---|---|
| Start value | `off` (read from the deployed version's bindings before the drill) |
| Drill working value | `allowlist` |
| Final value | `off` (verified refused after the last edit) |
| `allWithin60s` | true |

## C1 — off refuses GET and POST (three trials)
| Trial | GET list refused after | POST send refused after | Last status (GET / POST) |
|---|---|---|---|
| 1 | 0.57 s | 1.12 s | 403 / 403 |
| 2 | 0.67 s | 1.26 s | 403 / 403 |
| 3 | 0.72 s | 1.65 s | 403 / 403 |

The refusal is **HTTP 403 with no reason**, not a typed `messaging_off`: that is the agreed behaviour (KAN-509 ruling: `messaging_off` -> 403 without a reason; the app, KAN-550, maps a 403 without a reason to the unavailable state). So C1's wording "typed reason messaging_off" is met by this agreed form: the answer is the specific off refusal, not a generic error (a typed 403 such as `not_in_pilot` was not what came back, and the drill would not have counted it). Run 1 reported "NOT SEEN" only because the script wanted a typed reason; the script was fixed (`isOff`: 403 with no reason, or a typed `messaging_off`) and its tests added.

## C3 — restore to `allowlist` lets requests through (three trials)
Warm-up (first set to `allowlist`): first accepted GET after 0.79 s; account B also accepted.

| Trial | First accepted GET after | First POST past the access gate after | Last status (GET / POST) |
|---|---|---|---|
| 1 | 1.24 s | 1.56 s | 200 / 409 (game_ended) |
| 2 | 0.77 s | 1.08 s | 200 / 409 (game_ended) |
| 3 | 0.72 s | 1.08 s | 200 / 409 (game_ended) |

Message round trip: **not possible in this fixture state.** The test game is over, so the Worker answers a send with `409 game_ended`, which comes from past the access gate: it proves the gate is open and a send reaches the game-state check, but no message is stored and none is read back. A stored round trip needs an open game with an active member; none exists in the test data.

Final edit back to `off`: GET refused after 0.78 s, POST refused after 1.62 s (403 / 403).

## C2 — UI unavailable state
**Not observable.** No local review build with the messaging flags set true exists in this session, and the committed flags stay false until the launch ticket. The Worker side is proven; the app mapping (403 without a reason -> unavailable state) is KAN-550's behaviour and was not seen on screen.

## C4 — nothing else changed
`MESSAGING_ACCESS_MODE`: before `off`, after `off`. No secret, route, binding, database or D1 change, no deploy, no Pages change, no new resource; cost $0 (variable edits are free). The only writes were the drill's own send attempts, all refused with `409 game_ended`, so no message was stored.

## Findings
1. **KAN-554 (go-live): a dashboard edit of `MESSAGING_ACCESS_MODE` is lost on the next `wrangler deploy --env production`**, because top-level `keep_vars` is not set in `wrangler.toml` (Worker README, kill-switch section). The drill shows the dashboard edit takes effect in about 1 s and needs no release, but any later redeploy resets the variable to the committed value (`off`). Whoever turns messaging on for the launch must change the committed value (or settle `keep_vars`) as well, or the next deploy will silently turn it off. `wrangler.toml` was not changed here.
2. Off is a bare 403 with no reason by design; any client that wants to show "messaging is off" must treat a reasonless 403 as the unavailable state.
3. The test game fixture is over, so a stored send/read round trip cannot be proven until an open game with an active test member exists.
