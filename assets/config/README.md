# Local client configuration (not committed)

`local.env` in this folder is written by `scripts/setup_local_env.sh` and is
gitignored. It holds client-side values only (Supabase URL and anon key, app
name, environment) and is read by debug and profile runs when no
`--dart-define` values are supplied. See `docs/LOCAL_RUN.md`.

This README exists so the folder is always present in git and in the asset
list; release builds never read `local.env`.
