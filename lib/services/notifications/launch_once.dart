// A notification that launched the app is handled once. A relaunch can hand
// the same launch payload back (getInitialMessage and the local-notification
// launch details both read the Activity's launch intent), so the ids already
// handled are remembered across process restarts.

import 'package:shared_preferences/shared_preferences.dart';

class LaunchOnce {
  LaunchOnce(this._prefs);

  static const String prefsKey = 'push_launch_handled_ids';
  static const int _keep = 20;

  final Future<SharedPreferences> Function() _prefs;

  static final LaunchOnce instance = LaunchOnce(SharedPreferences.getInstance);

  /// True the first time [id] is claimed; false for every later launch with
  /// the same payload. A null id cannot be de-duplicated and is let through.
  Future<bool> claim(String? id) async {
    if (id == null || id.isEmpty) return true;
    try {
      final prefs = await _prefs();
      final seen = prefs.getStringList(prefsKey) ?? const <String>[];
      if (seen.contains(id)) return false;
      final next = <String>[...seen, id];
      await prefs.setStringList(
        prefsKey,
        next.length > _keep ? next.sublist(next.length - _keep) : next,
      );
      return true;
    } catch (_) {
      return true;
    }
  }
}
