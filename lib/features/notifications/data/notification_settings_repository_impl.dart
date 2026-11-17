import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_settings.dart';
import 'notification_settings_repository.dart';

/// Calls one Supabase RPC; replaceable in tests.
typedef NotificationSettingsRpc =
    Future<dynamic> Function(String fn, {Map<String, dynamic>? params});

/// Supabase-backed [NotificationSettingsRepository] over the KAN-975 RPCs.
/// They run as the caller (RLS `auth.uid() = user_id`); none touches the
/// table directly.
class NotificationSettingsRepositoryImpl
    implements NotificationSettingsRepository {
  NotificationSettingsRepositoryImpl(SupabaseClient client)
    : _rpc = ((fn, {params}) => client.rpc(fn, params: params));

  /// A repository over a fake RPC call.
  NotificationSettingsRepositoryImpl.withRpc(this._rpc);

  final NotificationSettingsRpc _rpc;

  @override
  Future<Result<NotificationSettings, Failure>> load() => Result.guard(
    () async => _row(await _rpc(SupabaseConfig.rpcGetMyNotificationSettings)),
    Failure.from,
  );

  @override
  Future<Result<NotificationSettings, Failure>> update(
    Map<String, dynamic> patch,
  ) => Result.guard(
    () async => _row(
      await _rpc(
        SupabaseConfig.rpcUpdateMyNotificationSettings,
        params: {'p_patch': patch},
      ),
    ),
    Failure.from,
  );

  @override
  Future<Result<NotificationSettings, Failure>> setTimezone(String tz) =>
      Result.guard(
        () async => _row(
          await _rpc(
            SupabaseConfig.rpcSetMyNotificationTimezone,
            params: {'p_tz': tz},
          ),
        ),
        Failure.from,
      );

  /// The RPCs return one `notification_settings` row (a JSON object; a list
  /// of one when PostgREST wraps it).
  static NotificationSettings _row(dynamic raw) {
    final Object? row = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (row is! Map) {
      throw const FormatException('notification_settings: expected a row');
    }
    return NotificationSettings.fromJson(Map<String, dynamic>.from(row));
  }
}
