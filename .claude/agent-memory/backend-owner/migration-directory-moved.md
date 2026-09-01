---
name: migration-directory-moved
description: KAN-33 (2026-08-29) moved the migration home from supabase/schema/migrations/ to supabase/migrations/ with timestamped filenames.
metadata:
  type: project
---

As of KAN-33 (T-032/T-033), landed 2026-08-29: the old `supabase/schema/migrations/`
directory is archived to `supabase/schema/archive/`. New migrations belong in
`supabase/migrations/`, matching the Supabase CLI's expected layout — filenames are
timestamped (`YYYYMMDDHHMMSS_description.sql`), not the old bare descriptive names
(`kan77_foo.sql`).

**Why:** aligns the repo with the Supabase CLI's own migration runner/ordering
instead of a hand-rolled scheme.

**How to apply:** author every new migration under `supabase/migrations/` with a
`YYYYMMDDHHMMSS_` prefix. Files already sitting in the archived
`supabase/schema/migrations/` (e.g. `kan77_circle_member_count_authz.sql`, authored
just before the move) are left in place as historical — don't move old work, just
target the new path going forward.
