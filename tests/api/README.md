# API — deterministic, repository-owned, read-only

**Owner:** `backend` capability (the collection is Product code). **Runner:** `qa`.
**Trigger:** routine for `supabase/` changes and for any item carrying `schema_change`,
`money_path` or `security_sensitive` — whatever its paths say.

```bash
npm run test:api
bash tests/api/run.sh [other.postman_collection.json]
```

Exit 0 is PASS. Exit 2 is the runner refusing for a named reason (no URL/key). Exit 1 is a
failed assertion, with JUnit XML at `tests/api/.results/junit.xml` (gitignored).

## Engine

`run.sh` uses the **Postman CLI** when `POSTMAN_API_KEY` is in the environment (it logs in
with it; the key is never read from a file in this repository), and otherwise **newman via
`npx`**, which runs the identical collection format with no account. The result is the same
either way; the CLI is preferred where a Postman workspace should receive the run.

## What the collection covers today — and the rule for extending it

| Case | Request | Proves |
|---|---|---|
| success | `GET /rest/v1/v_potential_vibes_default?limit=1` with anon key | anon can read an allowlisted public view (`docs/SCHEMA.md §2f`, `T-027`) |
| authentication | `GET /rest/v1/` with no key | the gateway refuses unauthenticated requests |
| health | `GET /auth/v1/health` | the auth service answers |
| authorization | `GET /rest/v1/users?limit=1` as anon | RLS holds: empty or refused, never rows |

**Measured 2026-09-15 and worth knowing:** the REST root `/rest/v1/` (the OpenAPI document)
is **not** an anon resource on `wtncuzcskpigqpmnxwws` — it answers `401 Only the
service_role API key can be used for this endpoint` for the anon JWT and the publishable key
alike. That is correct posture. A "success" case must read something anon is *meant* to read.

**Extend per work item, never speculatively.** When a ticket touches an API behaviour, add the
smallest request that would catch the same defect next time — one of: success, authentication,
authorization, invalid input, expected error, duplicate request, business rule, data
validation. A case that needs a signed-in user takes `E2E_EMAIL` / `E2E_PASSWORD` from the
environment and obtains its token in a pre-request script; it never stores one.

## Boundaries

- **Read-only.** Nothing here mutates production. A case that would insert, update, delete,
  call a mutating RPC or touch auth state is not an API smoke — it is a `supabase/tests/<KAN>`
  probe pack against a throwaway local Postgres (see `supabase/tests/kan128/run.sh`), which is
  the repository's existing convention for backend behaviour that needs a database.
- **Anon key only.** Public-by-design and RLS-protected. A service-role key in this directory
  is a defect and a leak, whatever it was for.
- **No secrets in Git.** `SUPABASE_URL` / `SUPABASE_ANON_KEY` come from the environment or
  `.env` (gitignored); `POSTMAN_API_KEY` only ever from the environment.
