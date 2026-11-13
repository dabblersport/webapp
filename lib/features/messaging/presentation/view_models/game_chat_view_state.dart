import 'package:equatable/equatable.dart';

import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
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

/// The local delivery state of one of the caller's own messages. [retrying] is
/// a manual Retry in flight (KAN-580). Delivered and seen come from the
/// receipts, not from this state.
enum OutgoingState { sending, retrying, sent, failed }

/// An image of the caller's that is not on the server yet (KAN-581): the
/// picked bytes for the preview, the idempotency key of its upload (reused on
/// a retry so the server returns the same attachment), the attachment id once
/// the upload finished, and the upload progress from 0 to 1.
class PendingImage extends Equatable {
  const PendingImage({
    required this.image,
    required this.uploadKey,
    this.attachmentId,
    this.progress = 0,
  });

  final PickedImage image;
  final String uploadKey;
  final String? attachmentId;
  final double progress;

  PendingImage copyWith({String? attachmentId, double? progress}) =>
      PendingImage(
        image: image,
        uploadKey: uploadKey,
        attachmentId: attachmentId ?? this.attachmentId,
        progress: progress ?? this.progress,
      );

  @override
  List<Object?> get props => [image, uploadKey, attachmentId, progress];
}

/// One row of the thread.
class ChatItem extends Equatable {
  const ChatItem({
    required this.body,
    required this.state,
    this.message,
    this.clientKey,
    this.failureReason,
    this.pending,
  });

  /// KAN-581: set while an image of the caller's is uploading or failed.
  final PendingImage? pending;

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
    PendingImage? pending,
    bool clearPending = false,
  }) => ChatItem(
    body: body,
    clientKey: clientKey,
    message: message ?? this.message,
    state: state ?? this.state,
    failureReason: failureReason,
    pending: clearPending ? null : (pending ?? this.pending),
  );

  @override
  List<Object?> get props => [
    message,
    clientKey,
    body,
    state,
    failureReason,
    pending,
  ];
}

class GameChatViewState extends Equatable {
  const GameChatViewState({
    required this.status,
    this.conversation,
    this.items = const [],
    this.reason,
    this.hasOlder = false,
    this.olderCursor,
    this.dm,
    this.fromCache = false,
  });

  final GameChatStatus status;

  /// True when this thread is the on-device copy shown because the network
  /// failed (KAN-607): read-only, sending refused with the offline line until
  /// a refresh succeeds.
  final bool fromCache;

  /// Set only for a direct message (KAN-556): the counterpart and the DM's
  /// read-only cause. Null for a game chat, whose state is unchanged.
  final DmThreadInfo? dm;

  /// Whether this is a direct message thread.
  bool get isDm => dm != null;
  final Conversation? conversation;
  final List<ChatItem> items;
  final MessagingReason? reason;
  final bool hasOlder;
  final int? olderCursor;

  /// True while any own message is being sent.
  bool get isSending => items.any(
    (i) =>
        i.pending == null &&
        (i.state == OutgoingState.sending ||
            i.state == OutgoingState.retrying),
  );

  /// True when the chat is closed because the game ended or was cancelled
  /// (the typed reason from the repository, never a client rule).
  bool get isClosedByGame =>
      status == GameChatStatus.readOnly &&
      (reason == MessagingReason.gameEnded ||
          reason == MessagingReason.gameCancelled);

  /// Whether the conversation is muted for the caller.
  bool get isMuted => conversation?.muted ?? false;

  /// The l10n key for [reason], or null.
  String? get reasonKey =>
      reason == null ? null : MessagingL10nKeys.of(reason!);

  GameChatViewState copyWith({
    GameChatStatus? status,
    Conversation? conversation,
    List<ChatItem>? items,
    MessagingReason? reason,
    bool? hasOlder,
    int? olderCursor,
    DmThreadInfo? dm,
    bool? fromCache,
  }) => GameChatViewState(
    status: status ?? this.status,
    conversation: conversation ?? this.conversation,
    items: items ?? this.items,
    reason: reason ?? this.reason,
    hasOlder: hasOlder ?? this.hasOlder,
    olderCursor: olderCursor ?? this.olderCursor,
    dm: dm ?? this.dm,
    fromCache: fromCache ?? this.fromCache,
  );

  @override
  List<Object?> get props => [
    status,
    conversation,
    items,
    reason,
    hasOlder,
    olderCursor,
    dm,
    fromCache,
  ];
}

/// Why a direct message cannot be written to (KAN-556). The Worker answers
/// `blocked` for a block in EITHER direction and `suspended` for a deleted or
/// banned counterpart; the direction comes from the app's existing block
/// lists (users I blocked vs blocked either way).
enum DmReadOnlyKind { youBlocked, blockedYou, counterpartGone }

/// The one-to-one part of a DM thread (KAN-556): who the other person is and,
/// when the DM is read-only, why.
class DmThreadInfo extends Equatable {
  const DmThreadInfo({
    this.counterpartUserId,
    this.counterpartName,
    this.counterpartAvatar,
    this.readOnly,
    this.capReached = false,
  });

  final String? counterpartUserId;

  /// The public display name; null or blank means "use the fallback".
  final String? counterpartName;

  /// The avatar reference (`profiles.avatar_url`), may be null.
  final String? counterpartAvatar;

  /// Set when the DM is read-only.
  final DmReadOnlyKind? readOnly;

  /// The request was refused with `dm_cap_reached`.
  final bool capReached;

  DmThreadInfo withReadOnly(DmReadOnlyKind kind) => DmThreadInfo(
    counterpartUserId: counterpartUserId,
    counterpartName: counterpartName,
    counterpartAvatar: counterpartAvatar,
    readOnly: kind,
    capReached: capReached,
  );

  @override
  List<Object?> get props => [
    counterpartUserId,
    counterpartName,
    counterpartAvatar,
    readOnly,
    capReached,
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
