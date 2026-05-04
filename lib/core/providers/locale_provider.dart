import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dabbler/core/services/mock_localization_service.dart';

const _kLangKey = 'mock_language';
const _kSupported = ['en', 'ar'];

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (saved != null && _kSupported.contains(saved)) {
      state = Locale(saved);
      return;
    }
    // First launch: sync with iOS/device system language
    final system =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final resolved = _kSupported.contains(system) ? system : 'en';
    state = Locale(resolved);
    await prefs.setString(_kLangKey, resolved);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, locale.languageCode);
    MockLocalizationService().setLanguage(locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
