/// Skill level enum definitions with visual representations and utility methods
library;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Enum representing different skill levels with visual and functional properties
enum SkillLevel {
  beginner(1, 'Beginner', 'Just starting out', Colors.green),
  intermediate(2, 'Intermediate', 'Comfortable with basics', Colors.blue),
  advanced(3, 'Advanced', 'Strong skills', Colors.orange),
  expert(4, 'Expert', 'Highly skilled', Colors.purple),
  professional(5, 'Professional', 'Elite level', Colors.red);

  final int value;
  final String name;
  final String description;
  final Color color;
  const SkillLevel(this.value, this.name, this.description, this.color);

  /// Create SkillLevel from integer value
  static SkillLevel fromValue(int value) => SkillLevel.values.firstWhere(
    (e) => e.value == value,
    orElse: () => SkillLevel.beginner,
  );

  /// Create SkillLevel from string name
  static SkillLevel fromString(String name) => SkillLevel.values.firstWhere(
    (e) => e.name.toLowerCase() == name.toLowerCase(),
    orElse: () => SkillLevel.beginner,
  );

  /// Generate a star rating widget representation of the skill level
  Widget toWidget({double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Iconsax.star_1_copy : Iconsax.star_copy,
          color: color,
          size: size,
        ),
      ),
    );
  }

  /// Generate a progress bar widget representation
  Widget toProgressBar({
    double width = 100,
    double height = 8,
    Color? backgroundColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[300],
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value / 5.0,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }

  /// Generate a chip widget representation
  Widget toChip({
    bool showStars = true,
    bool selected = false,
    VoidCallback? onSelected,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected != null ? (_) => onSelected() : null,
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (showStars) ...[
            const SizedBox(width: 8),
            ...List.generate(
              value,
              (index) => Icon(Iconsax.star_1_copy, color: color, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  /// Get the next skill level (for progression)
  SkillLevel? get next {
    if (this == SkillLevel.professional) return null;
    return SkillLevel.fromValue(value + 1);
  }

  /// Get the previous skill level
  SkillLevel? get previous {
    if (this == SkillLevel.beginner) return null;
    return SkillLevel.fromValue(value - 1);
  }

  /// Check if this skill level can compete with another
  bool canCompeteWith(SkillLevel other) {
    final difference = (value - other.value).abs();
    return difference <= 1; // Can compete within 1 level difference
  }

  /// Get skill level requirements or expectations
  List<String> get expectations {
    switch (this) {
      case SkillLevel.beginner:
        return [
          'Learning basic rules and techniques',
          'Focus on fundamentals',
          'Building confidence',
          'Having fun while learning',
        ];
      case SkillLevel.intermediate:
        return [
          'Comfortable with basic skills',
          'Understanding game strategy',
          'Consistent performance',
          'Ready for friendly competition',
        ];
      case SkillLevel.advanced:
        return [
          'Strong technical skills',
          'Good game awareness',
          'Can coach beginners',
          'Competitive mindset',
        ];
      case SkillLevel.expert:
        return [
          'Exceptional skills and knowledge',
          'Deep understanding of strategy',
          'Mentors others regularly',
          'Competes at high levels',
        ];
      case SkillLevel.professional:
        return [
          'Elite-level performance',
          'Professional training background',
          'Competes professionally',
          'Teaching and coaching expertise',
        ];
    }
  }

  /// Get recommended training focus for this skill level
  List<String> get trainingFocus {
    switch (this) {
      case SkillLevel.beginner:
        return [
          'Basic techniques',
          'Safety and rules',
          'Building stamina',
          'Enjoyment and motivation',
        ];
      case SkillLevel.intermediate:
        return [
          'Consistency practice',
          'Tactical understanding',
          'Physical conditioning',
          'Mental game development',
        ];
      case SkillLevel.advanced:
        return [
          'Advanced techniques',
          'Competition preparation',
          'Leadership skills',
          'Specialized training',
        ];
      case SkillLevel.expert:
        return [
          'Peak performance optimization',
          'Teaching methodology',
          'Advanced strategy',
          'Mental resilience',
        ];
      case SkillLevel.professional:
        return [
          'Professional development',
          'Cutting-edge techniques',
          'Competition psychology',
          'Career sustainability',
        ];
    }
  }

  /// Get estimated hours per week commitment for this level
  int get recommendedHoursPerWeek {
    switch (this) {
      case SkillLevel.beginner:
        return 3;
      case SkillLevel.intermediate:
        return 6;
      case SkillLevel.advanced:
        return 10;
      case SkillLevel.expert:
        return 15;
      case SkillLevel.professional:
        return 25;
    }
  }

  /// Get all skill levels as display options
  static List<SkillLevel> get allLevels => SkillLevel.values;

  /// Get skill levels suitable for beginners to play with
  static List<SkillLevel> get beginnerFriendly => [
    SkillLevel.beginner,
    SkillLevel.intermediate,
  ];

  /// Get competitive skill levels
  static List<SkillLevel> get competitive => [
    SkillLevel.advanced,
    SkillLevel.expert,
    SkillLevel.professional,
  ];
}
