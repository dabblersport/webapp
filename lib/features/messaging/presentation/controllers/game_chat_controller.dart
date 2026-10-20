import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// The game chat of one game (arg: game id). Loading is `AsyncLoading`; every
/// failure becomes a [GameChatViewState] status, never an exception.
class GameChatController
    extends FamilyAsyncNotifier<GameChatViewState, String> {
  MessagingRepository get _repo => ref.read(messagingRepositoryProvider);

  @override
  Future<GameChatViewState> build(String arg) async {
    _listenForWakes();
    return open(arg);
  }

  /// Resolves the conversation for [arg] (here: the game id) and opens it.
  /// The DM thread (KAN-556) overrides this to resolve a DM by its id.
  @protected
  Future<GameChatViewState> open(String arg) async {
    final conv = await _repo.getGameConversation(arg);
    if (conv is Err<Conversation, Failure>) return failureFor(conv.error);
    return openConversation(conv.requireValue);
  }

  /// Loads the newest page of [conversation]; [dm] is carried for a DM.
  @protected
  Future<GameChatViewState> openConversation(
    Conversation conversation, {
    DmThreadInfo? dm,
  }) async {
    final page = await _repo.listMessages(conversationId: conversation.id);
    if (page is Err) return failureFor(page.requireError);
    final p = page.requireValue;
    final items = [for (final m in p.messages) _sent(m)];
    return GameChatViewState(
      status: _openStatus(conversation, items),
      conversation: conversation,
      items: items,
      reason: conversation.writable ? null : conversation.readOnlyReason,
      hasOlder: p.hasOlder,
      olderCursor: p.olderCursor,
      dm: dm,
    );
  }

  /// The screen state of a failed open; [failureState] for a game chat.
  @protected
  GameChatViewState failureFor(Failure failure) => failureState(failure);

  /// Maps a failure to its screen state.
  static GameChatViewState failureState(Failure failure) {
    final reason = failure is MessagingFailure
        ? failure.reason
        : MessagingReason.unknown;
    final status = switch (reason) {
      MessagingReason.notInPilot => GameChatStatus.unavailable,
      MessagingReason.removed => GameChatStatus.removed,
      MessagingReason.offline => GameChatStatus.offline,
      MessagingReason.leftReadOnly ||
      MessagingReason.gameEnded ||
      MessagingReason.gameCancelled => GameChatStatus.readOnly,
      _ => GameChatStatus.error,
    };
    return GameChatViewState(status: status, reason: reason);
  }

  /// A later call refused with `removed` ends access: the thread, composer
  /// and any cached messages are dropped (T6 spec 03). Returns whether it did.
  bool _endIfRemoved(Failure failure) {
    if (failure is! MessagingFailure ||
        failure.reason != MessagingReason.removed) {
      return false;
    }
    state = AsyncData(failureState(failure));
    return true;
  }

  static GameChatStatus _openStatus(Conversation c, List<ChatItem> items) {
    if (!c.writable) return GameChatStatus.readOnly;
    return items.isEmpty ? GameChatStatus.empty : GameChatStatus.ready;
  }

  static ChatItem _sent(Message m) => ChatItem(
    message: m,
    clientKey: m.clientKey,
    body: m.body,
    state: OutgoingState.sent,
  );

  /// Sends [body] with a new idempotency key.
  Future<void> send(String body) async {
    final key = ref.read(messagingClientKeyGeneratorProvider)();
    final current = state.valueOrNull;
    if (current == null || current.conversation == null) return;
    state = AsyncData(
      current.copyWith(
        status: GameChatStatus.ready,
        items: [
          ...current.items,
          ChatItem(body: body, clientKey: key, state: OutgoingState.sending),
        ],
      ),
    );
    await _deliver(key, body);
  }

  /// Retries a failed send with the SAME key, so it cannot duplicate.
  Future<void> retry(String clientKey) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final item = current.items
        .where((i) => i.clientKey == clientKey)
        .firstOrNull;
    if (item == null || item.state != OutgoingState.failed) return;
    _replace(clientKey, item.copyWith(state: OutgoingState.retrying));
    await _deliver(clientKey, item.body);
  }

  Future<void> _deliver(String key, String body) async {
    final conversationId = state.valueOrNull?.conversation?.id;
    if (conversationId == null) return;
    final result = await _repo.sendTextMessage(
      conversationId: conversationId,
      body: body,
      idempotencyKey: key,
    );
    final item = state.valueOrNull?.items
        .where((i) => i.clientKey == key)
        .firstOrNull;
    if (item == null) return;
    result.fold(
      (failure) {
        if (_endIfRemoved(failure)) return;
        final reason = failure is MessagingFailure
            ? failure.reason
            : MessagingReason.unknown;
        _replace(
          key,
          item.copyWith(state: OutgoingState.failed, failureReason: reason),
        );
        onSendRefused(reason);
      },
      (message) => _replace(
        key,
        item.copyWith(message: message, state: OutgoingState.sent),
      ),
    );
  }

  /// A send refused because the game ended or was cancelled closes the
  /// chat: the repository's typed reason decides, not a client rule.
  @protected
  void onSendRefused(MessagingReason reason) {
    if (reason == MessagingReason.gameEnded ||
        reason == MessagingReason.gameCancelled) {
      closeChat(reason);
    }
  }

  /// Makes the chat read-only for [reason]; reads keep working.
  @protected
  void closeChat(MessagingReason reason) {
    final current = state.valueOrNull;
    final c = current?.conversation;
    if (current == null || c == null) return;
    state = AsyncData(
      current.copyWith(
        status: GameChatStatus.readOnly,
        reason: reason,
        conversation: copyConversation(
          c,
          writable: false,
          readOnlyReason: reason,
        ),
      ),
    );
  }

  /// [c] with the given fields replaced.
  static Conversation copyConversation(
    Conversation c, {
    bool? writable,
    bool? muted,
    MessagingReason? readOnlyReason,
  }) => Conversation(
    id: c.id,
    gameId: c.gameId,
    writable: writable ?? c.writable,
    muted: muted ?? c.muted,
    lastSeq: c.lastSeq,
    readOnlyReason: readOnlyReason ?? c.readOnlyReason,
    boundary: c.boundary,
  );

  /// Mutes or unmutes the conversation (conversation-level; there is no
  /// leave, D6). Returns false when the repository refused; the state is
  /// unchanged then.
  Future<bool> setMuted(bool muted) async {
    final c = state.valueOrNull?.conversation;
    if (c == null) return false;
    final result = muted
        ? await _repo.muteConversation(c.id)
        : await _repo.unmuteConversation(c.id);
    if (result is Err) return false;
    final latest = state.valueOrNull;
    final lc = latest?.conversation;
    if (latest == null || lc == null) return true;
    state = AsyncData(
      latest.copyWith(conversation: copyConversation(lc, muted: muted)),
    );
    return true;
  }

  /// Reports [messageId] with [reason]. Returns whether it was accepted.
  Future<bool> report(String messageId, ReportCategory reason) async {
    final result = await _repo.reportMessage(
      messageId: messageId,
      reason: reason,
    );
    return result is! Err;
  }

  void _replace(String key, ChatItem replacement) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final i in current.items)
            if (i.clientKey == key) replacement else i,
        ],
      ),
    );
  }

  /// Loads the page below the oldest loaded message. Returns false when the
  /// page could not be loaded (the pager shows its error state).
  Future<bool> loadOlder() async {
    final current = state.valueOrNull;
    final conversation = current?.conversation;
    if (current == null || conversation == null || !current.hasOlder) {
      return true;
    }
    final result = await _repo.listMessages(
      conversationId: conversation.id,
      cursor: current.olderCursor,
    );
    if (result is Err) {
      _endIfRemoved(result.requireError);
      return false;
    }
    final page = result.requireValue;
    final latest = state.valueOrNull ?? current;
    state = AsyncData(
      GameChatViewState(
        status: latest.status,
        conversation: latest.conversation ?? conversation,
        reason: latest.reason,
        items: [for (final m in page.messages) _sent(m), ...latest.items],
        hasOlder: page.hasOlder,
        olderCursor: page.olderCursor,
        dm: latest.dm,
      ),
    );
    return true;
  }

  /// Polling refresh: fetches the newest page and adds the messages not yet
  /// shown, by `seq`. Own messages still in flight or failed are kept at the
  /// end. A failed poll changes nothing. Also the catch-up fetch on a
  /// (re)subscribe and on app resume (KAN-544).
  Future<void> refreshNewest() async {
    final current = state.valueOrNull;
    final conversation = current?.conversation;
    if (current == null || conversation == null) return;
    final result = await _repo.listMessages(conversationId: conversation.id);
    if (result is Err) {
      _endIfRemoved(result.requireError);
      return;
    }
    _mergeFresh(result.requireValue.messages);
  }

  // ---------------------------------------------------------------- Realtime
  // KAN-544. A wake is a HINT (conversation id and seq, never text); polling
  // stays the source of truth. With Realtime off the channel is null and none
  // of this runs.

  Timer? _syncRetry;
  Future<void> _fetching = Future<void>.value();
  bool _open = false;

  /// The screen tells the controller whether the chat is on screen. Wakes and
  /// the catch-up on resubscribe act only while it is open: a closed chat
  /// fetches nothing (the poll timer lives in the screen and stops with it).
  void setOpen(bool open) {
    _open = open;
    if (!open) _syncRetry?.cancel();
  }

  StreamSubscription<MessagingWake>? _wakeSub;
  StreamSubscription<WakeChannelStatus>? _statusSub;

  /// Follows the user's channel without rebuilding the chat: when the channel
  /// appears, changes (another user) or goes away (sign-out) only the
  /// subscriptions move; the loaded messages stay.
  void _listenForWakes() {
    ref.listen<WakeChannel?>(
      messagingWakeChannelProvider,
      (_, channel) => _bind(channel),
      fireImmediately: true,
    );
    ref.onDispose(() {
      _wakeSub?.cancel();
      _statusSub?.cancel();
      _syncRetry?.cancel();
    });
  }

  void _bind(WakeChannel? channel) {
    _wakeSub?.cancel();
    _statusSub?.cancel();
    _wakeSub = null;
    _statusSub = null;
    if (channel == null) return;
    var subscribed = channel.status == WakeChannelStatus.subscribed;
    _wakeSub = channel.wakes.listen(_onWake);
    _statusSub = channel.statuses.listen((status) {
      final now = status == WakeChannelStatus.subscribed;
      // One catch-up fetch on every (re)subscribe.
      if (now && !subscribed && _open) unawaited(refreshNewest());
      subscribed = now;
    });
  }

  int get _maxSeq {
    var max = 0;
    for (final i in state.valueOrNull?.items ?? const <ChatItem>[]) {
      final m = i.message;
      if (m != null) max = math.max(max, m.seq);
    }
    return max;
  }

  void _onWake(MessagingWake wake) {
    if (!_open) return; // the chat is closed: nothing to do
    final conversation = state.valueOrNull?.conversation;
    // Another conversation: nothing to do.
    if (conversation == null || wake.conversationId != conversation.id) return;
    final seq = wake.seq;
    if (seq != null) {
      if (seq <= _maxSeq) return; // already have it
      _enqueue(() => _fetchNewer());
      return;
    }
    // A seq-less (`sync`) wake: fetch now; if that found nothing, once more
    // after a short delay.
    _enqueue(() async {
      final added = await _fetchNewer();
      if (added > 0) return;
      _syncRetry?.cancel();
      _syncRetry = Timer(ref.read(messagingSyncRetryDelayProvider), () {
        _enqueue(() => _fetchNewer());
      });
    });
  }

  /// Runs fetches one after another, so two wakes never overlap.
  void _enqueue(Future<void> Function() job) {
    _fetching = _fetching
        .then<void>((_) => job())
        .then<void>((_) {}, onError: (Object _) {});
  }

  /// Fetches what is newer than the client's highest seq through the existing
  /// list call, into the existing merge path. Returns how many messages were
  /// added.
  Future<int> _fetchNewer() async {
    final conversation = state.valueOrNull?.conversation;
    if (conversation == null) return 0;
    var cursor = _maxSeq;
    var added = 0;
    for (var page = 0; page < 5; page++) {
      final Result<MessagePage, Failure> result;
      if (cursor == 0) {
        result = await _repo.listMessages(conversationId: conversation.id);
      } else {
        result = await _repo.listMessages(
          conversationId: conversation.id,
          cursor: cursor,
          direction: MessageDirection.newer,
        );
      }
      if (result is Err) {
        _endIfRemoved(result.requireError);
        return added;
      }
      final p = result.requireValue;
      added += _mergeFresh(p.messages);
      final next = p.newerCursor;
      if (!p.hasNewer || next == null || next <= cursor) break;
      cursor = next;
    }
    return added;
  }

  /// Adds the messages not yet shown, ordered by `seq`; returns how many were
  /// new. The one merge path of polling and wakes.
  int _mergeFresh(List<Message> messages) {
    final latest = state.valueOrNull;
    if (latest == null) return 0;
    final known = <String>{
      for (final i in latest.items)
        if (i.message != null) i.message!.id,
    };
    final fresh = [
      for (final m in messages)
        if (!known.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return 0;
    final delivered = [
      for (final i in latest.items)
        if (i.message != null) i,
      for (final m in fresh)
        // A message that is the server copy of a pending own send replaces
        // that pending row instead of duplicating it.
        if (!latest.items.any(
          (i) =>
              i.message == null &&
              i.clientKey != null &&
              i.clientKey == m.clientKey,
        ))
          _sent(m),
    ]..sort((a, b) => a.message!.seq.compareTo(b.message!.seq));
    final pending = [
      for (final i in latest.items)
        if (i.message == null) i,
    ];
    state = AsyncData(
      latest.copyWith(
        status: latest.status == GameChatStatus.empty
            ? GameChatStatus.ready
            : latest.status,
        items: [...delivered, ...pending],
      ),
    );
    return fresh.length;
  }
}
