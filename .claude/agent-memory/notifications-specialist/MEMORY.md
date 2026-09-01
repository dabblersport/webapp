# Notifications Specialist Memory Index

- [Notifications schema](db-notifications-schema.md) — notifications/notification_kinds tables, notify_priority enum, indexes, FKs
- [Token & settings model](db-tokens-settings.md) — fcm_tokens + notification_settings tables, RLS, constraints
- [RLS policies](db-rls-policies.md) — per-user isolation on all notification tables; INSERT blocked on notifications
- [Triggers & fan-out](db-triggers-functions.md) — trg_*_notify triggers write notifications; trg_push_on_notification_insert calls edge fn
- [Edge functions](edge-functions.md) — send-push-notification / broadcast-notification; FCM HTTP v1
- [Trigger push 401 bug (STALE)](delivery-bug-trigger-401.md) — old finding, since fixed (x-trigger-secret lane added); superseded by gateway-legacy-jwt below
- [Gateway UNAUTHORIZED_LEGACY_JWT bug](delivery-bug-gateway-legacy-jwt.md) — LIVE 2026-08-31: push 100% failing, gateway rejects legacy JWT before verify_jwt=true function code runs; fix is verify_jwt:false, not yet applied
- [Flutter client wiring](client-wiring.md) — active AppNotification stack vs dead legacy datasource/model; FCM token persistence
- [KAN-59 authz fix](kan-59-authz-fix.md) — send-push-notification relationship-check + rate limit authored in repo, NOT yet deployed to prod
- [KAN-58 FCM revoke on logout](kan-58-fcm-revoke-on-logout.md) — PushNotificationService.instance.revokeToken(), must run before auth.signOut()
