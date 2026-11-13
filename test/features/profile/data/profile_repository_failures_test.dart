import 'dart:async';
import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/models.dart';
import 'package:dabbler/features/profile/data/datasources/profile_data_sources.dart'
    show ProfileLocalDataSource;
import 'package:dabbler/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:dabbler/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-603: raw data-source exceptions become the shared failures, and the
/// cached profile still answers when the link or server is the problem.
class _Remote implements ProfileRemoteDataSource {
  _Remote(this.error);
  final Object error;
  @override
  Future<UserProfile> getProfile(
    String userId, {
    bool includeSports = true,
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async => throw error;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Local implements ProfileLocalDataSource {
  _Local(this.cached);
  final UserProfile? cached;
  @override
  Future<UserProfile?> getCachedProfile(String userId) async => cached;
  @override
  Future<bool> isCacheValid(String userId) async => false;
  @override
  Future<void> cacheProfile(UserProfile profile) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _p() => UserProfile(
  id: 'p1',
  userId: 'u1',
  username: 'x',
  displayName: 'X',
  age: 20,
  personaType: 'player',
  profileType: 'personal',
  interests: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<Either<Failure, UserProfile>> _get(Object error, UserProfile? cached) =>
    ProfileRepositoryImpl(
      remoteDataSource: _Remote(error),
      localDataSource: _Local(cached),
    ).getProfile('u1');

Failure _left(Either<Failure, UserProfile> r) =>
    r.fold((f) => f, (_) => throw StateError('expected a failure'));

void main() {
  test('raw SocketException without a cache is no-internet', () async {
    final f = _left(await _get(const SocketException('x'), null));
    expect(f.category, FailureCode.noInternet);
  });

  test('web ClientException without a cache is no-internet', () async {
    final f = _left(await _get(ClientException('Failed to fetch'), null));
    expect(f.category, FailureCode.noInternet);
  });

  test('raw TimeoutException is timeout, not network', () async {
    final f = _left(await _get(TimeoutException('x'), null));
    expect(f.category, FailureCode.timeout);
    expect(f, isA<TimeoutFailure>());
  });

  test('server errors map to server; expired JWT to unauthenticated', () async {
    final s = _left(
      await _get(const PostgrestException(message: 'x', code: '500'), null),
    );
    expect(s.category, FailureCode.server);
    final u = _left(
      await _get(
        const PostgrestException(message: 'x', code: 'PGRST303'),
        null,
      ),
    );
    expect(u.category, FailureCode.unauthenticated);
  });

  test('a raw network error still answers from the cached profile', () async {
    final r = await _get(const SocketException('x'), _p());
    expect(r.isRight, isTrue);
  });

  test('an unclassified error stays a data failure', () async {
    final f = _left(await _get(StateError('boom'), null));
    expect(f, isA<DataFailure>());
  });
}
