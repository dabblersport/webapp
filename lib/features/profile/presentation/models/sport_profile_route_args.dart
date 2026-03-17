import 'package:flutter/foundation.dart';

@immutable
class SportProfileRouteArgs {
  const SportProfileRouteArgs({
    required this.profileId,
    required this.userId,
    required this.displayName,
    required this.personaType,
    required this.sportId,
    required this.sportKey,
    required this.sportName,
    this.avatarUrl,
    this.sportEmoji,
  });

  final String profileId;
  final String userId;
  final String displayName;
  final String personaType;
  final String sportId;
  final String sportKey;
  final String sportName;
  final String? avatarUrl;
  final String? sportEmoji;

  bool get isOrganiserPersona => personaType == 'organiser';

  @override
  bool operator ==(Object other) {
    return other is SportProfileRouteArgs &&
        other.profileId == profileId &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.personaType == personaType &&
        other.sportId == sportId &&
        other.sportKey == sportKey &&
        other.sportName == sportName &&
        other.avatarUrl == avatarUrl &&
        other.sportEmoji == sportEmoji;
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    userId,
    displayName,
    personaType,
    sportId,
    sportKey,
    sportName,
    avatarUrl,
    sportEmoji,
  );
}
