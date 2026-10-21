import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/features/messaging/data/chat_cache.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/presentation/controllers/dm_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// The two flags the Messages list surfaces read (Home icon and the
/// `/messaging` route). Defaults to the real compile-time flags (false); a
/// test overrides the provider instead of flipping a const.
typedef MessagesListFlags = ({bool messaging, bool gameChat});

final messagesListFlagsProvider = Provider<MessagesListFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    gameChat: FeatureFlags.enableMessagingGameChat,
  ),
);

/// Whether the Messages icon and list are available.
bool messagesListEnabled(MessagesListFlags flags) =>
    flags.messaging && flags.gameChat;

/// The repository behind the list, chosen like [messagingRepositoryProvider]
/// (KAN-550): the fake unless messaging is flagged on.
final myConversationsRepositoryProvider = Provider<MyConversationsRepository>(
  (ref) => switch (ref.watch(messagingBackendKindProvider)) {
    MessagingBackendKind.fake => ref.watch(fakeMessagingRepositoryProvider),
    MessagingBackendKind.worker => ref.watch(workerMessagingRepositoryProvider),
    MessagingBackendKind.unavailable => const UnavailableMessagingRepository(),
  },
);

/// The user's game chats in the repository's order. The value is the
/// `Result` itself, so a failure is data, never a thrown error. No Realtime:
/// it loads on open and on Retry (invalidate).
///
/// KAN-607: a list that loaded is kept on the device for the account; when the
/// request fails and a copy exists, the copy answers (read-only history).
final messagesListProvider =
    FutureProvider.autoDispose<Result<List<MyConversation>, Failure>>((
      ref,
    ) async {
      final result = await ref
          .watch(myConversationsRepositoryProvider)
          .listMyConversations();
      final account = ref.read(cacheAccountIdProvider);
      if (account == null) return result;
      final cache = ChatCache(ref.read(offlineCacheProvider), account);
      if (result is Ok<List<MyConversation>, Failure>) {
        unawaited(cache.saveList(result.requireValue));
        return result;
      }
      final failure = result is Err<List<MyConversation>, Failure>
          ? result.error
          : null;
      // Only an unreachable server falls back to the copy; a refusal stands.
      if (failure is! MessagingFailure ||
          failure.reason != MessagingReason.offline) {
        return result;
      }
      final cached = await cache.loadList();
      return cached == null ? result : Ok(cached);
    });

/// Start a DM and mute (KAN-562), chosen exactly like
/// [myConversationsRepositoryProvider].
final dmRepositoryProvider = Provider<DmRepository>(
  (ref) => switch (ref.watch(messagingBackendKindProvider)) {
    MessagingBackendKind.fake => ref.watch(fakeMessagingRepositoryProvider),
    MessagingBackendKind.worker => ref.watch(workerMessagingRepositoryProvider),
    MessagingBackendKind.unavailable => const UnavailableMessagingRepository(),
  },
);

/// The DM thread of one conversation, keyed by conversation id (KAN-556).
final dmChatControllerProvider =
    AsyncNotifierProvider.family<DmChatController, GameChatViewState, String>(
      DmChatController.new,
    );
