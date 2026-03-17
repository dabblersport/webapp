import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dabbler/design_system/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeModeKey = 'theme_mode';
  static const String _themeCategoryKey = 'theme_category';
  static const String _autoThemeKey = 'auto_theme_enabled';
  static const String _dayStartTimeKey = 'day_start_time';
  static const String _nightStartTimeKey = 'night_start_time';

  ThemeMode _themeMode = ThemeMode.system;
  String _themeCategory = AppTheme.defaultCategory;
  bool _autoThemeEnabled = true;
  TimeOfDay _dayStartTime = const TimeOfDay(hour: 6, minute: 0); // 6:00 AM
  TimeOfDay _nightStartTime = const TimeOfDay(hour: 18, minute: 0); // 6:00 PM
  StreamSubscription<AuthState>? _authSubscription;

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get themeCategory => _themeCategory;
  bool get autoThemeEnabled => _autoThemeEnabled;
  TimeOfDay get dayStartTime => _dayStartTime;
  TimeOfDay get nightStartTime => _nightStartTime;

  // Get effective theme mode (considering auto theme)
  ThemeMode get effectiveThemeMode {
    if (_themeMode == ThemeMode.system || _autoThemeEnabled) {
      return _getSystemThemeMode();
    }
    return _themeMode;
  }

  // Get current brightness
  Brightness get currentBrightness {
    switch (effectiveThemeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return _getSystemBrightness();
    }
  }

  // Initialize theme service
  Future<void> init() async {
    await _loadPreferences();
    AppTheme.setActiveCategory(_themeCategory);
    notifyListeners();
  }

  void attachAccountSyncListener() {
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
        .listen((event) {
          switch (event.event) {
            case AuthChangeEvent.initialSession:
            case AuthChangeEvent.signedIn:
            case AuthChangeEvent.tokenRefreshed:
            case AuthChangeEvent.userUpdated:
              unawaited(hydrateFromAccount());
            case AuthChangeEvent.signedOut:
            case AuthChangeEvent.passwordRecovery:
            case AuthChangeEvent.mfaChallengeVerified:
            case AuthChangeEvent.userDeleted:
              break;
          }
        });
  }

  Future<void> hydrateFromAccount() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final row = await client
          .from('user_settings')
          .select(
            'theme_mode, theme_category, auto_theme_enabled, day_start_time, night_start_time',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return;

      final nextThemeMode = _parseThemeMode(row['theme_mode']);
      final nextThemeCategory = AppTheme.normalizeCategory(
        row['theme_category'] as String? ?? _themeCategory,
      );
      final nextAutoThemeEnabled =
          row['auto_theme_enabled'] as bool? ?? _autoThemeEnabled;
      final nextDayStartTime = _parseDbTime(
        row['day_start_time'],
        fallback: _dayStartTime,
      );
      final nextNightStartTime = _parseDbTime(
        row['night_start_time'],
        fallback: _nightStartTime,
      );

      final hasThemeModeChanged = nextThemeMode != _themeMode;
      final hasThemeCategoryChanged = nextThemeCategory != _themeCategory;
      final hasAutoThemeChanged = nextAutoThemeEnabled != _autoThemeEnabled;
      final hasDayStartChanged = nextDayStartTime != _dayStartTime;
      final hasNightStartChanged = nextNightStartTime != _nightStartTime;
      if (!hasThemeModeChanged &&
          !hasThemeCategoryChanged &&
          !hasAutoThemeChanged &&
          !hasDayStartChanged &&
          !hasNightStartChanged) {
        return;
      }

      _themeMode = nextThemeMode;
      _themeCategory = nextThemeCategory;
      _autoThemeEnabled = nextAutoThemeEnabled;
      _dayStartTime = nextDayStartTime;
      _nightStartTime = nextNightStartTime;
      AppTheme.setActiveCategory(_themeCategory);
      await _savePreferences();
      notifyListeners();
    } on PostgrestException catch (error) {
      debugPrint('ThemeService hydrateFromAccount skipped: ${error.message}');
    } catch (error) {
      debugPrint('ThemeService hydrateFromAccount skipped: $error');
    }
  }

  // Load preferences from shared preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme mode with validation
    final themeModeIndex =
        prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    if (themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    } else {
      _themeMode = ThemeMode.system; // Default for invalid values
    }

    _themeCategory = AppTheme.normalizeCategory(
      prefs.getString(_themeCategoryKey) ?? AppTheme.defaultCategory,
    );

    // Load auto theme setting
    _autoThemeEnabled = prefs.getBool(_autoThemeKey) ?? true;

    // Load day start time with validation
    final dayStartMinutes = prefs.getInt(_dayStartTimeKey) ?? 360; // 6:00 AM
    final validatedDayStartMinutes = _validateTimeMinutes(dayStartMinutes, 360);
    _dayStartTime = TimeOfDay(
      hour: validatedDayStartMinutes ~/ 60,
      minute: validatedDayStartMinutes % 60,
    );

    // Load night start time with validation
    final nightStartMinutes =
        prefs.getInt(_nightStartTimeKey) ?? 1080; // 6:00 PM
    final validatedNightStartMinutes = _validateTimeMinutes(
      nightStartMinutes,
      1080,
    );
    _nightStartTime = TimeOfDay(
      hour: validatedNightStartMinutes ~/ 60,
      minute: validatedNightStartMinutes % 60,
    );
  }

  // Validate time minutes are within valid range (0-1439 minutes in a day)
  int _validateTimeMinutes(int minutes, int defaultValue) {
    if (minutes < 0 || minutes >= 1440) {
      // 1440 minutes = 24 hours
      return defaultValue;
    }
    return minutes;
  }

  // Save preferences to shared preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_themeModeKey, _themeMode.index);
    await prefs.setString(_themeCategoryKey, _themeCategory);
    await prefs.setBool(_autoThemeKey, _autoThemeEnabled);
    await prefs.setInt(
      _dayStartTimeKey,
      _dayStartTime.hour * 60 + _dayStartTime.minute,
    );
    await prefs.setInt(
      _nightStartTimeKey,
      _nightStartTime.hour * 60 + _nightStartTime.minute,
    );
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _savePreferences();
      notifyListeners();
      unawaited(_saveThemePreferencesToAccountIfAvailable());
    }
  }

  Future<void> setThemeCategory(String category) async {
    final normalized = AppTheme.normalizeCategory(category);
    if (_themeCategory == normalized) return;

    _themeCategory = normalized;
    AppTheme.setActiveCategory(_themeCategory);
    await _savePreferences();
    notifyListeners();
    unawaited(_saveThemePreferencesToAccountIfAvailable());
  }

  // Toggle auto theme
  Future<void> setAutoThemeEnabled(bool enabled) async {
    if (_autoThemeEnabled != enabled) {
      _autoThemeEnabled = enabled;
      await _savePreferences();
      notifyListeners();
      unawaited(_saveThemePreferencesToAccountIfAvailable());
    }
  }

  // Set day start time
  Future<void> setDayStartTime(TimeOfDay time) async {
    if (_dayStartTime != time) {
      _dayStartTime = time;
      await _savePreferences();
      notifyListeners();
      unawaited(_saveThemePreferencesToAccountIfAvailable());
    }
  }

  // Set night start time
  Future<void> setNightStartTime(TimeOfDay time) async {
    if (_nightStartTime != time) {
      _nightStartTime = time;
      await _savePreferences();
      notifyListeners();
      unawaited(_saveThemePreferencesToAccountIfAvailable());
    }
  }

  // Get system theme mode based on time
  ThemeMode _getSystemThemeMode() {
    if (!_autoThemeEnabled) {
      // Use system settings
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    }

    // Use time-based theme
    return _isNightTime() ? ThemeMode.dark : ThemeMode.light;
  }

  // Get system brightness
  Brightness _getSystemBrightness() {
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    if (_autoThemeEnabled) {
      return _isNightTime() ? Brightness.dark : Brightness.light;
    }

    return systemBrightness;
  }

  // Check if it's night time based on user settings
  bool _isNightTime() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final dayStartMinutes = _dayStartTime.hour * 60 + _dayStartTime.minute;
    final nightStartMinutes =
        _nightStartTime.hour * 60 + _nightStartTime.minute;

    if (dayStartMinutes < nightStartMinutes) {
      // Normal day (e.g., 6:00 AM to 6:00 PM)
      return nowMinutes < dayStartMinutes || nowMinutes >= nightStartMinutes;
    } else {
      // Overnight schedule (e.g., 6:00 PM to 6:00 AM)
      return nowMinutes >= nightStartMinutes && nowMinutes < dayStartMinutes;
    }
  }

  // Get theme description for UI
  String getThemeDescription() {
    final categoryLabel = getThemeCategoryDisplayName(_themeCategory);
    if (_autoThemeEnabled) {
      final isDark = _isNightTime();
      return '$categoryLabel · Auto (${isDark ? 'Dark' : 'Light'} mode)';
    }

    switch (_themeMode) {
      case ThemeMode.light:
        return '$categoryLabel · Light mode';
      case ThemeMode.dark:
        return '$categoryLabel · Dark mode';
      case ThemeMode.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return '$categoryLabel · System (${brightness == Brightness.dark ? 'Dark' : 'Light'} mode)';
    }
  }

  static String getThemeCategoryDisplayName(String category) {
    switch (AppTheme.normalizeCategory(category)) {
      case 'social':
        return 'Social';
      case 'sports':
        return 'Sports';
      case 'activity':
        return 'Activity';
      case 'profile':
        return 'Profile';
      case 'main':
      default:
        return 'Main';
    }
  }

  // Format time for display
  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  ThemeMode _parseThemeMode(dynamic rawValue) {
    if (rawValue is String) {
      for (final mode in ThemeMode.values) {
        if (mode.name == rawValue) {
          return mode;
        }
      }
    }
    return _themeMode;
  }

  Future<void> _saveThemePreferencesToAccountIfAvailable() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final payload = <String, dynamic>{
        'theme_mode': _themeMode.name,
        'theme_category': _themeCategory,
        'auto_theme_enabled': _autoThemeEnabled,
        'day_start_time': _formatDbTime(_dayStartTime),
        'night_start_time': _formatDbTime(_nightStartTime),
      };

      final existing = await client
          .from('user_settings')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('user_settings')
            .update(payload)
            .eq('user_id', user.id);
        return;
      }

      await client.from('user_settings').insert(<String, dynamic>{
        'user_id': user.id,
        ...payload,
      });
    } on PostgrestException catch (error) {
      debugPrint('ThemeService sync skipped: ${error.message}');
    } catch (error) {
      debugPrint('ThemeService sync skipped: $error');
    }
  }

  String _formatDbTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  TimeOfDay _parseDbTime(dynamic rawValue, {required TimeOfDay fallback}) {
    if (rawValue is! String || rawValue.isEmpty) {
      return fallback;
    }

    final parts = rawValue.split(':');
    if (parts.length < 2) {
      return fallback;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return fallback;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}
