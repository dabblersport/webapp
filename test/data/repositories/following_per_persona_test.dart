import 'dart:io';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// KAN-593 fix 1 / KAN-955: the Following feed is PER PROFILE (per persona):
// it reads the ACTIVE persona's follows. KAN-960: followed people only — the
// persona's followed sports are no longer read (see following_feed_955_test).

void main() {
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

    test('Following resolves the active persona profile by persona_type', () {
      final repo = File(
        'lib/data/repositories/post_repository_impl.dart',
      ).readAsStringSync();
      final body = repo.substring(repo.indexOf('> getFollowingFeed('));
      final method = body.substring(0, body.indexOf('@override'));
      expect(method, contains(".eq('persona_type', persona)"));
      expect(method, isNot(contains("order('created_at', ascending: true")));
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
