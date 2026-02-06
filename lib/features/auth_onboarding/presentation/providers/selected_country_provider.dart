import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/features/auth_onboarding/domain/location/location_detector.dart';

const _selectedCountryPrefsKey = 'selected_country';
const _selectedCityPrefsKey = 'selected_city';

/// Location state containing both country and city
class LocationState {
  final String country;
  final String? city;

  LocationState({required this.country, this.city});
}

class SelectedLocationNotifier
    extends StateNotifier<AsyncValue<LocationState>> {
  SelectedLocationNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCountry = prefs.getString(_selectedCountryPrefsKey);
      final savedCity = prefs.getString(_selectedCityPrefsKey);

      if (savedCountry != null && savedCountry.trim().isNotEmpty) {
        state = AsyncValue.data(
          LocationState(country: savedCountry, city: savedCity),
        );
        return;
      }

      final detected = await LocationDetector.detectUserLocation();
      state = AsyncValue.data(
        LocationState(country: detected.country, city: detected.city),
      );

      // Persist detected values
      await prefs.setString(_selectedCountryPrefsKey, detected.country);
      if (detected.city != null) {
        await prefs.setString(_selectedCityPrefsKey, detected.city!);
      }
    } catch (e, st) {
      // Safe fallback: keep UX working even if prefs/locale access fails.
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setLocation({required String country, String? city}) async {
    final trimmedCountry = country.trim();
    if (trimmedCountry.isEmpty) return;

    state = AsyncValue.data(
      LocationState(country: trimmedCountry, city: city?.trim()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedCountryPrefsKey, trimmedCountry);
      if (city != null && city.trim().isNotEmpty) {
        await prefs.setString(_selectedCityPrefsKey, city.trim());
      } else {
        await prefs.remove(_selectedCityPrefsKey);
      }
    } catch (_) {
      // Ignore persistence failures; state already updated in-memory.
    }
  }

  /// Legacy method for setting country only
  Future<void> setCountry(String country) async {
    await setLocation(country: country);
  }
}

/// Provider for location (country and city)
final selectedLocationProvider =
    StateNotifierProvider<SelectedLocationNotifier, AsyncValue<LocationState>>(
      (ref) => SelectedLocationNotifier(),
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
