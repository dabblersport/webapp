// CEO 2026-11-19: Home's games in the DabblerUpcomingReminder stack; one time
// line plus at most one short label; running first; sport emoji in the ring.

import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_display.dart'
    show homeSportEmoji;
import 'package:dabbler/features/home/presentation/widgets/home_upcoming.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart';
import 'package:dabbler/features/ongoing/data/ongoing_repository.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
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
  String? liveSport,
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
        homeEventSportProvider.overrideWith((ref, id) async => liveSport),
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
    final block = find.byType(DabblerUpcomingReminder);
    List<DabblerUpcomingItem> items(WidgetTester t) =>
        t.widget<DabblerUpcomingReminder>(block).items;
    String time(DateTime a, DateTime b, {bool h24 = false}) =>
        l.hc_time_range(ocClk(lang, a, h24: h24), ocClk(lang, b, h24: h24));
    final running = DateTime(2026, 11, 18, 20, 40);

    group('Home games stack ($lang)', () {
      testWidgets('uses the reminder with no title', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang);
        expect(block, findsOneWidget);
        expect(t.widget<DabblerUpcomingReminder>(block).title, '');
        expect(find.text(l.home_upcoming_title), findsNothing);
      });

      testWidgets('before the start: countdown ring, time only', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang);
        final u = items(t).single;
        expect(u.ringBig, '25');
        expect(u.ringSmall, l.home_upcoming_min);
        expect(u.detail, time(ocStart, ocEnd));
      });

      testWidgets('24-hour when the MediaQuery flag is set', (t) async {
        await _pump(t, rows: [ocRow()], locale: lang, h24: true);
        expect(items(t).single.detail, time(ocStart, ocEnd, h24: true));
      });

      testWidgets('check-in open: Check in, tap opens the sheet', (t) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'open')],
          locale: lang,
        );
        expect(
          items(t).single.detail,
          '${time(ocStart, ocEnd)} · ${l.g04_cta}',
        );
        items(t).single.onTap!();
        await t.pumpAndSettle();
        expect(find.text(l.g04_confirm_title), findsOneWidget);
        expect(find.text('route:sports:e1'), findsNothing);
      });

      testWidgets('organiser: no Check in, tap opens the event', (t) async {
        await _pump(
          t,
          rows: [ocRow(organiser: true, checkIn: 'open')],
          locale: lang,
        );
        expect(items(t).single.detail, time(ocStart, ocEnd));
        items(t).single.onTap!();
        await t.pumpAndSettle();
        expect(find.text('route:sports:e1'), findsOneWidget);
      });

      testWidgets('checked in: Checked in', (t) async {
        await _pump(
          t,
          rows: [ocRow(checkIn: 'checked_in')],
          locale: lang,
        );
        expect(items(t).single.detail, endsWith(l.hc_checked_in));
      });

      testWidgets('running: Live and the sport emoji', (t) async {
        await _pump(
          t,
          games: [_game('e1', 'Padel Night', ocStart)],
          rows: [ocRow()],
          locale: lang,
          now: running,
        );
        final u = items(t).single;
        expect(u.ringBig, homeSportEmoji('Football'));
        expect(u.detail, '${time(ocStart, ocEnd)} · ${l.activity_pill_live}');
        expect(u.detail, isNot(contains(l.hc_under_way)));
      });

      testWidgets('started game not in the games list: sport from the game', (
        t,
      ) async {
        await _pump(
          t,
          rows: [
            ocRow(state: 'started', startedAt: DateTime(2026, 11, 18, 20, 32)),
          ],
          locale: lang,
          now: running,
          liveSport: 'Padel',
        );
        expect(items(t).single.ringBig, homeSportEmoji('Padel'));
      });

      testWidgets('scheduled time ended: Ended, no long text', (t) async {
        await _pump(
          t,
          rows: [ocRow()],
          locale: lang,
          now: DateTime(2026, 11, 18, 21, 40),
        );
        final u = items(t).single;
        expect(u.detail, endsWith(l.oc_ended));
        expect(u.detail, isNot(contains(l.lc_time_ended)));
      });

      testWidgets('ended or cancelled: the item leaves', (t) async {
        await _pump(
          t,
          rows: [
            ocRow(id: 'a', cancelled: true),
            ocRow(id: 'b', state: 'confirmed'),
          ],
          locale: lang,
        );
        expect(block, findsNothing);
      });

      testWidgets('running plus upcoming: running first', (t) async {
        await _pump(
          t,
          games: [_game('g2', 'Tomorrow Game', DateTime(2026, 11, 19, 19))],
          rows: [ocRow()],
          locale: lang,
          now: running,
        );
        expect(items(t).map((u) => u.title).last, 'Tomorrow Game');
        expect(items(t), hasLength(2));
      });
    });
  }
}
