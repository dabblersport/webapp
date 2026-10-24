import 'package:dabbler/core/constants/timing/location_timing.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart' show SettingKeys;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/auth_onboarding/data/services/ip_country_detection_service.dart';
import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;

const _selectedCountryPrefsKey = 'selected_country';
const _selectedCityPrefsKey = 'selected_city';

/// Location state containing both country and city
class LocationState {
  final String country;
  final String? city;

  LocationState({required this.country, this.city});
}

/// The account-level copy of the service region (KAN-584), so the choice
/// follows the account across devices. Best effort: a failure leaves the local
/// copy in charge.
abstract class ServiceRegionRemote {
  /// The account's stored region, or null when none is stored / unreachable.
  Future<String?> fetch(String userId);
  Future<void> save(String userId, String region);
}

class SupabaseServiceRegionRemote implements ServiceRegionRemote {
  static const String table = 'account_service_region';

  @override
  Future<String?> fetch(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from(table)
          .select('region')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['region'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String userId, String region) async {
    try {
      await Supabase.instance.client.from(table).upsert({
        'user_id': userId,
        'region': region,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Local copy already applies; the next explicit change retries.
    }
  }
}

/// Detects the visitor's country from the IP (the `detect-country` edge
/// function); returns an English country name, or Global when it cannot.
typedef CountryDetector = Future<String> Function();

Future<String> _detectFromIp() =>
    IpCountryDetectionService().detectCountryFromIp();

/// The app's service region. KAN-640 R6 (CEO): on the very first run, with no
/// country saved on the device (or account), the country is detected once from
/// the IP and preselected when it is a supported country, otherwise Global; a
/// failed detection is Global and is tried again next launch. Once a country is
/// saved (detected or picked) it is never detected again, and a manual choice
/// always wins. Never from the device locale. A missing or unsupported value is
/// Global.
class SelectedLocationNotifier
    extends StateNotifier<AsyncValue<LocationState>> {
  SelectedLocationNotifier({
    String? userId,
    ServiceRegionRemote? remote,
    CountryDetector? detect,
  }) : _userId = userId,
       _remote = remote ?? SupabaseServiceRegionRemote(),
       _detect = detect ?? _detectFromIp,
       super(const AsyncValue.loading()) {
    _load();
  }

  final String? _userId;
  final ServiceRegionRemote _remote;
  final CountryDetector _detect;

  /// Set by any manual choice, so a late detection never overrides it.
  bool _chosen = false;

  /// Per account on this device, so another account never inherits it.
  String get _countryKey => _userId == null
      ? _selectedCountryPrefsKey
      : '$_selectedCountryPrefsKey.$_userId';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_selectedCityPrefsKey);
      // KAN-640 R5: the country picked on the signed-out screens (landing,
      // email entry) is the app's country; a first sign-in on this device
      // keeps it instead of falling back to Global.
      final String? saved =
          prefs.getString(_countryKey) ??
          (_userId == null ? null : prefs.getString(_selectedCountryPrefsKey));
      String region = normalizeServiceRegion(saved);
      if (saved != null && saved != region) {
        await prefs.setString(_countryKey, region);
      }

      final uid = _userId;
      var accountHasRegion = false;
      if (uid != null) {
        // KAN-608: a region change still waiting for the server is newer.
        final queued = await SettingsSyncBridge.hasPendingEdit(
          SettingKeys.region,
        );
        final String? remote = queued ? null : await _remote.fetch(uid);
        accountHasRegion = queued || remote != null;
        if (remote != null) {
          region = normalizeServiceRegion(remote);
          await prefs.setString(_countryKey, region);
        } else if (saved != null && region != kGlobalRegion) {
          // A choice made before this account had a stored region.
          await _remote.save(uid, region);
        }
      }
      state = AsyncValue.data(LocationState(country: region, city: savedCity));
      if (saved == null && !accountHasRegion && !_chosen) {
        await _detectFirstRun(prefs);
      }
    } catch (e, st) {
      // Safe fallback: keep UX working even if prefs access fails.
      state = AsyncValue.error(e, st);
    }
  }

  /// The one-time IP detection. A supported country is saved and preselected; a
  /// country the app does not serve is saved as Global; a failure saves nothing
  /// (Global shows, and the next launch tries again).
  Future<void> _detectFirstRun(SharedPreferences prefs) async {
    String detected;
    try {
      detected = await _detect().timeout(ipCountryDetectionTimeout);
    } catch (_) {
      return;
    }
    if (_chosen || !mounted) return;
    final String name = detected.trim();
    if (name.isEmpty || name == kGlobalRegion) return;
    final String region = normalizeServiceRegion(name);
    await prefs.setString(_countryKey, region);
    if (_chosen || !mounted) return;
    final String? city = state.valueOrNull?.city;
    state = AsyncValue.data(LocationState(country: region, city: city));
    final uid = _userId;
    if (uid != null && region != kGlobalRegion) await _remote.save(uid, region);
  }

  Future<void> setLocation({required String country, String? city}) async {
    if (country.trim().isEmpty) return;
    _chosen = true;
    final String region = normalizeServiceRegion(country);

    state = AsyncValue.data(LocationState(country: region, city: city?.trim()));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_countryKey, region);
      if (city != null && city.trim().isNotEmpty) {
        await prefs.setString(_selectedCityPrefsKey, city.trim());
      } else {
        await prefs.remove(_selectedCityPrefsKey);
      }
    } catch (_) {
      // Ignore persistence failures; state already updated in-memory.
    }
    final uid = _userId;
    if (uid == null) return;
    // KAN-608: applied on the device already; the offline queue sends it.
    if (await SettingsSyncBridge.submit(SettingKeys.region, {
      'region': region,
    })) {
      return;
    }
    await _remote.save(uid, region);
  }

  /// Legacy method for setting country only
  Future<void> setCountry(String country) async {
    await setLocation(country: country);
  }
}

/// Provider for location (country and city)
final selectedLocationProvider =
    StateNotifierProvider<SelectedLocationNotifier, AsyncValue<LocationState>>(
      (ref) =>
          SelectedLocationNotifier(userId: ref.watch(currentUserIdProvider)),
    );

/// Legacy provider for backwards compatibility - returns only country
class SelectedCountryNotifier extends StateNotifier<AsyncValue<String>> {
  final Ref _ref;

  SelectedCountryNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen to the location provider and extract country
    _ref.listen<AsyncValue<LocationState>>(selectedLocationProvider, (
      previous,
      next,
    ) {
      state = next.whenData((location) => location.country);
    }, fireImmediately: true);
  }

  Future<void> setCountry(String country) async {
    await _ref.read(selectedLocationProvider.notifier).setCountry(country);
  }
}

final selectedCountryProvider =
    StateNotifierProvider<SelectedCountryNotifier, AsyncValue<String>>(
      (ref) => SelectedCountryNotifier(ref),
    );
