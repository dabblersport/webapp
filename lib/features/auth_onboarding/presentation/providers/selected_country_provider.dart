import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart' show SettingKeys;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// The service region of the signed-in account. Chosen by the user only: never
/// from VPN, IP or the device locale. A missing or unsupported value is Global.
class SelectedLocationNotifier
    extends StateNotifier<AsyncValue<LocationState>> {
  SelectedLocationNotifier({String? userId, ServiceRegionRemote? remote})
    : _userId = userId,
      _remote = remote ?? SupabaseServiceRegionRemote(),
      super(const AsyncValue.loading()) {
    _load();
  }

  final String? _userId;
  final ServiceRegionRemote _remote;

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
      if (uid != null) {
        // KAN-608: a region change still waiting for the server is newer.
        final queued = await SettingsSyncBridge.hasPendingEdit(
          SettingKeys.region,
        );
        final String? remote = queued ? null : await _remote.fetch(uid);
        if (remote != null) {
          region = normalizeServiceRegion(remote);
          await prefs.setString(_countryKey, region);
        } else if (saved != null && region != kGlobalRegion) {
          // A choice made before this account had a stored region.
          await _remote.save(uid, region);
        }
      }
      state = AsyncValue.data(LocationState(country: region, city: savedCity));
    } catch (e, st) {
      // Safe fallback: keep UX working even if prefs access fails.
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setLocation({required String country, String? city}) async {
    if (country.trim().isEmpty) return;
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
