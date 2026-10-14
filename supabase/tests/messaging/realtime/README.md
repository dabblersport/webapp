# KAN-545 (Realtime R5): live proof runner

**Status: AUTHORED, NOT RUN against any live project.** Written and unit-tested with fakes only (no network,
no database, no Keychain read). Memphis runs it afterwards on staging with the two test accounts. It is not part
of the app (no `pubspec.yaml` change) and not part of CI.

The one dependency, `@supabase/supabase-js@2.117.3`, is pinned in this folder's `package.json` and
`package-lock.json` only. Node 20+ is needed (written and tested on Node 24).

## Unit tests (no network)

```
cd supabase/tests/messaging/realtime
npm ci
npm test            # node --test test/*.test.mjs
```

They cover the key-subset check (`{type, conversation_id, seq, id}`), the exp-iat decoder, the guard refusals
(wrong project, non-test profile, foreign game, bad environment) with fake clients, the output filter and the
Keychain reader with a fake `security`.

## Running it live (Memphis)

Preconditions the runner **prints and never changes**:

1. The messaging Worker has `MESSAGING_ACCESS_MODE = "allowlist"` for this run.
2. Both test accounts are in `public.msg_access_allowlist`.
3. User A (Keychain service `dabbler-test-user`) is the **host** of the fixture game
   `16223736-0ebb-4088-b823-91f3f9ef5643` and user B (`dabbler-test-user-b`) is an active player on it. Neither is
   active on any other game.
4. `MESSAGING_CONVERSATION_ID` is the `msg_conversations.id` of that game (clients cannot read that table).
5. For T-A4: KAN-542's SQL (and the Vault secret) is applied. Otherwise T-A4 reports `NOT RUN`.

```
export SUPABASE_URL=https://wtncuzcskpigqpmnxwws.supabase.co
export SUPABASE_ANON_KEY=<the project's public anon key>     # a public key; never commit it
export MESSAGING_WORKER_URL=<staging Worker base URL>
export MESSAGING_CONVERSATION_ID=<uuid>
# optional: T4_MAX_WAIT_SECONDS (default 900)
cd supabase/tests/messaging/realtime && npm ci && node run.mjs
```

Credentials are read at run time with `security find-generic-password -s <service> -w` (and the account from the
item's attributes) into process memory only. The runner never prints, logs or writes a credential, token, key or
wake payload. It prints only `PASS / FAIL / N-A / NOT RUN / SKIPPED` lines with counts and timings; any line that
looks like a token or key is withheld. A wake is reduced to its key names plus booleans on arrival.
Exit code: 0 no FAIL, 1 a FAIL, 2 refused or errored.

## Guards (the run is refused before any write)

1. `SUPABASE_URL` must be `https://wtncuzcskpigqpmnxwws.supabase.co`; checked before any credential is read.
2. Every profile of each account must have "test" in its username or display name.
3. **B** (the account that is the acting user for leave, join and the block) must be active on **no game but the
   fixture game**. **A** must be active on the fixture game and **may** be active on other games: the runner prints
   only their **count**, never an id or a name, and never targets them.
4. Every roster change and block goes through one wrapper (`lib/actions.mjs`). It refuses, before any request, a
   call whose game id is not the fixture game or whose user is not the other test account (leave/join: B, fixture
   game, `player`; remove: A, fixture game, B's profile only; block/unblock: B, A's user id only).
5. Before the block, read-only: B must host no game and have no follow with anyone but A (counts printed, refused
   otherwise), so the block can remove nothing but follows between the two test accounts.

It reads each account's own profile and roster only (RLS), and writes only through the app's normal APIs.

## What it does to data, and how it is undone

Through the app's RPCs only: A sends a few short test messages; B blocks then unblocks A (`rpc_block_user` also
removes follows between them); B leaves and rejoins; A removes B (`rpc_remove_player`) and B rejoins. The runner
rejoins B at the end and reports `RESTORE`. It does **not** deploy: afterwards the operator sets the Worker
`MESSAGING_ACCESS_MODE` back to `"off"` (the runner prints this reminder).

## Tests

| id | what | result values |
|---|---|---|
| T1 | A's access token `exp - iat` in seconds (expect 3600) | PASS/FAIL |
| T2 | N/A: per-user topics, no shared topic | N-A |
| T3 | B removed, `refreshSession()`, A's next message wakes B 0 times | PASS/FAIL |
| T4 | a never-refreshing client's socket closes by `exp + 30 s` (measured seconds after exp) | NOT RUN when it needs more than `T4_MAX_WAIT_SECONDS` (default 15 min; a 3600 s token needs about 60 min) |
| T5 | B removed: 0 wakes on its topic; joining A's private topic is refused or silent | PASS/FAIL |
| T6 | B's next list call returns reason `removed` | PASS/FAIL |
| T7 | a non-private (anon) join of the topic receives nothing | PASS/FAIL |
| T8 | load test | SKIPPED (CEO ruling) |
| T9 | every wake's key set is a subset of `{type, conversation_id, seq, id}`; no value kept | PASS/FAIL |
| T-A1 | A's message wakes B within 3 s (count and ms) | PASS/FAIL |
| T-A2 | A's second device (other session) is woken | PASS/FAIL |
| T-A3 | B blocks A: B gets no wake from A's next message | PASS/FAIL |
| T-A4 | B leaves/joins: A gets a `sync` wake | NOT RUN if none arrives (KAN-542 not live) |
