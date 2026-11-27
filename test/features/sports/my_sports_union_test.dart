// KAN-1056: the viewer's sports are interests ∪ sport_profiles ∪ primary
// sport; the nav keeps the gated tabs out while they load; a contributor's
// primary sport gets its own message.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
import 'package:dabbler/features/profile/domain/services/sport_removal.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:dabbler/l10n/app_localizations_ar.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_sports_provider_test.dart' show catalogue, football, gym;

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SportProfilesRepository {
  _Repo(this.ids);
  final Future<List<String>> ids;
  @override
  Future<Result<List<String>, Failure>> getSportIdsForProfile(
    String id,
  ) async => Ok(await ids);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile({List<String>? interests, String? primary}) => UserProfile(
  id: 'p1',
  userId: 'u1',
  displayName: 'Legacy',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  interests: interests,
  primarySport: primary,
);

ProviderContainer _container(ProfileState state, Future<List<String>> rows) {
  final c = ProviderContainer(
    overrides: [
      profileControllerProvider.overrideWith((ref) => _Profile(state)),
      sportProfilesRepositoryProvider.overrideWithValue(_Repo(rows)),
      sportsProvider.overrideWith((ref) async => catalogue),
      initializeProfileDataProvider.overrideWith((ref) async => true),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'legacy profile: a sport_profiles sport missing from interests counts',
    () async {
      final c = _container(
        ProfileState(profile: _profile(interests: const ['fb'])),
        Future.value(const ['gym']),
      );
      final mine = await c.read(mySportsProvider.future);
      expect(mine.sports, [football, gym]);
      expect(mine.showsMeetups, isTrue);
    },
  );

  test('primary sport alone is enough; inactive ids drop', () async {
    final c = _container(
      ProfileState(profile: _profile(primary: 'gym')),
      Future.value(const ['gone']),
    );
    expect((await c.read(mySportsProvider.future)).sports, [gym]);
  });

  test('nav: null (no gated tabs) while my sports loads', () async {
    final rows = Completer<List<String>>();
    final c = _container(
      ProfileState(profile: _profile(interests: const ['fb'])),
      rows.future,
    );
    final sub = c.listen(mySportsNavProvider, (_, __) {});
    addTearDown(sub.close);
    expect(sub.read(), isNull);
    rows.complete(const []);
    await c.read(mySportsProvider.future);
    final nav = sub.read();
    expect(nav, isNotNull);
    expect(nav!.showsMeetups, isFalse);
    expect(nav.showsGames, isTrue);
  });

  test('nav: null while the profile is still loading', () {
    final c = _container(
      const ProfileState(isLoading: true),
      Future.value(const []),
    );
    expect(c.read(mySportsNavProvider), isNull);
  });

  test('nav: signed out shows everything', () async {
    final c = _container(const ProfileState(), Future.value(const []));
    await c.read(initializeProfileDataProvider.future);
    final nav = c.read(mySportsNavProvider);
    expect(nav, isNotNull);
    expect(nav!.showsGames && nav.showsMeetups, isTrue);
  });

  group('removal block', () {
    test('a contributor\'s primary sport is blocked as primarySport', () {
      expect(
        sportRemovalBlock(
          sportId: 'fb',
          selectedCount: 2,
          profileType: 'contributor',
          primarySport: 'fb',
        ),
        SportRemovalBlock.primarySport,
      );
      expect(
        sportRemovalBlock(
          sportId: 'gym',
          selectedCount: 2,
          profileType: 'contributor',
          primarySport: 'fb',
        ),
        isNull,
      );
    });

    test('a legacy player\'s primary or preferred sport is blocked too', () {
      expect(
        sportRemovalBlock(
          sportId: 'fb',
          selectedCount: 2,
          profileType: 'player',
          primarySport: 'fb',
        ),
        SportRemovalBlock.primarySport,
      );
      expect(
        sportRemovalBlock(
          sportId: 'gym',
          selectedCount: 2,
          profileType: 'player',
          primarySport: null,
          preferredSport: 'gym',
        ),
        SportRemovalBlock.primarySport,
      );
      expect(
        sportRemovalBlock(
          sportId: 'gym',
          selectedCount: 2,
          profileType: 'player',
          primarySport: 'fb',
          preferredSport: 'fb',
        ),
        isNull,
      );
    });

    test('the primary-sport message is specific, EN and AR', () {
      final en = AppLocalizationsEn().manage_sports_remove_primary;
      expect(en, contains('primary sport'));
      expect(en, isNot(contains('Try again')));
      expect(AppLocalizationsAr().manage_sports_remove_primary, isNotEmpty);
    });
  });
}
