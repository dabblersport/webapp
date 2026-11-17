import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The id of this app installation for push registration (KAN-977).
///
/// A uuid v4, made once and stored in SharedPreferences under [prefsKey]
/// (localStorage on the web). It names the installation, not the user, so
/// sign-out never clears it; a reinstall or cleared storage makes a new one.
/// The server rejects ids that start with [reservedPrefix] (rows written by
/// old builds) or are longer than [maxLength], so a stored value like that is
/// replaced.
class PushInstallationId {
  PushInstallationId({
    Future<SharedPreferences> Function()? prefs,
    String Function()? generate,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _generate = generate ?? const Uuid().v4;

  static const String prefsKey = 'push_installation_id';
  static const String reservedPrefix = 'legacy:';
  static const int maxLength = 128;

  final Future<SharedPreferences> Function() _prefs;
  final String Function() _generate;
  Future<String>? _pending;

  /// Whether [id] is one the server accepts.
  static bool isValid(String? id) =>
      id != null &&
      id.trim().isNotEmpty &&
      id.length <= maxLength &&
      !id.startsWith(reservedPrefix);

  /// The stored id, made and stored on the first call. Concurrent first calls
  /// share one id.
  Future<String> read() async {
    try {
      return await (_pending ??= _readOrCreate());
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  Future<String> _readOrCreate() async {
    final prefs = await _prefs();
    final stored = prefs.getString(prefsKey);
    if (isValid(stored)) return stored!;
    final created = _generate();
    await prefs.setString(prefsKey, created);
    return created;
  }
}
