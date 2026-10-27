import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The settings that may be changed offline and sent on reconnect (KAN-657):
/// user preferences only. Payments, identity, persona/intention, privacy and
/// account deletion are never queued: offline they show the normal network
/// error. A key not listed here is refused.
const Set<String> kQueueableSettingKeys = {
  SettingKeys.notifications,
  SettingKeys.theme,
  SettingKeys.language,
  SettingKeys.region,
};

bool isQueueableSetting(String key) => kQueueableSettingKeys.contains(key);

/// Whether a failed send is worth retrying. A network error, a timeout or a
/// server fault may pass; anything else (validation, permission, not found,
/// conflict) will fail the same way again, so the queued edit is dropped.
bool isRetryableSettingFailure(Object error) {
  final f = error is Failure ? error : Failure.from(error);
  return f.isNetwork ||
      f.isTimeout ||
      f.isServer ||
      f.isUnknown ||
      f.category == FailureCode.rateLimited;
}

/// A one-line notice about a setting whose queued change did not stick.
enum SettingNotice {
  /// The server held a newer value (another device): it won.
  updatedElsewhere,

  /// The server refused the change; the saved value is back.
  rejected,
}

/// Notices waiting to be seen, by setting key. Set by the sync, cleared by the
/// user (tap) or by the next edit of that setting.
final settingNoticesProvider = StateProvider<Map<String, SettingNotice>>(
  (ref) => const {},
);
