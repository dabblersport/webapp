/// Profile-related enum definitions for completion levels and sport categories
library;

/// Enum representing different levels of profile completion
enum ProfileCompletionLevel {
  incomplete(0, 30, 'Complete your profile'),
  basic(30, 60, 'Add more details'),
  intermediate(60, 85, 'Almost there'),
  complete(85, 100, 'Profile complete');

  final int minPercentage;
  final int maxPercentage;
  final String message;
  const ProfileCompletionLevel(
    this.minPercentage,
    this.maxPercentage,
    this.message,
  );

  /// Get completion level from percentage value
  static ProfileCompletionLevel fromPercentage(int percentage) {
    return ProfileCompletionLevel.values.firstWhere(
      (level) =>
          percentage >= level.minPercentage && percentage < level.maxPercentage,
      orElse: () => ProfileCompletionLevel.complete,
    );
  }

  /// Check if profile completion level allows certain features
  bool get allowsGameCreation => minPercentage >= 30;
  bool get allowsMessaging => minPercentage >= 60;
  bool get allowsAdvancedFeatures => minPercentage >= 85;
}

/// Enum representing different sport categories
enum SportCategory {
  team('team', 'Team Sports'),
  individual('individual', 'Individual Sports'),
  racquet('racquet', 'Racquet Sports'),
  water('water', 'Water Sports'),
  winter('winter', 'Winter Sports'),
  other('other', 'Other Sports');

  final String value;
  final String displayName;
  const SportCategory(this.value, this.displayName);

  /// Create SportCategory from string value
  static SportCategory fromString(String value) => SportCategory.values
      .firstWhere((e) => e.value == value, orElse: () => SportCategory.other);

  /// Get example sports for this category
  List<String> get exampleSports {
    switch (this) {
      case SportCategory.team:
        return ['Football', 'Basketball', 'Soccer', 'Volleyball', 'Baseball'];
      case SportCategory.individual:
        return ['Running', 'Swimming', 'Cycling', 'Golf', 'Tennis'];
      case SportCategory.racquet:
        return ['Tennis', 'Badminton', 'Squash', 'Table Tennis', 'Racquetball'];
      case SportCategory.water:
        return ['Swimming', 'Surfing', 'Kayaking', 'Water Polo', 'Sailing'];
      case SportCategory.winter:
        return [
          'Skiing',
          'Snowboarding',
          'Ice Hockey',
          'Figure Skating',
          'Curling',
        ];
      case SportCategory.other:
        return ['Mixed Martial Arts', 'Rock Climbing', 'Gymnastics', 'Dancing'];
    }
  }
}
