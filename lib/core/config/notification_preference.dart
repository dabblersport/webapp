/// User's choice in the notification permission prompt.
///
/// [wireValue] is the string persisted in SharedPreferences and must remain
/// stable so existing installs keep their saved preference. Do not change the
/// wire values.
enum NotificationPreference {
  allow('allow'),
  remindLater('remind_later'),
  never('never');

  const NotificationPreference(this.wireValue);

  /// The persisted string value (stable contract).
  final String wireValue;

  /// Parses a persisted wire value, returning null for unknown/legacy values.
  static NotificationPreference? fromWire(String? value) {
    if (value == null) return null;
    for (final p in NotificationPreference.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}
