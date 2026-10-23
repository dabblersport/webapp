/// KAN-622: the data the Sport Overview page reads. Plain classes, no
/// generated code: every field is the record's own value, and a field the
/// record does not supply stays null so the page renders nothing for it.
library;

/// The sport itself: identity (`sports`) and its formats (`sport_variants`).
class SportInfo {
  const SportInfo({
    required this.id,
    required this.nameEn,
    this.nameAr,
    this.sportKey,
    this.formatsEn = const <String>[],
    this.formatsAr = const <String>[],
  });

  final String id;
  final String nameEn;
  final String? nameAr;
  final String? sportKey;
  final List<String> formatsEn;
  final List<String> formatsAr;

  String name(String languageCode) {
    final String? ar = nameAr?.trim();
    return languageCode == 'ar' && ar != null && ar.isNotEmpty ? ar : nameEn;
  }

  /// The formats in [languageCode], each falling back to English.
  List<String> formats(String languageCode) {
    if (languageCode != 'ar') return formatsEn;
    return <String>[
      for (int i = 0; i < formatsEn.length; i++)
        if (i < formatsAr.length && formatsAr[i].trim().isNotEmpty)
          formatsAr[i]
        else
          formatsEn[i],
    ];
  }
}

/// One of up to three people the viewer follows who also follow the sport.
class MutualFollower {
  const MutualFollower({this.displayName, this.username, this.avatarUrl});

  final String? displayName;
  final String? username;
  final String? avatarUrl;

  /// What the line shows: the display name, else the username; null when the
  /// row carries neither (it is then left out).
  String? get label {
    final String? name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String? handle = username?.trim();
    return handle != null && handle.isNotEmpty ? handle : null;
  }

  factory MutualFollower.fromJson(Map<String, dynamic> json) => MutualFollower(
    displayName: json['display_name'] as String?,
    username: json['username'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

/// The row `rpc_sport_overview` returns (KAN-621). `followers` is global; the
/// other counts follow the city asked for. `posts` is not city-scoped.
class SportOverviewCounts {
  const SportOverviewCounts({
    required this.followers,
    required this.gamesNext7,
    required this.meetupsNext7,
    required this.venues,
    required this.spaces,
    required this.posts,
    required this.news,
    this.mutualFollowers = const <MutualFollower>[],
  });

  final int followers;
  final int gamesNext7;
  final int meetupsNext7;
  final int venues;
  final int spaces;
  final int posts;
  final int news;

  /// At most three, already ordered by the server. Empty when none.
  final List<MutualFollower> mutualFollowers;

  /// A missing or malformed `mutual_followers` is an empty list: the line is
  /// hidden, never an error.
  factory SportOverviewCounts.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    final Object? raw = json['mutual_followers'];
    final List<MutualFollower> mutual = <MutualFollower>[
      if (raw is List)
        for (final Object? item in raw)
          if (item is Map)
            MutualFollower.fromJson(Map<String, dynamic>.from(item)),
    ].where((m) => m.label != null).take(3).toList();
    return SportOverviewCounts(
      followers: count('followers'),
      gamesNext7: count('games_next7'),
      meetupsNext7: count('meetups_next7'),
      venues: count('venues'),
      spaces: count('spaces'),
      posts: count('posts'),
      news: count('news'),
      mutualFollowers: mutual,
    );
  }
}

/// A venue that offers the sport. Rating and price are the record's own: a
/// venue with none shows none (never 0).
class SportVenue {
  const SportVenue({
    required this.id,
    required this.nameEn,
    this.nameAr,
    this.areaName,
    this.rating,
    this.ratingCount,
  });

  final String id;
  final String nameEn;
  final String? nameAr;
  final String? areaName;

  /// `venues.app_rating`; null or 0 means not rated yet.
  final double? rating;
  final int? ratingCount;

  String name(String languageCode) {
    final String? ar = nameAr?.trim();
    return languageCode == 'ar' && ar != null && ar.isNotEmpty ? ar : nameEn;
  }
}

/// A bookable space (court, pitch) of the sport inside a venue.
class SportSpace {
  const SportSpace({
    required this.id,
    required this.venueId,
    this.nameEn,
    this.nameAr,
    this.venueNameEn,
    this.venueNameAr,
    this.pricePerHour,
    this.capacity,
    this.indoor,
  });

  final String id;
  final String venueId;
  final String? nameEn;
  final String? nameAr;
  final String? venueNameEn;
  final String? venueNameAr;

  /// `venue_spaces.price_per_hour`; null when the space lists none.
  final double? pricePerHour;
  final int? capacity;
  final bool? indoor;

  String? name(String languageCode) {
    final String? ar = nameAr?.trim();
    if (languageCode == 'ar' && ar != null && ar.isNotEmpty) return ar;
    final String? en = nameEn?.trim();
    return en != null && en.isNotEmpty ? en : null;
  }

  String? venueName(String languageCode) {
    final String? ar = venueNameAr?.trim();
    if (languageCode == 'ar' && ar != null && ar.isNotEmpty) return ar;
    final String? en = venueNameEn?.trim();
    return en != null && en.isNotEmpty ? en : null;
  }
}

/// The page-local City filter. [code] is a `ref_cities.code` (what the RPC
/// takes); null with a [name] means the chosen city is not one the data is
/// keyed by yet (the page then shows every city and says so).
class SportPageCity {
  const SportPageCity({this.name, this.code});

  /// No city: the page's no-city state (CTA), data for every city.
  static const SportPageCity none = SportPageCity();

  final String? name;
  final String? code;

  bool get isNone => name == null;
  bool get isMapped => code != null;

  @override
  bool operator ==(Object other) =>
      other is SportPageCity && other.name == name && other.code == code;

  @override
  int get hashCode => Object.hash(name, code);
}
