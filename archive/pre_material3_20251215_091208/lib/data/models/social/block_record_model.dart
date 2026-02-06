/// Data model representing a block record
class BlockRecordModel {
  final String id;
  final String blockingUserId;
  final String blockedUserId;
  final String? reason;
  final String blockType; // 'full', 'partial', 'temporary'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;

  const BlockRecordModel({
    required this.id,
    required this.blockingUserId,
    required this.blockedUserId,
    this.reason,
    this.blockType = 'full',
    required this.createdAt,
    this.expiresAt,
    this.metadata,
  });

  /// Create BlockRecordModel from JSON
  factory BlockRecordModel.fromJson(Map<String, dynamic> json) {
    return BlockRecordModel(
      id: json['id'] as String,
      blockingUserId: json['blocking_user_id'] as String,
      blockedUserId: json['blocked_user_id'] as String,
      reason: json['reason'] as String?,
      blockType: json['block_type'] as String? ?? 'full',
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert BlockRecordModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blocking_user_id': blockingUserId,
      'blocked_user_id': blockedUserId,
      'reason': reason,
      'block_type': blockType,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  BlockRecordModel copyWith({
    String? id,
    String? blockingUserId,
    String? blockedUserId,
    String? reason,
    String? blockType,
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) {
    return BlockRecordModel(
      id: id ?? this.id,
      blockingUserId: blockingUserId ?? this.blockingUserId,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      reason: reason ?? this.reason,
      blockType: blockType ?? this.blockType,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockRecordModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BlockRecordModel{id: $id, blockingUserId: $blockingUserId, blockedUserId: $blockedUserId, blockType: $blockType}';
  }
}
