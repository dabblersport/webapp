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
    this.cityId,
    this.country,
    this.countryCode,
    this.savedLabel,
  });

  final String city;

  /// The map-service id and country of the chosen city, so two cities with the
  /// same name (Paris, France / Paris, Texas) stay distinct. Null when the city
  /// was derived from an area or a device fix.
  final String? cityId;
  final String? country;
  final String? countryCode;
  final String? area;
  final double? lat;
  final double? lng;
  final DeviceLocationMode mode;
  final DeviceLocationProvenance provenance;
  final DateTime updatedAt;

  /// The label of the saved place this location shows (KAN-589): set when the
  /// user selected a saved place (Manual) or when Auto's area has exactly one
  /// saved place. Null shows the area name. Per device, like the rest.
  final String? savedLabel;

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
      cityId: _prefs.getString(_k('cityId')),
      country: _prefs.getString(_k('country')),
      countryCode: _prefs.getString(_k('countryCode')),
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
      savedLabel: _prefs.getString(_k('savedLabel')),
    );
  }

  Future<void> _write(DeviceLocation l) async {
    await _prefs.setString(_k('city'), l.city);
    await _setOrRemoveString(_k('cityId'), l.cityId);
    await _setOrRemoveString(_k('country'), l.country);
    await _setOrRemoveString(_k('countryCode'), l.countryCode);
    await _setOrRemoveString(_k('area'), l.area);
    await _setOrRemoveString(_k('savedLabel'), l.savedLabel);
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
    String? savedLabel,
    DateTime? now,
  }) async {
    final DeviceLocation? cur = read();
    final bool sameCity = cur != null && cur.city == city;
    final DeviceLocation next = DeviceLocation(
      city: city,
      cityId: sameCity ? cur.cityId : null,
      country: sameCity ? cur.country : null,
      countryCode: sameCity ? cur.countryCode : null,
      area: area,
      lat: lat,
      lng: lng,
      mode: DeviceLocationMode.manual,
      provenance: DeviceLocationProvenance.manual,
      updatedAt: now ?? DateTime.now(),
      savedLabel: savedLabel,
    );
    await _write(next);
    return next;
  }

  /// The user changed the city. A different city clears the previous area and
  /// coordinates, so distance controls are off until a new area is chosen; the
  /// same city changes nothing. Mode becomes Manual.
  Future<DeviceLocation> changeCity(
    String city, {
    String? cityId,
    String? country,
    String? countryCode,
    DateTime? now,
  }) async {
    final DeviceLocation? cur = read();
    if (cur != null && cur.city == city) {
      // Same name is the same city unless both sides carry an identity and it
      // differs (Paris, France versus Paris, Texas).
      final bool differs =
          (cityId != null && cur.cityId != null && cityId != cur.cityId) ||
          (countryCode != null &&
              cur.countryCode != null &&
              countryCode.toLowerCase() != cur.countryCode!.toLowerCase());
      if (!differs) {
        if (cityId == null || cur.cityId != null) return cur;
        // The same city, now with an identity: keep the area, add the identity.
        final DeviceLocation withId = DeviceLocation(
          city: cur.city,
          cityId: cityId,
          country: country ?? cur.country,
          countryCode: countryCode ?? cur.countryCode,
          area: cur.area,
          lat: cur.lat,
          lng: cur.lng,
          mode: cur.mode,
          provenance: cur.provenance,
          updatedAt: cur.updatedAt,
          savedLabel: cur.savedLabel,
        );
        await _write(withId);
        return withId;
      }
    }
    final DeviceLocation next = DeviceLocation(
      city: city,
      cityId: cityId,
      country: country,
      countryCode: countryCode,
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
    String? savedLabel,
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
      savedLabel: savedLabel,
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
      cityId: cur.cityId,
      country: cur.country,
      countryCode: cur.countryCode,
      area: cur.area,
      lat: cur.lat,
      lng: cur.lng,
      mode: DeviceLocationMode.auto,
      provenance: DeviceLocationProvenance.lastKnown,
      updatedAt: cur.updatedAt,
      savedLabel: cur.savedLabel,
    );
    await _write(next);
    return next;
  }
}
