import 'package:equatable/equatable.dart';

import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// What the game chat screen shows (KAN-507, T12). Loading is the
/// `AsyncLoading` of the controller, not a value here. No copy lives in the
/// view-model: a screen turns [reason] into text through [MessagingL10nKeys].
enum GameChatStatus {
  /// Writable, no messages.
  empty,

  /// Writable, with messages.
  ready,

  /// Visible but closed for sending; [GameChatViewState.reason] says why
  /// (left_read_only, game_ended, game_cancelled).
  readOnly,

  /// Not available to this user (not_in_pilot; D19: "unavailable").
  unavailable,

  /// The user was removed from the game.
  removed,

  /// The request could not be made.
  offline,

  /// Any other typed failure; [GameChatViewState.reason] carries it.
  error,
}

/// The local delivery state of one of the caller's own messages. D8: sent and
/// failed only, no read or delivered ticks.
enum OutgoingState { sending, sent, failed }

/// One row of the thread.
class ChatItem extends Equatable {
  const ChatItem({
    required this.body,
    required this.state,
    this.message,
    this.clientKey,
    this.failureReason,
  });

  /// The server message; null while sending or after a failed send.
  final Message? message;

  /// The idempotency key, for the caller's own sends.
  final String? clientKey;
  final String body;
  final OutgoingState state;

  /// Why a send failed, when [state] is [OutgoingState.failed].
  final MessagingReason? failureReason;

  ChatItem copyWith({
    Message? message,
    OutgoingState? state,
    MessagingReason? failureReason,
  }) => ChatItem(
    body: body,
    clientKey: clientKey,
    message: message ?? this.message,
    state: state ?? this.state,
    failureReason: failureReason,
  );

  @override
  List<Object?> get props => [message, clientKey, body, state, failureReason];
}

class GameChatViewState extends Equatable {
  const GameChatViewState({
    required this.status,
    this.conversation,
    this.items = const [],
    this.reason,
    this.hasOlder = false,
    this.olderCursor,
  });

  final GameChatStatus status;
  final Conversation? conversation;
  final List<ChatItem> items;
  final MessagingReason? reason;
  final bool hasOlder;
  final int? olderCursor;

  /// True while any own message is being sent.
  bool get isSending => items.any((i) => i.state == OutgoingState.sending);

  /// The l10n key for [reason], or null.
  String? get reasonKey =>
      reason == null ? null : MessagingL10nKeys.of(reason!);

  GameChatViewState copyWith({
    GameChatStatus? status,
    List<ChatItem>? items,
    bool? hasOlder,
    int? olderCursor,
  }) => GameChatViewState(
    status: status ?? this.status,
    conversation: conversation,
    items: items ?? this.items,
    reason: reason,
    hasOlder: hasOlder ?? this.hasOlder,
    olderCursor: olderCursor ?? this.olderCursor,
  );

  @override
  List<Object?> get props => [
    status,
    conversation,
    items,
    reason,
    hasOlder,
    olderCursor,
  ];
}

/// l10n key identifiers (not copy) for each typed reason. The ARB entries are
/// a later ticket (T16 + content); these are identifiers only.
abstract final class MessagingL10nKeys {
  static String of(MessagingReason reason) =>
      'messagingReason${_pascal(reason.wireName)}';

  static String _pascal(String snake) => snake
      .split('_')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join();
}
