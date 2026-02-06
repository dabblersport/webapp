import 'package:dabbler/data/models/profile/user_settings.dart';

class UserSettingsModel extends UserSettings {
  const UserSettingsModel({
    super.themeMode,
    super.enableAnimations,
    super.textScale,
    super.highContrastMode,
    super.reduceMotion,
    super.language,
    super.region,
    super.distanceUnit,
    super.temperatureUnit,
    super.dateFormat,
    super.timeFormat,
    super.defaultSport,
    super.defaultGameDuration,
    super.defaultMaxPlayers,
    super.defaultIsPublic,
    super.defaultAllowWaitlist,
    super.defaultAdvanceNoticeHours,
    super.enablePushNotifications,
    super.gameInviteNotifications,
    super.gameReminderNotifications,
    super.gameUpdateNotifications,
    super.socialNotifications,
    super.systemNotifications,
    super.notificationSound,
    super.vibrationEnabled,
    super.reminderMinutesBefore,
    super.showTrafficLayer,
    super.showSatelliteView,
    super.defaultMapZoom,
    super.autoLocationDetection,
    super.enableDataSaver,
    super.preloadImages,
    super.backgroundRefresh,
    super.cacheSize,
    super.screenReaderEnabled,
    super.voiceOverEnabled,
    super.largeTextEnabled,
    super.buttonShapesEnabled,
  });

  /// Creates UserSettingsModel from domain entity
  factory UserSettingsModel.fromEntity(UserSettings entity) {
    return UserSettingsModel(
      themeMode: entity.themeMode,
      enableAnimations: entity.enableAnimations,
      textScale: entity.textScale,
      highContrastMode: entity.highContrastMode,
      reduceMotion: entity.reduceMotion,
      language: entity.language,
      region: entity.region,
      distanceUnit: entity.distanceUnit,
      temperatureUnit: entity.temperatureUnit,
      timeFormat: entity.timeFormat,
      dateFormat: entity.dateFormat,
      defaultSport: entity.defaultSport,
      defaultGameDuration: entity.defaultGameDuration,
      defaultMaxPlayers: entity.defaultMaxPlayers,
      defaultIsPublic: entity.defaultIsPublic,
      defaultAllowWaitlist: entity.defaultAllowWaitlist,
      defaultAdvanceNoticeHours: entity.defaultAdvanceNoticeHours,
      enablePushNotifications: entity.enablePushNotifications,
      gameInviteNotifications: entity.gameInviteNotifications,
      gameReminderNotifications: entity.gameReminderNotifications,
      gameUpdateNotifications: entity.gameUpdateNotifications,
      socialNotifications: entity.socialNotifications,
      systemNotifications: entity.systemNotifications,
      notificationSound: entity.notificationSound,
      vibrationEnabled: entity.vibrationEnabled,
      reminderMinutesBefore: entity.reminderMinutesBefore,
      showTrafficLayer: entity.showTrafficLayer,
      showSatelliteView: entity.showSatelliteView,
      defaultMapZoom: entity.defaultMapZoom,
      autoLocationDetection: entity.autoLocationDetection,
      enableDataSaver: entity.enableDataSaver,
      preloadImages: entity.preloadImages,
      backgroundRefresh: entity.backgroundRefresh,
      cacheSize: entity.cacheSize,
      screenReaderEnabled: entity.screenReaderEnabled,
      voiceOverEnabled: entity.voiceOverEnabled,
      largeTextEnabled: entity.largeTextEnabled,
      buttonShapesEnabled: entity.buttonShapesEnabled,
    );
  }

