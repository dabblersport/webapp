import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// KAN-960 (CEO 2026-11-16, reverts the KAN-955 followed-sports match): no
// feed reads followed sports (`profiles.interests`) any more. Following is
// followed people only; For you, Nearby, Active, News, search, profile, sport
// overview and direct links carry no followed-sports filter.

String _src(String path) => File(path).readAsStringSync();

/// Body of one Dart method in [src], from its name to the next `@override`.
String _method(String src, String name) {
  final start = src.indexOf('> $name(');
  expect(start, isNonNegative, reason: '$name not found');
  final end = src.indexOf('@override', start);
  return src.substring(start, end == -1 ? src.length : end);
}

void main() {
  group('wiring: no feed reads followed sports', () {
    final repo = _src('lib/data/repositories/post_repository_impl.dart');

    test('the followed-sports helper is gone', () {
      expect(
        File('lib/data/repositories/following_sport_filter.dart').existsSync(),
        isFalse,
      );
      expect(repo, isNot(contains('following_sport_filter')));
      expect(repo, isNot(contains('FollowedSport')));
    });

    test('getFollowingFeed matches followed authors only', () {
      final body = _method(repo, 'getFollowingFeed');
      expect(body, contains(".inFilter('author_profile_id', followedIds)"));
      expect(body, isNot(contains('.or(')));
      expect(body, isNot(contains('interests')));
      expect(body, isNot(contains('sport_id')));
    });

    test('every other feed and read path is unfiltered', () {
      for (final m in [
        'getHomeFeed',
        'getRpcFeed',
        'getNearbyFeed',
        'getPostsByIds', // direct link + realtime refresh
        '_fetchPostsByIds',
        'getPost', // post-by-id
        'getUserPosts', // profile posts
        'getHashtagFeed', // search/hashtag
        'getCircleFeed',
        'getSquadFeed',
        'getNewsFeed',
        'getAreaFeed',
      ]) {
        expect(_method(repo, m), isNot(contains('interests')), reason: m);
      }
      for (final path in [
        'lib/features/social/providers/feed_notifier.dart', // For you
        'lib/features/social/data/nearby_candidate_source.dart', // Nearby
        'lib/features/social/providers/active_feed_notifier.dart', // Active
        'lib/features/news/providers/news_providers.dart', // News
      ]) {
        expect(_src(path), isNot(contains('interests')), reason: path);
      }
    });
  });

  group(
    'TC3 creating a Tennis post never writes Following / sport profiles',
    () {
      test('client create paths do not touch interests or sport_profiles', () {
        final repo = _src('lib/data/repositories/post_repository_impl.dart');
        for (final m in ['createPost', 'insertPost', 'createFullPost']) {
          final body = _method(repo, m);
          expect(body, isNot(contains('interests')), reason: m);
          expect(body, isNot(contains('sportProfilesTable')), reason: m);
          expect(body, isNot(contains('sport_profiles')), reason: m);
          expect(
            body,
            isNot(contains('usersTable)\n          .update')),
            reason: m,
          );
        }
      });

      test(
        'create_post RPC (latest migration) writes no interests/profiles',
        () {
          final sql = _src(
            'supabase/migrations/20261013125000_create_post_keeps_place.sql',
          );
          expect(sql, isNot(contains('interests')));
          expect(sql, isNot(contains('sport_profiles')));
          expect(
            RegExp(
              r'UPDATE\s+public\.profiles',
              caseSensitive: false,
            ).hasMatch(sql),
            isFalse,
          );
        },
      );
    },
  );
}
