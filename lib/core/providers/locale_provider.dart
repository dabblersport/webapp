import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';

const _kLangKey = 'mock_language';
const _kSupported = ['en', 'ar'];

/// Synchronously picks the best supported locale from the device's preferred
/// locale list. Used as the initial state so the very first frame already has
/// the correct language and text direction — no flicker from 'en' → 'ar'.
Locale _deviceLocale() {
  final locales = WidgetsBinding.instance.platformDispatcher.locales;
  for (final l in locales) {
    if (_kSupported.contains(l.languageCode)) return Locale(l.languageCode);
  }
  return const Locale('en');
}

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_deviceLocale()) {
    _load();
  }

  String? _activeProfileId;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (saved != null && _kSupported.contains(saved)) {
      state = Locale(saved);
      return;
    }
    final system =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final resolved = _kSupported.contains(system) ? system : 'en';
    state = Locale(resolved);
    await prefs.setString(_kLangKey, resolved);
  }

  /// Hydrate locale from a loaded profile. Tracks the active profile id so
  /// future setLocale calls write back to the right row.
  Future<void> hydrateFromProfile(UserProfile? profile) async {
    _activeProfileId = profile?.id;
    final lang = profile?.language;
    if (lang == null || !_kSupported.contains(lang)) return;
    if (state.languageCode == lang) return;
    state = Locale(lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, lang);
  }

  /// User-initiated locale change. Persists to SharedPreferences and, when
  /// logged in, writes to the active profile.
  Future<void> setLocale(Locale locale) async {
    if (state.languageCode == locale.languageCode) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, locale.languageCode);

    final profileId = _activeProfileId;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && profileId != null && profileId.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'language': locale.languageCode})
            .eq('id', profileId);
      } catch (_) {
        // Best-effort — locale state is already updated locally
      }
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
