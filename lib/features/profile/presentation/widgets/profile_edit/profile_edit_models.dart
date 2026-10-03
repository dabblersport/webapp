import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:flutter/widgets.dart';

/// One weekly availability slot on the edit-profile screen.
class ProfileEditTimeSlot {
  const ProfileEditTimeSlot({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });

  final int dayOfWeek;
  final int startHour;
  final int endHour;
}

/// The three-part sport helpers the edit screen and its sections share.
/// Pure: they were private methods of the screen before KAN-418 and keep the
/// exact same behaviour.
abstract final class ProfileEditSports {
  static String categoryLabel(String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Other Sports';
    }

    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static List<Sport> sortByCategory(Iterable<Sport> sports) {
    final sortedSports = sports.toList();
    sortedSports.sort((a, b) {
      final categoryCompare = categoryLabel(
        a.category,
      ).compareTo(categoryLabel(b.category));
      if (categoryCompare != 0) {
        return categoryCompare;
      }

      return a.nameEn.compareTo(b.nameEn);
    });
    return sortedSports;
  }

  static Map<String, List<Sport>> groupByCategory(Iterable<Sport> sports) {
    final groupedSports = <String, List<Sport>>{};

    for (final sport in sortByCategory(sports)) {
      final category = categoryLabel(sport.category);
      groupedSports.putIfAbsent(category, () => <Sport>[]).add(sport);
    }

    return groupedSports;
  }

  static String keyOf(Sport sport) =>
      sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_');

  /// The sport's display label. The emoji the old label led with is dropped
  /// (CEO rule: no emoji); the localized name is unchanged.
  static String label(BuildContext context, Sport sport) =>
      sport.localizedName(context).trim();

  static String formatSportKey(String sport) {
    return sport
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String formatSkillLevel(SkillLevel level) {
    switch (level) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
      case SkillLevel.expert:
        return 'Expert';
    }
  }

  static String dayName(int dayOfWeek) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(dayOfWeek - 1) % 7];
  }

  static String formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }
}
