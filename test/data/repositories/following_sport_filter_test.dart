import 'dart:io';

import 'package:dabbler/data/repositories/following_sport_filter.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-955 (CEO 2026-11-16, supersedes the KAN-593 discovery filter): followed
// sports (profiles.interests uuid[]) match posts.sport_id uuid on the
// Following tab ONLY. For you, Nearby, Active, News, search, profile, sport
// overview and direct links carry no followed-sports filter.

const football = '11111111-1111-1111-1111-111111111111';
const padel = '33333333-3333-3333-3333-333333333333';

String _src(String path) => File(path).readAsStringSync();

/// Body of one Dart method in [src], from its name to the next `@override`.
String _method(String src, String name) {
  final start = src.indexOf('> $name(');
  expect(start, isNonNegative, reason: '$name not found');
  final end = src.indexOf('@override', start);
  return src.substring(start, end == -1 ? src.length : end);
}

void main() {
  group('parseFollowedSportIds', () {
    test('normalises case and whitespace', () {
      expect(parseFollowedSportIds([' ${football.toUpperCase()} ', padel]), {
        football,
        padel,
      });
    });

    group('empty / NULL interests = no sport match, no crash', () {
      for (final entry in <String, Object?>{
        'NULL': null,
        'empty list': <String>[],
        'only blanks': ['', '  '],
        'not a list': 'garbage',
      }.entries) {
        test(entry.key, () {
          expect(parseFollowedSportIds(entry.value), isNull);
          expect(
            followingFeedOrFilter(const [], parseFollowedSportIds(entry.value)),
            isNull,
          );
          expect(
            followingFeedOrFilter(const [
              'p1',
            ], parseFollowedSportIds(entry.value)),
            'author_profile_id.in.(p1)',
            reason: 'followed people still show',
          );
        });
      }
    });
  });

  group('wiring: only the Following feed reads followed sports', () {
    final repo = _src('lib/data/repositories/post_repository_impl.dart');

    test('getFollowingFeed loads followed sports and matches with or=', () {
      final body = _method(repo, 'getFollowingFeed');
      expect(body, contains('loadViewerFollowedSportIds'));
      expect(body, contains('followingFeedOrFilter'));
      expect(body, contains('.or(match)'));
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
        'getUserPostsBySport', // profile sport overview
        'getCommentedPostsBySport',
        'getReactedPostsBySport',
        'getHashtagFeed', // search/hashtag
        'getCircleFeed',
        'getSquadFeed',
        'getNewsFeed',
        'getAreaFeed',
      ]) {
        final body = _method(repo, m);
        expect(body, isNot(contains('loadViewerFollowedSportIds')), reason: m);
        expect(body, isNot(contains('followingFeedOrFilter')), reason: m);
      }
      for (final path in [
        'lib/features/social/providers/feed_notifier.dart', // For you
        'lib/features/social/data/nearby_candidate_source.dart', // Nearby
        'lib/features/social/providers/active_feed_notifier.dart', // Active
        'lib/features/news/providers/news_providers.dart', // News
      ]) {
        expect(_src(path), isNot(contains('following_sport_filter')));
      }
      expect(
        Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.contains('search') && f.path.endsWith('.dart'))
            .any((f) => f.readAsStringSync().contains('FollowedSport')),
        isFalse,
      );
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
