import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/chat_cache.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/social/block_providers.dart';

/// The direct-message thread of one conversation (KAN-556; arg: the
/// conversation id). It IS the game chat controller — send, retry, paging,
/// polling, Realtime wakes and report are inherited unchanged — with three
/// DM differences:
///
/// * **Open.** The contract has no "get conversation" for a DM, so the DM is
///   resolved from the caller's own row of `listMyConversations` (kind,
///   counterpart name and avatar, muted, read-only); its messages then come
///   from the shared `listMessages` by conversation id. A conversation that is
///   not one of the caller's DMs is not found: the unavailable state.
/// * **Mute** goes through `DmRepository.setMuted`, optimistically, and rolls
///   back when refused.
/// * **Read-only** carries its cause: you blocked them, they blocked you, or
///   the counterpart is gone (Worker `blocked` / `suspended`).
class DmChatController extends GameChatController {
  @override
  Future<GameChatViewState> open(String arg) async {
    final list = await ref
        .read(myConversationsRepositoryProvider)
        .listMyConversations(limit: dmLookupLimit);
    if (list is Err<List<MyConversation>, Failure>) {
      return failureFor(list.error);
    }
    final row = list.requireValue
        .where((c) => c.isDm && c.conversationId == arg)
        .firstOrNull;
    if (row == null) {
      return const GameChatViewState(
        status: GameChatStatus.unavailable,
        reason: MessagingReason.notFound,
      );
    }
    final readOnly = row.isDmReadOnly
        ? await _classify(row.counterpartUserId)
        : null;
    return openConversation(
      Conversation(
        id: row.conversationId,
        // A DM has no game; the shared model requires the field.
        gameId: '',
        writable: readOnly == null,
        muted: row.muted,
        lastSeq: 0,
        readOnlyReason: _reasonOf(readOnly),
      ),
      dm: DmThreadInfo(
        counterpartUserId: row.counterpartUserId,
        counterpartName: row.counterpartName,
        counterpartAvatar: row.counterpartAvatar,
        readOnly: readOnly,
      ),
    );
  }

  @override
  String cacheKey(String arg) => ChatCache.dmThreadKey(arg);

  /// The most rows the open asks `listMyConversations` for (the RPC's max).
  static const int dmLookupLimit = 100;

  /// Not found and no access are the unavailable state; `dm_cap_reached`
  /// keeps its own line; everything else as in the game chat.
  @override
  GameChatViewState failureFor(Failure failure) {
    if (failure is DmCapReachedFailure) {
      return const GameChatViewState(
        status: GameChatStatus.error,
        reason: MessagingReason.rateLimited,
        dm: DmThreadInfo(capReached: true),
      );
    }
    final reason = failure is MessagingFailure ? failure.reason : null;
    if (reason == MessagingReason.notFound ||
        reason == MessagingReason.notAMember) {
      return GameChatViewState(
        status: GameChatStatus.unavailable,
        reason: reason,
      );
    }
    return super.failureFor(failure);
  }

  static MessagingReason? _reasonOf(DmReadOnlyKind? kind) => switch (kind) {
    null => null,
    DmReadOnlyKind.counterpartGone => MessagingReason.suspended,
    _ => MessagingReason.blocked,
  };

  /// Which side of a read-only DM: a counterpart the caller blocked, one who
  /// blocked the caller (in the either-direction set only), or neither (the
  /// counterpart is deleted or banned). A lookup that fails reads as empty.
  Future<DmReadOnlyKind> _classify(String? counterpart) async {
    if (counterpart == null) return DmReadOnlyKind.counterpartGone;
    Future<Set<String>> safe(Future<Set<String>> Function() read) async {
      try {
        return await read();
      } catch (_) {
        return const <String>{};
      }
    }

    final mine = await safe(
      () async => {
        for (final r in await ref.read(blockedUsersWithProfilesProvider.future))
          ?_userId(r),
      },
    );
    if (mine.contains(counterpart)) return DmReadOnlyKind.youBlocked;
    final either = await safe(() => ref.read(blockedUserIdsProvider.future));
    return either.contains(counterpart)
        ? DmReadOnlyKind.blockedYou
        : DmReadOnlyKind.counterpartGone;
  }

  static String? _userId(Map<String, dynamic> row) {
    final id = row[_userIdField];
    return id is String ? id : null;
  }

  /// The user-id column of the existing blocked-users rows.
  static const String _userIdField = 'user_id';

  /// A send refused with `blocked` or `suspended` makes the DM read-only with
  /// its cause; any other refusal stays on the failed message.
  @override
  void onSendRefused(MessagingReason reason) {
    if (reason != MessagingReason.blocked &&
        reason != MessagingReason.suspended) {
      return;
    }
    final dm = state.valueOrNull?.dm;
    closeChat(reason);
    if (dm == null) return;
    if (reason == MessagingReason.suspended) {
      _setReadOnly(dm.withReadOnly(DmReadOnlyKind.counterpartGone));
      return;
    }
    _classify(dm.counterpartUserId).then((kind) {
      final latest = state.valueOrNull?.dm ?? dm;
      _setReadOnly(latest.withReadOnly(kind));
    });
  }

  /// The caller blocked the counterpart through the existing block flow: the
  /// DM becomes read-only ("you blocked"), history stays readable.
  void markBlockedByMe() {
    final dm = state.valueOrNull?.dm;
    if (dm == null) return;
    closeChat(MessagingReason.blocked);
    _setReadOnly(dm.withReadOnly(DmReadOnlyKind.youBlocked));
  }

  void _setReadOnly(DmThreadInfo dm) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(dm: dm));
  }

  /// Optimistic: the toggle shows the new value at once and goes back when the
  /// repository refuses. Returns whether it was accepted.
  @override
  Future<bool> setMuted(bool muted) async {
    final c = state.valueOrNull?.conversation;
    if (c == null) return false;
    _applyMuted(muted);
    final result = await ref.read(dmRepositoryProvider).setMuted(c.id, muted);
    if (result is Err) {
      _applyMuted(!muted);
      return false;
    }
    return true;
  }

  void _applyMuted(bool muted) {
    final current = state.valueOrNull;
    final c = current?.conversation;
    if (current == null || c == null) return;
    state = AsyncData(
      current.copyWith(
        conversation: GameChatController.copyConversation(c, muted: muted),
      ),
    );
  }
}
