import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'profile_render_support.dart';

const GameCounts _zeros = GameCounts(played: 0, organised: 0, upcoming: 0);
const GameCounts _some = GameCounts(played: 3, organised: 1, upcoming: 2);

Future<void> _pump(WidgetTester tester, Widget child) => pumpProfileScreen(
  tester,
  Scaffold(body: SingleChildScrollView(child: child)),
  const Locale('en'),
);

OwnProfileStats _stats(
  AsyncValue<GameCounts>? counts, {
  VoidCallback? onRetry,
}) => OwnProfileStats(
  posts: 7,
  sportsCount: 2,
  gamesPlayed: ownProfileCountsData(counts)?.played,
  organised: ownProfileCountsData(counts)?.organised,
  upcoming: ownProfileCountsData(counts)?.upcoming,
  countsFailed: ownProfileCountsFailed(counts),
  onRetryCounts: onRetry,
  newContributor: ownProfileIsNewContributor(counts),
);

void main() {
  setUpAll(loadProfileFonts);
  final AsyncValue<GameCounts> failed = AsyncError<GameCounts>(
    Exception('boom'),
    StackTrace.empty,
  );

  testWidgets('SourceFailed renders a retry state, not zero, and retry fires', (
    tester,
  ) async {
    int retries = 0;
    expect(ownProfileIsNewContributor(failed), isFalse);
    await _pump(tester, _stats(failed, onRetry: () => retries++));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('SourceGap omits the count tiles (no 0, no placeholder)', (
    tester,
  ) async {
    await _pump(tester, const OwnProfileStats(posts: 7, sportsCount: 2));
    expect(find.text('Organised'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('SourceData with real zeros renders newContributor', (
    tester,
  ) async {
    const AsyncValue<GameCounts> data = AsyncData<GameCounts>(_zeros);
    expect(ownProfileIsNewContributor(data), isTrue);
    await _pump(tester, _stats(data));
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('SourceData with non-zero does not render newContributor', (
    tester,
  ) async {
    const AsyncValue<GameCounts> data = AsyncData<GameCounts>(_some);
    expect(ownProfileIsNewContributor(data), isFalse);
    await _pump(tester, _stats(data));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  test('loading is neither failed nor newContributor', () {
    const AsyncValue<GameCounts> loading = AsyncLoading<GameCounts>();
    expect(ownProfileCountsFailed(loading), isFalse);
    expect(ownProfileIsNewContributor(loading), isFalse);
    expect(ownProfileIsNewContributor(null), isFalse);
  });
}
