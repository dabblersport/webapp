import 'package:dabbler/data/models/games/sport_config.dart';

class SportConfigModel extends SportConfig {
  final SportType type;

  const SportConfigModel({
    required this.type,
    required super.id,
    required super.name,
    required super.code,
    required super.iconUrl,
    required super.minPlayers,
    required super.maxPlayers,
    required super.defaultDuration,
    required super.requiresVenue,
    required super.isTeamSport,
    super.isIndoorSport,
    super.isOutdoorSport,
    super.requiredEquipment,
    super.optionalEquipment,
    super.rulesDescription,
    super.availableSkillLevels,
    super.scoringSystem,
    super.maxScore,
    super.hasTimeLimit,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SportConfigModel.fromJson(Map<String, dynamic> json) {
    return SportConfigModel(
      type: _parseSportType(json['type'] ?? json['sport_type']),
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      iconUrl: json['icon_url'] as String,
      minPlayers: json['min_players'] as int,
      maxPlayers: json['max_players'] as int,
      defaultDuration: json['default_duration'] as int,
      requiresVenue: json['requires_venue'] as bool? ?? true,
      isTeamSport: json['is_team_sport'] as bool? ?? false,
      isIndoorSport: json['is_indoor_sport'] as bool? ?? false,
      isOutdoorSport: json['is_outdoor_sport'] as bool? ?? true,
      requiredEquipment: _parseStringList(json['required_equipment']) ?? [],
      optionalEquipment: _parseStringList(json['optional_equipment']) ?? [],
      rulesDescription: json['rules_description'] as String?,
      availableSkillLevels:
          _parseStringList(json['available_skill_levels']) ??
          ['beginner', 'intermediate', 'advanced', 'mixed'],
      scoringSystem: json['scoring_system'] as String?,
      maxScore: json['max_score'] as int?,
      hasTimeLimit: json['has_time_limit'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static SportType _parseSportType(dynamic typeData) {
    if (typeData == null) return SportType.football;

    if (typeData is String) {
      try {
        return SportType.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              typeData.toLowerCase(),
          orElse: () => SportType.football,
        );
      } catch (e) {
        return SportType.football;
      }
    }

    return SportType.football;
  }

  static List<String>? _parseStringList(dynamic listData) {
    if (listData == null) return null;

    if (listData is List) {
      return listData.map((item) => item.toString()).toList();
    }

    if (listData is String) {
      if (listData.contains(',')) {
        return listData.split(',').map((s) => s.trim()).toList();
      }
      return [listData];
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'name': name,
      'code': code,
      'icon_url': iconUrl,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'default_duration': defaultDuration,
      'requires_venue': requiresVenue,
      'is_team_sport': isTeamSport,
      'is_indoor_sport': isIndoorSport,
      'is_outdoor_sport': isOutdoorSport,
      'required_equipment': requiredEquipment,
      'optional_equipment': optionalEquipment,
      'rules_description': rulesDescription,
      'available_skill_levels': availableSkillLevels,
      'scoring_system': scoringSystem,
      'max_score': maxScore,
      'has_time_limit': hasTimeLimit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Factory methods for common sports
  factory SportConfigModel.football() {
    final now = DateTime.now();
    return SportConfigModel(
      type: SportType.football,
      id: 'football',
      name: 'Football',
      code: 'FOOTBALL',
      iconUrl: '⚽',
      minPlayers: 2,
      maxPlayers: 22,
      defaultDuration: 90,
      requiresVenue: true,
      isTeamSport: true,
      isIndoorSport: false,
      isOutdoorSport: true,
      requiredEquipment: ['Football', 'Proper footwear'],
      optionalEquipment: ['Shin guards', 'Goalkeeper gloves'],
      rulesDescription: 'The beautiful game played with feet',
      availableSkillLevels: ['beginner', 'intermediate', 'advanced', 'mixed'],
      scoringSystem: 'goals',
      hasTimeLimit: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SportConfigModel.basketball() {
    final now = DateTime.now();
    return SportConfigModel(
      type: SportType.basketball,
      id: 'basketball',
      name: 'Basketball',
      code: 'BASKETBALL',
      iconUrl: '🏀',
      minPlayers: 2,
      maxPlayers: 10,
      defaultDuration: 48,
      requiresVenue: true,
      isTeamSport: true,
      isIndoorSport: true,
      isOutdoorSport: true,
      requiredEquipment: ['Basketball', 'Athletic shoes'],
      optionalEquipment: ['Knee pads', 'Shooting sleeves'],
      rulesDescription: 'Fast-paced sport with hoops',
      availableSkillLevels: ['beginner', 'intermediate', 'advanced', 'mixed'],
      scoringSystem: 'points',
      hasTimeLimit: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SportConfigModel.tennis() {
    final now = DateTime.now();
    return SportConfigModel(
      type: SportType.tennis,
      id: 'tennis',
      name: 'Tennis',
      code: 'TENNIS',
      iconUrl: '🎾',
      minPlayers: 2,
      maxPlayers: 4,
      defaultDuration: 180,
      requiresVenue: true,
      isTeamSport: false,
      isIndoorSport: true,
      isOutdoorSport: true,
      requiredEquipment: ['Tennis racket', 'Tennis balls', 'Proper shoes'],
      optionalEquipment: ['Wristbands', 'Headband'],
      rulesDescription: 'Racket sport played on court',
      availableSkillLevels: ['beginner', 'intermediate', 'advanced', 'mixed'],
      scoringSystem: 'sets',
      hasTimeLimit: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SportConfigModel.badminton() {
    final now = DateTime.now();
    return SportConfigModel(
      type: SportType.badminton,
      id: 'badminton',
      name: 'Badminton',
      code: 'BADMINTON',
      iconUrl: '🏸',
      minPlayers: 2,
      maxPlayers: 4,
      defaultDuration: 60,
      requiresVenue: true,
      isTeamSport: false,
      isIndoorSport: true,
      isOutdoorSport: false,
      requiredEquipment: ['Badminton racket', 'Shuttlecock'],
      optionalEquipment: ['Wristbands'],
      rulesDescription: 'Racket sport with shuttlecock',
      availableSkillLevels: ['beginner', 'intermediate', 'advanced', 'mixed'],
      scoringSystem: 'points',
      hasTimeLimit: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Create from SportType
  factory SportConfigModel.fromSportType(SportType sportType) {
    switch (sportType) {
      case SportType.football:
        return SportConfigModel.football();
      case SportType.basketball:
        return SportConfigModel.basketball();
      case SportType.tennis:
        return SportConfigModel.tennis();
      case SportType.badminton:
        return SportConfigModel.badminton();
      case SportType.volleyball:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.volleyball,
          id: 'volleyball',
          name: 'Volleyball',
          code: 'VOLLEYBALL',
          iconUrl: '🏐',
          minPlayers: 6,
          maxPlayers: 12,
          defaultDuration: 90,
          requiresVenue: true,
          isTeamSport: true,
          isIndoorSport: true,
          isOutdoorSport: true,
          requiredEquipment: ['Volleyball'],
          scoringSystem: 'points',
          createdAt: now,
          updatedAt: now,
        );
      case SportType.tabletennis:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.tabletennis,
          id: 'tabletennis',
          name: 'Table Tennis',
          code: 'TABLETENNIS',
          iconUrl: '🏓',
          minPlayers: 2,
          maxPlayers: 4,
          defaultDuration: 45,
          requiresVenue: true,
          isTeamSport: false,
          isIndoorSport: true,
          isOutdoorSport: false,
          requiredEquipment: ['Padel', 'Table tennis balls'],
          scoringSystem: 'points',
          createdAt: now,
          updatedAt: now,
        );
      case SportType.cricket:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.cricket,
          id: 'cricket',
          name: 'Cricket',
          code: 'CRICKET',
          iconUrl: '🏏',
          minPlayers: 2,
          maxPlayers: 22,
          defaultDuration: 480,
          requiresVenue: true,
          isTeamSport: true,
          isOutdoorSport: true,
          requiredEquipment: ['Cricket bat', 'Cricket ball', 'Wickets'],
          scoringSystem: 'runs',
          createdAt: now,
          updatedAt: now,
        );
      case SportType.running:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.running,
          id: 'running',
          name: 'Running',
          code: 'RUNNING',
          iconUrl: '🏃',
          minPlayers: 1,
          maxPlayers: 50,
          defaultDuration: 60,
          requiresVenue: false,
          isTeamSport: false,
          isOutdoorSport: true,
          requiredEquipment: ['Running shoes'],
          scoringSystem: 'time',
          createdAt: now,
          updatedAt: now,
        );
      case SportType.swimming:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.swimming,
          id: 'swimming',
          name: 'Swimming',
          code: 'SWIMMING',
          iconUrl: '🏊',
          minPlayers: 1,
          maxPlayers: 20,
          defaultDuration: 60,
          requiresVenue: true,
          isTeamSport: false,
          isIndoorSport: true,
          isOutdoorSport: true,
          requiredEquipment: ['Swimwear', 'Goggles'],
          scoringSystem: 'time',
          createdAt: now,
          updatedAt: now,
        );
      case SportType.cycling:
        final now = DateTime.now();
        return SportConfigModel(
          type: SportType.cycling,
          id: 'cycling',
          name: 'Cycling',
          code: 'CYCLING',
          iconUrl: '🚴',
          minPlayers: 1,
          maxPlayers: 30,
          defaultDuration: 120,
          requiresVenue: false,
          isTeamSport: false,
          isOutdoorSport: true,
          requiredEquipment: ['Bicycle', 'Helmet'],
          scoringSystem: 'time',
          createdAt: now,
          updatedAt: now,
        );
      default:
        final now = DateTime.now();
        return SportConfigModel(
          type: sportType,
          id: sportType.toString().split('.').last,
          name: sportType.displayName,
          code: sportType.code,
          iconUrl: '🏃',
          minPlayers: 1,
          maxPlayers: 50,
          defaultDuration: 60,
          requiresVenue: false,
          isTeamSport: false,
          createdAt: now,
          updatedAt: now,
        );
    }
  }

  // Static list of available sports
  static List<SportConfigModel> get availableSports => [
    SportConfigModel.football(),
    SportConfigModel.basketball(),
    SportConfigModel.tennis(),
    SportConfigModel.badminton(),
    SportConfigModel.fromSportType(SportType.volleyball),
    SportConfigModel.fromSportType(SportType.tabletennis),
    SportConfigModel.fromSportType(SportType.cricket),
    SportConfigModel.fromSportType(SportType.running),
    SportConfigModel.fromSportType(SportType.swimming),
    SportConfigModel.fromSportType(SportType.cycling),
  ];

  // Sport icon mapping
  static Map<SportType, String> get sportIcons => {
    SportType.football: '⚽',
    SportType.basketball: '🏀',
    SportType.tennis: '🎾',
    SportType.badminton: '🏸',
    SportType.volleyball: '🏐',
    SportType.tabletennis: '🏓',
    SportType.cricket: '🏏',
    SportType.running: '🏃',
    SportType.swimming: '🏊',
    SportType.cycling: '🚴',
    SportType.other: '🏃',
  };

  // Localized sport names support
  static Map<SportType, Map<String, String>> get localizedNames => {
    SportType.football: {
      'en': 'Football',
      'es': 'Fútbol',
      'fr': 'Football',
      'ar': 'كرة القدم',
    },
    SportType.basketball: {
      'en': 'Basketball',
      'es': 'Baloncesto',
      'fr': 'Basketball',
      'ar': 'كرة السلة',
    },
    SportType.tennis: {
      'en': 'Tennis',
      'es': 'Tenis',
      'fr': 'Tennis',
      'ar': 'التنس',
    },
    SportType.badminton: {
      'en': 'Badminton',
      'es': 'Bádminton',
      'fr': 'Badminton',
      'ar': 'الريشة الطائرة',
    },
    // Add more sports and languages as needed
  };

  String getLocalizedName(String languageCode) {
    return localizedNames[type]?[languageCode] ?? name;
  }

  @override
  SportConfigModel copyWith({
    SportType? type,
    String? id,
    String? name,
    String? code,
    String? iconUrl,
    int? minPlayers,
    int? maxPlayers,
    int? defaultDuration,
    bool? requiresVenue,
    bool? isTeamSport,
    bool? isIndoorSport,
    bool? isOutdoorSport,
    List<String>? requiredEquipment,
    List<String>? optionalEquipment,
    String? rulesDescription,
    List<String>? availableSkillLevels,
    String? scoringSystem,
    int? maxScore,
    bool? hasTimeLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SportConfigModel(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      iconUrl: iconUrl ?? this.iconUrl,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      requiresVenue: requiresVenue ?? this.requiresVenue,
      isTeamSport: isTeamSport ?? this.isTeamSport,
      isIndoorSport: isIndoorSport ?? this.isIndoorSport,
      isOutdoorSport: isOutdoorSport ?? this.isOutdoorSport,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      optionalEquipment: optionalEquipment ?? this.optionalEquipment,
      rulesDescription: rulesDescription ?? this.rulesDescription,
      availableSkillLevels: availableSkillLevels ?? this.availableSkillLevels,
      scoringSystem: scoringSystem ?? this.scoringSystem,
      maxScore: maxScore ?? this.maxScore,
      hasTimeLimit: hasTimeLimit ?? this.hasTimeLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
