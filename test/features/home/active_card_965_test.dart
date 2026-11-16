// KAN-965: every Active card variant against ActivityCard.dc.html and the
// Home Feed ACT_TONE / ACT_LOOK / ACT_ACTION / ACT_FAMILY_ICON tables, in EN
// and AR: the tone, the 120 mark, the kicker (glyph or live dot), the action,
// the date tile month, the time rule and the player ring.
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'active_957_support.dart';
import 'active_fixtures.dart';
import 'home_test_harness.dart';

DateTime _ago(Duration d) => activeNow.subtract(d);

/// One variant: the row, its card key and the design's values.
typedef _Variant = ({
  String name,
  ActiveItem row,
  String id,
  DabblerToneColor tone,
  String mark,
  String? family,
  String Function(AppLocalizations) kicker,
  String Function(AppLocalizations) action,
});

final List<_Variant> _variants = <_Variant>[
  (
    name: 'player',
    row: activePlayer(at: activeNow),
    id: 'player_joined:u1',
    tone: DabblerActivityTones.social,
    mark: 'profile-add',
    family: 'profile-add',
    kicker: (l) => l.act_kicker_player_joined,
    action: (l) => l.act_cta_follow,
  ),
  (
    name: 'venue',
    row: activeVenue(at: activeNow, spaces: 4),
    id: 'venue_added:v1',
    tone: DabblerActivityTones.bright,
    mark: 'building-4',
    family: 'building-4',
    kicker: (l) => l.act_kicker_venue_added,
    action: (l) => l.act_cta_view_venue,
  ),
  (
    name: 'upcoming game',
    row: activeGame(at: activeNow, count: 6, capacity: 14),
    id: 'game_created:g1',
    tone: DabblerActivityTones.main,
    mark: 'calendar-add',
    family: 'game',
    kicker: (l) => l.act_kicker_game_created,
    action: (l) => l.act_cta_join_game,
  ),
  (
    name: 'live game',
    row: activeGame(
      type: 'game_started',
      at: activeNow,
      startAt: _ago(const Duration(hours: 1)),
      endAt: activeNow.add(const Duration(hours: 1)),
      live: true,
      count: 4,
      capacity: 4,
    ),
    id: 'game_started:g1',
    tone: DabblerActivityTones.sport,
    mark: 'flash',
    family: null,
    kicker: (l) => l.act_kicker_live,
    action: (l) => l.act_cta_join_in,
  ),
  (
    name: 'finished game',
    row: activeGame(
      type: 'game_ended',
      at: activeNow,
      startAt: _ago(const Duration(hours: 3)),
      endAt: _ago(const Duration(hours: 1)),
      count: 10,
    ),
    id: 'game_ended:g1',
    tone: DabblerActivityTones.ended,
    mark: 'cup',
    family: 'game',
    kicker: (l) => l.act_kicker_game_ended,
    action: (l) => l.act_cta_see_results,
  ),
  (
    name: 'upcoming meetup',
    row: activeGame(
      kind: 'meetup',
      type: 'meetup_created',
      at: activeNow,
      count: 5,
    ),
    id: 'meetup_created:g1',
    tone: DabblerActivityTones.active,
    mark: 'people',
    family: 'people',
    kicker: (l) => l.act_kicker_meetup_created,
    action: (l) => l.act_cta_join_meetup,
  ),
  (
    name: 'live meetup',
    row: activeGame(
      kind: 'meetup',
      type: 'meetup_started',
      at: activeNow,
      startAt: _ago(const Duration(minutes: 30)),
      endAt: activeNow.add(const Duration(hours: 1)),
      live: true,
      count: 9,
    ),
    id: 'meetup_started:g1',
    tone: DabblerActivityTones.sport,
    mark: 'flash',
    family: null,
    kicker: (l) => l.act_kicker_live,
    action: (l) => l.act_cta_join_in,
  ),
  (
    name: 'finished meetup',
    row: activeGame(
      kind: 'meetup',
      type: 'meetup_completed',
      at: activeNow,
      startAt: _ago(const Duration(hours: 4)),
      endAt: _ago(const Duration(hours: 2)),
      count: 14,
    ),
    id: 'meetup_completed:g1',
    tone: DabblerActivityTones.accent,
    mark: 'medal-star',
    family: 'people',
    kicker: (l) => l.act_kicker_meetup_completed,
    action: (l) => l.act_cta_see_recap,
  ),
];

