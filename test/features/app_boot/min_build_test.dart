import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/app_boot/min_build/min_build_providers.dart';
import 'package:dabbler/features/app_boot/min_build/min_build_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Result<MinBuildRequirement?, Failure> _row(int? min, {String? url}) =>
    Ok(MinBuildRequirement(minBuild: min, storeUrl: url));

class _FakeRepo implements MinBuildRepository {
  _FakeRepo(this.answer);
  final Future<Result<MinBuildRequirement?, Failure>> Function() answer;
  @override
  Future<Result<MinBuildRequirement?, Failure>> fetch(String platform) =>
      answer();
}

Future<MinBuildStatus> _status({
  required MinBuildRepository repo,
  int? build = 174,
  String? platform = 'ios',
}) {
  final container = ProviderContainer(
    overrides: [
      minBuildRepositoryProvider.overrideWithValue(repo),
      currentAppBuildProvider.overrideWith((ref) async => build),
      minBuildPlatformProvider.overrideWithValue(platform),
    ],
  );
  addTearDown(container.dispose);
  return container.read(minBuildStatusProvider.future);
}

void main() {
  group('decideMinBuild', () {
    MinBuildStatus decide(Result<MinBuildRequirement?, Failure> fetched) =>
        decideMinBuild(platform: 'ios', currentBuild: 174, fetched: fetched);

    test('below the minimum is blocked, with the store url', () {
      final s = decide(_row(175, url: 'https://apps.apple.com/x'));
      expect(s.blocked, isTrue);
      expect(s.storeUrl, 'https://apps.apple.com/x');
      expect(s.platform, 'ios');
    });

    test('equal to the minimum is not blocked', () {
      expect(decide(_row(174)).blocked, isFalse);
    });

    test('above the minimum is not blocked', () {
      expect(decide(_row(100)).blocked, isFalse);
    });

    test('a fetch error is not blocked', () {
      expect(
        decide(Err(TimeoutFailure(message: 'timed out'))).blocked,
        isFalse,
      );
    });

    test('a missing row is not blocked', () {
      expect(decide(const Ok(null)).blocked, isFalse);
    });

    test('a null min_build is not blocked', () {
      expect(decide(_row(null)).blocked, isFalse);
    });

    test('an unknown build or ungated platform is not blocked', () {
      expect(
        decideMinBuild(
          platform: 'ios',
          currentBuild: null,
          fetched: _row(999),
        ).blocked,
        isFalse,
      );
      expect(
        decideMinBuild(
          platform: null,
          currentBuild: 1,
          fetched: _row(999),
        ).blocked,
        isFalse,
      );
    });
  });

  group('MinBuildRequirement.fromRow', () {
    test('no row is null', () {
      expect(MinBuildRequirement.fromRow(null), isNull);
    });

    test('reads int, num and numeric string; anything else is null', () {
      expect(MinBuildRequirement.fromRow({'min_build': 7})!.minBuild, 7);
      expect(MinBuildRequirement.fromRow({'min_build': 7.0})!.minBuild, 7);
      expect(MinBuildRequirement.fromRow({'min_build': '8'})!.minBuild, 8);
      expect(
        MinBuildRequirement.fromRow({'min_build': null})!.minBuild,
        isNull,
      );
      expect(MinBuildRequirement.fromRow({'min_build': 'x'})!.minBuild, isNull);
    });

    test('a blank store_url is null', () {
      expect(
        MinBuildRequirement.fromRow({
          'min_build': 1,
          'store_url': ' ',
        })!.storeUrl,
        isNull,
      );
    });
  });

  group('minBuildPlatformKey', () {
    test('web wins, then ios / android, others are ungated', () {
      expect(
        minBuildPlatformKey(isWeb: true, platform: TargetPlatform.iOS),
        'web',
      );
      expect(
        minBuildPlatformKey(isWeb: false, platform: TargetPlatform.iOS),
        'ios',
      );
      expect(
        minBuildPlatformKey(isWeb: false, platform: TargetPlatform.android),
        'android',
      );
      expect(
        minBuildPlatformKey(isWeb: false, platform: TargetPlatform.macOS),
        isNull,
      );
    });
  });

  group('minBuildStatusProvider fails open', () {
    test('blocked when below the minimum', () async {
      final s = await _status(repo: _FakeRepo(() async => _row(200)));
      expect(s.blocked, isTrue);
    });

    test('an Err from the repository is not blocked', () async {
      final s = await _status(
        repo: _FakeRepo(() async => Err(NetworkFailure(message: 'no network'))),
      );
      expect(s.blocked, isFalse);
    });

    test('a repository that throws is not blocked', () async {
      final s = await _status(repo: _FakeRepo(() => throw StateError('boom')));
      expect(s.blocked, isFalse);
    });

    test('an unreadable build is not blocked', () async {
      final s = await _status(
        repo: _FakeRepo(() async => _row(200)),
        build: null,
      );
      expect(s.blocked, isFalse);
    });

    test('an ungated platform is not blocked', () async {
      final s = await _status(
        repo: _FakeRepo(() async => _row(200)),
        platform: null,
      );
      expect(s.blocked, isFalse);
    });
  });
}
