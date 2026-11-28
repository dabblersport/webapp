// KAN-1061: Manage Sports has My sports (active cards) and Following
// (interests); hidden cards are out of My sports; RPC outcomes map to
// messages; nothing under lib/ reads `preferred_sport`.

import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/sports/data/my_sports_rpc.dart';
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sports/my_sports_provider_test.dart' show catalogue;

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  void set(ProfileState s) => state = s;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Active card ids only, as the repository returns them (hidden_at IS NULL).
class _Repo implements SportProfilesRepository {
  _Repo(this.active);
  List<String> active;
  @override
  Future<Result<List<String>, Failure>> getSportIdsForProfile(
    String id,
  ) async => Ok(List.of(active));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile(String name) => UserProfile(
  id: 'p1',
  userId: 'u1',
  displayName: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  interests: const ['fb'],
  primarySport: 'fb',
  profileType: 'player',
);

Future<void> _pumpSheet(WidgetTester tester, _Repo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          (ref) => _Profile(ProfileState(profile: _profile('A'))),
        ),
        sportProfilesRepositoryProvider.overrideWithValue(repo),
        sportsProvider.overrideWith((ref) async => catalogue),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => catalogue,
        ),
      ],
      child: MaterialApp(
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ManageSportsSheet(saving: ValueNotifier<bool>(false)),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _selectedIn(String section) => find.descendant(
  of: find.byKey(ValueKey<String>(section)),
  matching: find.byWidgetPredicate((w) => w is DabblerChip && w.selected),
);

void main() {
  testWidgets('two sections render, with the active card and the interest', (
    tester,
  ) async {
    await _pumpSheet(tester, _Repo(['gym']));
    expect(find.text('My sports'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(_selectedIn('manage-sports-mine'), findsOneWidget);
    expect(_selectedIn('manage-sports-following'), findsOneWidget);
    final mine = tester.widget<DabblerChip>(_selectedIn('manage-sports-mine'));
    expect(mine.label, 'Gym Training');
  });

  testWidgets('a hidden card is not in My sports', (tester) async {
    // gym's card is hidden: the repository (hidden_at IS NULL) leaves it out.
    await _pumpSheet(tester, _Repo([]));
    expect(_selectedIn('manage-sports-mine'), findsNothing);
    expect(_selectedIn('manage-sports-following'), findsOneWidget);
  });

  test('re-adding a hidden card shows it again in my sports', () async {
    final repo = _Repo([]);
    final notifier = _Profile(ProfileState(profile: _profile('A')));
    final c = ProviderContainer(
      overrides: [
        profileControllerProvider.overrideWith((ref) => notifier),
        sportProfilesRepositoryProvider.overrideWithValue(repo),
        sportsProvider.overrideWith((ref) async => catalogue),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(mySportsProvider, (_, _) {});
    addTearDown(sub.close);
    var mine = await c.read(mySportsProvider.future);
    expect(mine.sports.map((s) => s.id), isNot(contains('gym')));

    repo.active = ['gym']; // rpc_add_my_sport → restored
    notifier.set(ProfileState(profile: _profile('B')));
    mine = await c.read(mySportsProvider.future);
    expect(mine.sports.map((s) => s.id), contains('gym'));
  });

  test('preferred_sport is not part of my sports', () async {
    final profile = _profile('A').copyWith(preferredSport: 'pd');
    final c = ProviderContainer(
      overrides: [
        profileControllerProvider.overrideWith(
          (ref) => _Profile(ProfileState(profile: profile)),
        ),
        sportProfilesRepositoryProvider.overrideWithValue(_Repo([])),
        sportsProvider.overrideWith((ref) async => catalogue),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(mySportsProvider, (_, _) {});
    addTearDown(sub.close);
    final mine = await c.read(mySportsProvider.future);
    expect(mine.sports.map((s) => s.id), ['fb']);
  });

  group('outcomes', () {
    test('RPC text maps to an outcome', () {
      for (final done in [
        'followed',
        'unfollowed',
        'added',
        'restored',
        'removed',
        'set',
      ]) {
        expect(sportOutcomeFrom(done), SportOutcome.done);
      }
      expect(sportOutcomeFrom('unchanged'), SportOutcome.unchanged);
      expect(sportOutcomeFrom('blocked_primary'), SportOutcome.blockedPrimary);
      expect(
        sportOutcomeFrom('blocked_in_my_sports'),
        SportOutcome.blockedInMySports,
      );
      expect(sportOutcomeFrom('blocked_last'), SportOutcome.blockedLast);
      expect(sportOutcomeFrom('invalid_sport'), SportOutcome.invalid);
      expect(sportOutcomeFrom(null), SportOutcome.invalid);
    });

    for (final locale in ['en', 'ar']) {
      test('outcome messages in $locale', () {
        final l = lookupAppLocalizations(Locale(locale));
        expect(manageSportsOutcomeMessage(SportOutcome.done, l), isNull);
        expect(manageSportsOutcomeMessage(SportOutcome.unchanged, l), isNull);
        expect(
          manageSportsOutcomeMessage(SportOutcome.blockedPrimary, l),
          l.manage_sports_remove_primary,
        );
        expect(
          manageSportsOutcomeMessage(SportOutcome.blockedLast, l),
          l.manage_sports_last_sport,
        );
        expect(
          manageSportsOutcomeMessage(SportOutcome.blockedInMySports, l),
          l.manage_sports_unfollow_in_my_sports,
        );
      });
    }

    test('the new strings', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(
        en.manage_sports_unfollow_in_my_sports,
        'Remove it from your sports first',
      );
      expect(ar.manage_sports_unfollow_in_my_sports, 'أزلها من رياضاتك أولاً');
      expect(en.manage_sports_section_mine, 'My sports');
      expect(ar.manage_sports_section_following, 'أتابعها');
    });
  });

  test('no file under lib/ reads preferred_sport outside the compat sites', () {
    // Compat sites: writes (preferred_sport = primary_sport), the onboarding
    // RPC parameter, the model's JSON mapping and select lists that feed it.
    // None of them decides anything from the value.
    const allowed = <String>{
      'lib/core/services/auth_service.dart',
      'lib/features/profile/domain/services/profile_creation_service.dart',
      'lib/features/profile/presentation/screens/profile_edit_screen.dart',
      'lib/features/auth_onboarding/data/unified_onboarding_client.dart',
      'lib/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_welcome_screen.dart',
      'lib/features/auth_onboarding/presentation/controllers/onboarding_controller.dart',
      'lib/features/auth_onboarding/data/repositories/onboarding_repository.dart',
      'lib/features/profile/data/datasources/supabase_profile_datasource.dart',
      'lib/data/models/profile/user_profile.dart',
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      final text = f.readAsStringSync();
      if (!RegExp(r"""['"]p?_?preferred_sport['"]""").hasMatch(text)) {
        continue;
      }
      if (!allowed.contains(f.path.replaceAll(r'\', '/')))
        offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
