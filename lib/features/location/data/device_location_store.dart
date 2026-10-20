import 'package:shared_preferences/shared_preferences.dart';

/// How the device's current location was chosen (KAN-586).
enum DeviceLocationMode { manual, auto }

/// Where the stored point came from: the user picked it, the device fixed it,
/// or Auto is unavailable and this is the last point a fix produced.
enum DeviceLocationProvenance { manual, gps, lastKnown }

/// This device's current location: city, optional area and coordinates, the
/// Manual/Auto mode and the provenance of the point.
///
/// Per device and per signed-in account: it lives in this device's local
/// storage only, so another device's Auto fixes can never write to it. It is
/// separate from the public profile city/country and from the account service
/// region, which are account-level and never touched here.
class DeviceLocation {
  const DeviceLocation({
    required this.city,
    this.area,
    this.lat,
    this.lng,
    required this.mode,
    required this.provenance,
    required this.updatedAt,
  });

  final String city;
  final String? area;
  final double? lat;
  final double? lng;
  final DeviceLocationMode mode;
  final DeviceLocationProvenance provenance;
  final DateTime updatedAt;

  /// Distance sort and radius filters need a point; a city alone has none.
  bool get hasPoint => lat != null && lng != null;

  /// Distance controls stay off until an area or location is chosen.
  bool get distanceControlsEnabled => hasPoint;
}

/// Reads and writes the [DeviceLocation] of one account on this device, and
/// owns the rules of what may overwrite what.
class DeviceLocationStore {
  DeviceLocationStore(this._prefs, {required this.accountId});

  final SharedPreferences _prefs;

  /// The signed-in account; null (signed out) is its own scope.
  final String? accountId;

  String _k(String field) => 'device_location.${accountId ?? '-'}.$field';

  DeviceLocation? read() {
    final String? city = _prefs.getString(_k('city'));
    final String? mode = _prefs.getString(_k('mode'));
    final String? prov = _prefs.getString(_k('provenance'));
    if (city == null || mode == null || prov == null) return null;
    return DeviceLocation(
      city: city,
      area: _prefs.getString(_k('area')),
      lat: _prefs.getDouble(_k('lat')),
      lng: _prefs.getDouble(_k('lng')),
      mode:
          DeviceLocationMode.values.asNameMap()[mode] ??
          DeviceLocationMode.manual,
      provenance:
          DeviceLocationProvenance.values.asNameMap()[prov] ??
          DeviceLocationProvenance.manual,
      updatedAt:
          DateTime.tryParse(_prefs.getString(_k('updatedAt')) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> _write(DeviceLocation l) async {
    await _prefs.setString(_k('city'), l.city);
    await _setOrRemoveString(_k('area'), l.area);
    await _setOrRemoveDouble(_k('lat'), l.lat);
    await _setOrRemoveDouble(_k('lng'), l.lng);
    await _prefs.setString(_k('mode'), l.mode.name);
    await _prefs.setString(_k('provenance'), l.provenance.name);
    await _prefs.setString(_k('updatedAt'), l.updatedAt.toIso8601String());
  }

  Future<void> _setOrRemoveString(String key, String? v) async {
    if (v == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, v);
    }
  }

  Future<void> _setOrRemoveDouble(String key, double? v) async {
    if (v == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setDouble(key, v);
    }
  }

  /// The user chose a city, and an area with its point. Mode becomes Manual.
  Future<DeviceLocation> setManual({
    required String city,
    String? area,
    required double lat,
    required double lng,
    DateTime? now,
  }) async {
    final DeviceLocation next = DeviceLocation(
      city: city,
      area: area,
      lat: lat,
      lng: lng,
      mode: DeviceLocationMode.manual,
      provenance: DeviceLocationProvenance.manual,
      updatedAt: now ?? DateTime.now(),
    );
    await _write(next);
    return next;
  }

  /// The user changed the city. A different city clears the previous area and
  /// coordinates, so distance controls are off until a new area is chosen; the
  /// same city changes nothing. Mode becomes Manual.
  Future<DeviceLocation> changeCity(String city, {DateTime? now}) async {
    final DeviceLocation? cur = read();
    if (cur != null && cur.city == city) return cur;
    final DeviceLocation next = DeviceLocation(
      city: city,
      mode: DeviceLocationMode.manual,
      provenance: DeviceLocationProvenance.manual,
      updatedAt: now ?? DateTime.now(),
    );
    await _write(next);
    return next;
  }

  /// A device fix arrived while Auto. A Manual selection is never overwritten
  /// (returns it unchanged) unless the user explicitly switched back to Auto
  /// ([explicit]); otherwise the fix becomes the stored location.
  Future<DeviceLocation> applyAutoFix({
    required String city,
    String? area,
    required double lat,
    required double lng,
    bool explicit = false,
    DateTime? now,
  }) async {
    final DeviceLocation? cur = read();
    if (!explicit && cur != null && cur.mode == DeviceLocationMode.manual) {
      return cur;
    }
    final DeviceLocation next = DeviceLocation(
      city: city,
      area: area,
      lat: lat,
      lng: lng,
      mode: DeviceLocationMode.auto,
      provenance: DeviceLocationProvenance.gps,
      updatedAt: now ?? DateTime.now(),
    );
    await _write(next);
    return next;
  }

  /// Auto cannot read a position (permission denied, service off, timeout).
  /// The stored point stays as the last known one, labelled as such; nothing
  /// is invented and a Manual selection is untouched. Null when nothing is
  /// stored or the stored location has no point.
  Future<DeviceLocation?> markAutoUnavailable() async {
    final DeviceLocation? cur = read();
    if (cur == null || cur.mode == DeviceLocationMode.manual) return cur;
    if (!cur.hasPoint) return null;
    final DeviceLocation next = DeviceLocation(
      city: cur.city,
      area: cur.area,
      lat: cur.lat,
      lng: cur.lng,
      mode: DeviceLocationMode.auto,
      provenance: DeviceLocationProvenance.lastKnown,
      updatedAt: cur.updatedAt,
    );
    await _write(next);
    return next;
  }
}
