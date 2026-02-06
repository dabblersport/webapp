import 'package:equatable/equatable.dart';

/// Abstract base entity for all domain entities
abstract class BaseEntity extends Equatable {
  /// Unique identifier for the entity
  final String id;

  /// Base constructor requiring an ID
  const BaseEntity({required this.id});

  /// Entities are equal if their IDs are equal
  @override
  List<Object?> get props => [id];

  /// Default string representation
  @override
  String toString() => '$runtimeType(id: $id)';
}
