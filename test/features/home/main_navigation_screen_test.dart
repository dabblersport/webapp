import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:go_router/go_router.dart';

import 'home_test_harness.dart' show FakeFeed;
import '../../support/render_mode.dart';

/// The app shell: a [DabblerPage] holding the active branch and a
/// [DabblerNavigationBottomBar] (Feeds, Venues, Games, Meetups; create = post + game).
Future<GoRouter> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Key? boundaryKey,
  PersonaType? persona = PersonaType.player,
  bool meetupsOn = true,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget branch(String label) =>
      Center(child: DabblerEmptyState(title: label));
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => branch('home-branch')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/community', builder: (_, __) => branch('community-branch')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/venues', builder: (_, __) => branch('venues-branch')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/games', builder: (_, __) => branch('games-branch')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.meetups, builder: (_, __) => branch('meetups-branch')),
          ]),
        ],
      ),
      GoRoute(
        path: RoutePaths.createGame,
        builder: (_, __) => branch('create-game-route'),
      ),
      GoRoute(
        path: RoutePaths.socialCreatePost,
        builder: (_, __) => branch('create-post-route'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initializeProfileDataProvider.overrideWith((ref) async => false),
        // No profile in the shell harness, so the provider chain never
        // reaches the live Supabase client. The meet-up tile still shows: it
        // follows the flag only (Alpha test build).
        meetupActorProfileIdProvider.overrideWithValue(null),
        // The active persona decides the Create game / meet-up tiles.
        activePersonaProvider.overrideWithValue(persona),
        meetupsEnabledProvider.overrideWithValue(meetupsOn),
        feedNotifierProvider.overrideWith((ref) => FakeFeed(const FeedLoading())),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
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
  return router;
}

const String _shotsDir = String.fromEnvironment('SHELL_SHOTS_DIR');

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadRenderFonts);

  testWidgets('a DabblerPage with the DS bottom bar: Feeds, Venues, Games, Meetups', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.byType(DabblerPage), findsOneWidget);
    expect(find.byType(DabblerNavigationBottomBar), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
    // The active item shows its label; every item is a named button.
    expect(find.text('Feeds'), findsOneWidget);
    expect(find.bySemanticsLabel('Venues'), findsOneWidget);
    expect(find.bySemanticsLabel('Games'), findsOneWidget);
    expect(find.bySemanticsLabel('Meetups'), findsOneWidget);
    expect(find.text('home-branch'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a bar item switches the shell branch', (tester) async {
    final semantics = tester.ensureSemantics();
    final router = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Games'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), '/games');
    await tester.tap(find.bySemanticsLabel('Venues'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), '/venues');
    await tester.tap(find.bySemanticsLabel('Meetups'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      RoutePaths.meetups,
    );
    expect(find.text('meetups-branch'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('create menu offers post, game and meetup and routes',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create post'), findsOneWidget);
    expect(find.text('Create game'), findsOneWidget);
    expect(find.text('Create meetup'), findsOneWidget);
    await tester.tap(find.text('Create game'));
    await tester.pumpAndSettle();
    expect(find.text('create-game-route'), findsOneWidget);
    semantics.dispose();
  });

  // CEO ruling 2026-10-06: Create game and Create meetup are for the player
  // and the organiser; Create post is for everyone. Unknown persona: hidden.
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final rtl = locale.languageCode == 'ar';
    final dir = rtl ? 'rtl' : 'ltr';
    final post = rtl ? 'منشور جديد' : 'Create post';
    final game = rtl ? 'مباراة جديدة' : 'Create game';
    final meetup = rtl ? 'لقاء جديد' : 'Create meetup';
    for (final c in <(String, PersonaType?, bool, List<String>)>[
      ('player', PersonaType.player, true, [post, game, meetup]),
      ('organiser', PersonaType.organiser, true, [post, game, meetup]),
      ('socialiser', PersonaType.socialiser, true, [post]),
      ('host', PersonaType.host, true, [post]),
      ('persona not known yet', null, true, [post]),
      ('player, meetups flag off', PersonaType.player, false, [post, game]),
      ('organiser, meetups flag off', PersonaType.organiser, false, [post, game]),
      ('socialiser, meetups flag off', PersonaType.socialiser, false, [post]),
    ]) {
      testWidgets('create menu for ${c.$1} - $dir', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          locale: locale,
          persona: c.$2,
          meetupsOn: c.$3,
        );
        await tester.tap(find.bySemanticsLabel('Create'));
        await tester.pumpAndSettle();
        final items = tester
            .widget<DabblerNavigationBottomBar>(
              find.byType(DabblerNavigationBottomBar),
            )
            .createItems;
        expect(items.map((i) => i.label), c.$4);
        for (final label in <String>[post, game, meetup]) {
          expect(
            find.text(label),
            c.$4.contains(label) ? findsOneWidget : findsNothing,
          );
        }
        // Tiles sit left to right in both directions (the bar is unmirrored).
        final dx = [for (final l in c.$4) tester.getCenter(find.text(l)).dx];
        for (var i = 1; i < dx.length; i++) {
          expect(dx[i], greaterThan(dx[i - 1]));
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('action: add closed, close-circle open, add again — $dir',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, locale: locale);
      Iterable<String> glyph() => tester
          .widgetList<DabblerIcon>(
            find.descendant(
              of: find.byType(AnimatedRotation),
              matching: find.byType(DabblerIcon),
            ),
          )
          .map((i) => i.name);
      double turns() =>
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
      expect(glyph(), <String>['add']);
      await tester.tap(find.bySemanticsLabel('Create'));
      await tester.pumpAndSettle();
      expect(glyph(), <String>['close-circle']);
      expect(turns(), 0);
      await tester.tap(find.bySemanticsLabel('Close menu'));
      await tester.pumpAndSettle();
      expect(glyph(), <String>['add']);
      expect(turns(), 0);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final c in <(String, PersonaType)>[
      ('1tile', PersonaType.socialiser),
      ('3tiles', PersonaType.organiser),
    ]) {
      testWidgets('renders the create menu with ${c.$1} - $dir', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        const key = Key('shot');
        await _pump(tester, locale: locale, boundaryKey: key, persona: c.$2);
        await tester.tap(find.bySemanticsLabel('Create'));
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        await _shoot(tester, key, 'create-menu-${c.$1}-$dir-light');
        semantics.dispose();
      });
    }
  }

  testWidgets('RTL renders without error', (tester) async {
    await _pump(tester, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    expect(find.byType(DabblerNavigationBottomBar), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('renders the shell and the create sheet — $dir', (tester) async {
      final semantics = tester.ensureSemantics();
      const key = Key('shot');
      await _pump(tester, locale: locale, boundaryKey: key);
      await _shoot(tester, key, 'shell-$dir');
      await tester.tap(find.bySemanticsLabel('Create'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'shell-$dir-create');
      semantics.dispose();
    });
  }
}
