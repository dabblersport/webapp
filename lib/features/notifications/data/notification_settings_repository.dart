import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_settings.dart';

/// Read/write access to `public.notification_settings` (one row per user).
abstract class NotificationSettingsRepository {
  /// Loads the current user's settings. Returns table defaults when no row
  /// exists yet (the row is created lazily on first save).
  Future<Result<NotificationSettings, Failure>> load();

  /// Upserts the full settings row for the current user.
  Future<Result<NotificationSettings, Failure>> save(
    NotificationSettings settings,
  );
}
