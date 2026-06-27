---
name: client-wiring
description: Flutter notification client — active AppNotification stack, dead legacy stack, FCM token persistence
metadata:
  type: reference
---

ACTIVE in-app stack (lib/features/notifications/):
- Model `AppNotification` (data/models/notification_model.dart) — Freezed + json. Maps to_user_id, kind_key, context→`payload`, priority enum NotifyPriority(low/normal/high/urgent), is_read, read_at, clicked_at, interaction_count, ai_score. Run build_runner after edits.
- Repo interface data/notifications_repository.dart + impl data/notifications_repository_impl.dart (Result<T,Failure>). Reads base `notifications` table directly. Hardcodes `_table = 'notifications'` instead of SupabaseConfig.notificationsTable (convention violation). markClicked does read-then-write increment (race-prone). getUnreadCount selects all is_read=false (relies on RLS).
- Realtime: data/notification_realtime_service.dart subscribes to postgres INSERT on notifications filtered by to_user_id.
- Controller/screen: presentation/controllers/notifications_controller.dart, screens/notifications_screen_v2.dart, badge providers.

DEAD legacy stack (do not extend; safe to delete):
- data/datasources/notifications_datasource.dart (SupabaseNotificationsDataSource) — queries `.eq('user_id',...)`, `.eq('type',...)` and inserts; columns don't exist (real cols to_user_id/kind_key) and insert is RLS-blocked. Imports the OTHER model `lib/data/models/notifications/notification_model.dart`.
- domain/repositories/notifications_repository.dart — Either/fpdart interface using NotificationType; not wired.
- Neither is referenced anywhere outside its own file (grep-confirmed). Two model files + two repo interfaces named NotificationsRepository coexist.

Push/token (mobile): lib/services/notifications/push_notification_service_mobile.dart. requestPermission, foreground via flutter_local_notifications channel 'default_channel', token persisted to fcm_tokens via upsert onConflict 'user_id,platform' (platform=defaultTargetPlatform.name). Token refresh listener persists new token. Tap routing reads data['action_route']. Permission-prompt preference stored in SharedPreferences (NotificationPreference enum: allow/remind_later/never), NOT in DB. Stub + service.dart conditional for web/non-mobile.
NotificationSender (lib/services/notifications/notification_sender.dart) invokes send-push-notification with client user JWT; pre-checks user_blocks.

Not exported in lib/providers.dart (no 'notification' entries there) — feature uses its own presentation/providers.
