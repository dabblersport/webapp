# KAN-523 caller map: notify_admins_of_block()

Status: AUTHORED from the repo (Alpha `f755fbbe`). Nothing was measured live and nothing was run against any database.

Function: `public.notify_admins_of_block()`, `RETURNS trigger`, SECURITY DEFINER, `search_path public`, owner postgres. Baseline `supabase/migrations/20260829080500_baseline_schema.sql:9298-9318` (inserts one `moderation.user_blocked` notification per row of `app_admins`), owner `:9320`, the only explicit grant `GRANT ALL ... TO "service_role"` at `:35866`.

## Evidence

| Command | Result |
|---|---|
| `git grep -n "notify_admins_of_block" -- . ':!supabase/migrations/20260829080500_baseline_schema.sql'` | `docs/SCHEMA.md:1045` (prose list of triggers); `supabase/schema/archive/` and `supabase/schema/snapshots/` (history, not applied by the CLI); `supabase/tests/{anon_block_grants,block_overload_collapse}/` and `test/supabase/anon_block_grants_migration_test.dart` (comments and assertions that the function is untouched). No code caller. |
| `git grep -n "notify_admins_of_block" -- lib supabase/functions workers` | 0 hits (`workers/` does not exist on Alpha) |
| baseline | the definition (`:9298`), owner (`:9320`), the trigger `trg_notify_admins_of_block AFTER INSERT ON "public"."user_blocks" FOR EACH ROW EXECUTE FUNCTION "public"."notify_admins_of_block"()` (`:29991`), the service_role grant (`:35866`) |
| migrations after the baseline | none redefine, grant or revoke it |
| `supabase/schema/archive/revoke_execute_on_moderation_notify_triggers.sql` | `REVOKE EXECUTE ON FUNCTION public.notify_admins_of_block() FROM anon, authenticated;` recorded as applied to the remote as migration version 20260701172012. It names anon and authenticated but not PUBLIC, which is why anon still reaches it through PUBLIC (KAN-498 finding 1). |

## References

| Reference | Kind | Passes auth.uid()? | Anon-reachable | No JWT |
|---|---|---|---|---|
| `trg_notify_admins_of_block` (`AFTER INSERT ON public.user_blocks`, baseline `:29991`) | trigger | n/a: reads `NEW` and `app_admins`, no caller identity | no: fired by the engine inside the insert, never callable as an RPC | yes: runs under the inserting statement's context |
| `supabase/schema/archive/*`, `supabase/schema/snapshots/*` | history files | n/a | n/a | n/a |
| everything else above | docs / tests / comments | n/a | n/a | n/a |

**The only user of the function is `trg_notify_admins_of_block`.** The trigger is fired by inserts into `user_blocks`, which `rpc_block_user(uuid)` (SECURITY DEFINER) performs. Trigger firing does not check the invoker's EXECUTE privilege on the trigger function, so the revoke does not stop the notification; probe B3 proves it at run time.
