import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';

enum SportType { football, cricket, padel }

class Sport {
  final SportType type;
  final String name;
  final String displayName;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;

  const Sport({
    required this.type,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class SportsConfig {
  static const List<Sport> allSports = [
    Sport(
      type: SportType.football,
      name: 'football',
      displayName: 'Football',
      icon: LucideIcons.circle, // Football/Soccer ball
      primaryColor: Color(0xFF22C55E), // Green
      secondaryColor: Color(0xFFDCFCE7),
    ),
    Sport(
      type: SportType.cricket,
      name: 'cricket',
      displayName: 'Cricket',
      icon: LucideIcons.circle, // Cricket ball
      primaryColor: Color(0xFF8B5CF6), // Purple
      secondaryColor: Color(0xFFF3E8FF),
    ),
    Sport(
      type: SportType.padel,
      name: 'padel',
      displayName: 'Padel',
      icon: LucideIcons.square, // Padel court (rectangular)
      primaryColor: Color(0xFF06B6D4), // Cyan
      secondaryColor: Color(0xFFE0F7FA),
    ),
  ];

  static Sport getSportByName(String name) {
    return allSports.firstWhere(
      (sport) => sport.name.toLowerCase() == name.toLowerCase(),
      orElse: () => allSports.first,
    );
  }

  static Sport getSportByType(SportType type) {
    return allSports.firstWhere(
      (sport) => sport.type == type,
      orElse: () => allSports.first,
    );
  }

  static List<String> get sportNames =>
      allSports.map((sport) => sport.displayName).toList();

  static List<String> get sportNamesLowercase =>
      allSports.map((sport) => sport.name).toList();

  static IconData getSportIcon(String sportName) {
    return getSportByName(sportName).icon;
  }

  static Color getSportPrimaryColor(String sportName) {
    return getSportByName(sportName).primaryColor;
  }

  static Color getSportSecondaryColor(String sportName) {
    return getSportByName(sportName).secondaryColor;
  }

  // Get available formats for each sport
  static List<GameFormat> getFormatsForSport(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'football':
        return FootballFormat.allFormats.cast<GameFormat>();
      case 'cricket':
        return CricketFormat.allFormats.cast<GameFormat>();
      case 'padel':
        return PadelFormat.allFormats.cast<GameFormat>();
      default:
        return [];
    }
  }

  // Helper methods for common sport checks
  static bool isPadel(String sportName) {
    return sportName.toLowerCase() == 'padel';
  }

  static bool isFootball(String sportName) {
    return sportName.toLowerCase() == 'football';
  }

  static bool isCricket(String sportName) {
    return sportName.toLowerCase() == 'cricket';
  }

  // Get sample venue names for each sport
  static String getSampleVenue(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'football':
        return 'Football Stadium';
      case 'cricket':
        return 'Cricket Ground';
      case 'padel':
        return 'Padel Center';
      default:
        return 'Sports Complex';
    }
  }

  // Get typical game duration for each sport
  static Duration getTypicalDuration(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'football':
        return const Duration(minutes: 90);
      case 'cricket':
        return const Duration(hours: 3);
      case 'padel':
        return const Duration(minutes: 90);
      default:
        return const Duration(minutes: 60);
    }
  }

  // Get typical number of players for each sport (most common format)
  static int getTypicalPlayers(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'football':
        return 10; // Futsal default
      case 'cricket':
        return 22; // Standard cricket
      case 'padel':
        return 4; // Double padel
      default:
        return 8;
    }
  }

  // Get default format for each sport
  static GameFormat? getDefaultFormat(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'football':
        return FootballFormat.futsal;
      case 'cricket':
        return CricketFormat.standard;
      case 'padel':
        return PadelFormat.double;
      default:
        return null;
    }
  }
}
