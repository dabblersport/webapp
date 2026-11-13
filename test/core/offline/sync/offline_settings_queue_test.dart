import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/offline/sync/queueable_settings.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-657: only preference settings are queued; a rejected edit is dropped
/// with a notice; a newer server value wins with a notice.
class _Server extends SettingSyncHandler {
  DateTime? updatedAt;
  Object? pushError;
  int adopted = 0;
  final pushed = <String>[];

  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => updatedAt;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    final e = pushError;
    if (e != null) throw e;
    pushed.add('${edit.key}=${edit.value['v']}');
  }

  @override
  Future<void> adoptServer(String accountId) async => adopted++;
}

void main() {
  late _Server server;
  late List<String> notices;
  var offline = true;
  final t0 = DateTime.utc(2026, 10, 27, 10);

  SettingsSyncNotifier build() => SettingsSyncNotifier(
    accountId: 'A',
    handlers: {
      SettingKeys.theme: server,
      SettingKeys.notifications: server,
      SettingKeys.privacy: server,
      'payments': server,
      'persona': server,
    },
    isOffline: () => offline,
    now: () => t0,
    observeLifecycle: false,
    onNotice: (k, n) => notices.add('$k:${n?.name}'),
  );

  Future<void> settle() => pumpEventQueue(times: 40);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    notices = [];
    offline = true;
  });

  group('excluded settings are never queued', () {
    for (final key in [
      SettingKeys.privacy,
      'payments',
      'wallet',
      'persona',
      'intention',
      'profile_identity',
      'account_deletion',
    ]) {
      test('$key is refused offline and nothing is stored', () async {
        final n = build();
        addTearDown(n.dispose);
        await settle();
        expect(isQueueableSetting(key), isFalse);
        expect(await n.submit(key, {'v': 1}), SubmitOutcome.refused);
        expect(n.state, isEmpty);
        expect(await const PendingSettingsStore().load('A'), isEmpty);
        expect(server.pushed, isEmpty);
      });
    }

    test('the preference settings are queueable', () {
      for (final k in [
        SettingKeys.theme,
        SettingKeys.language,
        SettingKeys.notifications,
        SettingKeys.region,
      ]) {
        expect(isQueueableSetting(k), isTrue);
      }
    });
  });

  test(
    'same key: three offline edits leave one entry with the last value',
    () async {
      final n = build();
      addTearDown(n.dispose);
      await settle();
      await n.submit(SettingKeys.theme, {'v': 'dark'});
      await n.submit(SettingKeys.theme, {'v': 'light'});
      await n.submit(SettingKeys.theme, {'v': 'dark'});
      final q = await const PendingSettingsStore().load('A');
      expect(q.keys, [SettingKeys.theme]);
      expect(q[SettingKeys.theme]!.value['v'], 'dark');
      offline = false;
      await n.syncAll(force: true);
      expect(server.pushed, ['theme=dark']);
      expect(n.state, isEmpty);
    },
  );

  test('a validation or permission error drops the entry, restores the '
      'server value and shows a notice', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    server.pushError = const Failure(category: FailureCode.validation);
    offline = false;
    await n.syncAll(force: true);
    expect(await const PendingSettingsStore().load('A'), isEmpty);
    expect(n.state, isEmpty);
    expect(server.adopted, 1);
    expect(notices.last, 'theme:rejected');
  });

  test('a forbidden error is dropped too', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.notifications, {'v': 1});
    server.pushError = const Failure(category: FailureCode.forbidden);
    offline = false;
    await n.retry(SettingKeys.notifications);
    expect(await const PendingSettingsStore().load('A'), isEmpty);
  });

  test('a network error keeps the entry for retry', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    server.pushError = const Failure(category: FailureCode.noInternet);
    offline = false;
    await n.syncAll(force: true);
    expect(n.state, {SettingKeys.theme: SettingSyncState.failed});
    expect(await const PendingSettingsStore().load('A'), isNotEmpty);
    expect(notices.where((x) => x.endsWith('rejected')), isEmpty);
  });

  test('server newer than the local edit: server wins, notice says updated '
      'elsewhere', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    server.updatedAt = t0.add(const Duration(minutes: 5));
    offline = false;
    await n.syncAll(force: true);
    expect(server.pushed, isEmpty);
    expect(server.adopted, 1);
    expect(n.state, isEmpty);
    expect(notices.last, 'theme:updatedElsewhere');
  });

  test('a new edit clears the setting\'s earlier notice', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    expect(notices.last, 'theme:null');
  });

  test('queue persists across restart and is cleared on sign-out', () async {
    final n = build();
    await settle();
    await n.submit(SettingKeys.notifications, {'v': 1});
    n.dispose();
    final restarted = build();
    addTearDown(restarted.dispose);
    await settle();
    expect(restarted.state, {
      SettingKeys.notifications: SettingSyncState.pending,
    });
    await const PendingSettingsStore().wipe();
    expect(await const PendingSettingsStore().load('A'), isEmpty);
  });
}
