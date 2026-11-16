// KAN-964: the Active card's stat block and the venue's space count, from
// active_stream's participant_count, capacity and space_count (08bfa568).
// EN and AR, with the plural forms.
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart';
import 'active_fixtures.dart';
import 'home_test_harness.dart';

Finder _card(String id) => find.byKey(ValueKey<String>(id));

Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

Finder _stat(String id) =>
    _in(id, find.byKey(const ValueKey<String>('active-card-stat')));

Finder _bar(String id) =>
    _in(id, find.byKey(const ValueKey<String>('active-card-bar')));

String _w(String s) => DabblerType.toWesternDigits(s);

String _statText(WidgetTester tester, String id) => tester
    .widget<DabblerText>(
      find.descendant(of: _stat(id), matching: find.byType(DabblerText)),
    )
    .data!;

String _statIcon(WidgetTester tester, String id) => tester
    .widget<DabblerIcon>(
      find.descendant(of: _stat(id), matching: find.byType(DabblerIcon)),
    )
    .name;

DateTime _ago(Duration d) => activeNow.subtract(d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  test('active_stream counts parse, and null stays null', () {
    final row = activeGame(count: 6, capacity: 14).toRow();
    expect(row['participant_count'], 6);
    expect(row['capacity'], 14);
    final back = ActiveItem.fromRow(<String, dynamic>{
      ...row,
      'participant_count': 6.0,
      'capacity': null,
      'space_count': 4,
    })!;
    expect(back.participantCount, 6);
    expect(back.capacity, isNull);
    expect(back.spaceCount, 4);
    final bare = ActiveItem.fromRow(<String, dynamic>{
      ...row,
      'participant_count': null,
    })!;
    expect(bare.participantCount, isNull);
  });

  test('Arabic counts take their plural forms', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.act_stat_spots_left(1), isNot(ar.act_stat_spots_left(8)));
    expect(ar.act_stat_spots_left(2), isNot(ar.act_stat_spots_left(8)));
    expect(ar.act_stat_spots_left(8), isNot(ar.act_stat_spots_left(11)));
    expect(ar.act_venue_spaces(4), contains('ملاعب'));
    expect(ar.act_venue_spaces(12), contains('ملعبًا'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.act_stat_spots_left(1), '1 spot left');
    expect(en.act_venue_spaces(1), '1 court');
    expect(en.act_venue_spaces(4), '4 courts');
  });

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('upcoming game: players of capacity, spots left, bar — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(id: 'a', at: activeNow, count: 6, capacity: 14),
            activeGame(
              id: 'b',
              at: _ago(const Duration(minutes: 5)),
              count: 14,
              capacity: 14,
            ),
          ],
          hasMore: false,
        ),
      );
      const a = 'game_created:a';
      expect(
        _statText(tester, a),
        _w('${l.act_stat_players_of(6, 14)} · ${l.act_stat_spots_left(8)}'),
      );
      expect(_statIcon(tester, a), 'people');
      final bar = tester.widget<DabblerProgressBar>(_bar(a));
      expect(bar.value, closeTo(6 / 14, 1e-9));
      expect(bar.tone, DabblerProgressBarTone.brand);

      const b = 'game_created:b';
      expect(
        _statText(tester, b),
        _w('${l.act_stat_players_of(14, 14)} · ${l.act_stat_full}'),
      );
      expect(tester.widget<DabblerProgressBar>(_bar(b)).value, 1);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('live game bar; open capacity is the count only — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(
              id: 'live',
              type: 'game_started',
              at: activeNow,
              startAt: _ago(const Duration(hours: 1)),
              endAt: activeNow.add(const Duration(hours: 1)),
              live: true,
              count: 3,
              capacity: 4,
            ),
            activeGame(
              id: 'open',
              at: _ago(const Duration(minutes: 5)),
              count: 6,
            ),
          ],
          hasMore: false,
        ),
      );
      expect(
        tester.widget<DabblerProgressBar>(_bar('game_started:live')).tone,
        DabblerProgressBarTone.success,
      );
      expect(
        _statText(tester, 'game_started:live'),
        _w('${l.act_stat_players_of(3, 4)} · ${l.act_stat_spots_left(1)}'),
      );
      expect(_statText(tester, 'game_created:open'), _w(l.act_stat_players(6)));
      expect(_bar('game_created:open'), findsNothing);
    }, variant: desktopOnly);

    testWidgets('finished game played, meetups going and went — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(
              id: 'done',
              type: 'game_ended',
              at: activeNow,
              startAt: _ago(const Duration(hours: 3)),
              endAt: _ago(const Duration(hours: 1)),
              count: 10,
              capacity: 10,
            ),
            activeGame(
              id: 'm1',
              kind: 'meetup',
              type: 'meetup_created',
              at: _ago(const Duration(minutes: 5)),
              count: 9,
              capacity: 20,
            ),
            activeGame(
              id: 'm2',
              kind: 'meetup',
              type: 'meetup_completed',
              at: _ago(const Duration(minutes: 10)),
              startAt: _ago(const Duration(hours: 4)),
              endAt: _ago(const Duration(hours: 2)),
              count: 14,
            ),
          ],
          hasMore: false,
        ),
      );
      expect(_statText(tester, 'game_ended:done'), _w(l.act_stat_played(10)));
      expect(_statIcon(tester, 'game_ended:done'), 'tick-circle');
      expect(_bar('game_ended:done'), findsNothing);

      await tester.ensureVisible(_card('meetup_created:m1'));
      await tester.pump();
      expect(_statText(tester, 'meetup_created:m1'), _w(l.act_stat_going(9)));
      expect(_bar('meetup_created:m1'), findsNothing);

      await tester.ensureVisible(_card('meetup_completed:m2'));
      await tester.pump();
      expect(_statText(tester, 'meetup_completed:m2'), _w(l.act_stat_went(14)));
      expect(_statIcon(tester, 'meetup_completed:m2'), 'tick-circle');
    }, variant: desktopOnly);

    testWidgets('null counts hide; a venue lists its courts — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(id: 'n', at: activeNow, capacity: 14),
            activeVenue(
              id: 'v1',
              at: _ago(const Duration(minutes: 5)),
              spaces: 4,
            ),
            activeVenue(id: 'v2', at: _ago(const Duration(minutes: 10))),
          ],
          hasMore: false,
        ),
      );
      expect(_stat('game_created:n'), findsNothing);
      expect(_bar('game_created:n'), findsNothing);
      expect(
        _in(
          'venue_added:v1',
          find.text(
            _w('Jumeirah Lake Towers · ${l.act_venue_spaces(4)} · Dubai'),
          ),
        ),
        findsOneWidget,
      );
      expect(_stat('venue_added:v1'), findsNothing);
      await tester.ensureVisible(_card('venue_added:v2'));
      await tester.pump();
      expect(
        _in('venue_added:v2', find.text('Jumeirah Lake Towers · Dubai')),
        findsOneWidget,
      );
    }, variant: desktopOnly);
  }
}
