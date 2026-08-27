---
name: audit-false-positives
description: Confirmed false positives in the Dabbler audit — never re-flag these, and the scanner bugs that generate them
metadata:
  type: project
---

Verified non-findings. Re-flagging any of these costs trust and buries real findings.

**Scanner bugs in `.claude/skills/project-audit/scripts/scan.sh` that generate them:**
1. Orphan-screen detection uses `grep -oE 'class ([A-Z][A-Za-z0-9_]*Screen)'`, which
   substring-matches `NotificationsScreen` inside `NotificationsScreenV2`. Always re-verify
   an orphan claim with an anchored, whole-word grep before reporting it.
2. Import-reachability checks that match a path fragment (`features/x/data/y.dart`) miss
   **relative** imports (`../data/y.dart`). Match on the **basename** instead. This falsely
   condemned the whole `notifications` slice on run 1.
3. `grep -i` on `XXX` matches `AppSpacing.xxxl`; on `placeholder` it matches every l10n
   `*_placeholder` key. Use strict comment-token regexes for the incompleteness register.

**Claims I got WRONG and must not repeat:**

- **Security scope, understated ~2×.** I reported "49 views, 25 SECURITY DEFINER, 8 anon-exposed".
  Truth: **71 / 49 / 19**. Two conflations — the reported total was the definer count, and the
  reported definer count was the Supabase **advisor's finding count**. An advisor reports what it
  flags, not what exists. Consequence: 11 exposed views were never examined because the audit
  believed it had covered the set. **Always count with `pg_class`; never reuse an advisory total.**
  Census query is in `docs/SCHEMA.md` §2e.

- I reported `supabase/migrations/` as "empty — no schema history". **That directory does not
  exist.** The real SQL tree is `supabase/schema/` — 40 `.sql` files, 5,787 lines, 41
  git-tracked, with `migrations/` (38 files) and `snapshots/` beneath it. Several are
  security fixes worth reading before touching RLS (`v_game_card_visibility_gate.sql`,
  `fix_admin_functions_missing_auth_check.sql`). The real issue is only that they sit
  outside the path the Supabase CLI reads and lack timestamp prefixes.
  **Corrected AGAIN 2026-08-27:** even that was incomplete. `supabase_migrations.schema_migrations`
  holds **237 applied migrations**. Both my passes searched the filesystem; neither asked the
  database. The surviving finding is **reproducibility, not history** — 1 of 38 tracked `.sql`
  files has `CREATE TABLE`.
  **The claim propagated to eight documents before a reviewer running `ls` caught it.**
  Lesson: when asserting a path exists, run the command. And when a fact turns out wrong,
  grep for it everywhere — a reviewer sees the one file they were handed, not the six that
  copied from it.

**Confirmed non-findings:**
- Firebase `AIza…` keys (`lib/firebase_options.dart`, `android/app/google-services.json`) — public client IDs.
- `service_role` in `supabase/functions/**` — server-side Deno. Only a finding if it reaches `lib/`.
- `.g.dart`, `.freezed.dart`, `lib/l10n/app_localizations*.dart` — generated; exclude from all counts.
- App hangs on launch without `--dart-define-from-file=.env` — expected.
- `spatial_ref_sys` RLS ERROR — PostGIS extension-owned system table.
- 8 × `extension_in_public` (postgis, citext, pg_trgm, …) — Supabase default; moving them breaks queries.
- 300 + 299 `*_security_definer_function_executable` advisors — one per role per definer
  function, i.e. the entire deliberate RPC layer. Not individually actionable. The 25
  definer **views** are where the real exposure is.
- `notifications_screen_v2.dart` / `activities_screen_v2.dart` — `_v2` suffix but these are the
  live, routed screens; v1 was deleted in `c74d6e1`.
- `isAdmin` grep hits — every real gate calls `rpc(SupabaseConfig.isAdminFn)` server-side. Correct.
- `SportsHistoryScreen` — the class is orphaned, but the **file** has 3 importers pulling other symbols.
- `print()` in `lib/main.dart` zone guards and `lib/utils/logger.dart` — intentional error paths.
- `authControllerProvider` / `registerControllerProvider` throwing `UnimplementedError` — never
  watched, so no live crash. Delete, but not an incident.
- `encrypted_password` NULL on new users — by design (`trg_strip_signup_password`).

**Why:** every one of these was checked against the tree or the live database in run 1.
**How to apply:** when a scan surfaces one of these, state it in the "Looks bad but is
actually fine" section — never in the findings table.

See [[audit-baseline-2026-08-26]].
