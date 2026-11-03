# Local app-level stack (KAN-791)

A throwaway PostgreSQL 16 cluster with the Events migration chain applied, fronted by
PostgREST, GoTrue (supabase/auth) and Realtime, all on 127.0.0.1. It needs no Docker, no
Supabase CLI and no hosted service, and it **never** touches the production project.

```bash
bash scripts/local_stack/start.sh      # start (idempotent: reuses a healthy stack, rebuilds anything else)
bash scripts/local_stack/smoke.sh      # the stack's test: (a) PostgREST (b) GoTrue->PostgREST (c) Realtime
bash scripts/local_stack/teardown.sh   # stop everything, delete the data dir, verify nothing remains (idempotent)
```

`start.sh --restart` forces a fresh stack. `teardown.sh --purge-cache` also deletes the download cache.

## Where things live

`KAN791_HOME` defaults to `${TMPDIR}/kan791`. It must be outside the repository.

| Path | Contents | Lifetime |
|---|---|---|
| `$KAN791_HOME/dl` | PostgREST and GoTrue release binaries, the Realtime release built from source, wal2json built from source | cache, kept |
| `$KAN791_HOME/run` | PG data dir, unix socket, logs, pids, `stack.env` | deleted by teardown |
| `$KAN791_HOME/run/stack.env` | ports, URLs, **the per-run JWT secret**, and the anon and service keys (chmod 600) | regenerated on every start, never committed |

Use it with `. "$KAN791_HOME/run/stack.env"`, then `$POSTGREST_URL`, `$GOTRUE_URL`, `$REALTIME_URL`,
`$ANON_KEY`, `$SERVICE_KEY` and `$PG_URL`.

## Ports

Every port is picked free at start (bound to port 0 on 127.0.0.1), and 5432 is excluded.
The ports are printed and written to `stack.env`:

| Variable | Service |
|---|---|
| `PG_PORT` | Postgres, TCP on 127.0.0.1 plus a unix socket in `run/sock` |
| `POSTGREST_URL` / `POSTGREST_ADMIN_URL` | PostgREST API / admin (`/ready`) |
| `GOTRUE_URL` | GoTrue (`/health`) |
| `REALTIME_URL` | Realtime (`/healthcheck`). Clients must connect via `ws://realtime-dev.localhost:<port>/socket/websocket`, because the tenant comes from the Host subdomain |
| `REALTIME_EPMD_PORT` | a private epmd for Realtime's Erlang VM, killed by teardown |

## Versions

| Component | Version | Source |
|---|---|---|
| PostgreSQL | 16.15 (Homebrew `postgresql@16`, `PG_BIN`) | local install, required |
| PostgREST | v16.5 | release binary `postgrest-v16.5-macos-aarch64` |
| GoTrue (supabase/auth) | v2.197.0 | release binary `auth-v2.197.0-darwin-arm64`, and its `migrations/` |
| Realtime (supabase/realtime) | v2.152.0 | `MIX_ENV=prod mix release` from the tag; needs Elixir (built with Elixir 1.20.4 / OTP 29 from brew) |
| wal2json | `wal2json_2_6` | built with PGXS, loaded via `dynamic_library_path`, never installed into the Homebrew prefix |
| Node | v24 (global `WebSocket`) | used only by `smoke.sh` (c) |

## What start.sh does

1. initdb runs with `wal_level=logical`, and `output_plugin_libraries` gets `wal2json` added. This
   PG16.15 build only allows listed decoding plugins.
2. `stack_roles.sql` creates `anon`, `authenticated`, `service_role` and `authenticator`.
3. `auth migrate` runs. GoTrue creates the real `auth` schema and `auth.users`.
4. `apply_chain.sh` applies the Events chain in the order the KAN-789 clean proof validated (39
   steps, listed in `run/applied_chain.txt`). It uses a copy of `supabase/` with one transform:
   the kan711 harness's `CREATE TABLE auth.users` becomes `IF NOT EXISTS`.
5. `stack_shim.sql`:
   - restores Supabase's `auth.uid()` and `auth.role()`, which read `request.jwt.claims`. This is
     what PostgREST 12+ sets.
   - adds `local_stack.whoami()`.
6. PostgREST and GoTrue start, and start.sh waits for their health endpoints.
7. Realtime:
   - `realtime_prep.sql` runs, then Realtime's own migrations, then the `realtime-dev` self-host
     tenant seed.
   - Realtime starts and start.sh waits for `/healthcheck`.
   - If Realtime cannot build or start, `REALTIME_STATUS=NOT_RUN` is recorded with the exact
     reason in `REALTIME_NOTE`, and smoke (c) reports NOT RUN. It is never reported as working.

## What each component can and cannot prove

**Postgres plus the chain**
- Can prove:
  - schema, RLS, grants, triggers and RPC behaviour of the Events chain on a clean PG16
  - logical replication of the published tables
- Cannot prove:
  - production data shape or volume. The data here is the harness fixtures.
  - Supabase platform objects (`storage`, `supabase_functions`, `pg_net`, `pg_cron`, Vault)
  - production ownership, because everything is owned by the local superuser `postgres`
  - the platform-managed `supabase_realtime` publication. Locally it is created empty, and then
    KAN-716 adds its tables.

**PostgREST**
- Can prove:
  - what `anon` and `authenticated` can read and call over HTTP through the real request path:
    JWT, then role switch, then RLS
- Cannot prove:
  - the hosted API gateway (Kong), `apikey` validation, rate limits, or schema-exposure settings
    other than `public,local_stack`

**GoTrue**
- Can prove:
  - real signup and password grant, and a real Supabase-shaped access token signed with the
    stack secret
  - that `auth.uid()` resolves to that user's id inside RLS
  - user rows in the same cluster's `auth.users`
- Cannot prove:
  - email delivery (autoconfirm is on), OAuth providers, MFA or SMS
  - the production JWT secret and signing keys
  - production auth settings

**Realtime**
- Can prove:
  - that a `postgres_changes` subscription on a published table receives the INSERT, UPDATE or
    DELETE through wal2json
  - broadcast and presence on the `realtime-dev` tenant
  - channel authorization with a stack-signed JWT
- Cannot prove:
  - multi-node or cluster behaviour
  - hosted tenant configuration, or production quotas and limits
  - `realtime.messages` RLS as configured in production

## Constraints and known limitations

- After start, the database contains a `realtime` schema and a `supabase_admin` role. The Events
  harnesses (kan724/725/728/731, B16 `mode=before`) refuse to run on a database that has them,
  by design. **Run harnesses or the chain again by restarting the stack** (`start.sh --restart`),
  not against a running one.
- GoTrue and Realtime connect as the local superuser. PostgREST connects as `authenticator` and
  switches role per request, as on Supabase.
- `auth.uid()` here is the Supabase definition. The chain's local harnesses define a
  `request.jwt.claim.sub`-only stub, which `stack_shim.sql` replaces.
- The keys printed are valid only for this run's secret. A stack restart invalidates them.
