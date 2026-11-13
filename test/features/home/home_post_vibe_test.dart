// KAN-642: a post with a vibe shows it on its feed card (EN and AR); a post
// without one draws no vibe slot.
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'home_test_harness.dart';
import '../../support/render_mode.dart';

const _motivated = Vibe(
  id: 'v1',
  key: 'motivated',
  labelEn: 'Motivated',
  labelAr: 'متحمس',
);

Post _post({List<Vibe> vibes = const []}) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: 'Padel tonight',
  vibes: vibes,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

Future<void> _pump(WidgetTester tester, Post post, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Material(
          child: SingleChildScrollView(child: HomePostRow(post: post)),
        ),
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
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  testWidgets('[en] a post with a vibe renders the vibe pill', (tester) async {
    await _pump(tester, _post(vibes: const [_motivated]), const Locale('en'));
    expect(find.text('Motivated'), findsOneWidget);
    expect(_row(tester).vibeTagLabel, 'Motivated');
  });

  testWidgets('[ar] the vibe pill reads in Arabic', (tester) async {
    await _pump(tester, _post(vibes: const [_motivated]), const Locale('ar'));
    expect(find.text('متحمس'), findsOneWidget);
    expect(_row(tester).vibeTagLabel, 'متحمس');
  });

  testWidgets('a post without a vibe renders no vibe pill', (tester) async {
    await _pump(tester, _post(), const Locale('en'));
    expect(_row(tester).vibeTagLabel, isNull);
    expect(_row(tester).reactions, isNull);
  });
}
