enum ThemeMode { system, light, dark }

enum DistanceUnit { miles, kilometers }

enum TemperatureUnit { fahrenheit, celsius }

enum DateFormat { mmddyyyy, ddmmyyyy, yyyymmdd }

enum TimeFormat { twelve, twentyfour }

enum NotificationSound { standard, subtle, off }

class UserSettings {
  // Display preferences
  final ThemeMode themeMode;
  final bool enableAnimations;
  final double textScale;
  final bool highContrastMode;
  final bool reduceMotion;
  final String language;
  final String region;

  // Units and formats
  final DistanceUnit distanceUnit;
  final TemperatureUnit temperatureUnit;
  final DateFormat dateFormat;
  final TimeFormat timeFormat;

  // Game defaults
  final String defaultSport;
  final int defaultGameDuration; // minutes
  final int defaultMaxPlayers;
  final bool defaultIsPublic;
  final bool defaultAllowWaitlist;
  final int defaultAdvanceNoticeHours;

  // Notification preferences
  final bool enablePushNotifications;
  final bool gameInviteNotifications;
  final bool gameReminderNotifications;
  final bool gameUpdateNotifications;
  final bool socialNotifications;
  final bool systemNotifications;
  final NotificationSound notificationSound;
  final bool vibrationEnabled;
  final int reminderMinutesBefore;

  // Map preferences
  final bool showTrafficLayer;
  final bool showSatelliteView;
  final double defaultMapZoom;
  final bool autoLocationDetection;

  // Performance preferences
  final bool enableDataSaver;
  final bool preloadImages;
  final bool backgroundRefresh;
  final int cacheSize; // MB

  // Accessibility
  final bool screenReaderEnabled;
  final bool voiceOverEnabled;
  final bool largeTextEnabled;
  final bool buttonShapesEnabled;

  const UserSettings({
    this.themeMode = ThemeMode.system,
    this.enableAnimations = true,
    this.textScale = 1.0,
    this.highContrastMode = false,
    this.reduceMotion = false,
    this.language = 'en',
    this.region = 'US',
    this.distanceUnit = DistanceUnit.miles,
    this.temperatureUnit = TemperatureUnit.fahrenheit,
    this.dateFormat = DateFormat.mmddyyyy,
    this.timeFormat = TimeFormat.twelve,
    this.defaultSport = '',
    this.defaultGameDuration = 60,
    this.defaultMaxPlayers = 10,
    this.defaultIsPublic = true,
    this.defaultAllowWaitlist = true,
    this.defaultAdvanceNoticeHours = 24,
    this.enablePushNotifications = true,
    this.gameInviteNotifications = true,
    this.gameReminderNotifications = true,
    this.gameUpdateNotifications = true,
    this.socialNotifications = true,
    this.systemNotifications = false,
    this.notificationSound = NotificationSound.standard,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 60,
    this.showTrafficLayer = false,
    this.showSatelliteView = false,
    this.defaultMapZoom = 14.0,
    this.autoLocationDetection = true,
    this.enableDataSaver = false,
    this.preloadImages = true,
    this.backgroundRefresh = true,
    this.cacheSize = 100,
    this.screenReaderEnabled = false,
    this.voiceOverEnabled = false,
    this.largeTextEnabled = false,
    this.buttonShapesEnabled = false,
  });

  /// Returns formatted distance string based on unit preference
  String formatDistance(double distance) {
    switch (distanceUnit) {
      case DistanceUnit.miles:
        if (distance < 1) {
          final feet = (distance * 5280).round();
          return '$feet ft';
        }
        return '${distance.toStringAsFixed(1)} mi';
      case DistanceUnit.kilometers:
        if (distance < 1) {
          final meters = (distance * 1000).round();
          return '$meters m';
        }
        return '${distance.toStringAsFixed(1)} km';
    }
  }

  /// Returns formatted temperature string based on unit preference
  String formatTemperature(double celsius) {
    switch (temperatureUnit) {
      case TemperatureUnit.celsius:
        return '${celsius.round()}°C';
      case TemperatureUnit.fahrenheit:
        final fahrenheit = (celsius * 9 / 5) + 32;
        return '${fahrenheit.round()}°F';
    }
  }

