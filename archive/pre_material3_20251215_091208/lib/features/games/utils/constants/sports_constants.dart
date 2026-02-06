/// Sport types and configurations for the games system
enum SportType {
  basketball('Basketball', '🏀'),
  soccer('Soccer', '⚽'),
  tennis('Tennis', '🎾'),
  volleyball('Volleyball', '🏐'),
  badminton('Badminton', '🏸'),
  tabletennis('Table Tennis', '🏓'),
  squash('Squash', '🎾'),
  golf('Golf', '⛳'),
  swimming('Swimming', '🏊'),
  running('Running', '🏃'),
  cycling('Cycling', '🚴'),
  hiking('Hiking', '🥾'),
  yoga('Yoga', '🧘'),
  fitness('Fitness', '💪'),
  martialarts('Martial Arts', '🥋'),
  climbing('Climbing', '🧗'),
  skating('Skating', '⛸️'),
  skiing('Skiing', '🎿'),
  surfing('Surfing', '🏄'),
  other('Other', '🏆');

  const SportType(this.displayName, this.emoji);

  final String displayName;
  final String emoji;

  String get id => name;
  String get displayNameWithEmoji => '$emoji $displayName';

  static SportType fromString(String name) {
    return SportType.values.firstWhere(
      (sport) => sport.name.toLowerCase() == name.toLowerCase(),
      orElse: () => SportType.other,
    );
  }
}

/// Sport configuration data
class SportConfiguration {
  final SportType sport;
  final Duration suggestedDuration;
  final int minPlayers;
  final int maxPlayers;
  final int idealPlayers;
  final List<String> positions;
  final ScoringSystem scoringSystem;
  final List<String> equipmentNeeded;
  final List<String> skillLevels;
  final List<String> gameRules;
  final List<String> tips;
  final bool requiresReferee;
  final bool supportsMixedGender;
  final Duration setupTime;
  final Duration cleanupTime;

  const SportConfiguration({
    required this.sport,
    required this.suggestedDuration,
    required this.minPlayers,
    required this.maxPlayers,
    required this.idealPlayers,
    this.positions = const [],
    required this.scoringSystem,
    this.equipmentNeeded = const [],
    this.skillLevels = const ['Beginner', 'Intermediate', 'Advanced'],
    this.gameRules = const [],
    this.tips = const [],
    this.requiresReferee = false,
    this.supportsMixedGender = true,
    this.setupTime = const Duration(minutes: 10),
    this.cleanupTime = const Duration(minutes: 10),
  });

  /// Get suggested duration options for this sport
  List<Duration> get durationOptions {
    final base = suggestedDuration.inMinutes;
    return [
      Duration(minutes: (base * 0.75).round()), // 75% of suggested
      suggestedDuration, // Suggested duration
      Duration(minutes: (base * 1.25).round()), // 125% of suggested
      Duration(minutes: (base * 1.5).round()), // 150% of suggested
    ];
  }

  /// Get total time needed including setup and cleanup
  Duration getTotalTimeNeeded(Duration gameDuration) {
    return setupTime + gameDuration + cleanupTime;
  }

  /// Check if player count is valid for this sport
  bool isValidPlayerCount(int count) {
    return count >= minPlayers && count <= maxPlayers;
  }

  /// Check if player count is ideal
  bool isIdealPlayerCount(int count) {
    return count == idealPlayers;
  }
}

/// Scoring systems for different sports
enum ScoringSystem {
  points('Points'),
  sets('Sets'),
  goals('Goals'),
  time('Time-based'),
  distance('Distance'),
  none('No scoring');

  const ScoringSystem(this.displayName);
  final String displayName;
}

