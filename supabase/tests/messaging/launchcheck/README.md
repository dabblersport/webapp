# KAN-554: step-6 live check (production Worker, the two test accounts)

Checks the launch from the API side after `MESSAGING_ACCESS_MODE` is set to `all`: both members get the game
conversation, it is writable, A sends one test message, B lists it, B files a report on it, and each account's
Messages list (`msg_my_conversations`, the RPC the app uses) shows the game chat. It prints only statuses, reasons,
counts and timings. **It changes no variable, deploys nothing and touches no database directly.**

It does NOT check the screens (Home icon, the report sheet, the admin Reports screen and Read this message for the
CEO's admin account, realtime in the app); those are for a person signed in on the validation site.

## Run (one command, no prompts)
```
cd supabase/tests/messaging/launchcheck
set -a; . <path to the project .env holding SUPABASE_URL and SUPABASE_ANON_KEY>; set +a
node run.mjs
```
Credentials come from the macOS Keychain (`dabbler-test-user`, `dabbler-test-user-b`) into memory only; each account
must have "test" in its profile names or the run is refused. The game defaults to the KAN-554 test game "Dabbler Chat Test 2"
(set `MESSAGING_GAME_ID` to use another; the game must still be open, i.e. not ended). The Worker URL is fixed to the production Worker.

## Exit codes and what you see
* `3` and the line `MESSAGING_ACCESS_MODE is not all yet`: the Worker still answers with the off signal. Nothing was sent.
* `0`: every step printed `PASS`. `1`: a step printed `FAIL` (or the game is read-only because it ended). `2`: refused (wrong project, non-test profile, game not found).
* Each run sends one more test message and files one more report (normal paths, test accounts).

Open-versus-`all`: the two test accounts are also on the allowlist, so a pass cannot tell `all` from `allowlist`.
Only the Cloudflare dashboard value (or a member who is not on the allowlist) shows that.

## Tests (no network)
```
node --test test/launchcheck.test.mjs
```