  /// Creates UserSettingsModel from JSON (Supabase response)
  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      themeMode: _parseThemeMode(json['theme_mode']),
      enableAnimations: _parseBoolWithDefault(json['enable_animations'], true),
      textScale: _parseDoubleWithDefault(json['text_scale'], 1.0),
      highContrastMode: _parseBoolWithDefault(
        json['high_contrast_mode'],
        false,
      ),
      reduceMotion: _parseBoolWithDefault(json['reduce_motion'], false),
      language: json['language'] as String? ?? 'en',
      region: json['region'] as String? ?? 'US',
      distanceUnit: _parseDistanceUnit(json['distance_unit']),
      temperatureUnit: _parseTemperatureUnit(json['temperature_unit']),
      timeFormat: _parseTimeFormat(json['time_format']),
      dateFormat: _parseDateFormat(json['date_format']),
      defaultSport: json['default_sport'] as String? ?? '',
      defaultGameDuration: _parseIntWithDefault(
        json['default_game_duration'],
        60,
      ),
      defaultMaxPlayers: _parseIntWithDefault(json['default_max_players'], 10),
      defaultIsPublic: _parseBoolWithDefault(json['default_is_public'], true),
      defaultAllowWaitlist: _parseBoolWithDefault(
        json['default_allow_waitlist'],
        true,
      ),
      defaultAdvanceNoticeHours: _parseIntWithDefault(
        json['default_advance_notice_hours'],
        24,
      ),
      enablePushNotifications: _parseBoolWithDefault(
        json['enable_push_notifications'],
        true,
      ),
      gameInviteNotifications: _parseBoolWithDefault(
        json['game_invite_notifications'],
        true,
      ),
      gameReminderNotifications: _parseBoolWithDefault(
        json['game_reminder_notifications'],
        true,
      ),
      gameUpdateNotifications: _parseBoolWithDefault(
        json['game_update_notifications'],
        true,
      ),
      socialNotifications: _parseBoolWithDefault(
        json['social_notifications'],
        true,
      ),
      systemNotifications: _parseBoolWithDefault(
        json['system_notifications'],
        false,
      ),
      notificationSound: _parseNotificationSound(json['notification_sound']),
      vibrationEnabled: _parseBoolWithDefault(json['vibration_enabled'], true),
      reminderMinutesBefore: _parseIntWithDefault(
        json['reminder_minutes_before'],
        60,
      ),
      showTrafficLayer: _parseBoolWithDefault(
        json['show_traffic_layer'],
        false,
      ),
      showSatelliteView: _parseBoolWithDefault(
        json['show_satellite_view'],
        false,
      ),
      defaultMapZoom: _parseDoubleWithDefault(json['default_map_zoom'], 14.0),
      autoLocationDetection: _parseBoolWithDefault(
        json['auto_location_detection'],
        true,
      ),
      enableDataSaver: _parseBoolWithDefault(json['enable_data_saver'], false),
      preloadImages: _parseBoolWithDefault(json['preload_images'], true),
      backgroundRefresh: _parseBoolWithDefault(
        json['background_refresh'],
        true,
      ),
      cacheSize: _parseIntWithDefault(json['cache_size'], 100),
      screenReaderEnabled: _parseBoolWithDefault(
        json['screen_reader_enabled'],
        false,
      ),
      voiceOverEnabled: _parseBoolWithDefault(
        json['voice_over_enabled'],
        false,
      ),
      largeTextEnabled: _parseBoolWithDefault(
        json['large_text_enabled'],
        false,
      ),
      buttonShapesEnabled: _parseBoolWithDefault(
        json['button_shapes_enabled'],
        false,
      ),
    );
  }

  /// Creates UserSettingsModel from device/system settings
  factory UserSettingsModel.fromSystemDefaults({
    String? deviceLanguage,
    bool? systemDarkMode,
    String? systemRegion,
  }) {
    return UserSettingsModel(
      language: deviceLanguage ?? 'en',
      themeMode: systemDarkMode == true ? ThemeMode.dark : ThemeMode.light,
      region: systemRegion ?? 'US',
      // Other settings use defaults from domain entity
    );
  }

  /// Creates UserSettingsModel with accessibility optimizations
  factory UserSettingsModel.forAccessibility({
    bool highContrast = true,
    bool largeText = true,
    bool reduceMotion = true,
    bool screenReader = false,
  }) {
    return UserSettingsModel(
      highContrastMode: highContrast,
      largeTextEnabled: largeText,
      reduceMotion: reduceMotion,
      screenReaderEnabled: screenReader,
      textScale: largeText ? 1.3 : 1.0,
      enableAnimations: !reduceMotion,
    );
  }

  /// Converts UserSettingsModel to JSON for API requests
  @override
  Map<String, dynamic> toJson() {
    return {
      'theme_mode': themeMode.name,
      'enable_animations': enableAnimations,
      'text_scale': textScale,
      'high_contrast_mode': highContrastMode,
      'reduce_motion': reduceMotion,
      'language': language,
      'region': region,
      'distance_unit': distanceUnit.name,
      'temperature_unit': temperatureUnit.name,
      'time_format': timeFormat.name,
      'date_format': dateFormat.name,
      'default_sport': defaultSport,
      'default_game_duration': defaultGameDuration,
      'default_max_players': defaultMaxPlayers,
      'default_is_public': defaultIsPublic,
      'default_allow_waitlist': defaultAllowWaitlist,
      'default_advance_notice_hours': defaultAdvanceNoticeHours,
      'enable_push_notifications': enablePushNotifications,
      'game_invite_notifications': gameInviteNotifications,
      'game_reminder_notifications': gameReminderNotifications,
      'game_update_notifications': gameUpdateNotifications,
      'social_notifications': socialNotifications,
      'system_notifications': systemNotifications,
      'notification_sound': notificationSound.name,
      'vibration_enabled': vibrationEnabled,
      'reminder_minutes_before': reminderMinutesBefore,
      'show_traffic_layer': showTrafficLayer,
      'show_satellite_view': showSatelliteView,
      'default_map_zoom': defaultMapZoom,
      'auto_location_detection': autoLocationDetection,
      'enable_data_saver': enableDataSaver,
      'preload_images': preloadImages,
      'background_refresh': backgroundRefresh,
      'cache_size': cacheSize,
      'screen_reader_enabled': screenReaderEnabled,
      'voice_over_enabled': voiceOverEnabled,
      'large_text_enabled': largeTextEnabled,
      'button_shapes_enabled': buttonShapesEnabled,
    };
  }

  /// Converts to JSON with string enum values (for external APIs)
  Map<String, dynamic> toExternalJson() {
    return {
      'theme_mode': themeMode.name,
      'enable_animations': enableAnimations,
      'text_scale': textScale,
      'high_contrast_mode': highContrastMode,
      'reduce_motion': reduceMotion,
      'language': language,
      'region': region,
      'distance_unit': distanceUnit.name,
      'temperature_unit': temperatureUnit.name,
      'time_format': timeFormat.name,
      'date_format': dateFormat.name,
      'default_sport': defaultSport,
      'default_game_duration': defaultGameDuration,
      'default_max_players': defaultMaxPlayers,
      'default_is_public': defaultIsPublic,
      'default_allow_waitlist': defaultAllowWaitlist,
      'default_advance_notice_hours': defaultAdvanceNoticeHours,
      'enable_push_notifications': enablePushNotifications,
      'game_invite_notifications': gameInviteNotifications,
      'game_reminder_notifications': gameReminderNotifications,
      'game_update_notifications': gameUpdateNotifications,
      'social_notifications': socialNotifications,
      'system_notifications': systemNotifications,
      'notification_sound': notificationSound.name,
      'vibration_enabled': vibrationEnabled,
      'reminder_minutes_before': reminderMinutesBefore,
      'show_traffic_layer': showTrafficLayer,
      'show_satellite_view': showSatelliteView,
      'default_map_zoom': defaultMapZoom,
      'auto_location_detection': autoLocationDetection,
      'enable_data_saver': enableDataSaver,
      'preload_images': preloadImages,
      'background_refresh': backgroundRefresh,
      'cache_size': cacheSize,
      'screen_reader_enabled': screenReaderEnabled,
      'voice_over_enabled': voiceOverEnabled,
      'large_text_enabled': largeTextEnabled,
      'button_shapes_enabled': buttonShapesEnabled,
    };
  }

  /// Converts to JSON for database updates
  Map<String, dynamic> toUpdateJson() {
    return {
      'theme_mode': themeMode.name,
      'enable_animations': enableAnimations,
      'text_scale': textScale,
      'high_contrast_mode': highContrastMode,
      'reduce_motion': reduceMotion,
      'language': language,
      'region': region,
      'distance_unit': distanceUnit.name,
      'temperature_unit': temperatureUnit.name,
      'time_format': timeFormat.name,
      'date_format': dateFormat.name,
      'default_sport': defaultSport,
      'default_game_duration': defaultGameDuration,
      'default_max_players': defaultMaxPlayers,
      'default_is_public': defaultIsPublic,
      'default_allow_waitlist': defaultAllowWaitlist,
      'default_advance_notice_hours': defaultAdvanceNoticeHours,
      'enable_push_notifications': enablePushNotifications,
      'game_invite_notifications': gameInviteNotifications,
      'game_reminder_notifications': gameReminderNotifications,
      'game_update_notifications': gameUpdateNotifications,
      'social_notifications': socialNotifications,
      'system_notifications': systemNotifications,
      'notification_sound': notificationSound.name,
      'vibration_enabled': vibrationEnabled,
      'reminder_minutes_before': reminderMinutesBefore,
      'show_traffic_layer': showTrafficLayer,
      'show_satellite_view': showSatelliteView,
      'default_map_zoom': defaultMapZoom,
      'auto_location_detection': autoLocationDetection,
      'enable_data_saver': enableDataSaver,
      'preload_images': preloadImages,
      'background_refresh': backgroundRefresh,
      'cache_size': cacheSize,
      'screen_reader_enabled': screenReaderEnabled,
      'voice_over_enabled': voiceOverEnabled,
      'large_text_enabled': largeTextEnabled,
      'button_shapes_enabled': buttonShapesEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Returns settings grouped by category for UI
  Map<String, Map<String, dynamic>> getSettingsByCategory() {
    return {
      'Appearance': {
        'theme_mode': themeMode.name,
        'text_scale': textScale,
        'high_contrast_mode': highContrastMode,
        'large_text_enabled': largeTextEnabled,
        'reduce_motion': reduceMotion,
        'enable_animations': enableAnimations,
      },
      'Language & Region': {
        'language': language,
        'region': region,
        'distance_unit': distanceUnit.name,
        'temperature_unit': temperatureUnit.name,
        'time_format': timeFormat.name,
        'date_format': dateFormat.name,
      },
      'Notifications': {
        'enable_push_notifications': enablePushNotifications,
        'game_invite_notifications': gameInviteNotifications,
        'game_reminder_notifications': gameReminderNotifications,
        'game_update_notifications': gameUpdateNotifications,
        'social_notifications': socialNotifications,
        'system_notifications': systemNotifications,
        'notification_sound': notificationSound.name,
        'vibration_enabled': vibrationEnabled,
        'reminder_minutes_before': reminderMinutesBefore,
      },
      'Game Defaults': {
        'default_sport': defaultSport,
        'default_game_duration': defaultGameDuration,
        'default_max_players': defaultMaxPlayers,
        'default_is_public': defaultIsPublic,
        'default_allow_waitlist': defaultAllowWaitlist,
        'default_advance_notice_hours': defaultAdvanceNoticeHours,
      },
      'Map & Location': {
        'show_traffic_layer': showTrafficLayer,
        'show_satellite_view': showSatelliteView,
        'default_map_zoom': defaultMapZoom,
        'auto_location_detection': autoLocationDetection,
      },
      'Performance': {
        'enable_data_saver': enableDataSaver,
        'preload_images': preloadImages,
        'background_refresh': backgroundRefresh,
        'cache_size': cacheSize,
      },
      'Accessibility': {
        'screen_reader_enabled': screenReaderEnabled,
        'voice_over_enabled': voiceOverEnabled,
        'large_text_enabled': largeTextEnabled,
        'button_shapes_enabled': buttonShapesEnabled,
        'high_contrast_mode': highContrastMode,
        'reduce_motion': reduceMotion,
      },
    };
  }

  // Helper parsing methods

  static ThemeMode _parseThemeMode(dynamic value) {
    if (value == null) return ThemeMode.system;
    if (value is int) {
      if (value >= 0 && value < ThemeMode.values.length) {
        return ThemeMode.values[value];
      }
    }
    if (value is String) {
      for (final theme in ThemeMode.values) {
        if (theme.name.toLowerCase() == value.toLowerCase()) {
          return theme;
        }
      }
    }
    return ThemeMode.system;
  }

  static DistanceUnit _parseDistanceUnit(dynamic value) {
    if (value == null) return DistanceUnit.miles;
    if (value is int) {
      if (value >= 0 && value < DistanceUnit.values.length) {
        return DistanceUnit.values[value];
      }
    }
    if (value is String) {
      for (final unit in DistanceUnit.values) {
        if (unit.name.toLowerCase() == value.toLowerCase()) {
          return unit;
        }
      }
    }
    return DistanceUnit.miles;
  }

  static TemperatureUnit _parseTemperatureUnit(dynamic value) {
    if (value == null) return TemperatureUnit.fahrenheit;
    if (value is int) {
      if (value >= 0 && value < TemperatureUnit.values.length) {
        return TemperatureUnit.values[value];
      }
    }
    if (value is String) {
      for (final unit in TemperatureUnit.values) {
        if (unit.name.toLowerCase() == value.toLowerCase()) {
          return unit;
        }
      }
    }
    return TemperatureUnit.fahrenheit;
  }

  static TimeFormat _parseTimeFormat(dynamic value) {
    if (value == null) return TimeFormat.twelve;
    if (value is int) {
      if (value >= 0 && value < TimeFormat.values.length) {
        return TimeFormat.values[value];
      }
    }
    if (value is String) {
      for (final format in TimeFormat.values) {
        if (format.name.toLowerCase() == value.toLowerCase()) {
          return format;
        }
      }
    }
    return TimeFormat.twelve;
  }

  static DateFormat _parseDateFormat(dynamic value) {
    if (value == null) return DateFormat.mmddyyyy;
    if (value is int) {
      if (value >= 0 && value < DateFormat.values.length) {
        return DateFormat.values[value];
      }
    }
    if (value is String) {
      for (final format in DateFormat.values) {
        if (format.name.toLowerCase() == value.toLowerCase()) {
          return format;
        }
      }
    }
    return DateFormat.mmddyyyy;
  }

  static NotificationSound _parseNotificationSound(dynamic value) {
    if (value == null) return NotificationSound.standard;
    if (value is int) {
      if (value >= 0 && value < NotificationSound.values.length) {
        return NotificationSound.values[value];
      }
    }
    if (value is String) {
      for (final sound in NotificationSound.values) {
        if (sound.name.toLowerCase() == value.toLowerCase()) {
          return sound;
        }
      }
    }
    return NotificationSound.standard;
  }

  static bool _parseBoolWithDefault(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
  }

  static int _parseIntWithDefault(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _parseDoubleWithDefault(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Creates a copy with updated fields
  @override
  UserSettingsModel copyWith({
    ThemeMode? themeMode,
    bool? enableAnimations,
    double? textScale,
    bool? highContrastMode,
    bool? reduceMotion,
    String? language,
    String? region,
    DistanceUnit? distanceUnit,
    TemperatureUnit? temperatureUnit,
    DateFormat? dateFormat,
    TimeFormat? timeFormat,
    String? defaultSport,
    int? defaultGameDuration,
    int? defaultMaxPlayers,
    bool? defaultIsPublic,
    bool? defaultAllowWaitlist,
    int? defaultAdvanceNoticeHours,
    bool? enablePushNotifications,
    bool? gameInviteNotifications,
    bool? gameReminderNotifications,
    bool? gameUpdateNotifications,
    bool? socialNotifications,
    bool? systemNotifications,
    NotificationSound? notificationSound,
    bool? vibrationEnabled,
    int? reminderMinutesBefore,
    bool? showTrafficLayer,
    bool? showSatelliteView,
    double? defaultMapZoom,
    bool? autoLocationDetection,
    bool? enableDataSaver,
    bool? preloadImages,
    bool? backgroundRefresh,
    int? cacheSize,
    bool? screenReaderEnabled,
    bool? voiceOverEnabled,
    bool? largeTextEnabled,
    bool? buttonShapesEnabled,
  }) {
    return UserSettingsModel(
      themeMode: themeMode ?? this.themeMode,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      textScale: textScale ?? this.textScale,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      language: language ?? this.language,
      region: region ?? this.region,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultSport: defaultSport ?? this.defaultSport,
      defaultGameDuration: defaultGameDuration ?? this.defaultGameDuration,
      defaultMaxPlayers: defaultMaxPlayers ?? this.defaultMaxPlayers,
      defaultIsPublic: defaultIsPublic ?? this.defaultIsPublic,
      defaultAllowWaitlist: defaultAllowWaitlist ?? this.defaultAllowWaitlist,
      defaultAdvanceNoticeHours:
          defaultAdvanceNoticeHours ?? this.defaultAdvanceNoticeHours,
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      gameInviteNotifications:
          gameInviteNotifications ?? this.gameInviteNotifications,
      gameReminderNotifications:
          gameReminderNotifications ?? this.gameReminderNotifications,
      gameUpdateNotifications:
          gameUpdateNotifications ?? this.gameUpdateNotifications,
      socialNotifications: socialNotifications ?? this.socialNotifications,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      notificationSound: notificationSound ?? this.notificationSound,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      showTrafficLayer: showTrafficLayer ?? this.showTrafficLayer,
      showSatelliteView: showSatelliteView ?? this.showSatelliteView,
      defaultMapZoom: defaultMapZoom ?? this.defaultMapZoom,
      autoLocationDetection:
          autoLocationDetection ?? this.autoLocationDetection,
      enableDataSaver: enableDataSaver ?? this.enableDataSaver,
      preloadImages: preloadImages ?? this.preloadImages,
      backgroundRefresh: backgroundRefresh ?? this.backgroundRefresh,
      cacheSize: cacheSize ?? this.cacheSize,
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
      voiceOverEnabled: voiceOverEnabled ?? this.voiceOverEnabled,
      largeTextEnabled: largeTextEnabled ?? this.largeTextEnabled,
      buttonShapesEnabled: buttonShapesEnabled ?? this.buttonShapesEnabled,
    );
  }

  /// Converts back to domain entity
  UserSettings toEntity() {
    return UserSettings(
      themeMode: themeMode,
      enableAnimations: enableAnimations,
      textScale: textScale,
      highContrastMode: highContrastMode,
      reduceMotion: reduceMotion,
      language: language,
      region: region,
      distanceUnit: distanceUnit,
      temperatureUnit: temperatureUnit,
      timeFormat: timeFormat,
      dateFormat: dateFormat,
      defaultSport: defaultSport,
      defaultGameDuration: defaultGameDuration,
      defaultMaxPlayers: defaultMaxPlayers,
      defaultIsPublic: defaultIsPublic,
      defaultAllowWaitlist: defaultAllowWaitlist,
      defaultAdvanceNoticeHours: defaultAdvanceNoticeHours,
      enablePushNotifications: enablePushNotifications,
      gameInviteNotifications: gameInviteNotifications,
      gameReminderNotifications: gameReminderNotifications,
      gameUpdateNotifications: gameUpdateNotifications,
      socialNotifications: socialNotifications,
      systemNotifications: systemNotifications,
      notificationSound: notificationSound,
      vibrationEnabled: vibrationEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
      showTrafficLayer: showTrafficLayer,
      showSatelliteView: showSatelliteView,
      defaultMapZoom: defaultMapZoom,
      autoLocationDetection: autoLocationDetection,
      enableDataSaver: enableDataSaver,
      preloadImages: preloadImages,
      backgroundRefresh: backgroundRefresh,
      cacheSize: cacheSize,
      screenReaderEnabled: screenReaderEnabled,
      voiceOverEnabled: voiceOverEnabled,
      largeTextEnabled: largeTextEnabled,
      buttonShapesEnabled: buttonShapesEnabled,
    );
  }
}
