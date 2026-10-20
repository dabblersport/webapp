import 'dart:io';

import 'package:dabbler/data/repositories/following_sport_filter.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-593 — Following (profiles.interests uuid[]) filters DISCOVERY feeds by
// posts.sport_id uuid. Untagged posts always pass; empty/NULL Following = no
// filter; search, profile, sport overview and direct links are untouched.

const football = '11111111-1111-1111-1111-111111111111';
const tennis = '22222222-2222-2222-2222-222222222222';
const padel = '33333333-3333-3333-3333-333333333333';

Map<String, dynamic> row(String id, String? sportId) => {
  'id': id,
  'sport_id': sportId,
};

final rows = [
  row('football-post', football),
  row('tennis-post', tennis),
  row('padel-post', padel),
  row('untagged-post', null),
  row('blank-tag-post', ''),
];

List<String> ids(List<Map<String, dynamic>> r) =>
    r.map((e) => e['id'] as String).toList();

List<Map<String, dynamic>> discovery(Object? interests) =>
    filterByFollowedSports(
      rows,
      parseFollowedSportIds(interests),
      (r) => r['sport_id'] as String?,
    );

String _src(String path) => File(path).readAsStringSync();

/// Body of one Dart method in [src], from its name to the next `@override`.
String _method(String src, String name) {
  final start = src.indexOf('> $name(');
  expect(start, isNonNegative, reason: '$name not found');
  final end = src.indexOf('@override', start);
  return src.substring(start, end == -1 ? src.length : end);
}

void main() {
  group('TC1 viewer follows Football only', () {
    test('feed keeps Football + untagged, drops Tennis and Padel', () {
      expect(ids(discovery([football])), [
        'football-post',
        'untagged-post',
        'blank-tag-post',
      ]);
    });

    test('works on typed items (For you path keys on Post.sportId)', () {
      final posts = [
        (id: 'f', sportId: football),
        (id: 't', sportId: tennis),
        (id: 'u', sportId: null),
      ];
      final out = filterByFollowedSports<({String id, String? sportId})>(
        posts,
        parseFollowedSportIds([football]),
        (p) => p.sportId,
      );
      expect(out.map((p) => p.id), ['f', 'u']);
      expect(
        _src('lib/features/social/providers/feed_notifier.dart'),
        contains('(Post p) => p.sportId'),
      );
    });

    test('query-level filter expression keeps untagged and followed', () {
      expect(
        followedSportsOrFilter(parseFollowedSportIds([football])),
        'sport_id.is.null,sport_id.in.($football)',
      );
    });
  });

  test('follows several sports: Football + Padel', () {
    expect(ids(discovery([football, padel])), [
      'football-post',
      'padel-post',
      'untagged-post',
      'blank-tag-post',
    ]);
    expect(
      followedSportsOrFilter(parseFollowedSportIds([padel, football])),
      'sport_id.is.null,sport_id.in.($football,$padel)',
    );
  });

  test('UUID case is normalised on both sides', () {
    expect(ids(discovery([football.toUpperCase()])), contains('football-post'));
    expect(passesFollowingFilter(tennis.toUpperCase(), {tennis}), isTrue);
  });

  group('TC4 empty / NULL Following = unfiltered, no crash', () {
    for (final entry in <String, Object?>{
      'NULL': null,
      'empty list': <String>[],
      'only blanks': ['', '  '],
      'not a list': 'garbage',
    }.entries) {
      test(entry.key, () {
        expect(parseFollowedSportIds(entry.value), isNull);
        expect(ids(discovery(entry.value)), ids(rows));
        expect(
          followedSportsOrFilter(parseFollowedSportIds(entry.value)),
          isNull,
        );
      });
    }
  });

  group('wiring: discovery feeds filtered, others untouched', () {
    final repo = _src('lib/data/repositories/post_repository_impl.dart');
    final notifier = _src('lib/features/social/providers/feed_notifier.dart');

    test('discovery feeds load Following', () {
      for (final m in ['getHomeFeed', 'getRpcFeed', 'getNearbyFeed']) {
        expect(
          _method(repo, m),
          contains('loadViewerFollowedSportIds'),
          reason: m,
        );
      }
      // 'For you' (get_home_feed RPC) filters after getPostsByIds.
      expect(RegExp('filterByFollowedSports').allMatches(notifier).length, 2);
    });

    test('TC2 search / profile / sport overview / direct link unfiltered', () {
      for (final m in [
        'getPostsByIds', // direct link + realtime refresh
        '_fetchPostsByIds',
        'getPost', // post-by-id
        'getUserPosts', // profile posts
        'getUserPostsBySport', // profile sport overview
        'getCommentedPostsBySport',
        'getReactedPostsBySport',
        'getHashtagFeed', // search/hashtag
        'getFollowingFeed',
        'getCircleFeed',
        'getSquadFeed',
        'getNewsFeed',
        'getAreaFeed',
      ]) {
        final body = _method(repo, m);
        expect(body, isNot(contains('loadViewerFollowedSportIds')), reason: m);
        expect(body, isNot(contains('filterByFollowedSports')), reason: m);
      }
      final getPost = _method(repo, 'getPost');
      expect(getPost, isNot(contains('Followed')));
      // Search lives outside the post repository entirely.
      expect(
        Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.contains('search') && f.path.endsWith('.dart'))
            .any((f) => f.readAsStringSync().contains('FollowedSport')),
        isFalse,
      );
    });

    test('refreshPost (already-shown post) is not filtered', () {
      final refresh = notifier.substring(
        notifier.indexOf('Future<void> refreshPost('),
      );
      final end = refresh.indexOf('\n  }\n');
      expect(refresh.substring(0, end), isNot(contains('Followed')));
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
