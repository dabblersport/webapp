import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// The in-memory fake (KAN-507). There is no real messaging repository yet;
/// a later ticket adds it and overrides [messagingRepositoryProvider].
final fakeMessagingRepositoryProvider = Provider<FakeMessagingRepository>(
  (ref) => FakeMessagingRepository(),
);

/// The repository the messaging UI reads. DEFAULTS TO THE FAKE: no network
/// code exists behind it. Every surface is also behind flags that are false.
final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => ref.watch(fakeMessagingRepositoryProvider),
);

/// Generates the idempotency key of each new message (a UUID v4). Overridable
/// for deterministic tests.
final messagingClientKeyGeneratorProvider = Provider<String Function()>(
  (ref) =>
      () => const Uuid().v4(),
);

/// The game chat of one game, keyed by game id.
final gameChatControllerProvider =
    AsyncNotifierProvider.family<GameChatController, GameChatViewState, String>(
      GameChatController.new,
    );

/// How often the open game chat refreshes its newest page (polling only, no
/// Realtime). Null disables polling (tests).
/// A network refresh cadence, not a visual duration.
const int gameChatPollSeconds = 15;

final gameChatPollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: gameChatPollSeconds),
);

/// The clock the chat uses for date separators and the "game finished" line.
final messagingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
