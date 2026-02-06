import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/user_settings.dart';
import '../../domain/usecases/change_settings_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for settings management
class SettingsState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final UserSettings? settings;
  final Map<String, bool> categoryExpanded;
  final Map<String, dynamic> pendingChanges;
  final bool hasUnsavedChanges;
  final DateTime? lastSyncTime;

  const SettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.settings,
    this.categoryExpanded = const {},
    this.pendingChanges = const {},
    this.hasUnsavedChanges = false,
    this.lastSyncTime,
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    UserSettings? settings,
    Map<String, bool>? categoryExpanded,
    Map<String, dynamic>? pendingChanges,
    bool? hasUnsavedChanges,
    DateTime? lastSyncTime,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      settings: settings ?? this.settings,
      categoryExpanded: categoryExpanded ?? this.categoryExpanded,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Controller for user settings management with category organization
class SettingsController extends StateNotifier<SettingsState> {
  final ChangeSettingsUseCase? _changeSettingsUseCase;

  static const _categories = {
    'display': 'Display & Theme',
    'game_defaults': 'Game Defaults',
    'units': 'Units & Formats',
    'map': 'Map Preferences',
    'accessibility': 'Accessibility',
    'performance': 'Performance',
  };

  SettingsController({ChangeSettingsUseCase? changeSettingsUseCase})
    : _changeSettingsUseCase = changeSettingsUseCase,
      super(const SettingsState()) {
    _initializeCategories();
  }

  /// Initialize expanded state for all categories
  void _initializeCategories() {
    final expanded = <String, bool>{};
    for (final category in _categories.keys) {
      expanded[category] = false;
    }
    state = state.copyWith(categoryExpanded: expanded);
  }

