// KAN-969: player of the week shows MVP votes, player of the month Wins,
// in place of Hosted; other stats are kept.

import 'package:dabbler/features/home/presentation/widgets/active_card_honours.dart';
import 'package:dabbler/features/home/presentation/widgets/active_card_look.dart';
import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_fixtures.dart';

const List<ActiveStat> _all = <ActiveStat>[
  (key: 'games', value: 6),
  (key: 'rating', value: 4.9),
  (key: 'hosted', value: 2),
  (key: 'mvp_votes', value: 3),
  (key: 'wins', value: 4),
];

ActiveItem _award({bool month = false}) {
  final a = activeAward(month: month);
  return ActiveItem(
    eventType: a.eventType,
    eventAt: a.eventAt,
    entityKind: a.entityKind,
    entityId: a.entityId,
    stats: _all,
  );
}

List<String> _keys(ActiveItem e, ActiveLook look) => [
  for (final s in ActiveHonours.statsFor(e, look)) s.key,
];

void main() {
  test('week: games, rating, MVP votes', () {
    expect(_keys(_award(), ActiveLook.playerWeek), [
      'games',
      'rating',
      'mvp_votes',
    ]);
  });

  test('month: games, rating, wins', () {
    expect(_keys(_award(month: true), ActiveLook.playerMonth), [
      'games',
      'rating',
      'wins',
    ]);
  });

  test('other cards drop the award-only keys', () {
    expect(_keys(_award(), ActiveLook.venueWeek), [
      'games',
      'rating',
      'hosted',
    ]);
  });

  for (final code in ['en', 'ar']) {
    test('labels $code', () {
      final l = lookupAppLocalizations(Locale(code));
      expect(
        ActiveHonours.statLabel(l, 'mvp_votes'),
        l.act_stat_label_mvp_votes,
      );
      expect(ActiveHonours.statLabel(l, 'wins'), l.act_stat_label_wins);
      expect(l.act_stat_label_mvp_votes, isNot('mvp_votes'));
      expect(l.act_stat_label_wins, isNot('wins'));
    });
  }
}
