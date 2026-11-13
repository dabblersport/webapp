// KAN-592: the feed row's header names where the author POSTED FROM (area and
// city, the city alone, or Dubai for a legacy post). The place the post is
// about is its own pill (placeTagLabel) and never reaches the header. EN and AR.
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
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

Post _post({
  String? locationName,
  String? areaId,
  String? postedFromCity,
  String? postedFromArea,
}) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: 'Padel tonight',
  locationName: locationName,
  areaId: areaId,
  postedFromCity: postedFromCity,
  postedFromArea: postedFromArea,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

Future<void> _pump(
  WidgetTester tester,
  Post post, {
  Locale locale = const Locale('en'),
}) async {
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

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    final dubai = locale.languageCode == 'ar' ? '\u062f\u0628\u064a' : 'Dubai';

    testWidgets('[$tag] header is the posting area and city', (tester) async {
      await _pump(
        tester,
        _post(postedFromCity: 'Dubai', postedFromArea: 'Dubai Marina'),
        locale: locale,
      );
      expect(_row(tester).place, 'Dubai Marina, Dubai');
      expect(_row(tester).placeTagLabel, isNull);
    });

    testWidgets('[$tag] no area is invented: the header is the city alone', (
      tester,
    ) async {
      await _pump(tester, _post(postedFromCity: 'Sharjah'), locale: locale);
      expect(_row(tester).place, 'Sharjah');
    });

    testWidgets('[$tag] a post about an Abu Dhabi venue, posted from Dubai', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(
          locationName: 'Zayed Sports City',
          postedFromCity: 'Dubai',
          postedFromArea: 'Dubai Marina',
        ),
        locale: locale,
      );
      expect(_row(tester).place, 'Dubai Marina, Dubai');
      expect(_row(tester).placeTagLabel, 'Zayed Sports City');
      expect(find.textContaining('Abu Dhabi'), findsNothing);
    });

    testWidgets('[$tag] legacy post (never recorded) reads Dubai, no tag', (
      tester,
    ) async {
      await _pump(tester, _post(areaId: 'area-nas'), locale: locale);
      expect(_row(tester).place, dubai);
      expect(_row(tester).placeTagLabel, isNull);
      expect(find.textContaining('Nad Al Sheba'), findsNothing);
    });

    testWidgets('[$tag] a genuinely stored tag on a legacy post is kept', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(locationName: 'Marina Padel Club', areaId: 'area-nas'),
        locale: locale,
      );
      expect(_row(tester).place, dubai);
      expect(_row(tester).placeTagLabel, 'Marina Padel Club');
    });

    for (final name in <String?>[null, '', '   ']) {
      testWidgets('[$tag] no pill when the tag is "${name ?? 'null'}"', (
        tester,
      ) async {
        await _pump(
          tester,
          _post(locationName: name, postedFromCity: 'Dubai'),
          locale: locale,
        );
        expect(_row(tester).placeTagLabel, isNull);
      });
    }

    testWidgets('[$tag] a padded tag is trimmed', (tester) async {
      await _pump(
        tester,
        _post(locationName: '  Marina Padel Club ', postedFromCity: 'Dubai'),
        locale: locale,
      );
      expect(_row(tester).placeTagLabel, 'Marina Padel Club');
    });
  }
}
