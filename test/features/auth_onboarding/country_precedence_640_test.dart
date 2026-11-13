import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-640 R8 (CEO): an explicit pick wins over everything; otherwise the
/// country detected on this session wins over the account's region and is
/// written to the account; if detection fails the account region stands, and
/// with none it is Global (never the first list item).
class _Remote implements ServiceRegionRemote {
  _Remote(this.stored);

  String? stored;

  @override
  Future<String?> fetch(String userId) async => stored;

  @override
  Future<void> save(String userId, String region) async => stored = region;
}

class _QueueHandler extends SettingSyncHandler {
  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => null;
  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {}
  @override
  Future<void> adoptServer(String accountId) async {}
}

Future<String?> _signIn(_Remote remote, {String? detected}) async {
  final n = SelectedLocationNotifier(
    userId: 'u1',
    remote: remote,
    detect: () async => detected ?? (throw Exception('detection failed')),
  );
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return n.state.valueOrNull?.country;
}

void main() {
  test(
    '(a) picked UAE + account Egypt -> UAE, and the account becomes UAE',
    () async {
      SharedPreferences.setMockInitialValues({
        'selected_country': 'United Arab Emirates',
        'selected_country.source': 'picked',
      });
      final remote = _Remote('Egypt');
      // Even if detection says Egypt, the pick wins.
      expect(await _signIn(remote, detected: 'Egypt'), 'United Arab Emirates');
      expect(remote.stored, 'United Arab Emirates');
    },
  );

  test('(a2) a pick made on the signed-out screens survives sign-in over an '
      'Egypt account', () async {
    SharedPreferences.setMockInitialValues({});
    final out = SelectedLocationNotifier(detect: () async => 'Egypt');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await out.setLocation(country: 'United Arab Emirates');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_country.source'), 'picked');
    final remote = _Remote('Egypt');
    expect(await _signIn(remote, detected: 'Egypt'), 'United Arab Emirates');
    expect(remote.stored, 'United Arab Emirates');
  });

  test(
    '(b) detected UAE + account Egypt -> UAE, and the account becomes UAE',
    () async {
      SharedPreferences.setMockInitialValues({});
      final remote = _Remote('Egypt');
      expect(
        await _signIn(remote, detected: 'United Arab Emirates'),
        'United Arab Emirates',
      );
      expect(remote.stored, 'United Arab Emirates');
    },
  );

  test('(c) detection fails + account Egypt -> Egypt', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _Remote('Egypt');
    expect(await _signIn(remote), 'Egypt');
    expect(remote.stored, 'Egypt');
  });

  test('(d) detection fails + no account region -> Global, not the first '
      'list item', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _Remote(null);
    expect(await _signIn(remote), 'Global');
    expect(remote.stored, isNull);
  });

  test('the detected-country account write goes through the offline queue, '
      'so a failed write is not dropped', () async {
    SharedPreferences.setMockInitialValues({});
    final sync = SettingsSyncNotifier(
      accountId: 'u1',
      handlers: {SettingKeys.region: _QueueHandler()},
      isOffline: () => true,
      observeLifecycle: false,
    );
    addTearDown(sync.dispose);
    await pumpEventQueue(times: 20);
    final remote = _Remote('Egypt');
    expect(
      await _signIn(remote, detected: 'United Arab Emirates'),
      'United Arab Emirates',
    );
    // Queued for later, not written straight to the table.
    expect(remote.stored, 'Egypt');
    expect(
      (await sync.pendingValue(SettingKeys.region))!['region'],
      'United Arab Emirates',
    );
  });

  test('a detected country is recorded as detected', () async {
    SharedPreferences.setMockInitialValues({});
    SelectedLocationNotifier(detect: () async => 'United Arab Emirates');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_country'), 'United Arab Emirates');
    expect(prefs.getString('selected_country.source'), 'detected');
  });
}
