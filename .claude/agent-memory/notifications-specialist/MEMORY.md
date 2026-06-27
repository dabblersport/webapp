# Notifications Specialist Memory Index

- [Notifications schema](db-notifications-schema.md) — notifications/notification_kinds tables, notify_priority enum, indexes, FKs
- [Token & settings model](db-tokens-settings.md) — fcm_tokens + notification_settings tables, RLS, constraints
- [RLS policies](db-rls-policies.md) — per-user isolation on all notification tables; INSERT blocked on notifications
- [Triggers & fan-out](db-triggers-functions.md) — trg_*_notify triggers write notifications; trg_push_on_notification_insert calls edge fn
- [Edge functions](edge-functions.md) — send-push-notification / broadcast-notification; FCM HTTP v1
- [Trigger push 401 bug](delivery-bug-trigger-401.md) — DB-trigger push path returns 401 (anon-key caller rejected by getUser())
- [Flutter client wiring](client-wiring.md) — active AppNotification stack vs dead legacy datasource/model; FCM token persistence
