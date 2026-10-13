# KAN-524 caller map: `public.create_post` (15 parameters today, 20 after the migration)

Status: AUTHORED from the repo on Alpha `ff1c4092`. Nothing was measured live and nothing was run against any
database. Project `wtncuzcskpigqpmnxwws` only.

## Result

* **Every caller of `create_post` passes named parameters only**, so the new signature (the same 15 parameters
  in the same order, then five new defaulted ones) is backward compatible. No caller is positional. No stop
  condition applies.
* Callers: `lib/data/repositories/post_repository_impl.dart` only (three call sites, all `_db.rpc('create_post',
  params: {...})`, a map of `p_*` names). No edge function, worker, trigger, view, policy, CI script or other
  function body calls it.

## Evidence (commands run on Alpha `ff1c4092`)

| Command | Result |
|---|---|
| `git grep -n "create_post" -- lib` (excluding `can_create_post`, `rpc_create_post`, l10n labels `nav_create_post` and `composer_create_post`) | `post_repository_impl.dart:882`, `:984`, `:1107` (the `rpc('create_post', ...)` calls); `:961` and `:1087` are comments about it. |
| `git grep -n "create_post" -- supabase/functions workers scripts` | 0 hits. |
| `git grep -n "create_post" -- supabase/migrations ':!supabase/migrations/20260829080500_baseline_schema.sql'` | 0 hits: no later migration redefines, calls or grants it. |
| baseline `20260829080500_baseline_schema.sql` | definition 4813-4875, owner 4877, grants to `authenticated` and `service_role` only (35116-35117). Other `create_post` text there is `can_create_post` / `rpc_create_post` (different functions). |
| `git grep -n "create_post(" -- test integration_test` | 0 hits (no test calls it positionally). |

## Callers

| # | Caller | Kind | Parameters | Passes place today |
|---|---|---|---|---|
| 1 | `post_repository_impl.dart:882` (createPost, any visibility) | app | named: `p_kind, p_visibility, p_post_type, p_origin_type, p_body, p_sport, p_media, p_tags, p_game_id, p_location_tag_id, p_primary_vibe_id, p_vibe_ids, p_circle_ids, p_squad_ids, p_mention_profile_ids` (optional ones sent only when non-null) | only `p_location_tag_id` |
| 2 | `post_repository_impl.dart:984` (circle post from a circle id) | app | named, `p_visibility: 'circle'`, `p_circle_ids` | no |
| 3 | `post_repository_impl.dart:1107` (circle post from a request) | app | named, `p_visibility: 'circle'`, `p_circle_ids` | no |
| 4 | edge functions, workers | edge fn | none | n/a |
| 5 | triggers, views, policies | trigger / view / policy | none | n/a |
| 6 | other function bodies | function | none (the similarly named `rpc_create_post` is a different function) | n/a |
| 7 | migrations | migration-only | baseline creates it, sets the owner and the grants; no later migration touches it | n/a |

The app change that sends the place for circle posts is a separate ticket ("Circle posts send the chosen place"),
blocked by this one. Until it ships the three calls keep working unchanged and still send no place.