Finder _card(String id) => find.byKey(ValueKey<String>(id));

Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  test('the time rule: minutes under an hour, then the clock', () async {
    await initializeDateFormatting();
    String n(String s) =>
        DabblerType.toWesternDigits(s).replaceAll('\u202f', ' ');
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    final at = DateTime(2026, 11, 16, 8, 30);
    expect(
      ActiveEventCard.timeLabel(en, at, at.add(const Duration(minutes: 3))),
      '3 min ago',
    );
    expect(
      ActiveEventCard.timeLabel(ar, at, at.add(const Duration(minutes: 3))),
      'قبل 3 د',
    );
    expect(
      n(ActiveEventCard.timeLabel(en, at, at.add(const Duration(minutes: 71)))),
      '8:30 AM',
    );
    expect(
      n(ActiveEventCard.timeLabel(ar, at, at.add(const Duration(hours: 5)))),
      '8:30 ص',
    );
    expect(ActiveEventCard.monthLabel(DateTime(2026, 10, 21)), 'OCT');
  });

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    for (final v in _variants) {
      testWidgets('${v.name}: tone, mark, kicker, action — $dir', (
        tester,
      ) async {
        final l = await openActiveTab(
          tester,
          locale: locale,
          state: ActiveFeedData(events: <ActiveItem>[v.row], hasMore: false),
        );
        final card = tester.widget<DabblerActivityCard>(
          _in(v.id, find.byType(DabblerActivityCard)),
        );
        expect(card.tone, v.tone);
        expect(card.mark, v.mark);
        final kicker = tester.widget<DabblerActivityKicker>(
          _in(v.id, find.byType(DabblerActivityKicker)),
        );
        expect(kicker.label, v.kicker(l));
        expect(kicker.live, v.family == null);
        expect(kicker.ink, v.tone.ink);
        if (v.family != null) expect(kicker.icon, v.family);
        expect(
          _in(v.id, find.byKey(const ValueKey<String>('activity-live-dot'))),
          v.family == null ? findsOneWidget : findsNothing,
        );
        final action = tester.widget<DabblerActivityAction>(
          _in(v.id, find.byType(DabblerActivityAction)),
        );
        expect(action.label, v.action(l));
        expect(action.ink, v.tone.ink);
        // The card is the design's exact ground, mark and inks.
        final mark = tester.widget<DabblerIcon>(
          _in(v.id, find.byKey(const ValueKey<String>('activity-card-mark'))),
        );
        expect(mark.size, 120);
        expect(mark.color, v.tone.ink.withValues(alpha: 0.14));
        final ground = tester.widget<ColoredBox>(
          find
              .descendant(
                of: _in(v.id, find.byType(DabblerActivityCard)),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(ground.color, v.tone.surface);
        final row = v.row;
        if (row.isEvent && row.startAt != null) {
          final tile = tester.widget<DabblerActivityDateTile>(
            _in(v.id, find.byType(DabblerActivityDateTile)),
          );
          expect(tile.month, ActiveEventCard.monthLabel(row.startAt!));
          expect(tile.ink, v.tone.ink);
          expect(
            tester.getSize(_in(v.id, find.byType(DabblerActivityDateTile))),
            const Size(56, 62),
          );
        }
        if (row.entityKind == 'profile') {
          final avatar = tester.widget<DabblerAvatar>(
            _in(v.id, find.byType(DabblerAvatar)),
          );
          expect(avatar.size, DabblerAvatarSize.lg);
          expect(avatar.ringWidth, 3);
        }
        expect(tester.takeException(), isNull);
      }, variant: desktopOnly);
    }
  }
}
