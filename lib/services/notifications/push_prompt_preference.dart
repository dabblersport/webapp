// The "turn on notifications" prompt's remembered answer (moved out of
// push_notification_service_mobile.dart by KAN-1016; behaviour unchanged).

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/config/notification_preference.dart';

abstract final class PushPromptPreference {
  static const String preferenceKey = 'notification_prompt_preference';
  static const String nextAtKey = 'notification_prompt_next_at_ms';

  /// Check if we should show the notification permission prompt
  /// Returns true if user hasn't decided yet (remind later or never asked)
  static Future<bool> shouldShow({required Duration cooldown}) async {
    final prefs = await SharedPreferences.getInstance();
    final preference = prefs.getString(preferenceKey);

    // Never prompt again
    if (preference == 'never' || preference == 'allow') {
      return false;
    }

    // First time
    if (preference == null) {
      return true;
    }

    // Cooldown gating for "remind_later"
    if (preference == 'remind_later') {
      final nextAtMs = prefs.getInt(nextAtKey);

      // Backward-compat: older installs stored only the string.
      // Apply the cooldown starting now.
      if (nextAtMs == null) {
        final nextAt = DateTime.now().add(cooldown);
        await prefs.setInt(nextAtKey, nextAt.millisecondsSinceEpoch);
        return false;
      }

      return DateTime.now().millisecondsSinceEpoch >= nextAtMs;
    }

    // Unknown value -> treat as eligible
    return true;
  }

  /// Save user's notification permission preference
  static Future<void> save(
    NotificationPreference preference, {
    required Duration cooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, preference.wireValue);

    if (preference == NotificationPreference.remindLater) {
      final nextAt = DateTime.now().add(cooldown);
      await prefs.setInt(nextAtKey, nextAt.millisecondsSinceEpoch);
    } else {
      // If user allowed or never wants prompts, clear any scheduled reminder.
      await prefs.remove(nextAtKey);
    }
  }
}
