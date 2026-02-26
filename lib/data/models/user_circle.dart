/// Domain models for named user circles (curated follower groups).
///
/// Uses plain Dart classes (no code-gen required).
library;

// ─────────────────────────────────────────────────────────────────────────────
// UserCircle
// ─────────────────────────────────────────────────────────────────────────────

class UserCircle {
  const UserCircle({
    required this.id,
    required this.name,
    required this.ownerProfileId,
    this.memberCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;

  /// Owner profile id (profiles.id).
  ///
  /// Note: Supabase schema uses `circles.owner_profile_id`.
  final String ownerProfileId;
  final int memberCount;
  final DateTime? createdAt;

  factory UserCircle.fromJson(Map<String, dynamic> json) => UserCircle(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerProfileId:
        (json['owner_profile_id'] ?? json['owner_user_id'] ?? '') as String,
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'owner_profile_id': ownerProfileId,
    'member_count': memberCount,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  UserCircle copyWith({
    String? id,
    String? name,
    String? ownerProfileId,
    int? memberCount,
    DateTime? createdAt,
  }) => UserCircle(
    id: id ?? this.id,
    name: name ?? this.name,
    ownerProfileId: ownerProfileId ?? this.ownerProfileId,
    memberCount: memberCount ?? this.memberCount,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCircle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserCircle(id: $id, name: $name, members: $memberCount)';
}

// ─────────────────────────────────────────────────────────────────────────────
// CircleMember
// ─────────────────────────────────────────────────────────────────────────────

class CircleMember {
  const CircleMember({
    required this.profileId,
    this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.addedAt,
  });

  final String profileId;
  final String? userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime? addedAt;

  /// Parses from a `user_circle_members` row joined with profiles.
  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
    profileId:
        (json['member_profile_id'] ??
                json['profile_id'] ??
                json['friend_profile_id'] ??
                '')
            as String,
    userId:
        (json['member_user_id'] ?? json['user_id'] ?? json['friend_user_id'])
            as String?,
    displayName: json['display_name'] as String?,
    username: json['username'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    addedAt: json['added_at'] != null
        ? DateTime.tryParse(json['added_at'] as String)
        : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleMember &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId;

  @override
  int get hashCode => profileId.hashCode;

  @override
  String toString() =>
      'CircleMember(profileId: $profileId, name: $displayName)';
}
