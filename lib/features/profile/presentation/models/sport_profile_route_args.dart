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

  /// Query representation so the route survives web refresh / direct URL
  /// entry, where GoRouter's `state.extra` is lost.
  Map<String, String> toQueryParameters() => {
    'profileId': profileId,
    'userId': userId,
    'sportId': sportId,
    'sportKey': sportKey,
    'persona': personaType,
    'sportName': sportName,
    if (displayName.isNotEmpty) 'displayName': displayName,
    if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatarUrl': avatarUrl!,
    if (sportEmoji != null && sportEmoji!.isNotEmpty) 'sportEmoji': sportEmoji!,
  };

  /// Rebuilds args from query params; returns null when required params are
  /// missing or invalid, so the router can fall back to its error page.
  static SportProfileRouteArgs? fromQueryParameters(Map<String, String> query) {
    final profileId = query['profileId'];
    final userId = query['userId'];
    final sportId = query['sportId'];
    final sportKey = query['sportKey'];
    final persona = query['persona'];
    if (profileId == null ||
        profileId.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        sportId == null ||
        sportId.isEmpty ||
        sportKey == null ||
        sportKey.isEmpty ||
        (persona != 'player' && persona != 'organiser')) {
      return null;
    }
    return SportProfileRouteArgs(
      profileId: profileId,
      userId: userId,
      displayName: query['displayName'] ?? '',
      personaType: persona!,
      sportId: sportId,
      sportKey: sportKey,
      sportName: query['sportName'] ?? _titleCase(sportKey),
      avatarUrl: query['avatarUrl'],
      sportEmoji: query['sportEmoji'],
    );
  }

  static String _titleCase(String key) => key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

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
