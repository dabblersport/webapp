/// The viewer's bench state, read from their own `user_status` row
/// (KAN-706). No row means not benched; the four visibility flags then carry
/// the backend defaults (feed, search and friend requests on; social
/// notifications off).
class BenchStatus {
  const BenchStatus({
    required this.isBenched,
    this.benchedAt,
    this.reason,
    this.benchUntil,
    this.hideInFeed = true,
    this.hideInSearch = true,
    this.blockFriendRequests = true,
    this.suppressSocialNotifications = false,
    this.updatedAt,
  });

  /// No row: not benched, backend defaults.
  static const BenchStatus none = BenchStatus(isBenched: false);

  final bool isBenched;
  final DateTime? benchedAt;
  final String? reason;
  final DateTime? benchUntil;
  final bool hideInFeed;
  final bool hideInSearch;
  final bool blockFriendRequests;
  final bool suppressSocialNotifications;
  final DateTime? updatedAt;

  /// Maps a `user_status` row; `null` (no row) is [none].
  factory BenchStatus.fromRow(Map<String, dynamic>? row) {
    if (row == null) return none;
    DateTime? at(String key) {
      final Object? v = row[key];
      return v is String ? DateTime.tryParse(v) : null;
    }

    bool flag(String key, bool fallback) {
      final Object? v = row[key];
      return v is bool ? v : fallback;
    }

    final Object? reason = row['reason'];
    return BenchStatus(
      isBenched: flag('is_benched', false),
      benchedAt: at('benched_at'),
      reason: reason is String && reason.trim().isNotEmpty ? reason : null,
      benchUntil: at('bench_until'),
      hideInFeed: flag('hide_in_feed', true),
      hideInSearch: flag('hide_in_search', true),
      blockFriendRequests: flag('block_friend_requests', true),
      suppressSocialNotifications: flag('suppress_social_notifications', false),
      updatedAt: at('updated_at'),
    );
  }

  /// The row shape [fromRow] reads, for the on-device cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'is_benched': isBenched,
    'benched_at': benchedAt?.toIso8601String(),
    'reason': reason,
    'bench_until': benchUntil?.toIso8601String(),
    'hide_in_feed': hideInFeed,
    'hide_in_search': hideInSearch,
    'block_friend_requests': blockFriendRequests,
    'suppress_social_notifications': suppressSocialNotifications,
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// The form's starting values: this status when benched (Edit), the
  /// defaults otherwise (Start).
  BenchSettings toSettings() => isBenched
      ? BenchSettings(
          reason: reason,
          benchUntil: benchUntil?.toLocal(),
          hideInFeed: hideInFeed,
          hideInSearch: hideInSearch,
          blockFriendRequests: blockFriendRequests,
          suppressSocialNotifications: suppressSocialNotifications,
        )
      : const BenchSettings();
}

/// What the bench form submits to the toggle-bench RPC.
class BenchSettings {
  const BenchSettings({
    this.reason,
    this.benchUntil,
    this.hideInFeed = true,
    this.hideInSearch = true,
    this.blockFriendRequests = true,
    this.suppressSocialNotifications = false,
  });

  final String? reason;

  /// The chosen end day, local; `null` is no end date.
  final DateTime? benchUntil;
  final bool hideInFeed;
  final bool hideInSearch;
  final bool blockFriendRequests;
  final bool suppressSocialNotifications;

  BenchSettings copyWith({
    String? reason,
    DateTime? benchUntil,
    bool clearBenchUntil = false,
    bool? hideInFeed,
    bool? hideInSearch,
    bool? blockFriendRequests,
    bool? suppressSocialNotifications,
  }) => BenchSettings(
    reason: reason ?? this.reason,
    benchUntil: clearBenchUntil ? null : (benchUntil ?? this.benchUntil),
    hideInFeed: hideInFeed ?? this.hideInFeed,
    hideInSearch: hideInSearch ?? this.hideInSearch,
    blockFriendRequests: blockFriendRequests ?? this.blockFriendRequests,
    suppressSocialNotifications:
        suppressSocialNotifications ?? this.suppressSocialNotifications,
  );

  /// The toggle-bench RPC arguments for starting or editing a bench. A
  /// blank reason is sent as null; the end date is the end of the chosen
  /// local day, sent in UTC.
  Map<String, dynamic> toToggleParams() {
    final String? note = reason?.trim();
    final DateTime? day = benchUntil;
    return <String, dynamic>{
      'p_is_benched': true,
      'p_reason': note == null || note.isEmpty ? null : note,
      'p_bench_until': day == null
          ? null
          : DateTime(
              day.year,
              day.month,
              day.day,
              23,
              59,
              59,
            ).toUtc().toIso8601String(),
      'p_hide_in_feed': hideInFeed,
      'p_hide_in_search': hideInSearch,
      'p_block_friend_requests': blockFriendRequests,
      'p_suppress_social_notifications': suppressSocialNotifications,
    };
  }
}
