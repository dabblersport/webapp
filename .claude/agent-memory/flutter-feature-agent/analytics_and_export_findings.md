---
name: analytics-and-export-findings
description: Live analytics RPC pattern and the missing data_export_requests table found while working KAN-51/KAN-52
metadata:
  type: project
---

**`rpc_track_event` is a real, live RPC** — `public.analytics_events` exists in production
(RLS enabled, verified via `list_tables`). The pattern `ActivityAnalyticsDatasource`
(`lib/features/activities/data/datasources/activity_analytics_datasource.dart`) established
first: fire-and-forget, catch-and-log, never throw. `AnalyticsService`
(`lib/core/services/analytics/analytics_service.dart`) now forwards to the same RPC via
`SupabaseConfig.rpcTrackEventFn`. `T-016`/`P-008` (docs/DECISIONS.md) didn't know this RPC
was already live when they scoped KAN-51 — worth checking DECISIONS.md is corrected if this
comes up again.

**`public.data_export_requests` does not exist in production**, despite
`supabase_config.dart:178` naming it and KAN-52's own ticket text asserting it does.
Verified via `list_tables` 2026-08-29 — absent from the schema entirely, not just empty.
`DataExportService._storeExportRequest()` swallows the resulting `PostgrestException`
(logs a warning, continues), so the export UI I wired in `AccountManagementScreen` will
appear to work while silently not persisting the request. **Do not treat KAN-52 as closable
by Flutter work alone** — it needs a migration from `backend-owner` (schema posted in the
KAN-52 Jira comment, 2026-08-29) plus a real email-delivery decision (`EmailService.sendEmail`
in `data_export_service.dart` is a local no-op stub).

**Why:** both of these were "verify against the real repo, not the ticket text" lessons —
the ticket descriptions for KAN-51 and KAN-52 both contained claims (rpc_track_event
existing as if new, data_export_requests existing) that didn't hold up under a live DB
check. [[jira-tickets-need-live-verification]]

**How to apply:** before treating a ticket's "the backend already exists" claim as fact,
run `list_tables` (read is always allowed per decision 019) rather than trusting the ticket
text or a prior agent's comment.

**Update 2026-08-31:** `data_export_requests` now exists (backend-owner's migration landed)
and was live-verified — exact insert/update shape the app sends succeeds under RLS,
cross-user isolation confirmed, via a rolled-back transaction using
`set local request.jwt.claims` to simulate an authenticated session without touching real
auth or leaving residue. Good pattern for "verify RLS against prod without a device" —
reuse it instead of trying to run `flutter test` with real network (blocked: `flutter test`
returns HTTP 400 for all requests under `TestWidgetsFlutterBinding` by default, and
`shared_preferences`/`supabase_flutter`'s local storage needs plugin mocking anyway).

**Bigger finding: `DataExportService`'s data-gathering methods reference ~12 tables that
don't exist in production** — `performance_metrics`, `user_game_statistics`,
`game_participants`, `messages`, `audit_logs`, `login_history`, `friendships`,
`user_media`, `location_data`, `device_info`, `payment_records`,
`third_party_connections`. Only `profiles`, `user_settings`, `user_preferences`,
`sport_profiles`, `privacy_settings`, `consent_records`, `notifications`, `user_blocks`
are real. Each missing-table call is try/catch-wrapped and returns `null` silently — same
pattern as the original missing-table bug, just deeper in the file. Checked against the
privacy policy the app actually ships (`lib/features/profile/presentation/screens/about/legal_content.dart`,
`kPrivacyPolicySections` §1): it declares activity data, communications, and device/usage
data as collected, none of which the export can currently produce. This is why KAN-52 is
still not closable even with the table fixed — it's a much bigger schema-vs-code drift
than the ticket originally scoped. Correct owners for the next step: `backend-owner`/`cto`
to decide build-vs-rewrite per table (e.g. `game_roster` exists and could replace the
`game_participants` reference; `posts`/`comments` exist and could replace `messages`).
