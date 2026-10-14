import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// The game chat of one game (arg: game id). Loading is `AsyncLoading`; every
/// failure becomes a [GameChatViewState] status, never an exception.
class GameChatController
    extends FamilyAsyncNotifier<GameChatViewState, String> {
  MessagingRepository get _repo => ref.read(messagingRepositoryProvider);

  @override
  Future<GameChatViewState> build(String arg) async {
    final conv = await _repo.getGameConversation(arg);
    if (conv is Err<Conversation, Failure>) return failureState(conv.error);
    final conversation = conv.requireValue;
    final page = await _repo.listMessages(conversationId: conversation.id);
    if (page is Err) return failureState(page.requireError);
    final p = page.requireValue;
    final items = [for (final m in p.messages) _sent(m)];
    return GameChatViewState(
      status: _openStatus(conversation, items),
      conversation: conversation,
      items: items,
      reason: conversation.writable ? null : conversation.readOnlyReason,
      hasOlder: p.hasOlder,
      olderCursor: p.olderCursor,
    );
  }

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
    _replace(clientKey, item.copyWith(state: OutgoingState.sending));
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
      (failure) => _replace(
        key,
        item.copyWith(
          state: OutgoingState.failed,
          failureReason: failure is MessagingFailure
              ? failure.reason
              : MessagingReason.unknown,
        ),
      ),
      (message) => _replace(
        key,
        item.copyWith(message: message, state: OutgoingState.sent),
      ),
    );
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
    if (result is Err) return false;
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
      ),
    );
    return true;
  }

  /// Polling refresh (no Realtime): fetches the newest page and adds the
  /// messages not yet shown, by `seq`. Own messages still in flight or failed
  /// are kept at the end. A failed poll changes nothing.
  Future<void> refreshNewest() async {
    final current = state.valueOrNull;
    final conversation = current?.conversation;
    if (current == null || conversation == null) return;
    final result = await _repo.listMessages(conversationId: conversation.id);
    if (result is Err) return;
    final latest = state.valueOrNull;
    if (latest == null) return;
    final known = <String>{
      for (final i in latest.items)
        if (i.message != null) i.message!.id,
    };
    final fresh = [
      for (final m in result.requireValue.messages)
        if (!known.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return;
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
  }
}
