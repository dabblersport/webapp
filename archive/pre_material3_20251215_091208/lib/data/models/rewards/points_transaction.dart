import 'package:dabbler/features/core/entities/base_entity.dart';

/// Entity representing a points transaction (earning or spending)
class PointsTransaction extends BaseEntity {
  final String userId;
  final int points;
  final PointsTransactionType type;
  final String reason;
  final String? sourceId; // ID of the achievement, purchase, etc.
  final String? sourceType; // 'achievement', 'purchase', 'bonus', etc.
  final DateTime createdAt;

  const PointsTransaction({
    required super.id,
    required this.userId,
    required this.points,
    required this.type,
    required this.reason,
    this.sourceId,
    this.sourceType,
    required this.createdAt,
  });

  /// Compatibility alias used by some services expecting `finalPoints` (see PointTransaction model).
  int get finalPoints => points;

  @override
  List<Object?> get props => [
    id,
    userId,
    points,
    type,
    reason,
    sourceId,
    sourceType,
    createdAt,
  ];

  @override
  String toString() {
    return 'PointsTransaction('
        'id: $id, '
        'userId: $userId, '
        'points: $points, '
        'type: $type, '
        'reason: $reason, '
        'sourceId: $sourceId, '
        'sourceType: $sourceType, '
        'createdAt: $createdAt'
        ')';
  }

  /// Create a copy of this transaction with updated values
  PointsTransaction copyWith({
    String? id,
    String? userId,
    int? points,
    PointsTransactionType? type,
    String? reason,
    String? sourceId,
    String? sourceType,
    DateTime? createdAt,
  }) {
    return PointsTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      points: points ?? this.points,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for storage/transport
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'points': points,
      'type': type.name,
      'reason': reason,
      'source_id': sourceId,
      'source_type': sourceType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON data
  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      points: json['points'] as int,
      type: PointsTransactionType.values.firstWhere(
        (type) => type.name == json['type'],
      ),
      reason: json['reason'] as String,
      sourceId: json['source_id'] as String?,
      sourceType: json['source_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Types of points transactions
enum PointsTransactionType { earned, spent, bonus, penalty }

/// Extension for points transaction type display
extension PointsTransactionTypeExtension on PointsTransactionType {
  String get displayName {
    switch (this) {
      case PointsTransactionType.earned:
        return 'Earned';
      case PointsTransactionType.spent:
        return 'Spent';
      case PointsTransactionType.bonus:
        return 'Bonus';
      case PointsTransactionType.penalty:
        return 'Penalty';
    }
  }

  String get description {
    switch (this) {
      case PointsTransactionType.earned:
        return 'Points earned from activities';
      case PointsTransactionType.spent:
        return 'Points spent on rewards';
      case PointsTransactionType.bonus:
        return 'Bonus points awarded';
      case PointsTransactionType.penalty:
        return 'Points deducted';
    }
  }

  bool get isPositive {
    switch (this) {
      case PointsTransactionType.earned:
      case PointsTransactionType.bonus:
        return true;
      case PointsTransactionType.spent:
      case PointsTransactionType.penalty:
        return false;
    }
  }
}
