import '../../../../utils/enums/social_enums.dart';

/// Domain entity for reactions
class Reaction {
  final String id;
  final String userId;
  final String targetId;
  final ReactionTargetType targetType;
  final ReactionType reactionType;
  final DateTime createdAt;

  const Reaction({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.reactionType,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reaction && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for reaction target types
enum ReactionTargetType { post, comment, profile, message }
