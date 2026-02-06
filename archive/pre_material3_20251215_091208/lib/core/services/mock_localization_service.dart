import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalizationService {
  static final MockLocalizationService _instance =
      MockLocalizationService._internal();
  factory MockLocalizationService() => _instance;
  MockLocalizationService._internal();

  // Default language
  String _currentLanguage = 'en';
  final String _languageKey = 'mock_language';

  // Initialize language
  Future<void> _initializeLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'en';
  }

  // Get current language
  Future<String> getCurrentLanguage() async {
    await _initializeLanguage();
    return _currentLanguage;
  }

  // Set language
  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    _currentLanguage = languageCode;
  }

  // Get supported languages
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
      {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
    ];
  }

  // Check if language is supported
  bool isLanguageSupported(String languageCode) {
    final supportedLanguages = getSupportedLanguages();
    return supportedLanguages.any((lang) => lang['code'] == languageCode);
  }

  // Get language name by code
  String? getLanguageName(String languageCode) {
    final supportedLanguages = getSupportedLanguages();
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => {'code': '', 'name': '', 'native': '', 'flag': ''},
    );
    return language['name'];
  }

  // Get native language name by code
  String? getNativeLanguageName(String languageCode) {
    final supportedLanguages = getSupportedLanguages();
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => {'code': '', 'name': '', 'native': '', 'flag': ''},
    );
    return language['native'];
  }

  // Get language flag by code
  String? getLanguageFlag(String languageCode) {
    final supportedLanguages = getSupportedLanguages();
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => {'code': '', 'name': '', 'native': '', 'flag': ''},
    );
    return language['flag'];
  }

  // Reset to default language
  Future<void> resetToDefault() async {
    await setLanguage('en');
  }
}
