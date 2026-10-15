import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// The in-memory fake (KAN-507): the default for tests and flag-off builds.
final fakeMessagingRepositoryProvider = Provider<FakeMessagingRepository>(
  (ref) => FakeMessagingRepository(),
);

/// The inputs that pick the backend (KAN-550). Defaults to the real
/// compile-time flags (false) and the build's `MESSAGING_API_BASE_URL`; a
/// test overrides this provider instead of flipping a const.
typedef MessagingBackendConfig = ({
  bool messaging,
  bool gameChat,
  String baseUrl,
});

final messagingBackendConfigProvider = Provider<MessagingBackendConfig>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    gameChat: FeatureFlags.enableMessagingGameChat,
    baseUrl: Environment.messagingApiBaseUrl,
  ),
);

enum MessagingBackendKind { fake, worker, unavailable }

/// Real Worker only when both flags are on AND a base URL is configured; a
/// flag-on build without a URL is unavailable; anything else is the fake.
MessagingBackendKind selectMessagingBackend(MessagingBackendConfig c) {
  if (!(c.messaging && c.gameChat)) return MessagingBackendKind.fake;
  return c.baseUrl.trim().isEmpty
      ? MessagingBackendKind.unavailable
      : MessagingBackendKind.worker;
}

final messagingBackendKindProvider = Provider<MessagingBackendKind>(
  (ref) => selectMessagingBackend(ref.watch(messagingBackendConfigProvider)),
);

/// Seams of the real repository; tests override them (no network, no
/// Supabase instance).
final messagingHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final messagingTokenSupplierProvider = Provider<MessagingTokenSupplier>(
  (ref) => supabaseAccessToken,
);

final messagingRpcCallerProvider = Provider<MessagingRpcCaller>(
  (ref) => supabaseRpc,
);

final workerMessagingRepositoryProvider = Provider<WorkerMessagingRepository>(
  (ref) => WorkerMessagingRepository(
    http: MessagingHttpClient(
      client: ref.watch(messagingHttpClientProvider),
      tokenSupplier: ref.watch(messagingTokenSupplierProvider),
      baseUrl: ref.watch(messagingBackendConfigProvider).baseUrl,
    ),
    rpc: ref.watch(messagingRpcCallerProvider),
  ),
);

/// The repository the messaging UI reads, chosen by
/// [messagingBackendKindProvider]. Flag-off builds and tests get the fake.
final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => switch (ref.watch(messagingBackendKindProvider)) {
    MessagingBackendKind.fake => ref.watch(fakeMessagingRepositoryProvider),
    MessagingBackendKind.worker => ref.watch(workerMessagingRepositoryProvider),
    MessagingBackendKind.unavailable => const UnavailableMessagingRepository(),
  },
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
