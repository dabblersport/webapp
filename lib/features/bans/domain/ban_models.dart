// KAN-1014: an organiser's ban on a person, and the scope a removal applies.

/// The `p_ban_scope` a removal RPC takes: no ban, this event (or series), or
/// every event the organiser runs.
enum BanScope {
  none('none'),
  event('event'),
  organiser('organiser');

  const BanScope(this.wire);
  final String wire;

  static BanScope fromWire(Object? v) => switch (v?.toString()) {
    'event' => BanScope.event,
    'organiser' => BanScope.organiser,
    _ => BanScope.none,
  };
}

/// What the host chose in the removal sheet.
class RemovalChoice {
  const RemovalChoice({required this.scope, this.reason});
  final BanScope scope;

  /// Trimmed; null when left empty.
  final String? reason;
}

/// One row of `rpc_list_my_bans`.
class OrganiserBan {
  const OrganiserBan({
    required this.banId,
    required this.scope,
    required this.createdAt,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.eventTitle,
    this.seriesId,
  });

  factory OrganiserBan.fromJson(Map<String, dynamic> j) => OrganiserBan(
    banId: j['ban_id'].toString(),
    scope: BanScope.fromWire(j['scope']),
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    displayName: j['display_name'] as String?,
    username: j['username'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    eventTitle: j['event_title'] as String?,
    seriesId: j['series_id']?.toString(),
  );

  final String banId;
  final BanScope scope;
  final DateTime? createdAt;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? eventTitle;
  final String? seriesId;
}
