// CEO 2026-11-19: one Home card per game in the Upcoming design; the same
// card carries the KAN-1008 running states; running first; no section title.

import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/home_game_card.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_display.dart'
    show homeSportEmoji;
import 'package:dabbler/features/home/presentation/widgets/home_upcoming.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart';
import 'package:dabbler/features/ongoing/data/ongoing_repository.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../attendance/attendance_fakes.dart';
import 'package:go_router/go_router.dart';

import '../ongoing/ongoing_fakes.dart';

Game _game(String id, String title, DateTime at, {String venue = 'Arena'}) {
  String two(int v) => v.toString().padLeft(2, '0');
  return Game(
    id: id,
    title: title,
    description: '',
    sport: 'Football',
    venueName: venue,
    scheduledDate: DateTime(at.year, at.month, at.day),
    startTime: '${two(at.hour)}:${two(at.minute)}',
    endTime: '23:59',
    minPlayers: 2,
    maxPlayers: 10,
    currentPlayers: 4,
    organizerId: 'o',
    skillLevel: 'mixed',
    pricePerPlayer: 0,
    status: GameStatus.upcoming,
    isPublic: true,
    allowsWaitlist: false,
    checkInEnabled: false,
    createdAt: at,
    updatedAt: at,
  );
}

Future<void> _pump(
  WidgetTester t, {
  List<Map<String, dynamic>> rows = const [],
  List<Game> games = const [],
  String locale = 'en',
  DateTime? now,
  bool h24 = false,
}) async {
  final clock = now ?? ocClock;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: HomeUpcoming())),
      ),
      for (final p in ['/sports/games/:id', '/meetups/:id', '/check-in/:id'])
        GoRoute(
          path: p,
          builder: (_, s) => Scaffold(
            body: Text('route:${p.split('/')[1]}:${s.pathParameters['id']}'),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ongoingRepositoryProvider.overrideWithValue(OcRepo(rows)),
        lifecycleClockProvider.overrideWithValue(() => clock),
        homeNowProvider.overrideWithValue(() => clock),
        ongoingNoticeSignalProvider.overrideWith((ref) => null),
        userUpcomingGamesProvider.overrideWith((ref) async => games),
        noCheckInOverride,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: h24),
          child: child!,
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l = lookupAppLocalizations(Locale(lang));
    final cards = find.byType(HomeGameCard);

    group('HomeGameCard ($lang)', () {
      testWidgets('before the start: countdown ring, no Check in', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang);
        expect(cards, findsOneWidget);
        expect(ocKey('home-game-countdown'), findsOneWidget);
        expect(ocKey('home-game-running'), findsNothing);
        expect(find.text('25'), findsOneWidget);
        expect(find.text(l.home_upcoming_min), findsOneWidget);
        expect(ocKey('home-game-check-in'), findsNothing);
      });

      testWidgets('check-in open: Check in opens the confirm sheet in place', (
        t,
      ) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'open')],
          locale: lang,
        );
        expect(ocKey('home-game-check-in'), findsOneWidget);
        expect(find.text(l.g04_cta), findsOneWidget);
        await t.tap(ocKey('home-game-check-in'));
        await t.pumpAndSettle();
        expect(find.text(l.g04_confirm_title), findsOneWidget);
        expect(find.text('route:check-in:e1'), findsNothing);
      });

      testWidgets('the organiser sees no Check in', (t) async {
        await _pump(
          t,
          rows: [ocRow(organiser: true, checkIn: 'open')],
          locale: lang,
        );
        expect(cards, findsOneWidget);
        expect(ocKey('home-game-check-in'), findsNothing);
      });

      Text statusText(WidgetTester t) => t.widget<Text>(
        find.descendant(
          of: ocKey('home-game-check-in-status'),
          matching: find.byType(Text),
        ),
      );

      testWidgets('checked in: Checked in label, no button', (t) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'checked_in')],
          locale: lang,
        );
        expect(statusText(t).data, l.hc_checked_in);
        expect(ocKey('home-game-check-in'), findsNothing);
      });

      testWidgets('check-in open: Check in available label', (t) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'open')],
          locale: lang,
        );
        expect(statusText(t).data, l.hc_check_in_available);
        expect(ocKey('home-game-check-in'), findsOneWidget);
      });

      testWidgets('check-in closed: Check in closed label', (t) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'closed')],
          locale: lang,
          now: DateTime(2026, 11, 18, 21),
        );
        expect(statusText(t).data, l.hc_check_in_closed);
        expect(ocKey('home-game-check-in'), findsNothing);
      });

      testWidgets('before the window or organiser: no check-in label', (
        t,
      ) async {
        await _pump(
          t,
          rows: [
            ocRow(id: 'a'),
            ocRow(id: 'b', organiser: true, checkIn: 'open'),
          ],
          locale: lang,
        );
        expect(cards, findsNWidgets(2));
        expect(ocKey('home-game-check-in-status'), findsNothing);
      });

      testWidgets('time on one line: start until end', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang);
        final want = l.hc_time_range(ocClk(lang, ocStart), ocClk(lang, ocEnd));
        expect(ocHas(want), findsOneWidget);
        final line = t.widget<Text>(ocHas(want));
        expect(line.maxLines, 1);
      });

      testWidgets('24-hour when the MediaQuery flag is set', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang, h24: true);
        final want = l.hc_time_range(
          ocClk(lang, ocStart, h24: true),
          ocClk(lang, ocEnd, h24: true),
        );
        expect(ocHas(want), findsOneWidget);
        expect(ocHas('20:30'), findsOneWidget);
      });

      testWidgets('running: the sport emoji in the ring', (t) async {
        await _pump(
          t,
          games: [_game('e1', 'Padel Night', ocStart)],
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 20, 40),
        );
        expect(
          find.descendant(
            of: ocKey('home-game-running'),
            matching: ocKey('home-game-sport'),
          ),
          findsOneWidget,
        );
        expect(find.text(homeSportEmoji('Football')), findsOneWidget);
      });

      testWidgets('running, no sport known: the play icon', (t) async {
        await _pump(
          t,
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 20, 40),
        );
        expect(ocKey('home-game-sport'), findsNothing);
      });

      testWidgets('scheduled time running: running indicator, until', (
        t,
      ) async {
        await _pump(
          t,
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 20, 40),
        );
        expect(ocKey('home-game-running'), findsOneWidget);
        expect(ocKey('home-game-countdown'), findsNothing);
        expect(ocHas(l.hc_under_way), findsOneWidget);
        // The end time appears once: on the time line, not the status.
        expect(ocHas(ocClk(lang, ocEnd)), findsOneWidget);
      });

      testWidgets('started by the organiser: Started <time>', (t) async {
        final at = DateTime(2026, 11, 18, 20, 32);
        await _pump(
          t,
          rows: [ocRow(state: 'started', startedAt: at)],
          locale: lang,
          now: DateTime(2026, 11, 18, 20, 40),
        );
        expect(ocKey('home-game-running'), findsOneWidget);
        expect(ocHas(l.lc_started_at(ocClk(lang, at))), findsOneWidget);
      });

      testWidgets('changed: old → new', (t) async {
        await _pump(
          t,
          rows: [ocRow(previousStart: DateTime(2026, 11, 18, 20))],
          locale: lang,
        );
        expect(ocKey('home-game-changed'), findsOneWidget);
        expect(ocHas(ocClk(lang, DateTime(2026, 11, 18, 20))), findsOneWidget);
      });

      testWidgets('scheduled time ended', (t) async {
        await _pump(
          t,
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 21, 40),
        );
        expect(ocHas(l.lc_time_ended), findsOneWidget);
      });

      testWidgets('ended or cancelled: the card leaves', (t) async {
        await _pump(
          t,
          rows: [
            ocRow(id: 'a', cancelled: true),
            ocRow(id: 'b', state: 'confirmed'),
          ],
          locale: lang,
        );
        expect(cards, findsNothing);
      });

      testWidgets('tap opens the event', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang);
        await t.tap(ocKey('home-game-e1'));
        await t.pumpAndSettle();
        expect(find.text('route:sports:e1'), findsOneWidget);
      });

      testWidgets('one game: one card, and no Upcoming title', (t) async {
        final start = DateTime(2026, 11, 19, 19, 30);
        await _pump(
          t,
          games: [_game('e1', 'Padel Night', start)],
          rows: [ocRow(start: start, end: start.add(const Duration(hours: 1)))],
          locale: lang,
        );
        expect(cards, findsOneWidget);
        expect(find.text(l.home_upcoming_title), findsNothing);
        expect(ocHas(l.home_upcoming_title_count(1)), findsNothing);
        expect(find.text(l.home_upcoming_hide), findsNothing);
      });

      testWidgets('running plus upcoming: two cards, running first', (t) async {
        await _pump(
          t,
          games: [_game('g2', 'Tomorrow Game', DateTime(2026, 11, 19, 19))],
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 20, 40),
        );
        expect(cards, findsNWidgets(2));
        final running = t.getTopLeft(ocKey('home-game-e1'));
        final upcoming = t.getTopLeft(ocKey('home-game-g2'));
        expect(running.dy, lessThan(upcoming.dy));
      });
    });
  }
}
