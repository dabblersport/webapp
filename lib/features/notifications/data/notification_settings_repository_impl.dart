import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_settings.dart';
import 'notification_settings_repository.dart';

/// Supabase-backed implementation of [NotificationSettingsRepository].
///
/// Targets `public.notification_settings`. RLS restricts every row to
/// `user_id = auth.uid()`, so all queries are implicitly scoped to the caller.
class NotificationSettingsRepositoryImpl
    implements NotificationSettingsRepository {
  NotificationSettingsRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _table = SupabaseConfig.notificationSettingsTable;

  @override
  Future<Result<NotificationSettings, Failure>> load() {
    return Result.guard(() async {
      final userId = _requireUserId();
      final row = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        return NotificationSettings.defaults(userId);
      }
      return NotificationSettings.fromJson(row);
    }, Failure.from);
  }

  @override
  Future<Result<NotificationSettings, Failure>> save(
    NotificationSettings settings,
  ) {
    return Result.guard(() async {
      final userId = _requireUserId();
      final payload = <String, dynamic>{
        'user_id': userId,
        'tz': settings.tz,
        'quiet_start_min': settings.quietStartMin,
        'quiet_end_min': settings.quietEndMin,
        'push_enabled': settings.pushEnabled,
        'email_enabled': settings.emailEnabled,
        'sms_enabled': settings.smsEnabled,
        'muted_kinds': settings.mutedKinds,
        'allow_high_priority_override': settings.allowHighPriorityOverride,
        'allow_all_override': settings.allowAllOverride,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final row = await _client
          .from(_table)
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      return NotificationSettings.fromJson(row);
    }, Failure.from);
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }
    return userId;
  }
}
