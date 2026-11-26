// KAN-1052: the viewer's sports and their is_challenge_sport / can_solo flags.

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const football = Sport(id: 'fb', nameEn: 'Football', isChallengeSport: true);
const cricket = Sport(id: 'cr', nameEn: 'Cricket', isChallengeSport: true);
const padel = Sport(id: 'pd', nameEn: 'Padel', isChallengeSport: true);
const gym = Sport(id: 'gym', nameEn: 'Gym Training', canSolo: true);
const catalogue = <Sport>[cricket, football, gym, padel];

String _id(Sport s) => s.id;

void main() {
  test('Sport.fromMap reads both flags (default false)', () {
    final s = Sport.fromMap({
      'id': 'x',
      'name_en': 'X',
      'is_challenge_sport': true,
      'can_solo': true,
    });
    expect(s.isChallengeSport, isTrue);
    expect(s.canSolo, isTrue);
    final bare = Sport.fromMap({'id': 'y', 'name_en': 'Y'});
    expect(bare.isChallengeSport, isFalse);
    expect(bare.canSolo, isFalse);
  });

  group('MySports.fromIds', () {
    test('no ids is unscoped: every section shows', () {
      final m = MySports.fromIds(catalogue, const <String?>[null, '']);
      expect(m.isScoped, isFalse);
      expect(m.showsGames, isTrue);
      expect(m.showsMeetups, isTrue);
      expect(m.idsFor(SportSection.games), isNull);
      expect(m.scope(catalogue, SportSection.games, _id), catalogue);
    });

    test('ids outside the catalogue are dropped', () {
      final m = MySports.fromIds(catalogue, const ['fb', 'gone']);
      expect(m.sports, [football]);
    });

    test('challenge sports only: Games shows, Meetups hides', () {
      final m = MySports.fromIds(catalogue, const ['fb', 'pd']);
      expect(m.showsGames, isTrue);
      expect(m.showsMeetups, isFalse);
      expect(m.shows(SportSection.venues), isTrue);
    });

    test('can-solo sports only: Meetups shows, Games hides', () {
      final m = MySports.fromIds(catalogue, const ['gym']);
      expect(m.showsGames, isFalse);
      expect(m.showsMeetups, isTrue);
    });

    test('both kinds: both show', () {
      final m = MySports.fromIds(catalogue, const ['cr', 'gym']);
      expect(m.showsGames, isTrue);
      expect(m.showsMeetups, isTrue);
    });
  });

  group('scope', () {
    final m = MySports.fromIds(catalogue, const ['fb', 'gym']);

    test('Games are the challenge sports, Meetups the can-solo ones', () {
      expect(m.scope(catalogue, SportSection.games, _id), [football]);
      expect(m.scope(catalogue, SportSection.meetups, _id), [gym]);
    });

    test('Venues are any of the viewer\'s sports', () {
      expect(m.scope(catalogue, SportSection.venues, _id), [football, gym]);
    });

    test('Browse all shows the rest of the catalogue', () {
      expect(
        m.scope(catalogue, SportSection.games, _id, browseAll: true),
        catalogue,
      );
      expect(m.hasMore(catalogue, SportSection.games, _id), isTrue);
    });

    test('nothing in the catalogue is the viewer\'s: the whole catalogue', () {
      final onlyGym = MySports.fromIds(catalogue, const ['gym']);
      final challenge = <Sport>[cricket, football, padel];
      expect(onlyGym.scope(challenge, SportSection.games, _id), challenge);
    });

    test('no other sports: no Browse all entry', () {
      final all = MySports.fromIds(catalogue, const ['fb', 'cr', 'pd', 'gym']);
      expect(all.hasMore(catalogue, SportSection.venues, _id), isFalse);
    });
  });

  test('mySportsNowProvider is unscoped until the sports resolve', () async {
    final c = ProviderContainer(
      overrides: [
        mySportsProvider.overrideWith(
          (ref) async => MySports.fromIds(catalogue, const ['gym']),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(mySportsNowProvider, (_, __) {});
    expect(sub.read().isScoped, isFalse);
    await c.read(mySportsProvider.future);
    expect(c.read(mySportsNowProvider).showsGames, isFalse);
  });
}
