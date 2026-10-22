import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/chat_cache.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_image_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_attachment.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
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
    return _withCache(await open(arg));
  }

  /// The cache key of this thread's on-device copy (KAN-607).
  @protected
  String cacheKey(String arg) => ChatCache.gameThreadKey(arg);

  /// A thread that opened is stored (newest [ChatCache.maxMessagesPerThread]
  /// messages); one that could not be reached answers from the stored copy;
  /// one the server closed to this account (removed, unavailable) drops it.
  Future<GameChatViewState> _withCache(GameChatViewState fresh) async {
    final account = ref.read(cacheAccountIdProvider);
    if (account == null) return fresh;
    final cache = ChatCache(ref.read(offlineCacheProvider), account);
    final key = cacheKey(arg);
    switch (fresh.status) {
      case GameChatStatus.ready:
      case GameChatStatus.empty:
      case GameChatStatus.readOnly:
        if (fresh.conversation != null) unawaited(cache.saveThread(key, fresh));
      case GameChatStatus.unavailable:
      case GameChatStatus.removed:
        unawaited(cache.removeThread(key));
      case GameChatStatus.offline:
        return await cache.loadThread(key) ?? fresh;
      case GameChatStatus.error:
        break;
    }
    return fresh;
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
    // Sending offline is out of scope (KAN-607): a thread shown from the
    // device copy refuses a send; the composer already says why.
    if (current.fromCache) return;
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

  /// The image operations of the active backend (KAN-581).
  MessagingImageRepository get _images {
    final repo = ref.read(messagingRepositoryProvider);
    return repo is MessagingImageRepository
        ? repo as MessagingImageRepository
        : const UnavailableMessagingRepository();
  }

  final Map<String, UploadCancel> _uploadCancels = {};

  /// Image deliveries run one after another, so a tray of images reaches the
  /// server in the order it was queued.
  Future<void> _imageTurn = Future<void>.value();

  /// Sends one picked image (KAN-581): it shows at once under the upload veil,
  /// uploads (progress, cancel), then is sent as a message carrying the
  /// attachment id, with [caption] as its text. The message key and the upload
  /// key are created once and reused by [retry], so a retry never duplicates.
  Future<void> sendImage(PickedImage image, {String caption = ''}) async {
    final generate = ref.read(messagingClientKeyGeneratorProvider);
    final key = generate();
    final uploadKey = generate();
    final current = state.valueOrNull;
    if (current == null || current.conversation == null) return;
    state = AsyncData(
      current.copyWith(
        status: GameChatStatus.ready,
        items: [
          ...current.items,
          ChatItem(
            body: caption,
            clientKey: key,
            state: OutgoingState.sending,
            pending: PendingImage(image: image, uploadKey: uploadKey),
          ),
        ],
      ),
    );
    final turn = _imageTurn.then((_) => _deliverImage(key));
    _imageTurn = turn.catchError((Object _) {});
    await turn;
  }

  /// Stops an upload in flight, or drops a failed one: the image leaves the
  /// thread and nothing is sent.
  void cancelImage(String clientKey) {
    _uploadCancels.remove(clientKey)?.cancel();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final i in current.items)
            if (!(i.clientKey == clientKey && i.pending != null)) i,
        ],
      ),
    );
  }

  Future<void> _deliverImage(String key) async {
    ChatItem? find() => state.valueOrNull?.items
        .where((i) => i.clientKey == key && i.pending != null)
        .firstOrNull;
    final conversationId = state.valueOrNull?.conversation?.id;
    var item = find();
    if (conversationId == null || item == null) return;
    var pending = item.pending!;

    void fail(Failure failure) {
      if (_endIfRemoved(failure)) return;
      final reason = failure is MessagingFailure
          ? failure.reason
          : MessagingReason.unknown;
      final latest = find();
      if (latest == null) return;
      _replace(
        key,
        latest.copyWith(state: OutgoingState.failed, failureReason: reason),
      );
      onSendRefused(reason);
    }

    if (pending.attachmentId == null) {
      final cancel = _uploadCancels[key] = UploadCancel();
      final uploaded = await _images.uploadImage(
        conversationId: conversationId,
        image: pending.image,
        idempotencyKey: pending.uploadKey,
        cancel: cancel,
        onProgress: (sent, total) => _setProgress(key, sent / total),
      );
      _uploadCancels.remove(key);
      if (cancel.isCancelled) return; // already removed by [cancelImage]
      item = find();
      if (item == null) return;
      if (uploaded is Err<MessageAttachment, Failure>) {
        fail(uploaded.error);
        return;
      }
      pending = item.pending!.copyWith(
        attachmentId: uploaded.requireValue.id,
        progress: 1,
      );
      item = item.copyWith(pending: pending);
      _replace(key, item);
    }

    final sent = await _images.sendImageMessage(
      conversationId: conversationId,
      idempotencyKey: key,
      attachmentIds: [pending.attachmentId!],
      caption: item.body,
    );
    final latest = find();
    if (latest == null) return;
    sent.fold(
      fail,
      (message) => _replace(
        key,
        latest.copyWith(
          message: message,
          state: OutgoingState.sent,
          clearPending: true,
        ),
      ),
    );
  }

  void _setProgress(String key, double value) {
    final item = state.valueOrNull?.items
        .where((i) => i.clientKey == key && i.pending != null)
        .firstOrNull;
    if (item == null) return;
    final shown = item.pending!.progress;
    // A step of under 2% is not worth a rebuild; the last step always is.
    if (value < 1 && value - shown < 0.02) return;
    _replace(key, item.copyWith(pending: item.pending!.copyWith(progress: value)));
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
    if (item.pending != null) {
      await _deliverImage(clientKey);
      return;
    }
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
    // The network answered: the device copy is no longer what is shown.
    final shown = state.valueOrNull;
    if (shown != null && shown.fromCache) {
      state = AsyncData(shown.copyWith(fromCache: false));
    }
    _mergeFresh(result.requireValue.messages);
    final merged = state.valueOrNull;
    final account = ref.read(cacheAccountIdProvider);
    if (merged != null && account != null) {
      unawaited(
        ChatCache(
          ref.read(offlineCacheProvider),
          account,
        ).saveThread(cacheKey(arg), merged),
      );
    }
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
