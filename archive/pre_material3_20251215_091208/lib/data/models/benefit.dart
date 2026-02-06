import 'package:meta/meta.dart';

@immutable
class Benefit {
  final String? id;
  final String? ownerUserId;
  final String? venueId;
  final String title;
  final String? description;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Benefit({
    required this.id,
    required this.ownerUserId,
    required this.venueId,
    required this.title,
    required this.description,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  static bool _bool(dynamic v, {bool def = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return def;
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory Benefit.fromMap(Map<String, dynamic> m) => Benefit(
    id: m['id']?.toString(),
    ownerUserId: m['owner_user_id']?.toString() ?? m['ownerId']?.toString(),
    venueId: m['venue_id']?.toString(),
    title: (m['title'] ?? m['name'] ?? '').toString(),
    description: m['description']?.toString(),
    isActive: _bool(m['is_active'] ?? m['active'] ?? true, def: true),
    startsAt: _dt(m['starts_at']),
    endsAt: _dt(m['ends_at']),
    imageUrl: m['image_url']?.toString(),
    createdAt: _dt(m['created_at']),
    updatedAt: _dt(m['updated_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'venue_id': venueId,
    'title': title,
    'description': description,
    'is_active': isActive,
    'starts_at': startsAt?.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'image_url': imageUrl,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Use for inserts (omit id/created/updated).
  Map<String, dynamic> toInsertMap() => {
    'owner_user_id': ownerUserId,
    'venue_id': venueId,
    'title': title,
    'description': description,
    'is_active': isActive,
    'starts_at': startsAt?.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'image_url': imageUrl,
  };

  /// Use for updates (only non-null fields are applied).
  Map<String, dynamic> toPatchMap() {
    final m = <String, dynamic>{};
    void put(String k, dynamic v) {
      if (v != null) m[k] = v;
    }

    put('owner_user_id', ownerUserId);
    put('venue_id', venueId);
    put('title', title);
    put('description', description);
    put('is_active', isActive);
    put('starts_at', startsAt?.toIso8601String());
    put('ends_at', endsAt?.toIso8601String());
    put('image_url', imageUrl);
    return m;
  }
}
