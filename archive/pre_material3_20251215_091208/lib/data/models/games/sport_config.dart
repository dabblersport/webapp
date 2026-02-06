enum SportType {
  football,
  basketball,
  tennis,
  badminton,
  volleyball,
  tabletennis,
  squash,
  cricket,
  baseball,
  soccer,
  hockey,
  rugby,
  swimming,
  golf,
  boxing,
  mma,
  yoga,
  fitness,
  running,
  cycling,
  other,
}

extension SportTypeExtension on SportType {
  String get displayName {
    switch (this) {
      case SportType.football:
        return 'Football';
      case SportType.basketball:
        return 'Basketball';
      case SportType.tennis:
        return 'Tennis';
      case SportType.badminton:
        return 'Badminton';
      case SportType.volleyball:
        return 'Volleyball';
      case SportType.tabletennis:
        return 'Table Tennis';
      case SportType.squash:
        return 'Squash';
      case SportType.cricket:
        return 'Cricket';
      case SportType.baseball:
        return 'Baseball';
      case SportType.soccer:
        return 'Soccer';
      case SportType.hockey:
        return 'Hockey';
      case SportType.rugby:
        return 'Rugby';
      case SportType.swimming:
        return 'Swimming';
      case SportType.golf:
        return 'Golf';
      case SportType.boxing:
        return 'Boxing';
      case SportType.mma:
        return 'MMA';
      case SportType.yoga:
        return 'Yoga';
      case SportType.fitness:
        return 'Fitness';
      case SportType.running:
        return 'Running';
      case SportType.cycling:
        return 'Cycling';
      case SportType.other:
        return 'Other';
    }
  }

  String get code {
    return name.toUpperCase();
  }
}

class SportConfig {
  final String id;
  final String name;
  final String code;
  final String iconUrl;

  // Player requirements
  final int minPlayers;
  final int maxPlayers;
  final int defaultDuration; // in minutes

  // Sport characteristics
  final bool requiresVenue;
  final bool isTeamSport;
  final bool isIndoorSport;
  final bool isOutdoorSport;

  // Equipment and rules
  final List<String> requiredEquipment;
  final List<String> optionalEquipment;
  final String? rulesDescription;

  // Skill levels
  final List<String> availableSkillLevels;

  // Scoring system
  final String? scoringSystem; // 'points', 'sets', 'goals', etc.
  final int? maxScore;
  final bool hasTimeLimit;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const SportConfig({
    required this.id,
    required this.name,
    required this.code,
    required this.iconUrl,
    required this.minPlayers,
    required this.maxPlayers,
    required this.defaultDuration,
    required this.requiresVenue,
    required this.isTeamSport,
    this.isIndoorSport = false,
    this.isOutdoorSport = false,
    this.requiredEquipment = const [],
    this.optionalEquipment = const [],
    this.rulesDescription,
    this.availableSkillLevels = const [
      'beginner',
      'intermediate',
      'advanced',
      'mixed',
    ],
    this.scoringSystem,
    this.maxScore,
    this.hasTimeLimit = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if this sport can be played with the given number of players
  bool canPlayWith(int playerCount) {
    return playerCount >= minPlayers && playerCount <= maxPlayers;
  }

  /// Get the optimal number of players for this sport
  int get optimalPlayers {
    // For team sports, return the maximum to fill teams
    if (isTeamSport) {
      return maxPlayers;
    }

    // For individual sports, return minimum needed
    return minPlayers;
  }

  /// Check if this sport requires specific equipment
  bool get requiresEquipment {
    return requiredEquipment.isNotEmpty;
  }

  /// Get formatted duration text
  String get durationText {
    if (defaultDuration < 60) {
      return '${defaultDuration}min';
    } else {
      final hours = defaultDuration ~/ 60;
      final minutes = defaultDuration % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}min';
      }
    }
  }

  /// Get player count range text
  String get playerCountText {
    if (minPlayers == maxPlayers) {
      return '$minPlayers players';
    } else {
      return '$minPlayers-$maxPlayers players';
    }
  }

  /// Check if skill level is valid for this sport
  bool isValidSkillLevel(String skillLevel) {
    return availableSkillLevels.contains(skillLevel.toLowerCase());
  }

  /// Get display text for venue requirement
  String get venueRequirementText {
    if (requiresVenue) {
      if (isIndoorSport && isOutdoorSport) {
        return 'Venue required (Indoor/Outdoor)';
      } else if (isIndoorSport) {
        return 'Indoor venue required';
      } else if (isOutdoorSport) {
        return 'Outdoor venue required';
      } else {
        return 'Venue required';
      }
    } else {
      return 'No venue required';
    }
  }

  /// Factory method to create common sport configurations
  static SportConfig football() {
    return SportConfig(
      id: 'football',
      name: 'Football',
      code: 'FB',
      iconUrl: 'assets/sports/football.svg',
      minPlayers: 22,
      maxPlayers: 22,
      defaultDuration: 90,
      requiresVenue: true,
      isTeamSport: true,
      isOutdoorSport: true,
      requiredEquipment: ['Football', 'Goals'],
      optionalEquipment: ['Shin guards', 'Cleats'],
      rulesDescription: 'Standard football rules with 11 players per team',
      scoringSystem: 'goals',
      hasTimeLimit: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static SportConfig basketball() {
    return SportConfig(
      id: 'basketball',
      name: 'Basketball',
      code: 'BB',
      iconUrl: 'assets/sports/basketball.svg',
      minPlayers: 6,
      maxPlayers: 10,
      defaultDuration: 48,
      requiresVenue: true,
      isTeamSport: true,
      isIndoorSport: true,
      isOutdoorSport: true,
      requiredEquipment: ['Basketball', 'Hoops'],
      optionalEquipment: ['Basketball shoes'],
      rulesDescription: 'Standard basketball rules with 5 players per team',
      scoringSystem: 'points',
      hasTimeLimit: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static SportConfig tennis() {
    return SportConfig(
      id: 'tennis',
      name: 'Tennis',
      code: 'TN',
      iconUrl: 'assets/sports/tennis.svg',
      minPlayers: 2,
      maxPlayers: 4,
      defaultDuration: 90,
      requiresVenue: true,
      isTeamSport: false,
      isIndoorSport: true,
      isOutdoorSport: true,
      requiredEquipment: ['Tennis rackets', 'Tennis balls', 'Net'],
      optionalEquipment: ['Tennis shoes', 'Wristbands'],
      rulesDescription: 'Singles or doubles tennis match',
      scoringSystem: 'sets',
      hasTimeLimit: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static SportConfig badminton() {
    return SportConfig(
      id: 'badminton',
      name: 'Badminton',
      code: 'BD',
      iconUrl: 'assets/sports/badminton.svg',
      minPlayers: 2,
      maxPlayers: 4,
      defaultDuration: 60,
      requiresVenue: true,
      isTeamSport: false,
      isIndoorSport: true,
      requiredEquipment: ['Badminton rackets', 'Shuttlecocks', 'Net'],
      optionalEquipment: ['Badminton shoes', 'Grip tape'],
      rulesDescription: 'Singles or doubles badminton match',
      scoringSystem: 'points',
      maxScore: 21,
      hasTimeLimit: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  SportConfig copyWith({
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
    return SportConfig(
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SportConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SportConfig{id: $id, name: $name, players: $minPlayers-$maxPlayers}';
  }
}
