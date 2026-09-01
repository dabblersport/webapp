---
name: legacy-schema-migrations-path-anomaly
description: supabase/schema/migrations/ and supabase/schema/rollback/ reappeared untracked on 2026-09-01 with only 4-5 files, including a KAN-52 (data export) migration P-025 explicitly descoped — excluded from the sprint-2 commit, flagged unresolved
metadata:
  type: project
---

**T-032/T-033 (2026-08-29) archived the old `supabase/schema/migrations/` (43 files)
to `supabase/schema/archive/` and adopted `supabase/migrations/` as the CLI-convention
baseline** (`8c82caf`, "baseline schema and archive stale schema/migrations, KAN-33").

**On 2026-09-01, `supabase/schema/migrations/` (4 files: kan48, kan52, 2×kan77) and
`supabase/schema/rollback/` (1 file: kan48 rollback) showed up again as untracked,**
all with the same mtime (2026-08-30 12:04), no corresponding files under the adopted
`supabase/migrations/` path, and not present in git history at that path since the
archive commit. One of them — `kan52_data_export_requests_table.sql` — creates the
exact table `P-025` (2026-08-31) ruled **out of scope, not being built for MVP1/MVP1+**.

**Left uncommitted and unresolved on 2026-09-01's sprint-end push.** This is not the
same thing as the KAN-52/103 stash (`stash@{0}`, "P-025 descoped: stray data-export
UI/service work") — that stash was confirmed intact and untouched. This is a
*different* recurrence: someone (an agent, going by habit rather than the T-032
convention) wrote new migration text into the legacy path after it was archived, for
a ticket the PO has since descoped. Don't assume it's safe to delete (could be
legitimate backend-owner work not yet reconciled) or safe to apply (contradicts
P-025). Route to `cto`/backend-owner or the PO for a ruling before touching it.

**How to apply:** before staging anything under `supabase/schema/`, check
`git log --oneline --all -- supabase/schema/` first — if the path was archived by a
T-03x decision and content has reappeared since, treat it the same as a stash
reappearing: stop and report, don't commit or discard.