  /// Load user settings
  Future<void> loadSettings(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Note: This would typically load from repository
      // For now, we'll create a basic settings object
      const settings = UserSettings(
        themeMode: ThemeMode.system,
        enableAnimations: true,
        textScale: 1.0,
        language: 'en',
        enablePushNotifications: true,
        gameInviteNotifications: true,
        gameReminderNotifications: true,
        gameUpdateNotifications: true,
        socialNotifications: true,
        systemNotifications: false,
        vibrationEnabled: true,
        enableDataSaver: false,
        backgroundRefresh: true,
      );

      state = state.copyWith(
        isLoading: false,
        settings: settings,
        lastSyncTime: DateTime.now(),
        pendingChanges: {},
        hasUnsavedChanges: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Toggle category expansion
  void toggleCategory(String category) {
    final updatedExpanded = Map<String, bool>.from(state.categoryExpanded);
    updatedExpanded[category] = !(updatedExpanded[category] ?? false);

    state = state.copyWith(categoryExpanded: updatedExpanded);
  }

  /// Expand all categories
  void expandAllCategories() {
    final updatedExpanded = <String, bool>{};
    for (final category in _categories.keys) {
      updatedExpanded[category] = true;
    }
    state = state.copyWith(categoryExpanded: updatedExpanded);
  }

  /// Collapse all categories
  void collapseAllCategories() {
    final updatedExpanded = <String, bool>{};
    for (final category in _categories.keys) {
      updatedExpanded[category] = false;
    }
    state = state.copyWith(categoryExpanded: updatedExpanded);
  }

  /// Update theme mode
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _updateField('themeMode', themeMode.toString().split('.').last);
  }

  /// Update language
  Future<void> updateLanguage(String languageCode) async {
    await _updateField('language', languageCode);
  }

  /// Update distance unit
  Future<void> updateDistanceUnit(DistanceUnit unit) async {
    await _updateField('distanceUnit', unit.toString().split('.').last);
  }

  /// Update temperature unit
  Future<void> updateTemperatureUnit(TemperatureUnit unit) async {
    await _updateField('temperatureUnit', unit.toString().split('.').last);
  }

  /// Update default game settings
  Future<void> updateGameDefault(String key, dynamic value) async {
    await _updateField(key, value);
  }

  /// Save all pending changes
  Future<bool> saveAllChanges() async {
    if (state.settings == null || !state.hasUnsavedChanges) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final params = ChangeSettingsParams(
        userId: 'current-user-id', // Would come from auth
        themeMode: state.pendingChanges['themeMode'] != null
            ? ThemeMode.values.firstWhere(
                (e) =>
                    e.toString().split('.').last ==
                    state.pendingChanges['themeMode'],
              )
            : null,
        language: state.pendingChanges['language'] as String?,
        enablePushNotifications:
            state.pendingChanges['enablePushNotifications'] as bool?,
        gameInviteNotifications:
            state.pendingChanges['gameInviteNotifications'] as bool?,
        enableDataSaver: state.pendingChanges['enableDataSaver'] as bool?,
      );

      if (_changeSettingsUseCase == null) {
        state = state.copyWith(isSaving: false, lastSyncTime: DateTime.now());
        return true;
      }

      final result = await _changeSettingsUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
          return false;
        },
        (changeResult) {
          state = state.copyWith(
            isSaving: false,
            settings: changeResult.updatedSettings,
            pendingChanges: {},
            hasUnsavedChanges: false,
            lastSyncTime: DateTime.now(),
          );

          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _getErrorMessage(error),
      );
      return false;
    }
  }

  /// Reset settings to defaults
  Future<void> resetAllSettings() async {
    const defaultSettings = UserSettings();

    final allChanges = {
      'themeMode': defaultSettings.themeMode.toString().split('.').last,
      'enableAnimations': defaultSettings.enableAnimations,
      'textScale': defaultSettings.textScale,
      'language': defaultSettings.language,
      'enablePushNotifications': defaultSettings.enablePushNotifications,
      'gameInviteNotifications': defaultSettings.gameInviteNotifications,
      'vibrationEnabled': defaultSettings.vibrationEnabled,
      'enableDataSaver': defaultSettings.enableDataSaver,
    };

    state = state.copyWith(
      settings: defaultSettings,
      pendingChanges: allChanges,
      hasUnsavedChanges: true,
    );
  }

  /// Get settings grouped by category
  Map<String, List<SettingItem>> get categorizedSettings {
    final settings = state.settings;
    if (settings == null) return {};

    return {
      'display': [
        SettingItem(
          key: 'themeMode',
          title: 'Theme',
          subtitle: 'Choose your preferred theme',
          value: settings.themeMode,
          type: SettingType.selection,
          options: ThemeMode.values
              .map((t) => t.toString().split('.').last)
              .toList(),
        ),
        SettingItem(
          key: 'enableAnimations',
          title: 'Animations',
          subtitle: 'Enable smooth animations',
          value: settings.enableAnimations,
          type: SettingType.boolean,
        ),
        SettingItem(
          key: 'textScale',
          title: 'Text Size',
          subtitle: 'Adjust text size for readability',
          value: settings.textScale,
          type: SettingType.number,
        ),
      ],
      'game_defaults': [
        SettingItem(
          key: 'defaultSport',
          title: 'Default Sport',
          subtitle: 'Your preferred sport for new games',
          value: settings.defaultSport,
          type: SettingType.text,
        ),
        SettingItem(
          key: 'defaultGameDuration',
          title: 'Game Duration',
          subtitle: 'Default game length in minutes',
          value: settings.defaultGameDuration,
          type: SettingType.number,
        ),
        SettingItem(
          key: 'defaultIsPublic',
          title: 'Public Games',
          subtitle: 'Make games public by default',
          value: settings.defaultIsPublic,
          type: SettingType.boolean,
        ),
      ],
      'units': [
        SettingItem(
          key: 'distanceUnit',
          title: 'Distance Unit',
          subtitle: 'Miles or kilometers',
          value: settings.distanceUnit,
          type: SettingType.selection,
          options: DistanceUnit.values
              .map((u) => u.toString().split('.').last)
              .toList(),
        ),
        SettingItem(
          key: 'temperatureUnit',
          title: 'Temperature Unit',
          subtitle: 'Fahrenheit or Celsius',
          value: settings.temperatureUnit,
          type: SettingType.selection,
          options: TemperatureUnit.values
              .map((u) => u.toString().split('.').last)
              .toList(),
        ),
      ],
      'performance': [
        SettingItem(
          key: 'enableDataSaver',
          title: 'Data Saver',
          subtitle: 'Reduce data usage',
          value: settings.enableDataSaver,
          type: SettingType.boolean,
        ),
        SettingItem(
          key: 'backgroundRefresh',
          title: 'Background Refresh',
          subtitle: 'Allow background data updates',
          value: settings.backgroundRefresh,
          type: SettingType.boolean,
        ),
      ],
    };
  }

  /// Get category display name
  String getCategoryName(String category) => _categories[category] ?? category;

  /// Check if category is expanded
  bool isCategoryExpanded(String category) =>
      state.categoryExpanded[category] ?? false;

  /// Get setting change count
  int get pendingChangeCount => state.pendingChanges.length;

  /// Update a single field
  Future<void> _updateField(String field, dynamic value) async {
    final currentSettings = state.settings;
    if (currentSettings == null) return;

    final updatedPendingChanges = Map<String, dynamic>.from(
      state.pendingChanges,
    );
    updatedPendingChanges[field] = value;

    // Apply change immediately for UI update
    UserSettings updatedSettings = currentSettings;

    switch (field) {
      case 'themeMode':
        final theme = ThemeMode.values.firstWhere(
          (e) => e.toString().split('.').last == value,
          orElse: () => ThemeMode.system,
        );
        updatedSettings = updatedSettings.copyWith(themeMode: theme);
        break;
      case 'enableAnimations':
        updatedSettings = updatedSettings.copyWith(
          enableAnimations: value as bool,
        );
        break;
      case 'enablePushNotifications':
        updatedSettings = updatedSettings.copyWith(
          enablePushNotifications: value as bool,
        );
        break;
      case 'gameInviteNotifications':
        updatedSettings = updatedSettings.copyWith(
          gameInviteNotifications: value as bool,
        );
        break;
      case 'vibrationEnabled':
        updatedSettings = updatedSettings.copyWith(
          vibrationEnabled: value as bool,
        );
        break;
      case 'language':
        updatedSettings = updatedSettings.copyWith(language: value as String);
        break;
      case 'enableDataSaver':
        updatedSettings = updatedSettings.copyWith(
          enableDataSaver: value as bool,
        );
        break;
      // Add other fields as needed
    }

    state = state.copyWith(
      settings: updatedSettings,
      pendingChanges: updatedPendingChanges,
      hasUnsavedChanges: true,
    );
  }

  /// Convert error to user-friendly message
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  /// Convert failure to user-friendly message
  String _getFailureMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ValidationFailure:
        return failure.message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case ServerFailure:
        return 'Server error. Please try again later.';
      default:
        return failure.message;
    }
  }
}

/// Represents a setting item for UI display
class SettingItem {
  final String key;
  final String title;
  final String subtitle;
  final dynamic value;
  final SettingType type;
  final List<String>? options;

  const SettingItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.type,
    this.options,
  });
}

/// Types of settings for UI rendering
enum SettingType { boolean, selection, text, number }
