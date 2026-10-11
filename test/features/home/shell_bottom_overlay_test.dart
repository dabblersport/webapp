import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import 'home_test_harness.dart' show FakeFeed, initHomeTestSupabase;

/// The shell's floating bottom bar (CEO 2026-10-11): the strip around it is
/// transparent (the feed shows and scrolls behind it), the bar sits at the
/// design's 24 from the bottom but never below the home-indicator inset, and
/// the last list item stays reachable.
const Key _boundary = Key('shell-boundary');
const Color _feedRed = Color(0xFFD01010);

/// Writes labelled PNGs only with `--dart-define=SHELL_OVERLAY_SHOTS=<dir>`.
const String _shots = String.fromEnvironment('SHELL_OVERLAY_SHOTS');

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  required double inset,
  required Widget Function() feed,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: inset);
  tester.view.viewPadding = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: [
          for (final String p in <String>[
            '/home',
            '/community',
            '/venues',
            '/games',
            '/meetups',
          ])
            StatefulShellBranch(
              routes: [GoRoute(path: p, builder: (_, __) => feed())],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initializeProfileDataProvider.overrideWith((ref) async => false),
        meetupActorProfileIdProvider.overrideWithValue(null),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        meetupsEnabledProvider.overrideWithValue(true),
        feedNotifierProvider.overrideWith(
          (ref) => FakeFeed(const FeedLoading()),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _boundary, child: child),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            ThemeData(brightness: Brightness.light),
          ),
          locale: locale,
        ),
        darkTheme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            ThemeData(brightness: Brightness.dark),
          ),
          locale: locale,
        ),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<ui.Image> _image(WidgetTester tester) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final RenderRepaintBoundary b =
        tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
    image = await b.toImage(pixelRatio: 1);
  });
  return image;
}

Future<Color> _pixel(WidgetTester tester, ui.Image image, Offset p) async {
  late ByteData data;
  await tester.runAsync(() async {
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final int i = (p.dy.round() * image.width + p.dx.round()) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

bool _near(Color a, Color b) =>
    (a.r * 255 - b.r * 255).abs() < 3 &&
    (a.g * 255 - b.g * 255).abs() < 3 &&
    (a.b * 255 - b.b * 255).abs() < 3;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    for (final Brightness b in Brightness.values) {
      for (final double inset in <double>[0, 34]) {
        final String tag = '$dir ${b.name} inset $inset';

        testWidgets('the strip around the bar is transparent: the feed shows '
            'behind it, $tag', (tester) async {
          await _pump(
            tester,
            locale: locale,
            brightness: b,
            inset: inset,
            feed: () =>
                const SizedBox.expand(child: ColoredBox(color: _feedRed)),
          );
          expect(find.byType(DabblerFade), findsNothing);
          final Rect bar = tester.getRect(
            find.byType(DabblerNavigationBottomBar),
          );
          final ui.Image image = await _image(tester);
          final Color pageGround = DabblerColors.resolve(
            theme: DabblerTheme.main,
            brightness: b,
          ).bgPrimary;
          // Above the bar, in the strip the fade used to wash out; between and
          // beside the pill and the "+": the feed colour, not the page colour.
          for (final Offset p in <Offset>[
            Offset(8, bar.top - 6),
            Offset(196, bar.top - 20),
            Offset(8, bar.center.dy),
            Offset(385, bar.center.dy),
            Offset(196, bar.bottom + 2),
          ]) {
            final Color c = await _pixel(tester, image, p);
            expect(
              _near(c, _feedRed),
              isTrue,
              reason: '$p is $c, not the feed',
            );
            expect(_near(c, pageGround), isFalse);
          }
          expect(tester.takeException(), isNull);
        });

        testWidgets('the bar sits at the design offset, never below the '
            'home-indicator inset, $tag', (tester) async {
          await _pump(
            tester,
            locale: locale,
            brightness: b,
            inset: inset,
            feed: () => const SizedBox.expand(),
          );
          final Rect bar = tester.getRect(
            find.byType(DabblerNavigationBottomBar),
          );
          final double offset = 852 - bar.bottom;
          // Design `0 18px 24px`: 24 from the bottom; the inset when larger.
          expect(offset, inset > 24 ? inset : 24);
          debugPrint('BAR_BOTTOM_OFFSET $tag = $offset');
          expect(bar.height, 56, reason: 'bar and "+" sizes unchanged');
        });

        testWidgets('the last list item stays reachable above the bar, $tag', (
          tester,
        ) async {
          await _pump(
            tester,
            locale: locale,
            brightness: b,
            inset: inset,
            feed: () => ListView.builder(
              itemCount: 30,
              itemBuilder: (_, i) => SizedBox(
                height: 80,
                child: Text('row-$i', key: ValueKey<int>(i)),
              ),
            ),
          );
          final ScrollableState s = tester.state(find.byType(Scrollable).first);
          s.position.jumpTo(s.position.maxScrollExtent);
          await tester.pump();
          final Rect bar = tester.getRect(
            find.byType(DabblerNavigationBottomBar),
          );
          final Rect last = tester.getRect(find.byKey(const ValueKey<int>(29)));
          expect(
            last.bottom,
            lessThanOrEqualTo(bar.top + 0.5),
            reason: 'last row ${last.bottom} vs bar top ${bar.top}',
          );
        });
      }
    }
  }

  testWidgets('a small phone (360 x 640) keeps the same offsets', (
    tester,
  ) async {
    await _pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      inset: 0,
      size: const Size(360, 640),
      feed: () => const SizedBox.expand(),
    );
    final Rect bar = tester.getRect(find.byType(DabblerNavigationBottomBar));
    expect(640 - bar.bottom, 24);
    expect(bar.left, 18);
    expect(tester.takeException(), isNull);
  });

  if (_shots.isNotEmpty) {
    for (final (String dir, Locale locale) in <(String, Locale)>[
      ('en', const Locale('en')),
      ('ar', const Locale('ar')),
    ]) {
      for (final Brightness b in Brightness.values) {
        for (final (String phone, Size size, double inset)
            in <(String, Size, double)>[
              ('large', const Size(393, 852), 34),
              ('small', const Size(360, 640), 0),
            ]) {
          testWidgets('shots $dir ${b.name} $phone', (tester) async {
            await _pump(
              tester,
              locale: locale,
              brightness: b,
              inset: inset,
              size: size,
              feed: () => ListView.builder(
                itemCount: 20,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? const Color(0xFF7328CE)
                          : const Color(0xFF2D7331),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          'post ${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final ScrollableState s = tester.state(
              find.byType(Scrollable).first,
            );
            s.position.jumpTo(300);
            await tester.pump();
            final ui.Image image = await _image(tester);
            await tester.runAsync(() async {
              final ByteData? png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(_shots).createSync(recursive: true);
              File(
                '$_shots/$dir-${b.name}-$phone.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
            });
          });
        }
      }
    }
  }
}
