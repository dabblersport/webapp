import 'dart:io';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/models.dart';
import 'package:dabbler/features/profile/data/datasources/profile_data_sources.dart'
    show ProfileLocalDataSourceImpl;
import 'package:dabbler/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:dabbler/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-607: profiles (own and others') survive a restart in the per-account
/// cache, a stale copy answers when the network fails, and a copy that is still
/// fresh is revalidated in the background on every open.
class _Remote implements ProfileRemoteDataSource {
  _Remote(this.profiles);
  Map<String, UserProfile> profiles;
  bool offline = false;
  int calls = 0;
  @override
  Future<UserProfile> getProfile(
    String userId, {
    bool includeSports = true,
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {
    calls++;
    if (offline) throw const SocketException('offline');
    return profiles[userId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _p(String userId, String name) => UserProfile(
  id: 'p-$userId',
  userId: userId,
  username: name.toLowerCase(),
  displayName: name,
  age: 20,
  personaType: 'player',
  profileType: 'personal',
  interests: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late OfflineCache disk;
  String? account;

  /// A fresh data source = a restarted app: nothing in memory, disk survives.
  ProfileLocalDataSourceImpl restarted() {
    final local = ProfileLocalDataSourceImpl();
    local.clearMemoryForTest();
    local.useDiskForTest(disk, () => account);
    return local;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    disk = OfflineCache(prefs: await SharedPreferences.getInstance());
    account = 'A';
  });

  test(
    'own and another user\'s profile open offline after a restart',
    () async {
      final remote = _Remote({'me': _p('me', 'Me'), 'you': _p('you', 'You')});
      var repo = ProfileRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: restarted(),
      );
      await repo.getProfile('me');
      await repo.getProfile('you');

      remote.offline = true;
      repo = ProfileRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: restarted(),
      );
      for (final id in ['me', 'you']) {
        final r = await repo.getProfile(id);
        expect(r.fold((_) => null, (p) => p.userId), id);
      }
    },
  );

  test(
    'a cache older than 12 h still answers when the network fails',
    () async {
      final remote = _Remote({'you': _p('you', 'You')});
      final old = DateTime.now().subtract(const Duration(hours: 13));
      await disk.write(
        'A',
        'profile.you',
        _p('you', 'You').toJson(),
        fetchedAt: old,
      );
      remote.offline = true;
      final local = restarted();
      expect(await local.isCacheValid('you'), isFalse);
      final r = await ProfileRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      ).getProfile('you');
      expect(r.fold((_) => null, (p) => p.displayName), 'You');
    },
  );

  test(
    'a fresh copy is shown at once and revalidated in the background',
    () async {
      final remote = _Remote({'you': _p('you', 'You')});
      final repo = ProfileRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: restarted(),
      );
      await repo.getProfile('you');
      expect(remote.calls, 1);

      remote.profiles = {'you': _p('you', 'You renamed')};
      final again = await repo.getProfile('you');
      expect(again.fold((_) => null, (p) => p.displayName), 'You'); // no jump
      await Future<void>.delayed(Duration.zero);
      expect(remote.calls, 2); // revalidated
      final next = await repo.getProfile('you');
      expect(next.fold((_) => null, (p) => p.displayName), 'You renamed');
    },
  );

  test('another account never reads the first account\'s profile', () async {
    final remote = _Remote({'you': _p('you', 'You')});
    await ProfileRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: restarted(),
    ).getProfile('you');

    account = 'B';
    remote.offline = true;
    final r = await ProfileRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: restarted(),
    ).getProfile('you');
    expect(r, isA<Left>());
  });

  test('sign-out wipe removes the stored profiles', () async {
    final remote = _Remote({'you': _p('you', 'You')});
    await ProfileRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: restarted(),
    ).getProfile('you');
    await disk.wipe();
    expect(await disk.read('A', 'profile.you'), isNull);
  });
}
