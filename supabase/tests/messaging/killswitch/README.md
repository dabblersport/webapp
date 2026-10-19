# KAN-553: kill-switch drill (live Worker)

Measures how long the production messaging Worker takes to refuse everything when `MESSAGING_ACCESS_MODE` is set to
`off`, and to accept again when it is set to `allowlist`, as the two test accounts. **The script changes no variable,
deploys nothing and touches no database.** The operator flips the variable in the Cloudflare dashboard at its prompts;
the timer starts when Enter is pressed. Nothing is printed or written except reasons, status codes, counts and timings:
no password, token, key or message text.

## Run (in a Terminal, it needs the Enter key)
```
cd supabase/tests/messaging/killswitch
set -a; . <path to the project .env holding SUPABASE_URL and SUPABASE_ANON_KEY>; set +a
node run.mjs
```
`MESSAGING_GAME_ID` defaults to the KAN-545 test game fixture; `MESSAGING_WORKER_URL` defaults to the production Worker
and is refused if it is anything else; `SUPABASE_URL` must be the Dabbler project. Credentials come from the macOS
Keychain (`dabbler-test-user`, `dabbler-test-user-b`) through `../realtime/lib/keychain.mjs`, into memory only; each
account must have "test" in its profile names or the run is refused.

## What you see
1. A start check (the Worker should answer `messaging_off`), then `>>> SET MESSAGING_ACCESS_MODE=allowlist NOW, then press Enter`.
   Edit the variable (Workers -> dabbler-messaging-staging -> Settings -> Variables), save, press Enter.
2. Three trials, each: `>>> SET ...=off NOW` (GET and POST must be refused: the Worker answers **403 with no reason** when the variable is off, which is the agreed
   behaviour; a typed `messaging_off` would count too), then
   `>>> SET ...=allowlist NOW` (first accepted GET, first POST past the gate). One timing line per step.
3. `>>> SET ...=off NOW (final value)`, confirmed refused. **Leave the variable at `off`.**
4. A `SUMMARY` line, a `DRILL_RESULT {...}` line, and the same JSON in `kan553-drill-result.json` next to the script.

If the fixture game is over (no open game), sends are refused with a typed `game_ended` instead of being stored: the
script says so, treats any answer from past the access gate (200/201, 409 `game_ended`, 429, ...) as "accepted", and reports that no round trip was possible.

Note: a dashboard edit of a variable is lost on the next `wrangler deploy --env production` unless `keep_vars` is set
(Worker README, kill-switch section). That is a finding for the launch tickets; this drill does not change `wrangler.toml`.

## Tests (no network)
```
node --test test/drill.test.mjs
```
