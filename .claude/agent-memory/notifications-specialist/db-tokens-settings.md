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
- ORPHANED: NOT read/written by any client code (settings_repository updateNotificationPreferences throws UnimplementedError; notification_settings_screen is static UI). Quiet hours / muted_kinds are NOT enforced by the push trigger or edge function. There is NO SupabaseConfig constant for this table.

Other settings tables exist (user_settings: push_enabled/email_enabled/quiet_start/quiet_end; user_preferences: get_updates) — overlapping/duplicate notification-preference surfaces.
