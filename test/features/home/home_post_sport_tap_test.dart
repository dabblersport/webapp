// KAN-622: the sport tag on a post row opens that sport's page. The flag-off,
// same-sport and unknown-sport cases leave the tag as a plain, untappable pill.
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/post_sport_tap.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

Post _post({String? sport = 'Football', String? sportId}) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: 'Padel tonight',
  sport: sport,
  sportId: sportId,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

Future<void> _pump(
  WidgetTester tester,
  Post post, {
  String? currentSportId,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Material(
          child: SingleChildScrollView(
            child: HomePostRow(post: post, currentSportId: currentSportId),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.sportOverview,
        name: RouteNames.sportOverview,
        builder: (_, state) =>
            Text('sport-page:${state.pathParameters['sportId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        myProfileIdProvider.overrideWith((ref) async => 'someone-else'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        builder: (context, child) => DabblerToastProvider(child: child!),
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

DabblerPostRow _row(WidgetTester tester) =>
    tester.widget<DabblerPostRow>(find.byType(DabblerPostRow));

void main() {
  group('sport tag on a post row (KAN-622)', () {
    testWidgets("tapping the tag opens the post's own sport page", (
      tester,
    ) async {
      await _pump(tester, _post(sportId: 'sport-from-post'));
      expect(_row(tester).onSportTap, isNotNull);
      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();
      expect(find.text('sport-page:sport-from-post'), findsOneWidget);
    });

    testWidgets('a post with only a sport name resolves the id from the '
        'existing mapping', (tester) async {
      await _pump(tester, _post());
      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();
      expect(
        find.text('sport-page:${SportIdMapping.getSportId('football')}'),
        findsOneWidget,
      );
    });

    testWidgets("the open sport page's own tag does nothing", (tester) async {
      await _pump(
        tester,
        _post(sportId: 'sport-from-post'),
        currentSportId: 'sport-from-post',
      );
      expect(_row(tester).onSportTap, isNull);
      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sport-page:'), findsNothing);
    });

    testWidgets("another sport's tag on a sport page opens that page", (
      tester,
    ) async {
      await _pump(
        tester,
        _post(sportId: 'sport-from-post'),
        currentSportId: 'some-other-sport',
      );
      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();
      expect(find.text('sport-page:sport-from-post'), findsOneWidget);
    });

    testWidgets('a sport with no id is not a button', (tester) async {
      await _pump(tester, _post(sport: 'Quidditch'));
      expect(_row(tester).onSportTap, isNull);
    });

    testWidgets('a post with no sport has no tag to tap', (tester) async {
      await _pump(tester, _post(sport: null));
      expect(_row(tester).onSportTap, isNull);
    });
  });

  group('postSportTap with the flag off (KAN-622)', () {
    testWidgets('returns no callback, so nothing can navigate', (tester) async {
      VoidCallback? tap = () {};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              tap = postSportTap(
                context,
                _post(sportId: 'sport-from-post'),
                enabled: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tap, isNull);
    });
  });
}
