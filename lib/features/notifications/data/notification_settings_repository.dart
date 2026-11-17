import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_settings.dart';

/// Read/write access to the caller's `public.notification_settings` row,
/// through the KAN-975 RPCs only (KAN-991).
abstract class NotificationSettingsRepository {
  /// Loads the current user's settings (`rpc_get_my_notification_settings`,
  /// which creates the row with the table defaults on first read).
  Future<Result<NotificationSettings, Failure>> load();

  /// Applies a partial [patch] (`rpc_update_my_notification_settings`) and
  /// returns the row as stored. `category_prefs` and `reminder_rungs` merge
  /// per key on the server; `muted_kinds` is replaced.
  Future<Result<NotificationSettings, Failure>> update(
    Map<String, dynamic> patch,
  );

  /// Stores the device time zone, an IANA name
  /// (`rpc_set_my_notification_timezone`).
  Future<Result<NotificationSettings, Failure>> setTimezone(String tz);
}
