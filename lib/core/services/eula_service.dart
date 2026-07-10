import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

/// Tracks whether the user has viewed and accepted the app's Terms of Use
/// (EULA) / Privacy Policy, as required by App Store Guideline 1.2.
///
/// Acceptance must be captured BEFORE the user can reach registration or
/// login, so this state is cached in-memory (populated via [preload] at
/// app boot) and persisted locally via SharedPreferences. It is also
/// best-effort synced to `consent_records` for an audit trail, using a
/// stable per-device id since acceptance happens before any auth session
/// exists.
class EulaService {
  EulaService._();

  static const String _acceptedKey = 'eula_accepted_v1';
  static const String _acceptedVersionKey = 'eula_accepted_version';
  static const String _deviceIdKey = 'eula_device_id';

  /// Bump this when the Terms of Use / Privacy Policy materially change to
  /// force re-acceptance. Acceptance is only honored when the persisted
  /// [_acceptedVersionKey] matches this value — see [preload]/[accept].
  static const String currentVersion = '1.0';

  static bool _cachedAccepted = false;

  /// Synchronous read used by the router redirect — safe to call after
  /// [preload] has completed once at app startup.
  static bool get hasAccepted => _cachedAccepted;

  /// Loads persisted acceptance state into memory. Must be awaited before
  /// the router's first redirect evaluation (called from main.dart boot).
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_acceptedKey) ?? false;
    final acceptedVersion = prefs.getString(_acceptedVersionKey);
    _cachedAccepted = accepted && acceptedVersion == currentVersion;
  }

  /// Records acceptance locally (source of truth for the redirect gate) and
  /// fires a best-effort write to `consent_records` for an audit trail.
  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
    await prefs.setString(_acceptedVersionKey, currentVersion);
    _cachedAccepted = true;

    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    final result = await Result.guard(
      () => Supabase.instance.client
          .from(SupabaseConfig.consentRecordsTable)
          .insert({
            'user_id': uid,
            'device_id': deviceId,
            'consent_type': 'eula',
            'consent_version': currentVersion,
          }),
      (e) => Failure.from(e),
    );

    // Best-effort only — local acceptance is what gates the app; a failed
    // network sync must never block the user from proceeding. Still log it
    // so a dropped audit-trail write isn't silently invisible.
    result.fold(
      (failure) => debugPrint('[EulaService] consent sync failed: $failure'),
      (_) {},
    );
  }
}
