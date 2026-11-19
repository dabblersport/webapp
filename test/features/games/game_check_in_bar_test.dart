// The game detail's bottom bar follows the player's check-in (EN and AR):
// before the window "Leave game"; open: "Check in" with leave as a text
// action; checked in or closed: no leave. The host's bar is unchanged.

import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../attendance/attendance_fakes.dart';
import '../home/home_test_harness.dart';

class _FakeGameController extends StateNotifier<GameViewState>
    implements GameViewController {
  _FakeGameController(super.state, this.host, this.onRoster, this.waitlisted);
  final bool host;
  final bool onRoster;
  final bool waitlisted;

  @override
  String? get currentUserId => 'me';
  @override
  bool get isHost => host;
  @override
  bool get isOnRoster => onRoster;
  @override
  bool get isOnWaitlist => waitlisted;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> resync() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GameView _game() {
  final start = DateTime.now().add(const Duration(days: 1));
  return GameView(
    id: 'g1',
    title: 'Tuesday 5-a-side',
    gameType: 'casual',
    startAt: start,
    endAt: start.add(const Duration(minutes: 90)),
    capacity: 10,
    benchSlots: 2,
    totalSlots: 12,
    rosterCount: 2,
    listingVisibility: 'public',
    joinPolicy: 'open',
    allowSpectators: true,
    allowsWaitlist: true,
    isCancelled: false,
    joiningRule: 'free',
    costCover: 'free',
    sportKey: 'football',
    sportNameEn: 'Football',
    creatorProfileId: 'p1',
    creatorDisplayName: 'Ahmed Farouk',
    venueName: 'Elite Football Arena',
  );
}

const List<GameRosterEntry> _roster = [
  GameRosterEntry(
    profileId: 'p1',
    userId: 'u1',
    role: 'host',
    displayName: 'Ahmed',
  ),
  GameRosterEntry(
    profileId: 'p3',
    userId: 'me',
    role: 'player',
    displayName: 'Aisha',
  ),
];

Future<void> _pump(
  WidgetTester t,
  Locale locale,
  CheckInPhase phase, {
  bool host = false,
  DateTime? checkedInAt,
}) async {
  // Wide: the test font draws every glyph a full em, so a bar label that
  // fits a phone in the real face overflows one here.
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        checkInPhaseOverride(phase, checkedInAt: checkedInAt),
        gameViewControllerProvider.overrideWith(
          (ref, id) => _FakeGameController(
            GameViewState(game: _game(), roster: _roster),
            host,
            true,
            false,
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        routes: {'/': (_) => const GameDetailScreen(gameId: 'g1')},
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder _inBar(Finder f) =>
    find.descendant(of: find.byType(DabblerActionBar), matching: f);

void main() {
  setUpAll(initHomeTestSupabase);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;

    testWidgets('[$tag] before the window: Leave game, as today', (t) async {
      await _pump(t, locale, CheckInPhase.beforeWindow);
      expect(_inBar(find.text(l.game_leave)), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      await t.tap(_inBar(find.text(l.game_leave)));
      await t.pumpAndSettle();
      expect(find.text(l.game_leave_title), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] not eligible: Leave game, as today', (t) async {
      await _pump(t, locale, CheckInPhase.notEligible);
      expect(_inBar(find.text(l.game_leave)), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] open: Check in, leave as a text action', (t) async {
      await _pump(t, locale, CheckInPhase.open);
      final cta = find.byKey(const ValueKey('check-in-cta'));
      expect(cta, findsOneWidget);
      expect(
        find.descendant(of: cta, matching: find.text(l.g04_cta)),
        findsOneWidget,
      );
      final leave = find.byKey(const ValueKey('check-in-leave'));
      expect(
        find.descendant(of: leave, matching: find.text(l.game_leave)),
        findsOneWidget,
      );
      await t.tap(leave);
      await t.pumpAndSettle();
      expect(find.text(l.game_leave_title), findsOneWidget);
      expect(find.text(l.game_leave_body), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] submitting: the check-in button is busy', (t) async {
      await _pump(t, locale, CheckInPhase.submitting);
      expect(find.byKey(const ValueKey('check-in-cta')), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-leave')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] checked in: informational, no leave', (t) async {
      await _pump(
        t,
        locale,
        CheckInPhase.checkedIn,
        checkedInAt: DateTime(2026, 11, 19, 18, 5),
      );
      expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      expect(find.byKey(const ValueKey('check-in-leave')), findsNothing);
      expect(_inBar(find.text(l.game_leave)), findsNothing);
      expect(
        _inBar(find.textContaining(l.g04_checked_in_at('').trim())),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    for (final phase in const [CheckInPhase.closed, CheckInPhase.cancelled]) {
      testWidgets('[$tag] ${phase.name}: no check-in, no leave', (t) async {
        await _pump(t, locale, phase);
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
        expect(_inBar(find.text(l.game_leave)), findsNothing);
        expect(
          _inBar(
            find.text(
              phase == CheckInPhase.closed ? l.g04_closed : l.g04_cancelled,
            ),
          ),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('[$tag] the host: Edit game, unchanged', (t) async {
      await _pump(t, locale, CheckInPhase.open, host: true);
      expect(_inBar(find.text(l.game_edit)), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  }
}
