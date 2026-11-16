import 'package:flutter/foundation.dart';

/// KAN-966: `get_home_feed`'s keyset on the merged post + Active card rows:
/// the last row's `feed_at`, `cursor_id` and `item_kind`. A cursor read from
/// an older cache has only [at] and pages the legacy way (`feed_at < at`).
@immutable
class HomeFeedCursor {
  const HomeFeedCursor(this.at, {this.id, this.kind});

  final DateTime at;
  final String? id;

  /// `post` or `active`.
  final String? kind;

  /// The next page's RPC params.
  Map<String, dynamic> get params => <String, dynamic>{
    'p_cursor': at.toUtc().toIso8601String(),
    if (id != null && kind != null) 'p_cursor_id': id,
    if (id != null && kind != null) 'p_cursor_kind': kind,
  };

  /// The cursor after [row]; null when the row carries no time.
  static HomeFeedCursor? fromRow(Map<String, dynamic> row) {
    final at = DateTime.tryParse(
      (row['feed_at'] ?? row['created_at'] ?? '').toString(),
    );
    if (at == null) return null;
    final id = row['cursor_id']?.toString();
    final kind = row['item_kind']?.toString();
    final keyed =
        id != null && id.isNotEmpty && (kind == 'post' || kind == 'active');
    return HomeFeedCursor(at, id: keyed ? id : null, kind: keyed ? kind : null);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toUtc().toIso8601String(),
    'id': id,
    'kind': kind,
  };

  /// The cached cursor: the KAN-966 map, or an older cache's bare time.
  static HomeFeedCursor? fromCache(Object? raw) {
    if (raw is String) {
      final at = DateTime.tryParse(raw);
      return at == null ? null : HomeFeedCursor(at);
    }
    if (raw is Map) {
      return fromRow(<String, dynamic>{
        'feed_at': raw['at'],
        'cursor_id': raw['id'],
        'item_kind': raw['kind'],
      });
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is HomeFeedCursor &&
      other.at == at &&
      other.id == id &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(at, id, kind);
}
