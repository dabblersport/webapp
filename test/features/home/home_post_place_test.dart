// The feed row's place line shows the post's saved place name only. The area
// name is never rendered as a place; a null, blank or whitespace name shows
// no place. EN and AR.
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

Post _post({String? locationName, String? areaId}) => Post(
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

void _noAreaAsPlace() {
  expect(find.textContaining('Nad Al Sheba'), findsNothing);
  expect(find.textContaining('Unknown area'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] saved place name is shown', (tester) async {
      await _pump(
        tester,
        _post(locationName: 'Marina Padel Club', areaId: 'area-nas'),
        locale: locale,
      );
      expect(find.textContaining('Marina Padel Club'), findsWidgets);
      _noAreaAsPlace();
    });

    testWidgets('[$tag] area name is never shown as the place', (tester) async {
      await _pump(tester, _post(areaId: 'area-nas'), locale: locale);
      _noAreaAsPlace();
    });

    for (final name in <String?>[null, '', '   ']) {
      testWidgets('[$tag] no place line when the name is "${name ?? 'null'}"', (
        tester,
      ) async {
        await _pump(
          tester,
          _post(locationName: name, areaId: 'area-nas'),
          locale: locale,
        );
        _noAreaAsPlace();
        final row = tester.widget<DabblerPostRow>(find.byType(DabblerPostRow));
        expect(row.place, isEmpty);
      });
    }

    testWidgets('[$tag] a padded saved name is trimmed', (tester) async {
      await _pump(
        tester,
        _post(locationName: '  Marina Padel Club '),
        locale: locale,
      );
      final row = tester.widget<DabblerPostRow>(find.byType(DabblerPostRow));
      expect(row.place, 'Marina Padel Club');
    });
  }
}
