import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_settings_repository.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/profile/data/repositories/settings_repository_impl.dart';
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/supabase_test_client.dart';
import '../home/home_test_harness.dart';

/// KAN-608: notification and privacy edits made offline apply at once, are
/// queued, and are what the screen shows after a reload with no connection.
class _NoServer extends SettingSyncHandler {
  final List<Map<String, dynamic>> pushed = [];
  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => null;
  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async =>
      pushed.add(edit.value);
  @override
  Future<void> adoptServer(String accountId) async {}
}

class _Repo implements NotificationSettingsRepository {
  _Repo(this.settings);
  NotificationSettings? settings; // null: the network is gone
  @override
  Future<Result<NotificationSettings, Failure>> load() async => settings == null
      ? const Err(Failure(message: 'no internet'))
      : Ok(settings!);
  @override
  Future<Result<NotificationSettings, Failure>> save(
    NotificationSettings s,
  ) async => throw StateError('offline-first never writes through');
}

void main() {
  late OfflineCache cache;
  late SettingsSyncNotifier sync;
  late _NoServer server;
  var offline = true;

  setUpAll(initHomeTestSupabase);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
    server = _NoServer();
    offline = true;
    sync = SettingsSyncNotifier(
      accountId: 'A',
      handlers: {
        SettingKeys.notifications: server,
        SettingKeys.privacy: server,
      },
      isOffline: () => offline,
      observeLifecycle: false,
    );
    addTearDown(sync.dispose);
    await pumpEventQueue(times: 20);
  });

  group('notifications', () {
    NotificationSettingsController build(_Repo repo) =>
        NotificationSettingsController(
          repo,
          sync: sync,
          accountId: 'A',
          cache: cache,
        );

    test('an offline toggle applies at once and is queued', () async {
      final c = build(_Repo(NotificationSettings.defaults('A')));
      addTearDown(c.dispose);
      await pumpEventQueue(times: 20);
      expect(c.state.settings!.pushEnabled, isTrue);

      await c.setPushEnabled(false);

      expect(c.state.settings!.pushEnabled, isFalse);
      expect(c.state.error, isNull);
      expect(sync.state, {SettingKeys.notifications: SettingSyncState.pending});
      expect(
        (await sync.pendingValue(SettingKeys.notifications))!['push_enabled'],
        isFalse,
      );
    });

    test('after a restart, offline, the queued value is what shows', () async {
      final c = build(_Repo(NotificationSettings.defaults('A')));
      await pumpEventQueue(times: 20);
      await c.setSmsEnabled(true);
      c.dispose();

      final reopened = build(_Repo(null)); // no connection, server unreachable
      addTearDown(reopened.dispose);
      await pumpEventQueue(times: 20);
      expect(reopened.state.settings!.smsEnabled, isTrue);
      expect(reopened.state.error, isNull);
    });

    test('offline with nothing queued, the last server copy shows', () async {
      final online = build(_Repo(NotificationSettings.defaults('A')));
      await pumpEventQueue(times: 20);
      online.dispose();

      final offlineC = build(_Repo(null));
      addTearDown(offlineC.dispose);
      await pumpEventQueue(times: 20);
      expect(offlineC.state.settings, isNotNull);
      expect(offlineC.state.error, isNull);
    });

    test('when the connection returns the queued value is sent', () async {
      final c = build(_Repo(NotificationSettings.defaults('A')));
      addTearDown(c.dispose);
      await pumpEventQueue(times: 20);
      await c.setEmailEnabled(true);
      offline = false;
      await sync.syncAll(force: true);
      expect(server.pushed.single['email_enabled'], isTrue);
      expect(sync.state, isEmpty);
    });
  });

  group('privacy', () {
    PrivacyController build() => PrivacyController(
      settingsRepository: SettingsRepositoryImpl(
        buildTestSupabaseClient(
          (r) async => postgrestErrorResponse(
            message: 'offline',
            code: '500',
            status: 500,
            request: r,
          ),
        ),
      ),
      sync: sync,
      accountId: 'A',
      cache: cache,
    );

    test(
      'an offline change is not queued: privacy is excluded (KAN-657)',
      () async {
        final c = build();
        addTearDown(c.dispose);
        await c.loadPrivacySettings('A');

        c.updateSetting('showEmail', true);
        await c.saveAllChanges('A');

        // The existing network error path ran; nothing was queued.
        expect(sync.state, isEmpty);
        expect(await const PendingSettingsStore().load('A'), isEmpty);
      },
    );

    test('another account\'s id does not use this queue', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.loadPrivacySettings('B'); // not the sync account: old path
      c.updateSetting('showEmail', true);
      await c.saveAllChanges('B');
      expect(sync.state, isEmpty);
    });
  });
}
