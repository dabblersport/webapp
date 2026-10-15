import 'package:equatable/equatable.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The caller's state in one of their game chats, as `msg_my_conversations`
/// (KAN-547) derives it at call time.
enum MyConversationState {
  /// Active member of a game that is neither cancelled nor ended.
  send('send'),

  /// Active member of a cancelled or ended game.
  readOnly('read_only'),

  /// The caller left the game.
  left('left');

  const MyConversationState(this.wireName);

  final String wireName;

  /// The state for [name]; null when unrecognised.
  static MyConversationState? fromWire(Object? name) {
    for (final s in values) {
      if (s.wireName == name) return s;
    }
    return null;
  }
}

/// One row of the Messages list (KAN-549): a game chat the signed-in user is
/// (or was) a member of. Field names follow the `msg_my_conversations` RPC
/// (`supabase/migrations/20261013160800_kan547_msg_my_conversations.sql`).
/// No message content, sender names or unread counts exist on it by design.
class MyConversation extends Equatable {
  const MyConversation({
    required this.conversationId,
    required this.gameId,
    required this.state,
    this.title,
    this.sport,
    this.startAt,
    this.endAt,
    this.lastActivityAt,
  });

  final String conversationId;
  final String gameId;

  /// The game's title; null or blank means "build one from the sport".
  final String? title;

  /// The sport's key (e.g. `football`); may be null or unknown.
  final String? sport;
  final DateTime? startAt;
  final DateTime? endAt;
  final MyConversationState state;
  final DateTime? lastActivityAt;

  /// Parses one RPC row. A malformed payload is a [Failure], never a throw:
  /// the two ids must be non-empty strings and `state` a known value; every
  /// other field is optional and a wrong type or bad date reads as null.
  static Result<MyConversation, Failure> parse(Object? json) {
    if (json is! Map) return _malformed();
    final id = json['conversation_id'];
    final gameId = json['game_id'];
    final state = MyConversationState.fromWire(json['state']);
    if (id is! String || id.isEmpty || gameId is! String || gameId.isEmpty) {
      return _malformed();
    }
    if (state == null) return _malformed();
    final title = json['game_title'];
    final sport = json['sport'];
    return Ok(
      MyConversation(
        conversationId: id,
        gameId: gameId,
        state: state,
        title: title is String ? title : null,
        sport: sport is String ? sport : null,
        startAt: _date(json['start_at']),
        endAt: _date(json['end_at']),
        lastActivityAt: _date(json['last_activity_at']),
      ),
    );
  }

  /// Parses the RPC's row list, keeping its order. Any malformed row makes
  /// the whole result a [Failure].
  static Result<List<MyConversation>, Failure> parseList(Object? json) {
    if (json is! List) return _malformed();
    final out = <MyConversation>[];
    for (final row in json) {
      final parsed = parse(row);
      if (parsed is Err<MyConversation, Failure>) {
        return Err(parsed.error);
      }
      out.add(parsed.requireValue);
    }
    return Ok(List.unmodifiable(out));
  }

  static Err<T, Failure> _malformed<T>() => Err(
    MessagingFailure(
      reason: MessagingReason.unknown,
      message: 'Malformed my-conversations payload',
    ),
  );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'game_id': gameId,
    'game_title': title,
    'sport': sport,
    'start_at': startAt?.toIso8601String(),
    'end_at': endAt?.toIso8601String(),
    'state': state.wireName,
    'last_activity_at': lastActivityAt?.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    conversationId,
    gameId,
    title,
    sport,
    startAt,
    endAt,
    state,
    lastActivityAt,
  ];
}
