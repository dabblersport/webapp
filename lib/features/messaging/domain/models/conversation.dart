import 'package:equatable/equatable.dart';

import 'package:dabbler/features/messaging/domain/models/view_boundary.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The chat of one game, as the caller may use it (`components.schemas.Conversation`).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.gameId,
    required this.writable,
    required this.muted,
    required this.lastSeq,
    this.readOnlyReason,
    this.boundary,
  });

  final String id;
  final String gameId;

  /// True iff the caller may send now: the game is not cancelled, its `end_at`
  /// has not passed, and the caller is still an active member.
  final bool writable;

  /// Why [writable] is false: leftReadOnly, gameEnded or gameCancelled. Null
  /// when writable (an unrecognised value is [MessagingReason.unknown]).
  final MessagingReason? readOnlyReason;

  /// A limit on what the caller may view (a member who left), or null.
  final ViewBoundary? boundary;

  final bool muted;

  /// The highest `seq` the caller may view (0 when none).
  final int lastSeq;

  /// Throws [FormatException] on a malformed payload; the repository
  /// implementation catches it and returns a failure.
  factory Conversation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final gameId = json['game_id'];
    final writable = json['writable'];
    final muted = json['muted'];
    final lastSeq = json['last_seq'];
    if (id is! String ||
        gameId is! String ||
        writable is! bool ||
        muted is! bool ||
        lastSeq is! int) {
      throw const FormatException('Malformed conversation payload');
    }
    final reason = json['read_only_reason'];
    return Conversation(
      id: id,
      gameId: gameId,
      writable: writable,
      muted: muted,
      lastSeq: lastSeq,
      readOnlyReason: reason is String
          ? MessagingReason.fromWire(reason)
          : null,
      boundary: ViewBoundary.tryFromJson(json['boundary']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': 'game',
    'game_id': gameId,
    'writable': writable,
    'read_only_reason': readOnlyReason?.wireName,
    'boundary': boundary?.toJson(),
    'muted': muted,
    'last_seq': lastSeq,
  };

  @override
  List<Object?> get props => [
    id,
    gameId,
    writable,
    readOnlyReason,
    boundary,
    muted,
    lastSeq,
  ];
}
