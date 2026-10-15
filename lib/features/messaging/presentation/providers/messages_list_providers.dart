import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
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

/// The repository behind the list. DEFAULTS TO THE FAKE (no network code);
/// the real-repository ticket overrides it.
final myConversationsRepositoryProvider = Provider<MyConversationsRepository>(
  (ref) => ref.watch(fakeMessagingRepositoryProvider),
);

/// The user's game chats in the repository's order. The value is the
/// `Result` itself, so a failure is data, never a thrown error. No Realtime:
/// it loads on open and on Retry (invalidate).
final messagesListProvider =
    FutureProvider.autoDispose<Result<List<MyConversation>, Failure>>(
      (ref) =>
          ref.watch(myConversationsRepositoryProvider).listMyConversations(),
    );
