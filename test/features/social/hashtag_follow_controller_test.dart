// KAN-971: hashtag follow persists, unfollows, and reverts on failure.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/social/data/hashtag_follow_repository.dart';
import 'package:dabbler/features/social/presentation/providers/hashtag_follow_providers.dart';

class _FakeRepo implements HashtagFollowRepository {
  bool stored = false;
  bool fail = false;

  @override
  Future<Result<bool, Failure>> isFollowing(String slug) async =>
      Ok<bool, Failure>(stored);

  @override
  Future<Result<bool, Failure>> setFollowing(String slug, bool f) async {
    if (fail) return const Err<bool, Failure>(ServerFailure(message: "x"));
    stored = f;
    return Ok<bool, Failure>(stored);
  }
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer c;
  final p = hashtagFollowControllerProvider('#Padel');

  setUp(() {
    repo = _FakeRepo();
    c = ProviderContainer(
      overrides: [hashtagFollowRepositoryProvider.overrideWithValue(repo)],
    );
    c.listen(p, (_, _) {});
  });
  tearDown(() => c.dispose());

  test('follow then unfollow persists to the repository', () async {
    await Future<void>.delayed(Duration.zero);
    expect(c.read(p).following, isFalse);
    await c.read(p.notifier).toggle();
    expect(repo.stored, isTrue);
    expect(c.read(p).following, isTrue);
    await c.read(p.notifier).toggle();
    expect(repo.stored, isFalse);
    expect(c.read(p).following, isFalse);
  });

  test('stored follow is read back on open', () async {
    repo.stored = true;
    final fresh = ProviderContainer(
      overrides: [hashtagFollowRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(fresh.dispose);
    fresh.listen(p, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(fresh.read(p).following, isTrue);
  });

  test('a failed write reverts and reports an error', () async {
    await Future<void>.delayed(Duration.zero);
    repo.fail = true;
    await c.read(p.notifier).toggle();
    expect(c.read(p).following, isFalse);
    expect(c.read(p).error, isA<ServerFailure>());
    expect(c.read(p).busy, isFalse);
  });
}
