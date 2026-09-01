---
name: kan-58-fcm-revoke-on-logout
description: PushNotificationService.instance.revokeToken() — deletes fcm_tokens row on logout, must run before supabase.auth.signOut()
metadata:
  type: project
---

2026-08-28: Built for KAN-58 (T-004 teardown contract) at flutter-feature-agent's
request while they built the cache-teardown half. Before this, logout never
deleted the `fcm_tokens` row — `_listenAuthState()` in
`push_notification_service_mobile.dart` only handled `signedIn` (upsert), never
`signedOut`.

Added `revokeToken()` to all four notification-service files (all under my
`lib/services/notifications/**` grant):
- `push_notification_service.dart` — public facade, `PushNotificationService.instance.revokeToken()`
- `push_notification_service_mobile.dart` — deletes `fcm_tokens` row for `(user_id, platform=defaultTargetPlatform.name)`, then best-effort `FirebaseMessaging.instance.deleteToken()`
- `push_notification_service_web.dart` — same, `platform='web'`
- `push_notification_service_stub.dart` — no-op

**Hard ordering constraint**: delete is RLS-gated on `auth.uid()=user_id`
(see [[db-rls-policies]] — fcm_tokens has per-op auth.uid()=user_id, no
service-role exception needed since caller has a live session). Must be
called BEFORE `supabase.auth.signOut()`; after sign-out `currentUser` is
null and the method silently no-ops (not an error) — nothing gets deleted.

Call-site wiring (`AuthService.signOut()` in
`lib/core/services/auth_service.dart:261`) is NOT mine — that file isn't in
my CONTRACT.md grant. flutter-feature-agent owns wiring the call in before
`_supabase.auth.signOut()`. `dart analyze lib/services/notifications/` was
clean after this change; not yet run on-device.

**Resolved 2026-08-28:** flutter-feature-agent wired it — `signOut()` calls
`revokeToken()` first (try/catch, never blocks logout), then clears
UserService/ProfileCacheService/LocationService, then
`supabase.auth.signOut()`. `flutter analyze` clean, 66 tests pass. KAN-58
moved to In Review; only open item is a real-device "no further pushes
after logout" check flagged for QA.
