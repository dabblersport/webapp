import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-608: offline settings edits are queued with their edit time, survive a
/// restart, sync in timestamp order with last-write-wins, collapse duplicates,
/// keep a failed edit with a bounded backoff, and are discarded on sign-out
/// and account switch.
class _Server extends SettingSyncHandler {
  _Server(this.sent);
  final List<String> sent;
  DateTime? updatedAt;
  bool fails = false;
  int adopted = 0;
  final String name = 's';

  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => updatedAt;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    if (fails) throw StateError('no internet');
    sent.add('${edit.key}=${edit.value['v']}@${edit.editedAt.millisecond}');
    updatedAt = edit.editedAt;
  }

  @override
  Future<void> adoptServer(String accountId) async => adopted++;
}

void main() {
  late List<String> sent;
  late Map<String, _Server> servers;
  var offline = true;
  var clock = DateTime.utc(2026, 10, 21, 10);

  SettingsSyncNotifier build({String? account = 'A'}) => SettingsSyncNotifier(
    accountId: account,
    handlers: servers,
    isOffline: () => offline,
    now: () => clock,
    observeLifecycle: false,
  );

  Future<void> settle() => pumpEventQueue(times: 40);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    servers = {
      SettingKeys.notifications: _Server(sent),
      SettingKeys.privacy: _Server(sent),
      SettingKeys.theme: _Server(sent),
    };
    offline = true;
    clock = DateTime.utc(2026, 10, 21, 10);
  });

  test('an offline edit is queued and nothing is sent', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    final out = await n.submit(SettingKeys.theme, {'v': 'dark'});
    expect(out, SubmitOutcome.queued);
    expect(sent, isEmpty);
    expect(n.state, {SettingKeys.theme: SettingSyncState.pending});
  });

  test('the queue survives an app restart and syncs on reconnect', () async {
    final first = build();
    await settle();
    await first.submit(SettingKeys.theme, {'v': 'dark'});
    first.dispose();

    final restarted = build(); // offline: just loads
    addTearDown(restarted.dispose);
    await settle();
    expect(restarted.state.keys, [SettingKeys.theme]);
    expect(sent, isEmpty);

    offline = false; // the connection returns
    await restarted.syncAll(force: true);
    expect(sent, hasLength(1));
    expect(restarted.state, isEmpty);
  });

  test('edits of one setting collapse to the latest value', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'}, editedAt: clock);
    await n.submit(SettingKeys.theme, {
      'v': 'light',
    }, editedAt: clock.add(const Duration(milliseconds: 5)));
    offline = false;
    await n.syncAll(force: true);
    expect(sent, ['theme=light@5']);
  });

  test('pending edits are sent in edit-timestamp order', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.privacy, {
      'v': 'p',
    }, editedAt: clock.add(const Duration(milliseconds: 30)));
    await n.submit(SettingKeys.notifications, {
      'v': 'n',
    }, editedAt: clock.add(const Duration(milliseconds: 10)));
    await n.submit(SettingKeys.theme, {
      'v': 't',
    }, editedAt: clock.add(const Duration(milliseconds: 20)));
    offline = false;
    await n.syncAll(force: true);
    expect(sent, ['notifications=n@10', 'theme=t@20', 'privacy=p@30']);
  });

  test('last write wins: a newer server value is not overwritten', () async {
    final server = servers[SettingKeys.notifications]!
      ..updatedAt = clock.add(const Duration(minutes: 5));
    final n = build();
    addTearDown(n.dispose);
    await settle();
    final adopted = <String>[];
    n.adopted.listen(adopted.add);
    await n.submit(SettingKeys.notifications, {'v': 'old'}, editedAt: clock);
    offline = false;
    await n.syncAll(force: true);
    await settle();
    expect(sent, isEmpty, reason: 'the local edit was older: it is dropped');
    expect(server.adopted, 1);
    expect(adopted, [SettingKeys.notifications]);
    expect(n.state, isEmpty);
  });

  test(
    'last write wins: a later local edit is sent and stamps the row',
    () async {
      final server = servers[SettingKeys.notifications]!..updatedAt = clock;
      final n = build();
      addTearDown(n.dispose);
      await settle();
      offline = false;
      final later = clock.add(const Duration(minutes: 1));
      final out = await n.submit(SettingKeys.notifications, {
        'v': 'new',
      }, editedAt: later);
      expect(out, SubmitOutcome.synced);
      expect(server.updatedAt, later);
    },
  );

  test('a failed sync keeps the edit and shows the failed state', () async {
    servers[SettingKeys.theme]!.fails = true;
    final n = build();
    addTearDown(n.dispose);
    await settle();
    offline = false;
    final out = await n.submit(SettingKeys.theme, {'v': 'dark'});
    expect(out, SubmitOutcome.queued);
    expect(n.state[SettingKeys.theme], SettingSyncState.failed);
    expect(await n.pendingValue(SettingKeys.theme), {'v': 'dark'});
  });

  test('retry after the failure clears the state', () async {
    final server = servers[SettingKeys.theme]!..fails = true;
    final n = build();
    addTearDown(n.dispose);
    await settle();
    offline = false;
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    server.fails = false;
    await n.retry(SettingKeys.theme);
    expect(n.state, isEmpty);
    expect(sent, hasLength(1));
  });

  test('the backoff doubles and is capped', () async {
    final n = build();
    addTearDown(n.dispose);
    expect(n.backoffFor(1), n.backoffFor(0) * 2);
    expect(n.backoffFor(2), n.backoffFor(0) * 4);
    expect(n.backoffFor(50) <= n.backoffFor(7), isTrue);
    expect(n.backoffFor(50), n.backoffFor(20));
  });

  test(
    'a timer-driven sync respects the backoff, a reconnect does not',
    () async {
      final server = servers[SettingKeys.theme]!..fails = true;
      final n = build();
      addTearDown(n.dispose);
      await settle();
      offline = false;
      await n.submit(SettingKeys.theme, {'v': 'dark'}); // fails once, now
      server.fails = false;
      await n.syncAll(); // not due yet: the clock has not moved
      expect(sent, isEmpty);
      await n.syncAll(force: true); // reconnect / resume / tap
      expect(sent, hasLength(1));
    },
  );

  test('another account\'s queue is discarded on a switch', () async {
    final a = build();
    await settle();
    await a.submit(SettingKeys.theme, {'v': 'dark'});
    a.dispose();

    final b = build(account: 'B');
    addTearDown(b.dispose);
    await settle();
    expect(b.state, isEmpty);
    expect(await const PendingSettingsStore().load('A'), isEmpty);
    offline = false;
    await b.syncAll(force: true);
    expect(sent, isEmpty, reason: 'A\'s edit is never applied to B');
  });

  test('sign-out discards the queue', () async {
    final n = build();
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    n.dispose();
    await const PendingSettingsStore().wipe();
    expect(await const PendingSettingsStore().load('A'), isEmpty);
  });

  test('the queue stores only the setting value and its stamps', () async {
    final n = build();
    addTearDown(n.dispose);
    await settle();
    await n.submit(SettingKeys.theme, {'v': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings_sync.v1.A')!;
    expect(raw.contains('token'), isFalse);
    expect(
      (await const PendingSettingsStore().load('A'))[SettingKeys.theme]!.value,
      {'v': 'dark'},
    );
  });
}
