---
name: app-store-submission-170
description: Resolution history for the v1.0 build 170 rejection (Guideline 5.1.1 account deletion + Guideline 1.2 UGC moderation), submission 9e8a4758-58a4-4bba-baff-960517f83e1e.
metadata:
  type: project
---

2026-07-01: Apple rejected submission `9e8a4758-58a4-4bba-baff-960517f83e1e` (v1.0, build 170) on two guidelines. Demo-account/login-credentials issue was already resolved separately (untouched this round — do not re-touch auth/demo-account logic for this rejection).

**Guideline 5.1.1 (account deletion)**: the in-app UI (`account_management_screen.dart`'s `_showDeleteAccountDialog`/`_deleteAccount`) was already fully compliant — clear "Delete Account" action, "This action cannot be undone. All your data will be permanently deleted." copy, type-DELETE-to-confirm, calls `delete_my_account` RPC, signs out, routes to `/auth-welcome`. The actual root cause was a **backend bug**: the RPC could throw a FK violation and fail silently for real users (see [[backend_moderation_infra]]). Fixed via migration only — zero Flutter changes needed for this guideline.

**Guideline 1.2 (UGC moderation)**: report_content RPC and user_blocks/rpc_block_user already existed backend-side but (a) report was only reachable from user profiles, not from posts in the feed, (b) blocking never actually filtered the feed, (c) no developer notification on new reports/blocks, (d) no EULA gate before login. All four fixed this session — see [[backend_moderation_infra]] and [[eula_gate_implementation]].

Repo state at time of this fix: `pubspec.yaml` had `version: 1.7.3+169`, NOT `1.0+170` as the task brief assumed — bumped to `1.7.3+170` (kept the real marketing version 1.7.3; did not force it down to "1.0"). **If a future rejection brief cites a build/version number, verify against `pubspec.yaml` directly rather than trusting the brief** — it may be stale or referring to an App-Store-Connect-side override (`--build-number=` flag) that diverged from the committed source.
