import 'package:equatable/equatable.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The caller's state in one of their conversations, as `msg_my_conversations`
/// (KAN-547, KAN-555) derives it at call time.
enum MyConversationState {
  /// Active member of a game that is neither cancelled nor ended.
  send('send'),

  /// Active member of a cancelled or ended game; for a DM, either user
  /// blocked the other or the counterpart is deleted or banned.
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

/// What a Messages list row is (KAN-562): the `kind` column of
/// `msg_my_conversations` v2 (KAN-555).
enum MyConversationKind {
  game('game'),
  dm('dm'),

  /// A meetup chat (KAN-558/KAN-559): title, sport and times come from the
  /// meetup; the RPC's `game_id` column carries the meetup id (read into
  /// [MyConversation.meetupId]); there is no game id and no counterpart.
  meetup('meetup');

  const MyConversationKind(this.wireName);

  final String wireName;

  /// The kind for [name]; null when unrecognised.
  static MyConversationKind? fromWire(Object? name) {
    for (final k in values) {
      if (k.wireName == name) return k;
    }
    return null;
  }
}

/// One row of the Messages list (KAN-549, KAN-562): a game chat or a direct
/// message the signed-in user is (or was) a member of. Field names follow the
/// `msg_my_conversations` RPC (v1
/// `supabase/migrations/20261013160800_kan547_msg_my_conversations.sql`, v2
/// `20261013161000_kan555_msg_my_conversations_dm.sql`). No message content,
/// sender names or unread counts exist on it by design.
class MyConversation extends Equatable {
  const MyConversation({
    required this.conversationId,
    required this.state,
    this.gameId,
    this.meetupId,
    this.kind = MyConversationKind.game,
    this.title,
    this.sport,
    this.startAt,
    this.endAt,
    this.lastActivityAt,
    this.counterpartUserId,
    this.counterpartName,
    this.counterpartAvatar,
    this.muted = false,
  });

  final String conversationId;

  /// The game; always set on a game row, null on a DM row.
  final String? gameId;

  /// Meetup rows only: the meetup id, which the RPC returns in its
  /// `game_id` column for `kind = meetup` (KAN-559). Null on an older row
  /// that carried none, and always null on game and DM rows.
  final String? meetupId;

  /// Game chat or DM. A v1 row without `kind` is a game row.
  final MyConversationKind kind;

  /// DM only: the other member's user id.
  final String? counterpartUserId;

  /// DM only: their public display name; null means "use the fallback".
  final String? counterpartName;

  /// DM only: their avatar reference (`profiles.avatar_url`); may be null.
  final String? counterpartAvatar;

  /// Whether the caller muted this conversation.
  final bool muted;

  bool get isDm => kind == MyConversationKind.dm;

  /// A meetup chat row (KAN-559).
  bool get isMeetup => kind == MyConversationKind.meetup;

  /// A DM that cannot be written to: either user blocked the other, or the
  /// counterpart is deleted or banned (the RPC's `read_only` for a DM).
  bool get isDmReadOnly => isDm && state == MyConversationState.readOnly;

  /// The game's title; null or blank means "build one from the sport".
  final String? title;

  /// The sport's key (e.g. `football`); may be null or unknown.
  final String? sport;
  final DateTime? startAt;
  final DateTime? endAt;
  final MyConversationState state;
  final DateTime? lastActivityAt;

  /// Parses one RPC row. A malformed payload is a [Failure], never a throw:
  /// `conversation_id` must be a non-empty string and `state` a known value;
  /// `kind` is `game` (or absent, a v1 row) or `dm`, any other value is
  /// malformed; a game row needs a non-empty `game_id`, a DM row a non-empty
  /// `counterpart_user_id`. Every other field is optional and a wrong type or
  /// bad date reads as null (`muted` as false).
  static Result<MyConversation, Failure> parse(Object? json) {
    if (json is! Map) return _malformed();
    final id = json['conversation_id'];
    final state = MyConversationState.fromWire(json['state']);
    if (id is! String || id.isEmpty || state == null) return _malformed();
    final rawKind = json['kind'];
    final kind = rawKind == null
        ? MyConversationKind.game
        : MyConversationKind.fromWire(rawKind);
    if (kind == null) return _malformed();
    final gameId = json['game_id'];
    final counterpart = json['counterpart_user_id'];
    switch (kind) {
      case MyConversationKind.game:
        if (gameId is! String || gameId.isEmpty) return _malformed();
      case MyConversationKind.dm:
        if (counterpart is! String || counterpart.isEmpty) return _malformed();
      case MyConversationKind.meetup:
        // KAN-559: `game_id` carries the meetup id. Optional, so a row from
        // before that migration (no id) still parses.
        break;
    }
    String? str(Object? v) => v is String ? v : null;
    return Ok(
      MyConversation(
        conversationId: id,
        kind: kind,
        gameId: kind == MyConversationKind.meetup ? null : str(gameId),
        meetupId: kind == MyConversationKind.meetup && str(gameId) != ''
            ? str(gameId)
            : null,
        state: state,
        title: str(json['game_title']),
        sport: str(json['sport']),
        startAt: _date(json['start_at']),
        endAt: _date(json['end_at']),
        lastActivityAt: _date(json['last_activity_at']),
        counterpartUserId: str(counterpart),
        counterpartName: str(json['counterpart_name']),
        counterpartAvatar: str(json['counterpart_avatar']),
        muted: json['muted'] == true,
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
    'game_id': isMeetup ? meetupId : gameId,
    'game_title': title,
    'sport': sport,
    'start_at': startAt?.toIso8601String(),
    'end_at': endAt?.toIso8601String(),
    'state': state.wireName,
    'last_activity_at': lastActivityAt?.toIso8601String(),
    'kind': kind.wireName,
    'counterpart_user_id': counterpartUserId,
    'counterpart_name': counterpartName,
    'counterpart_avatar': counterpartAvatar,
    'muted': muted,
  };

  @override
  List<Object?> get props => [
    conversationId,
    gameId,
    meetupId,
    title,
    sport,
    startAt,
    endAt,
    state,
    lastActivityAt,
    kind,
    counterpartUserId,
    counterpartName,
    counterpartAvatar,
    muted,
  ];
}
