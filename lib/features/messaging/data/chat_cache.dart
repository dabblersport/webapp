import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// Read-only on-device copy of message history (KAN-607), kept in the
/// per-account [OfflineCache] of KAN-605.
///
/// It is a disposable read cache of what the Worker already returned to this
/// account: not a second history store, never sent back, wiped on sign-out and
/// account switch by the cache layer. Only delivered messages are kept (never
/// a pending or failed own send, so the failed-message behaviour is
/// unchanged) and no token or secret is ever stored.
class ChatCache {
  const ChatCache(this._cache, this._accountId);

  final OfflineCache _cache;
  final String _accountId;

  /// The newest messages kept per thread (N = 50, the size of one page).
  static const int maxMessagesPerThread = 50;

  static const String listKey = 'messages.list';
  static String gameThreadKey(String gameId) => 'chat.game.$gameId';
  static String dmThreadKey(String conversationId) => 'chat.dm.$conversationId';

  Future<void> saveList(List<MyConversation> rows) =>
      _cache.write(_accountId, listKey, [for (final r in rows) r.toJson()]);

  Future<List<MyConversation>?> loadList() async {
    final hit = await _cache.read(_accountId, listKey);
    if (hit == null) return null;
    final parsed = MyConversation.parseList(hit.payload);
    return parsed is Ok<List<MyConversation>, Failure>
        ? parsed.requireValue
        : null;
  }

  Future<void> saveThread(String key, GameChatViewState view) {
    final conversation = view.conversation;
    if (conversation == null) return Future<void>.value();
    final sent = [
      for (final i in view.items)
        if (i.message != null && i.state == OutgoingState.sent) i.message!,
    ];
    final kept = sent.length > maxMessagesPerThread
        ? sent.sublist(sent.length - maxMessagesPerThread)
        : sent;
    final dm = view.dm;
    return _cache.write(_accountId, key, {
      'status': view.status.name,
      'conversation': conversation.toJson(),
      'reason': view.reason?.wireName,
      'messages': [for (final m in kept) m.toJson()],
      if (dm != null)
        'dm': {
          'user': dm.counterpartUserId,
          'name': dm.counterpartName,
          'avatar': dm.counterpartAvatar,
          'read_only': dm.readOnly?.name,
        },
    });
  }

  Future<GameChatViewState?> loadThread(String key) async {
    final hit = await _cache.read(_accountId, key);
    if (hit == null) return null;
    try {
      final map = Map<String, dynamic>.from(hit.payload as Map);
      final conversation = Conversation.fromJson(
        Map<String, dynamic>.from(map['conversation'] as Map),
      );
      final items = [
        for (final m in map['messages'] as List)
          () {
            final message = Message.fromJson(
              Map<String, dynamic>.from(m as Map),
            );
            return ChatItem(
              message: message,
              clientKey: message.clientKey,
              body: message.body,
              state: OutgoingState.sent,
            );
          }(),
      ];
      final stored = GameChatStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GameChatStatus.ready,
      );
      final dmMap = map['dm'];
      return GameChatViewState(
        status: stored == GameChatStatus.readOnly
            ? stored
            : (items.isEmpty ? GameChatStatus.empty : GameChatStatus.ready),
        conversation: conversation,
        items: items,
        reason: conversation.writable ? null : conversation.readOnlyReason,
        dm: dmMap is Map
            ? DmThreadInfo(
                counterpartUserId: dmMap['user'] as String?,
                counterpartName: dmMap['name'] as String?,
                counterpartAvatar: dmMap['avatar'] as String?,
                readOnly: DmReadOnlyKind.values
                    .where((k) => k.name == dmMap['read_only'])
                    .firstOrNull,
              )
            : null,
        fromCache: true,
      );
    } catch (_) {
      return null; // a shape that no longer parses: treat as no cache
    }
  }

  Future<void> removeThread(String key) => _cache.remove(_accountId, key);
}
