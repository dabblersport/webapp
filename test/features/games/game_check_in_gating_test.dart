// KAN-998: the game detail draws the check-in row only for a roster player
// who is not the host.

import 'package:dabbler/features/attendance/presentation/check_in_entry.dart';
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
  WidgetTester t, {
  bool host = false,
  bool onRoster = false,
  bool waitlisted = false,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        noCheckInOverride,
        gameViewControllerProvider.overrideWith(
          (ref, id) => _FakeGameController(
            GameViewState(game: _game(), roster: _roster),
            host,
            onRoster,
            waitlisted,
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: const GameDetailScreen(gameId: 'g1'),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initHomeTestSupabase);

  testWidgets('a roster player sees the row', (t) async {
    await _pump(t, onRoster: true);
    expect(find.byType(CheckInEntry), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the host does not', (t) async {
    await _pump(t, host: true, onRoster: true);
    expect(find.byType(CheckInEntry), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a waitlisted user does not', (t) async {
    await _pump(t, waitlisted: true);
    expect(find.byType(CheckInEntry), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
