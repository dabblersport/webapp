---
name: db-tokens-settings
description: fcm_tokens (device token storage) and notification_settings tables — schema, constraints, RLS
metadata:
  type: reference
---

`public.fcm_tokens` (constant `SupabaseConfig.fcmTokensTable = 'fcm_tokens'`):
- id uuid PK, user_id uuid NOT NULL → FK auth.users ON DELETE CASCADE
- token text NOT NULL, platform text NOT NULL, created_at, updated_at
- UNIQUE (user_id, platform) = `unique_user_platform`; client upserts onConflict 'user_id,platform'
- CHECK platform IN ('android','iOS','macOS','web','linux','windows','fuchsia')
- Indexes: idx_fcm_tokens_token, idx_fcm_tokens_user_id
- RLS: full CRUD each scoped to auth.uid()=user_id (correct, secure)
- WARNING: client writes `platform: defaultTargetPlatform.name` (Dart gives 'android','iOS','macOS','windows','linux','fuchsia') — matches the CHECK. Web platform not handled by mobile service.

`public.notification_settings` (PK = user_id, FK auth.users ON DELETE CASCADE). Columns: tz (default 'Asia/Dubai'), quiet_start_min, quiet_end_min (CHECK 0..1439), push_enabled (def true), email_enabled (def false), sms_enabled (def false), muted_kinds text[] (def {}), allow_high_priority_override, allow_all_override, created_at, updated_at.
- RLS: ns_self_ins / ns_self_rw / ns_self_upd all auth.uid()=user_id (secure).
- WIRED END-TO-END (since commit 3b7fd50 + enforce_notification_settings_in_push_trigger.sql): client reads/writes via NotificationSettingsRepositoryImpl (`SupabaseConfig.notificationSettingsTable = 'notification_settings'`), UI is NotificationSettingsScreen (push/email/sms toggles, quiet hours, per-kind mutes, allow_high_priority_override AND allow_all_override toggles — the latter added 2026-07-11). Server-side: trg_push_on_notification_insert enforces push_enabled, muted_kinds, and tz-aware quiet hours (with high-priority/all overrides) before dispatching push.

Other settings tables exist (user_settings: push_enabled/email_enabled/quiet_start/quiet_end; user_preferences: get_updates) — overlapping/duplicate notification-preference surfaces.
