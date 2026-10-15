import 'dart:math' as math;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/models/view_boundary.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The repository operations a scripted failure can target.
enum FakeMessagingOp {
  getGameConversation,
  listMessages,
  sendTextMessage,
  reportMessage,
  muteConversation,
  unmuteConversation,
}

/// An in-memory [MessagingRepository] (KAN-507, T12). It has NO network and
/// no database: every scenario T16 needs is scripted in memory.
///
/// - empty or populated threads: [seedGameConversation];
/// - pagination by `seq` cursor and limit, as the contract defines it;
/// - idempotent send: a retry with the same key returns the same message;
/// - offline: set [offline] to make every call return
///   `MessagingFailure.offline()`;
/// - any typed reason: [failAlways] (until [clearFailures]) or [failNext]
///   (once, then the call succeeds — a failed send followed by a retry).
///
/// Ids and time are deterministic through the injectable [clock] and
/// [idGenerator].
class FakeMessagingRepository
    implements MessagingRepository, MyConversationsRepository {
  FakeMessagingRepository({
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.currentUserId = 'fake-user',
  }) : _clock = clock ?? _defaultClock(),
       _idGenerator = idGenerator ?? _defaultIdGenerator();

  final DateTime Function() _clock;
  final String Function() _idGenerator;

  /// The sender id given to messages sent through this fake.
  final String currentUserId;

  /// When true every call fails with `MessagingFailure.offline()`.
  bool offline = false;

  final Map<String, Conversation> _byGame = {};
  final Map<String, Conversation> _byId = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, Message> _sentByKey = {};
  final Map<FakeMessagingOp, MessagingReason> _always = {};
  final Map<FakeMessagingOp, List<MessagingReason>> _next = {};
  final Set<String> _reported = {};

  final List<MyConversation> _myConversations = [];

  /// When set, [listMyConversations] waits this long before answering (the
  /// Messages list's loading state).
  Duration? myConversationsDelay;

  /// How many times [listMyConversations] was called.
  int myConversationsCalls = 0;

  // Scripted failures of [listMyConversations]. Kept apart from
  // [FakeMessagingOp], which enumerates the six contract operations only.
  final List<MessagingReason> _myConversationsNext = [];

  /// When set, every [listMyConversations] fails with it.
  MessagingReason? myConversationsFailAlways;

  /// The next [listMyConversations] fails with [reason]; later calls succeed.
  void failNextMyConversations(MessagingReason reason) =>
      _myConversationsNext.add(reason);

  /// Replaces the user's game chats returned by [listMyConversations]. The
  /// fake orders them as the RPC does: newest `lastActivityAt` first (nulls
  /// last), ties by newest `startAt`.
  void seedMyConversations(List<MyConversation> chats) {
    _myConversations
      ..clear()
      ..addAll(chats);
  }

  /// How many times [sendTextMessage] was called (including failed calls).
  int sendAttempts = 0;

  static DateTime Function() _defaultClock() {
    var tick = 0;
    final base = DateTime.utc(2026, 1, 1);
    return () => base.add(Duration(seconds: tick++));
  }

  static String Function() _defaultIdGenerator() {
    var n = 0;
    return () => 'fake-${++n}';
  }

  /// Creates (or replaces) the conversation of [gameId] with [messageCount]
  /// messages, seq 1..messageCount.
  Conversation seedGameConversation(
    String gameId, {
    int messageCount = 0,
    bool writable = true,
    MessagingReason? readOnlyReason,
    ViewBoundary? boundary,
    bool muted = false,
  }) {
    final id = 'conv-$gameId';
    final messages = <Message>[
      for (var seq = 1; seq <= messageCount; seq++)
        Message(
          id: _idGenerator(),
          conversationId: id,
          seq: seq,
          senderUserId: 'member-${seq % 3}',
          kind: MessageKind.text,
          body: 'm$seq',
          createdAt: _clock(),
        ),
    ];
    _messages[id] = messages;
    final conversation = Conversation(
      id: id,
      gameId: gameId,
      writable: writable,
      muted: muted,
      lastSeq: messageCount,
      readOnlyReason: writable ? null : readOnlyReason,
      boundary: boundary,
    );
    _byGame[gameId] = conversation;
    _byId[id] = conversation;
    return conversation;
  }

  /// Every call of [op] fails with [reason] until [clearFailures].
  void failAlways(FakeMessagingOp op, MessagingReason reason) =>
      _always[op] = reason;

  /// The next call of [op] fails with [reason]; later calls succeed.
  void failNext(FakeMessagingOp op, MessagingReason reason) =>
      (_next[op] ??= []).add(reason);

  void clearFailures() {
    _always.clear();
    _next.clear();
  }

  /// The messages stored for [conversationId], ascending by seq.
  List<Message> storedMessages(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);

  /// Whether [messageId] was reported.
  bool wasReported(String messageId) => _reported.contains(messageId);

  MessagingFailure? _scripted(FakeMessagingOp op) {
    if (offline) return MessagingFailure.offline();
    final queued = _next[op];
    if (queued != null && queued.isNotEmpty) {
      return _failure(queued.removeAt(0));
    }
    final always = _always[op];
    return always == null ? null : _failure(always);
  }

  static MessagingFailure _failure(MessagingReason reason) {
    if (reason == MessagingReason.offline) return MessagingFailure.offline();
    return MessagingFailure(
      reason: reason,
      retryAfterSeconds: reason == MessagingReason.rateLimited ? 30 : null,
    );
  }

  Result<T, Failure> _err<T>(MessagingFailure f) => Err<T, Failure>(f);

  @override
  Future<Result<Conversation, Failure>> getGameConversation(
    String gameId,
  ) async {
    final scripted = _scripted(FakeMessagingOp.getGameConversation);
    if (scripted != null) return _err(scripted);
    final conversation = _byGame[gameId];
    if (conversation == null) {
      return _err(_failure(MessagingReason.notFound));
    }
    return Ok(conversation);
  }

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) async {
    final scripted = _scripted(FakeMessagingOp.listMessages);
    if (scripted != null) return _err(scripted);
    final conversation = _byId[conversationId];
    if (conversation == null) return _err(_failure(MessagingReason.notFound));
    final size = limit ?? MessagingLimits.defaultPageSize;
    if (size < 1 || size > MessagingLimits.maxPageSize) {
      return _err(_failure(MessagingReason.invalidRequest));
    }
    final boundary = conversation.boundary;
    final all = [
      for (final m in _messages[conversationId] ?? const <Message>[])
        if (boundary == null || m.seq <= boundary.seq) m,
    ];

    List<Message> page;
    bool hasOlder;
    bool hasNewer;
    if (cursor == null || direction == MessageDirection.older) {
      final below = cursor == null
          ? all
          : all.where((m) => m.seq < cursor).toList();
      final start = math.max(below.length - size, 0);
      page = below.sublist(start);
      hasOlder = start > 0;
      hasNewer = cursor != null && all.any((m) => m.seq >= cursor);
    } else {
      final above = all.where((m) => m.seq > cursor).toList();
      page = above.take(size).toList();
      hasNewer = above.length > size;
      hasOlder = all.any((m) => m.seq <= cursor);
    }
    return Ok(
      MessagePage(
        messages: page,
        hasOlder: hasOlder && page.isNotEmpty,
        hasNewer: hasNewer && page.isNotEmpty,
        olderCursor: hasOlder && page.isNotEmpty ? page.first.seq : null,
        newerCursor: hasNewer && page.isNotEmpty ? page.last.seq : null,
        pageSize: size,
        boundary: boundary,
      ),
    );
  }

  @override
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) async {
    sendAttempts++;
    final scripted = _scripted(FakeMessagingOp.sendTextMessage);
    if (scripted != null) return _err(scripted);
    final existing = _sentByKey[idempotencyKey];
    if (existing != null) return Ok(existing);
    final conversation = _byId[conversationId];
    if (conversation == null) return _err(_failure(MessagingReason.notFound));
    if (!conversation.writable) {
      return _err(
        _failure(conversation.readOnlyReason ?? MessagingReason.leftReadOnly),
      );
    }
    if (body.trim().isEmpty ||
        body.length > MessagingLimits.maxBodyLength ||
        idempotencyKey.isEmpty) {
      return _err(_failure(MessagingReason.invalidRequest));
    }
    final list = _messages[conversationId] ??= [];
    final seq = list.isEmpty ? 1 : list.last.seq + 1;
    final message = Message(
      id: _idGenerator(),
      conversationId: conversationId,
      seq: seq,
      senderUserId: currentUserId,
      kind: MessageKind.text,
      body: body,
      clientKey: idempotencyKey,
      createdAt: _clock(),
    );
    list.add(message);
    _sentByKey[idempotencyKey] = message;
    final updated = Conversation(
      id: conversation.id,
      gameId: conversation.gameId,
      writable: conversation.writable,
      muted: conversation.muted,
      lastSeq: seq,
      readOnlyReason: conversation.readOnlyReason,
      boundary: conversation.boundary,
    );
    _byId[conversationId] = updated;
    _byGame[conversation.gameId] = updated;
    return Ok(message);
  }

  @override
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  }) async {
    final scripted = _scripted(FakeMessagingOp.reportMessage);
    if (scripted != null) return _err(scripted);
    final known = _messages.values.any((l) => l.any((m) => m.id == messageId));
    if (!known) return _err(_failure(MessagingReason.notFound));
    _reported.add(messageId);
    return const Ok(null);
  }

  @override
  Future<Result<void, Failure>> muteConversation(String conversationId) =>
      _setMuted(FakeMessagingOp.muteConversation, conversationId, true);

  @override
  Future<Result<void, Failure>> unmuteConversation(String conversationId) =>
      _setMuted(FakeMessagingOp.unmuteConversation, conversationId, false);

  Future<Result<void, Failure>> _setMuted(
    FakeMessagingOp op,
    String conversationId,
    bool muted,
  ) async {
    final scripted = _scripted(op);
    if (scripted != null) return _err(scripted);
    final c = _byId[conversationId];
    if (c == null) return _err(_failure(MessagingReason.notFound));
    final updated = Conversation(
      id: c.id,
      gameId: c.gameId,
      writable: c.writable,
      muted: muted,
      lastSeq: c.lastSeq,
      readOnlyReason: c.readOnlyReason,
      boundary: c.boundary,
    );
    _byId[c.id] = updated;
    _byGame[c.gameId] = updated;
    return const Ok(null);
  }

  @override
  Future<Result<List<MyConversation>, Failure>> listMyConversations({
    int? limit,
  }) async {
    myConversationsCalls++;
    final delay = myConversationsDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (offline) return _err(MessagingFailure.offline());
    if (_myConversationsNext.isNotEmpty) {
      return _err(_failure(_myConversationsNext.removeAt(0)));
    }
    final always = myConversationsFailAlways;
    if (always != null) return _err(_failure(always));
    final size = math.min(math.max(limit ?? 50, 1), 100);
    int byTime(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    final sorted = [..._myConversations]
      ..sort((a, b) {
        final c = byTime(a.lastActivityAt, b.lastActivityAt);
        return c != 0 ? c : byTime(a.startAt, b.startAt);
      });
    return Ok(List.unmodifiable(sorted.take(size)));
  }
}
