/// Enums that mirror the Supabase DB enum types for posts.
///
/// These map 1:1 to the database enum values. Do NOT rename entries.
library;

/// Mirrors `post_type_enum` in the DB.
///
/// DB values: moment, dab, kick_in
/// The Dart name `kickIn` maps to the DB string `kick_in`.
enum PostType {
  moment,
  dab,
  kickIn;

  /// The wire value sent to / received from the DB.
  String get dbValue {
    if (this == PostType.kickIn) return 'kick_in';
    return name;
  }

  /// Convert from DB string (e.g. 'kick_in') → enum.
  static PostType fromString(String value) {
    if (value == 'kick_in' || value == 'kickin') return PostType.kickIn;
    return PostType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PostType.dab,
    );
  }
}

/// Mirrors `post_kind` enum in the DB.
///
/// DB values: moment, dab, kickin
enum PostKind {
  moment,
  dab,
  kickin;

  /// Default `post_type` for this kind.
  PostType get defaultPostType {
    switch (this) {
      case PostKind.moment:
        return PostType.moment;
      case PostKind.dab:
        return PostType.dab;
      case PostKind.kickin:
        return PostType.kickIn;
    }
  }

  static PostKind fromString(String value) => PostKind.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PostKind.moment,
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
