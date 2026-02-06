import 'post.dart';

/// Domain entity for conversations
class Conversation {
  final String id;
  final ConversationType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final bool isActive;

  const Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.description,
    this.avatarUrl,
    this.isActive = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
