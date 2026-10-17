import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

const _url = 'https://worker.example.invalid';

ProviderContainer _container(MessagingBackendConfig config) {
  final c = ProviderContainer(
    overrides: [
      messagingBackendConfigProvider.overrideWithValue(config),
      messagingHttpClientProvider.overrideWithValue(
        MockClient((_) async => http.Response('', 500)),
      ),
      messagingTokenSupplierProvider.overrideWithValue(() async => 't'),
      messagingRpcCallerProvider.overrideWithValue((_, _) async => const []),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'default config uses the committed flags (on, KAN-554 launch) -> the real '
    'Worker, or unavailable without a base URL; never the fake',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final cfg = c.read(messagingBackendConfigProvider);
      expect(cfg.messaging, isTrue);
      expect(cfg.gameChat, isTrue);
      expect(
        c.read(messagingBackendKindProvider),
        cfg.baseUrl.trim().isEmpty
            ? MessagingBackendKind.unavailable
            : MessagingBackendKind.worker,
      );
      expect(
        c.read(messagingRepositoryProvider),
        isNot(isA<FakeMessagingRepository>()),
      );
    },
  );

  final cases = <(MessagingBackendConfig, MessagingBackendKind, Type)>[
    (
      (messaging: false, gameChat: false, baseUrl: _url),
      MessagingBackendKind.fake,
      FakeMessagingRepository,
    ),
    (
      (messaging: true, gameChat: false, baseUrl: _url),
      MessagingBackendKind.fake,
      FakeMessagingRepository,
    ),
    (
      (messaging: true, gameChat: true, baseUrl: ''),
      MessagingBackendKind.unavailable,
      UnavailableMessagingRepository,
    ),
    (
      (messaging: true, gameChat: true, baseUrl: _url),
      MessagingBackendKind.worker,
      WorkerMessagingRepository,
    ),
  ];

  for (final (config, kind, type) in cases) {
    test('$config -> $kind', () {
      final c = _container(config);
      expect(c.read(messagingBackendKindProvider), kind);
      expect(c.read(messagingRepositoryProvider).runtimeType, type);
      expect(c.read(myConversationsRepositoryProvider).runtimeType, type);
    });
  }

  test('flag-on with empty URL -> not_in_pilot (unavailable state)', () async {
    final c = _container((messaging: true, gameChat: true, baseUrl: '  '));
    final repo = c.read(messagingRepositoryProvider);
    final r = await repo.getGameConversation('g1');
    final f = r.requireError as MessagingFailure;
    expect(f.reason, MessagingReason.notInPilot);
    expect(f.category, FailureCode.forbidden);
    final list = await c
        .read(myConversationsRepositoryProvider)
        .listMyConversations();
    expect(
      (list.requireError as MessagingFailure).reason,
      MessagingReason.notInPilot,
    );
  });
}
