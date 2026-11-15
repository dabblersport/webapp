import 'dart:io';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/repositories/following_sport_filter.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// KAN-593 fix 1 — followed sports are PER PROFILE (per persona). KAN-955: the
// Following feed matches on the ACTIVE persona's profiles.interests, never the
// oldest profile's. No interests means no sport match.

const football = '11111111-1111-1111-1111-111111111111';
const tennis = '22222222-2222-2222-2222-222222222222';

/// Fake `profiles` table: one user, two active profiles. A is OLDER.
List<Map<String, dynamic>> profiles({Object? aInterests = const [football]}) =>
    [
      {
        'user_id': 'u1',
        'persona_type': 'player',
        'created_at': '2026-01-01',
        'interests': aInterests,
      },
      {
        'user_id': 'u1',
        'persona_type': 'organiser',
        'created_at': '2026-06-01',
        'interests': [tennis],
      },
    ];

ActiveProfileInterestsFetch fakeFetch(
  List<Map<String, dynamic>> table,
  List<String> queried,
) => (userId, persona) async {
  queried.add(persona);
  return table
      .where((r) => r['user_id'] == userId && r['persona_type'] == persona)
      .toList();
};

/// Posts the Following feed would match on sport for [followed] (KAN-955).
List<String> feedFor(Set<String>? followed) => [
  for (final p in const [
    ('football-post', football),
    ('tennis-post', tennis),
    ('untagged-post', null),
  ])
    if (p.$2 != null && (followed?.contains(p.$2) ?? false)) p.$1,
];

void main() {
  group('loader resolves the ACTIVE persona', () {
    test('active=A (player) filters by A only', () async {
      final q = <String>[];
      final f = await loadFollowedSportIdsFor(
        userId: 'u1',
        personaType: 'player',
        fetch: fakeFetch(profiles(), q),
      );
      expect(feedFor(f), ['football-post']);
      expect(q, ['player']);
    });

    test('switch to B (organiser, newer) filters by B only', () async {
      final q = <String>[];
      final f = await loadFollowedSportIdsFor(
        userId: 'u1',
        personaType: 'organiser',
        fetch: fakeFetch(profiles(), q),
      );
      expect(feedFor(f), ['tennis-post']);
      expect(q, ['organiser']);
    });

    test('active persona unresolved -> no sport match, no lookup', () async {
      final q = <String>[];
      final f = await loadFollowedSportIdsFor(
        userId: 'u1',
        personaType: null,
        fetch: fakeFetch(profiles(), q),
      );
      expect(f, isNull);
      expect(feedFor(f), isEmpty);
      expect(q, isEmpty, reason: 'never falls back to the oldest profile');
    });

    test('no signed-in user -> no sport match', () async {
      final f = await loadFollowedSportIdsFor(
        userId: null,
        personaType: 'player',
        fetch: fakeFetch(profiles(), []),
      );
      expect(f, isNull);
    });

    for (final empty in <Object?>[null, const <String>[]]) {
      test('active persona interests $empty while other has some -> '
          'no sport match', () async {
        final f = await loadFollowedSportIdsFor(
          userId: 'u1',
          personaType: 'player',
          fetch: fakeFetch(profiles(aInterests: empty), []),
        );
        expect(f, isNull);
        expect(feedFor(f), isEmpty);
      });
    }

    test('lookup error -> no sport match, never a crash', () async {
      final f = await loadFollowedSportIdsFor(
        userId: 'u1',
        personaType: 'player',
        fetch: (_, __) async => throw Exception('network'),
      );
      expect(f, isNull);
    });

    test('Supabase query filters by persona_type, not created_at order', () {
      final src = File(
        'lib/data/repositories/following_sport_filter.dart',
      ).readAsStringSync();
      final body = src.substring(
        src.indexOf('Future<Set<String>?> loadViewerFollowedSportIds('),
      );
      expect(body, contains(".eq('persona_type', persona)"));
      expect(body, isNot(contains("order('created_at'")));
    });
  });

  group('wiring: active persona reaches the feeds and reloads them', () {
    ProviderContainer container() => ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(
          SupabaseService(
            SupabaseClient('http://localhost', 'anon'),
            SupabaseErrorMapper(),
          ),
        ),
        activeProfileTypeProvider.overrideWith((ref) => 'player'),
      ],
    );

    test('repository carries the active persona and is rebuilt on switch', () {
      final c = container();
      addTearDown(c.dispose);
      final first = c.read(postRepositoryProvider) as PostRepositoryImpl;
      expect(first.activePersonaType, 'player');

      c.read(activeProfileTypeProvider.notifier).state = 'organiser';
      final second = c.read(postRepositoryProvider) as PostRepositoryImpl;
      expect(second.activePersonaType, 'organiser');
      expect(
        identical(first, second),
        isFalse,
        reason: 'feeds watching postRepositoryProvider rebuild and reload',
      );
    });

    test('only the Following feed reads the active persona sports', () {
      final repo = File(
        'lib/data/repositories/post_repository_impl.dart',
      ).readAsStringSync();
      expect(
        RegExp(
          r'loadViewerFollowedSportIds\(\s*_db,\s*personaType: activePersonaType',
        ).allMatches(repo).length,
        1,
        reason: 'getFollowingFeed only (KAN-955)',
      );
      final notifier = File(
        'lib/features/social/providers/feed_notifier.dart',
      ).readAsStringSync();
      expect(notifier, isNot(contains('loadViewerFollowedSportIds')));
      final tab = File(
        'lib/features/social/providers/tab_feed_notifier.dart',
      ).readAsStringSync();
      final nearby = tab.substring(tab.indexOf('final nearbyFeedProvider'));
      expect(nearby, contains('ref.watch(postRepositoryProvider)'));
      final pp = File(
        'lib/features/social/providers/post_providers.dart',
      ).readAsStringSync();
      expect(pp, contains('ref.watch(activePersonaProvider)'));
    });
  });
}
