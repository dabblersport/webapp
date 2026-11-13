import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-608: theme, language and service region reach the queue through the
/// bridge, and a server hydrate does not overwrite a queued edit.
class _Remote implements ServiceRegionRemote {
  String? stored;
  int saves = 0;
  @override
  Future<String?> fetch(String userId) async => stored;
  @override
  Future<void> save(String userId, String region) async {
    saves++;
    stored = region;
  }
}

class _Handler extends SettingSyncHandler {
  final List<Map<String, dynamic>> pushed = [];
  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => null;
  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async =>
      pushed.add(edit.value);
  @override
  Future<void> adoptServer(String accountId) async {}
}

void main() {
  late _Handler handler;
  late SettingsSyncNotifier sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    handler = _Handler();
    sync = SettingsSyncNotifier(
      accountId: 'A',
      handlers: {
        SettingKeys.theme: handler,
        SettingKeys.language: handler,
        SettingKeys.region: handler,
      },
      isOffline: () => true,
      observeLifecycle: false,
    );
    await pumpEventQueue(times: 20);
  });
  tearDown(() => sync.dispose());

  test('the bridge queues an edit and reports a pending one', () async {
    expect(await SettingsSyncBridge.hasPendingEdit(SettingKeys.theme), isFalse);
    expect(
      await SettingsSyncBridge.submit(SettingKeys.theme, {
        'theme_mode': 'dark',
      }),
      isTrue,
    );
    expect(await SettingsSyncBridge.hasPendingEdit(SettingKeys.theme), isTrue);
  });

  test(
    'with no queue running the bridge declines (direct write stays)',
    () async {
      sync.dispose();
      expect(
        await SettingsSyncBridge.submit(SettingKeys.theme, {
          'theme_mode': 'dark',
        }),
        isFalse,
      );
      sync = SettingsSyncNotifier(
        accountId: 'A',
        handlers: const {},
        isOffline: () => true,
        observeLifecycle: false,
      );
    },
  );

  test(
    'a region change offline is applied locally and queued, not sent',
    () async {
      final remote = _Remote();
      final n = SelectedLocationNotifier(userId: 'A', remote: remote);
      await pumpEventQueue(times: 20);

      await n.setCountry('Qatar');

      expect(n.state.valueOrNull!.country, 'Qatar');
      expect(remote.saves, 0);
      expect(
        (await sync.pendingValue(SettingKeys.region))!['region'],
        n.state.valueOrNull!.country,
      );
    },
  );

  test(
    'a queued region change is not overwritten by the server copy',
    () async {
      final remote = _Remote()..stored = 'Egypt';
      final first = SelectedLocationNotifier(userId: 'A', remote: remote);
      await pumpEventQueue(times: 20);
      await first.setCountry('Qatar');

      final reopened = SelectedLocationNotifier(userId: 'A', remote: remote);
      await pumpEventQueue(times: 20);
      expect(reopened.state.valueOrNull!.country, 'Qatar');
    },
  );
}