  /// Returns formatted date string based on format preference
  String formatDate(DateTime date) {
    switch (dateFormat) {
      case DateFormat.mmddyyyy:
        return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
      case DateFormat.ddmmyyyy:
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case DateFormat.yyyymmdd:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Returns formatted time string based on format preference
  String formatTime(DateTime time) {
    switch (timeFormat) {
      case TimeFormat.twelve:
        final hour12 = time.hour == 0
            ? 12
            : (time.hour > 12 ? time.hour - 12 : time.hour);
        final period = time.hour >= 12 ? 'PM' : 'AM';
        return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
      case TimeFormat.twentyfour:
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Checks if notifications are enabled for a specific type
  bool isNotificationEnabled(String type) {
    if (!enablePushNotifications) return false;

    switch (type) {
      case 'gameInvite':
        return gameInviteNotifications;
      case 'gameReminder':
        return gameReminderNotifications;
      case 'gameUpdate':
        return gameUpdateNotifications;
      case 'social':
        return socialNotifications;
      case 'system':
        return systemNotifications;
      default:
        return false;
    }
  }

  /// Returns optimal settings for data saver mode
  UserSettings getDataSaverSettings() {
    if (!enableDataSaver) return this;

    return copyWith(
      enableAnimations: false,
      preloadImages: false,
      backgroundRefresh: false,
      cacheSize: 50,
      showTrafficLayer: false,
    );
  }

  /// Returns accessibility-optimized settings
  UserSettings getAccessibilitySettings() {
    return copyWith(
      textScale: largeTextEnabled ? 1.3 : textScale,
      highContrastMode: true,
      reduceMotion: true,
      enableAnimations: !reduceMotion,
    );
  }

  /// Creates a copy with updated fields
  UserSettings copyWith({
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
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      textScale: textScale ?? this.textScale,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      language: language ?? this.language,
      region: region ?? this.region,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
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

  /// Creates UserSettings from JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.toString().split('.').last == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      enableAnimations: json['enableAnimations'] as bool? ?? true,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      highContrastMode: json['highContrastMode'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
      region: json['region'] as String? ?? 'US',
      distanceUnit: DistanceUnit.values.firstWhere(
        (e) => e.toString().split('.').last == json['distanceUnit'],
        orElse: () => DistanceUnit.miles,
      ),
      temperatureUnit: TemperatureUnit.values.firstWhere(
        (e) => e.toString().split('.').last == json['temperatureUnit'],
        orElse: () => TemperatureUnit.fahrenheit,
      ),
      dateFormat: DateFormat.values.firstWhere(
        (e) => e.toString().split('.').last == json['dateFormat'],
        orElse: () => DateFormat.mmddyyyy,
      ),
      timeFormat: TimeFormat.values.firstWhere(
        (e) => e.toString().split('.').last == json['timeFormat'],
        orElse: () => TimeFormat.twelve,
      ),
      defaultSport: json['defaultSport'] as String? ?? '',
      defaultGameDuration: json['defaultGameDuration'] as int? ?? 60,
      defaultMaxPlayers: json['defaultMaxPlayers'] as int? ?? 10,
      defaultIsPublic: json['defaultIsPublic'] as bool? ?? true,
      defaultAllowWaitlist: json['defaultAllowWaitlist'] as bool? ?? true,
      defaultAdvanceNoticeHours:
          json['defaultAdvanceNoticeHours'] as int? ?? 24,
      enablePushNotifications: json['enablePushNotifications'] as bool? ?? true,
      gameInviteNotifications: json['gameInviteNotifications'] as bool? ?? true,
      gameReminderNotifications:
          json['gameReminderNotifications'] as bool? ?? true,
      gameUpdateNotifications: json['gameUpdateNotifications'] as bool? ?? true,
      socialNotifications: json['socialNotifications'] as bool? ?? true,
      systemNotifications: json['systemNotifications'] as bool? ?? false,
      notificationSound: NotificationSound.values.firstWhere(
        (e) => e.toString().split('.').last == json['notificationSound'],
        orElse: () => NotificationSound.standard,
      ),
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 60,
      showTrafficLayer: json['showTrafficLayer'] as bool? ?? false,
      showSatelliteView: json['showSatelliteView'] as bool? ?? false,
      defaultMapZoom: (json['defaultMapZoom'] as num?)?.toDouble() ?? 14.0,
      autoLocationDetection: json['autoLocationDetection'] as bool? ?? true,
      enableDataSaver: json['enableDataSaver'] as bool? ?? false,
      preloadImages: json['preloadImages'] as bool? ?? true,
      backgroundRefresh: json['backgroundRefresh'] as bool? ?? true,
      cacheSize: json['cacheSize'] as int? ?? 100,
      screenReaderEnabled: json['screenReaderEnabled'] as bool? ?? false,
      voiceOverEnabled: json['voiceOverEnabled'] as bool? ?? false,
      largeTextEnabled: json['largeTextEnabled'] as bool? ?? false,
      buttonShapesEnabled: json['buttonShapesEnabled'] as bool? ?? false,
    );
  }

  /// Converts UserSettings to JSON
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.toString().split('.').last,
      'enableAnimations': enableAnimations,
      'textScale': textScale,
      'highContrastMode': highContrastMode,
      'reduceMotion': reduceMotion,
      'language': language,
      'region': region,
      'distanceUnit': distanceUnit.toString().split('.').last,
      'temperatureUnit': temperatureUnit.toString().split('.').last,
      'dateFormat': dateFormat.toString().split('.').last,
      'timeFormat': timeFormat.toString().split('.').last,
      'defaultSport': defaultSport,
      'defaultGameDuration': defaultGameDuration,
      'defaultMaxPlayers': defaultMaxPlayers,
      'defaultIsPublic': defaultIsPublic,
      'defaultAllowWaitlist': defaultAllowWaitlist,
      'defaultAdvanceNoticeHours': defaultAdvanceNoticeHours,
      'enablePushNotifications': enablePushNotifications,
      'gameInviteNotifications': gameInviteNotifications,
      'gameReminderNotifications': gameReminderNotifications,
      'gameUpdateNotifications': gameUpdateNotifications,
      'socialNotifications': socialNotifications,
      'systemNotifications': systemNotifications,
      'notificationSound': notificationSound.toString().split('.').last,
      'vibrationEnabled': vibrationEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'showTrafficLayer': showTrafficLayer,
      'showSatelliteView': showSatelliteView,
      'defaultMapZoom': defaultMapZoom,
      'autoLocationDetection': autoLocationDetection,
      'enableDataSaver': enableDataSaver,
      'preloadImages': preloadImages,
      'backgroundRefresh': backgroundRefresh,
      'cacheSize': cacheSize,
      'screenReaderEnabled': screenReaderEnabled,
      'voiceOverEnabled': voiceOverEnabled,
      'largeTextEnabled': largeTextEnabled,
      'buttonShapesEnabled': buttonShapesEnabled,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings &&
        other.themeMode == themeMode &&
        other.enableAnimations == enableAnimations &&
        other.textScale == textScale &&
        other.highContrastMode == highContrastMode &&
        other.reduceMotion == reduceMotion &&
        other.language == language &&
        other.region == region &&
        other.distanceUnit == distanceUnit &&
        other.temperatureUnit == temperatureUnit &&
        other.dateFormat == dateFormat &&
        other.timeFormat == timeFormat &&
        other.defaultSport == defaultSport &&
        other.defaultGameDuration == defaultGameDuration &&
        other.defaultMaxPlayers == defaultMaxPlayers &&
        other.defaultIsPublic == defaultIsPublic &&
        other.defaultAllowWaitlist == defaultAllowWaitlist &&
        other.defaultAdvanceNoticeHours == defaultAdvanceNoticeHours &&
        other.enablePushNotifications == enablePushNotifications &&
        other.gameInviteNotifications == gameInviteNotifications &&
        other.gameReminderNotifications == gameReminderNotifications &&
        other.gameUpdateNotifications == gameUpdateNotifications &&
        other.socialNotifications == socialNotifications &&
        other.systemNotifications == systemNotifications &&
        other.notificationSound == notificationSound &&
        other.vibrationEnabled == vibrationEnabled &&
        other.reminderMinutesBefore == reminderMinutesBefore &&
        other.showTrafficLayer == showTrafficLayer &&
        other.showSatelliteView == showSatelliteView &&
        other.defaultMapZoom == defaultMapZoom &&
        other.autoLocationDetection == autoLocationDetection &&
        other.enableDataSaver == enableDataSaver &&
        other.preloadImages == preloadImages &&
        other.backgroundRefresh == backgroundRefresh &&
        other.cacheSize == cacheSize &&
        other.screenReaderEnabled == screenReaderEnabled &&
        other.voiceOverEnabled == voiceOverEnabled &&
        other.largeTextEnabled == largeTextEnabled &&
        other.buttonShapesEnabled == buttonShapesEnabled;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      themeMode,
      enableAnimations,
      textScale,
      highContrastMode,
      reduceMotion,
      language,
      region,
      distanceUnit,
      temperatureUnit,
      dateFormat,
      timeFormat,
      defaultSport,
      defaultGameDuration,
      defaultMaxPlayers,
      defaultIsPublic,
      defaultAllowWaitlist,
      defaultAdvanceNoticeHours,
      enablePushNotifications,
      gameInviteNotifications,
      gameReminderNotifications,
      gameUpdateNotifications,
      socialNotifications,
      systemNotifications,
      notificationSound,
      vibrationEnabled,
      reminderMinutesBefore,
      showTrafficLayer,
      showSatelliteView,
      defaultMapZoom,
      autoLocationDetection,
      enableDataSaver,
      preloadImages,
      backgroundRefresh,
      cacheSize,
      screenReaderEnabled,
      voiceOverEnabled,
      largeTextEnabled,
      buttonShapesEnabled,
    ]);
  }
}
