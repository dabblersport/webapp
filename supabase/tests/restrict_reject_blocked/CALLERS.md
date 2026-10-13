# KAN-522 caller map: rpc_restrict_set / rpc_restrict_clear

Status: AUTHORED from the repo (Alpha `f755fbbe`). Nothing was measured live and nothing was run against any database.

Functions (project wtncuzcskpigqpmnxwws only): `public.rpc_restrict_set(p_target uuid, p_type text)` and `public.rpc_restrict_clear(p_target uuid, p_type text)`, baseline `supabase/migrations/20260829080500_baseline_schema.sql:15024-15047` and `15008-15021`; grants `GRANT ALL` to anon, authenticated, service_role at `:36683-36685` and `:36677-36679`.

## Evidence

| Command | Result |
|---|---|
| `git grep -n "rpc_restrict_set\|rpc_restrict_clear\|restrict_set\|restrict_clear" -- . ':!docs' ':!supabase/tests/block_overload_collapse'` | only the baseline definitions, owner lines and grants above. **No caller.** |
| same over `lib/`, `supabase/functions/` (broadcast-notification, detect-country, send-export-email, send-push-notification), `workers/` (the directory does not exist on Alpha), `scripts/`, `tests/`, `integration_test/` | 0 hits |
| `git grep -n "rpcRestrict\|restrictions" -- lib` | 0 call hits (the matches are unrelated game-slot and privacy fields) |
| migrations after the baseline | none redefine either function |
| `docs/SCHEMA.md` section 2g allowlist block | neither function is an allowlist entry (the only mentions are prose at lines 769 and 998), so the stop condition "an anon-allowlist entry" does not apply |
| `supabase/tests/block_overload_collapse/CALLERS.md` (KAN-499, read from `origin/Alpha-karnak`) | the source of this ticket; records the same functions as the residual second block store |

## Callers

| Caller | Kind | Passes auth.uid()? | Anon-reachable | No JWT |
|---|---|---|---|---|
| none | | | | |

Neither function is called by a view, another function, a trigger, an edge function or the app. Both read `auth.uid()` inside themselves and raise `not_authenticated` when it is NULL. `is_hidden(from_user, to_user)` reads `restrictions` rows of type `hidden` only and is unchanged.

## Reachability today

Both hold explicit anon grants (and the default PUBLIC execute). With no caller, the revoke from PUBLIC and anon changes nothing for any existing flow; a `hidden` preference needs a signed-in user.
