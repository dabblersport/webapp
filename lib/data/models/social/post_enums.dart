/// Enums that mirror the Supabase DB enum types for posts.
///
/// These map 1:1 to the database enum values. Do NOT rename entries.
library;

/// Mirrors `post_type_enum` in the DB.
///
/// Controls layout/behavior only. The Dart name `kickIn` maps to the DB
/// string `kick_in`.
enum PostType {
  moment,
  dab,
  kickIn,
  allocated;

  /// The wire value sent to / received from the DB.
  String get dbValue {
    if (this == PostType.kickIn) return 'kick_in';
    return name;
  }

  bool get isUserSelectable {
    switch (this) {
      case PostType.moment:
      case PostType.dab:
      case PostType.kickIn:
        return true;
      case PostType.allocated:
        return false;
    }
  }

  /// Convert from DB string (e.g. 'kick_in') → enum.
  static PostType fromString(String value) {
    if (value == 'kick_in' || value == 'kickin') return PostType.kickIn;
    return PostType.values.firstWhere(
      (e) => e.dbValue == value || e.name == value,
      orElse: () => PostType.dab,
    );
  }
}

/// Controls meaning / theme / content type.
///
/// Not user-selectable — set by the system or post origin.
enum PostKind {
  original,
  news,
  announcement,
  alert,
  highlight,
  general,
  feature;

  bool get isUserSelectable => false;

  static PostKind fromString(String value) => PostKind.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PostKind.original,
  );
}

/// Mirrors `origin_type_enum` in the DB.
enum OriginType {
  manual,
  game,
  achievement,
  venue,
  admin,
  system,
  repost;

  static OriginType fromString(String value) => OriginType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => OriginType.manual,
  );
}

/// Visibility values stored as text in the DB.
enum PostVisibility {
  public,
  followers,
  circle,
  squad,
  private,
  link;

  static PostVisibility fromString(String value) => PostVisibility.values
      .firstWhere((e) => e.name == value, orElse: () => PostVisibility.public);
}