/// Sport configurations map
class SportsConstants {
  static const Map<SportType, SportConfiguration> configurations = {
    SportType.basketball: SportConfiguration(
      sport: SportType.basketball,
      suggestedDuration: Duration(minutes: 90),
      minPlayers: 4,
      maxPlayers: 10,
      idealPlayers: 10,
      positions: [
        'Point Guard',
        'Shooting Guard',
        'Small Forward',
        'Power Forward',
        'Center',
      ],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Basketball', 'Court'],
      skillLevels: ['Beginner', 'Recreational', 'Competitive', 'Advanced'],
      gameRules: [
        'Two teams of 5 players each',
        'Score by shooting ball through opponent\'s hoop',
        'Games typically played to 21 points or timed',
        'Standard fouls and violations apply',
      ],
      tips: [
        'Bring water and towel',
        'Wear proper basketball shoes',
        'Warm up before playing',
        'Communicate with teammates',
      ],
      requiresReferee: false,
      setupTime: Duration(minutes: 5),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.soccer: SportConfiguration(
      sport: SportType.soccer,
      suggestedDuration: Duration(minutes: 120),
      minPlayers: 6,
      maxPlayers: 22,
      idealPlayers: 22,
      positions: ['Goalkeeper', 'Defender', 'Midfielder', 'Forward', 'Striker'],
      scoringSystem: ScoringSystem.goals,
      equipmentNeeded: ['Soccer Ball', 'Goals', 'Cones'],
      skillLevels: [
        'Beginner',
        'Recreational',
        'Intermediate',
        'Competitive',
        'Advanced',
      ],
      gameRules: [
        'Two teams of 11 players each (can be modified)',
        'Score by getting ball into opponent\'s goal',
        'No hands except for goalkeeper',
        'Offside rule applies',
      ],
      tips: [
        'Wear shin guards',
        'Bring extra water',
        'Check weather conditions',
        'Practice passing before game',
      ],
      requiresReferee: true,
      setupTime: Duration(minutes: 15),
      cleanupTime: Duration(minutes: 10),
    ),

    SportType.tennis: SportConfiguration(
      sport: SportType.tennis,
      suggestedDuration: Duration(minutes: 90),
      minPlayers: 2,
      maxPlayers: 4,
      idealPlayers: 4,
      positions: ['Singles Player', 'Doubles Partner'],
      scoringSystem: ScoringSystem.sets,
      equipmentNeeded: ['Tennis Rackets', 'Tennis Balls', 'Net'],
      skillLevels: ['Beginner', 'Intermediate', 'Advanced', 'Professional'],
      gameRules: [
        'Singles: 1v1, Doubles: 2v2',
        'Win by winning sets (best of 3 or 5)',
        'Scoring: 15, 30, 40, game',
        'Must win by 2 games to take set',
      ],
      tips: [
        'Warm up your serve',
        'Stay hydrated',
        'Focus on footwork',
        'Watch the ball contact point',
      ],
      requiresReferee: false,
      setupTime: Duration(minutes: 10),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.volleyball: SportConfiguration(
      sport: SportType.volleyball,
      suggestedDuration: Duration(minutes: 75),
      minPlayers: 6,
      maxPlayers: 12,
      idealPlayers: 12,
      positions: [
        'Outside Hitter',
        'Middle Blocker',
        'Opposite Hitter',
        'Setter',
        'Libero',
        'Defensive Specialist',
      ],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Volleyball', 'Net'],
      skillLevels: ['Beginner', 'Recreational', 'Intermediate', 'Competitive'],
      gameRules: [
        'Two teams of 6 players',
        'Three hits per side maximum',
        'Rally scoring to 25 points',
        'Must win by 2 points',
      ],
      tips: [
        'Practice serving before game',
        'Communicate with teammates',
        'Keep knees bent for better movement',
        'Watch for hand signals',
      ],
      requiresReferee: false,
      setupTime: Duration(minutes: 10),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.badminton: SportConfiguration(
      sport: SportType.badminton,
      suggestedDuration: Duration(minutes: 60),
      minPlayers: 2,
      maxPlayers: 4,
      idealPlayers: 4,
      positions: ['Singles Player', 'Doubles Partner'],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Badminton Rackets', 'Shuttlecocks', 'Net'],
      gameRules: [
        'Singles: 1v1, Doubles: 2v2',
        'Rally scoring to 21 points',
        'Must win by 2 points',
        'Best of 3 games',
      ],
      tips: [
        'Use wrist action for power',
        'Stay light on your feet',
        'Anticipate opponent\'s shots',
        'Control the center of the court',
      ],
      setupTime: Duration(minutes: 5),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.tabletennis: SportConfiguration(
      sport: SportType.tabletennis,
      suggestedDuration: Duration(minutes: 45),
      minPlayers: 2,
      maxPlayers: 4,
      idealPlayers: 4,
      positions: ['Singles Player', 'Doubles Partner'],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Table Tennis Padels', 'Ping Pong Balls', 'Table'],
      gameRules: [
        'Singles: 1v1, Doubles: 2v2',
        'First to 11 points wins game',
        'Must win by 2 points',
        'Best of 5 or 7 games',
      ],
      tips: [
        'Keep your paddle angle consistent',
        'Use your whole body for power',
        'Practice different spins',
        'Stay close to the table',
      ],
      setupTime: Duration(minutes: 5),
      cleanupTime: Duration(minutes: 3),
    ),

    SportType.squash: SportConfiguration(
      sport: SportType.squash,
      suggestedDuration: Duration(minutes: 60),
      minPlayers: 2,
      maxPlayers: 2,
      idealPlayers: 2,
      positions: ['Player'],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Squash Rackets', 'Squash Ball', 'Court'],
      gameRules: [
        'Two players alternate hitting ball',
        'Ball must hit front wall',
        'Rally scoring to 11 points',
        'Best of 5 games',
      ],
      tips: [
        'Warm up the ball properly',
        'Stay behind your opponent',
        'Use the whole court',
        'Vary your shots',
      ],
      setupTime: Duration(minutes: 5),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.golf: SportConfiguration(
      sport: SportType.golf,
      suggestedDuration: Duration(minutes: 240), // 4 hours
      minPlayers: 1,
      maxPlayers: 4,
      idealPlayers: 4,
      positions: ['Golfer'],
      scoringSystem: ScoringSystem.points,
      equipmentNeeded: ['Golf Clubs', 'Golf Balls', 'Tees'],
      skillLevels: [
        'Beginner',
        'High Handicap',
        'Mid Handicap',
        'Low Handicap',
      ],
      gameRules: [
        'Play 18 holes (or 9 holes)',
        'Lowest score wins',
        'Standard golf rules apply',
        'Maintain pace of play',
      ],
      tips: [
        'Arrive early to warm up',
        'Bring extra balls and tees',
        'Check weather conditions',
        'Respect course etiquette',
      ],
      setupTime: Duration(minutes: 30),
      cleanupTime: Duration(minutes: 15),
    ),

    SportType.running: SportConfiguration(
      sport: SportType.running,
      suggestedDuration: Duration(minutes: 60),
      minPlayers: 1,
      maxPlayers: 50,
      idealPlayers: 8,
      positions: ['Runner'],
      scoringSystem: ScoringSystem.time,
      equipmentNeeded: ['Running Shoes'],
      skillLevels: ['Beginner', 'Recreational', 'Competitive', 'Elite'],
      gameRules: [
        'Set distance or time goal',
        'Maintain steady pace',
        'Stay together as group',
        'Safety first',
      ],
      tips: [
        'Warm up properly',
        'Bring water',
        'Wear reflective gear if dark',
        'Know your limits',
      ],
      requiresReferee: false,
      setupTime: Duration(minutes: 10),
      cleanupTime: Duration(minutes: 5),
    ),

    SportType.cycling: SportConfiguration(
      sport: SportType.cycling,
      suggestedDuration: Duration(minutes: 120),
      minPlayers: 1,
      maxPlayers: 30,
      idealPlayers: 10,
      positions: ['Cyclist'],
      scoringSystem: ScoringSystem.distance,
      equipmentNeeded: ['Bicycle', 'Helmet'],
      skillLevels: ['Beginner', 'Recreational', 'Intermediate', 'Advanced'],
      gameRules: [
        'Set route and distance',
        'Stay in group formation',
        'Follow traffic rules',
        'Wear helmets at all times',
      ],
      tips: [
        'Check bike before riding',
        'Bring repair kit',
        'Stay hydrated',
        'Plan your route',
      ],
      setupTime: Duration(minutes: 15),
      cleanupTime: Duration(minutes: 10),
    ),

    SportType.yoga: SportConfiguration(
      sport: SportType.yoga,
      suggestedDuration: Duration(minutes: 75),
      minPlayers: 1,
      maxPlayers: 20,
      idealPlayers: 12,
      positions: ['Practitioner'],
      scoringSystem: ScoringSystem.none,
      equipmentNeeded: ['Yoga Mat'],
      skillLevels: ['Beginner', 'Intermediate', 'Advanced'],
      gameRules: [
        'Follow instructor\'s guidance',
        'Move at your own pace',
        'Focus on breathing',
        'Respect personal space',
      ],
      tips: [
        'Bring your own mat',
        'Eat light before class',
        'Communicate any injuries',
        'Stay hydrated',
      ],
      setupTime: Duration(minutes: 10),
      cleanupTime: Duration(minutes: 10),
    ),

    SportType.fitness: SportConfiguration(
      sport: SportType.fitness,
      suggestedDuration: Duration(minutes: 60),
      minPlayers: 1,
      maxPlayers: 25,
      idealPlayers: 15,
      positions: ['Participant'],
      scoringSystem: ScoringSystem.none,
      equipmentNeeded: ['Various Gym Equipment'],
      skillLevels: ['Beginner', 'Intermediate', 'Advanced'],
      gameRules: [
        'Follow workout plan',
        'Use proper form',
        'Respect equipment and others',
        'Clean equipment after use',
      ],
      tips: [
        'Warm up thoroughly',
        'Bring water and towel',
        'Know your limits',
        'Ask for help if needed',
      ],
      setupTime: Duration(minutes: 10),
      cleanupTime: Duration(minutes: 10),
    ),
  };

  /// Get configuration for a sport type
  static SportConfiguration? getConfiguration(SportType sport) {
    return configurations[sport];
  }

  /// Get configuration by sport name
  static SportConfiguration? getConfigurationByName(String sportName) {
    final sport = SportType.fromString(sportName);
    return configurations[sport];
  }

  /// Get all available sports
  static List<SportType> get allSports => SportType.values;

  /// Get popular sports (most commonly played)
  static List<SportType> get popularSports => [
    SportType.basketball,
    SportType.soccer,
    SportType.tennis,
    SportType.volleyball,
    SportType.badminton,
    SportType.running,
    SportType.cycling,
    SportType.fitness,
  ];

  /// Get indoor sports
  static List<SportType> get indoorSports => [
    SportType.basketball,
    SportType.volleyball,
    SportType.badminton,
    SportType.tabletennis,
    SportType.squash,
    SportType.yoga,
    SportType.fitness,
    SportType.martialarts,
    SportType.climbing,
  ];

  /// Get outdoor sports
  static List<SportType> get outdoorSports => [
    SportType.soccer,
    SportType.tennis,
    SportType.golf,
    SportType.running,
    SportType.cycling,
    SportType.hiking,
    SportType.surfing,
    SportType.skiing,
  ];

  /// Get team sports (require multiple players)
  static List<SportType> get teamSports => configurations.entries
      .where((entry) => entry.value.minPlayers > 2)
      .map((entry) => entry.key)
      .toList();

  /// Get individual sports (can be played solo)
  static List<SportType> get individualSports => configurations.entries
      .where((entry) => entry.value.minPlayers == 1)
      .map((entry) => entry.key)
      .toList();

  /// Get sports that require referee
  static List<SportType> get sportsRequiringReferee => configurations.entries
      .where((entry) => entry.value.requiresReferee)
      .map((entry) => entry.key)
      .toList();

  /// Get default skill levels
  static List<String> get defaultSkillLevels => [
    'Beginner',
    'Recreational',
    'Intermediate',
    'Competitive',
    'Advanced',
  ];

  /// Get skill level description
  static String getSkillLevelDescription(String skillLevel) {
    switch (skillLevel.toLowerCase()) {
      case 'beginner':
        return 'New to the sport, learning basics';
      case 'recreational':
        return 'Playing for fun, casual level';
      case 'intermediate':
        return 'Some experience, improving skills';
      case 'competitive':
        return 'Regular player, competitive level';
      case 'advanced':
        return 'Highly skilled, experienced player';
      default:
        return 'Skill level varies';
    }
  }

  /// Validate sport and skill level combination
  static bool isValidSkillLevel(SportType sport, String skillLevel) {
    final config = configurations[sport];
    if (config == null) return false;

    return config.skillLevels.any(
      (level) => level.toLowerCase() == skillLevel.toLowerCase(),
    );
  }

  /// Get recommended game duration for sport and skill level
  static Duration getRecommendedDuration(SportType sport, String skillLevel) {
    final config = configurations[sport];
    if (config == null) return const Duration(hours: 1);

    final baseDuration = config.suggestedDuration;

    // Adjust based on skill level
    switch (skillLevel.toLowerCase()) {
      case 'beginner':
        return Duration(minutes: (baseDuration.inMinutes * 0.8).round());
      case 'advanced':
      case 'professional':
        return Duration(minutes: (baseDuration.inMinutes * 1.2).round());
      default:
        return baseDuration;
    }
  }
}
