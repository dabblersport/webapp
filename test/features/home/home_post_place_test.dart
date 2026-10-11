// KAN-492: the feed row's place line shows the saved place name; it falls
// back to the area name only when that area resolves to a real name, and
// shows nothing (never a placeholder) otherwise. EN and AR.
import 'dart:async';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
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
  Post post,
  Future<String?> Function() areaName, {
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
        postAreaNameProvider.overrideWith((ref, id) => areaName()),
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

void _noFabricatedPlace() {
  expect(find.textContaining('Nad Al Sheba'), findsNothing);
  expect(find.textContaining('Unknown area'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] saved place name is shown first', (tester) async {
      await _pump(
        tester,
        _post(locationName: 'Marina Padel Club', areaId: 'area-nas'),
        () async => 'Nad Al Sheba',
        locale: locale,
      );
      expect(find.textContaining('Marina Padel Club'), findsWidgets);
      _noFabricatedPlace();
    });

    testWidgets('[$tag] area fallback when the area resolves', (tester) async {
      await _pump(
        tester,
        _post(areaId: 'area-marina'),
        () async => 'Dubai Marina',
        locale: locale,
      );
      expect(find.textContaining('Dubai Marina'), findsWidgets);
    });

    testWidgets('[$tag] nothing while the area is loading', (tester) async {
      final never = Completer<String?>();
      await _pump(
        tester,
        _post(areaId: 'area-nas'),
        () => never.future,
        locale: locale,
      );
      _noFabricatedPlace();
    });

    testWidgets('[$tag] nothing when the area lookup fails or is unknown', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(areaId: 'area-x'),
        () async => null,
        locale: locale,
      );
      _noFabricatedPlace();
      await _pump(
        tester,
        _post(areaId: 'area-x'),
        () async => throw StateError('lookup failed'),
        locale: locale,
      );
      _noFabricatedPlace();
    });

    testWidgets('[$tag] nothing when the post has no area id', (tester) async {
      var asked = false;
      await _pump(tester, _post(), () async {
        asked = true;
        return 'Nad Al Sheba';
      }, locale: locale);
      expect(asked, isFalse);
      _noFabricatedPlace();
    });
  }
}
