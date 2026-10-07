import 'dart:io';

import 'package:dabbler/core/system_ui/system_chrome_sync.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SystemUiOverlayStyle _style(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(SystemChromeSync),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    )
    .value;

Future<DabblerColors> _pump(WidgetTester tester, ThemeMode mode) async {
  late DabblerColors colors;
  await tester.pumpWidget(
    MaterialApp(
      themeMode: mode,
      theme: DabblerDesignSystemTheme.withTokens(
        ThemeData(brightness: Brightness.light),
      ),
      darkTheme: DabblerDesignSystemTheme.withTokens(
        ThemeData(brightness: Brightness.dark),
      ),
      home: Builder(
        builder: (context) {
          colors = DabblerColors.of(context);
          return const SystemChromeSync(child: SizedBox());
        },
      ),
    ),
  );
  return colors;
}

void main() {
  testWidgets('overlay style follows the theme: light page, dark icons', (
    tester,
  ) async {
    final colors = await _pump(tester, ThemeMode.light);
    final s = _style(tester);
    expect(s.statusBarColor, colors.bgPrimary);
    expect(s.systemNavigationBarColor, colors.bgPrimary);
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    expect(s.statusBarBrightness, Brightness.light);
  });

  testWidgets('overlay style follows the theme: dark page, light icons', (
    tester,
  ) async {
    final colors = await _pump(tester, ThemeMode.dark);
    final s = _style(tester);
    expect(s.statusBarColor, colors.bgPrimary);
    expect(s.systemNavigationBarColor, colors.bgPrimary);
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    expect(s.statusBarBrightness, Brightness.dark);
  });

  testWidgets('toggling the theme changes the style', (tester) async {
    await _pump(tester, ThemeMode.light);
    final light = _style(tester);
    await _pump(tester, ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(_style(tester).statusBarColor, isNot(light.statusBarColor));
  });

  group('dynamic surfaces', () {
    Future<void> pumpApp(
      WidgetTester tester,
      Widget Function(BuildContext) detail,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DabblerDesignSystemTheme.withTokens(
            ThemeData(brightness: Brightness.light),
          ),
          builder: (context, child) =>
              Builder(builder: (context) => SystemChromeSync(child: child!)),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: detail)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    SystemUiOverlayStyle effective(WidgetTester tester) => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .descendant(
                of: find.byType(SystemChromeSync),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .first,
        )
        .value;

    testWidgets('a yellow-hero screen sets the bars, pop restores the page', (
      tester,
    ) async {
      await pumpApp(
        tester,
        (_) => Scaffold(
          body: SystemChromeSurface.detailHeader(
            tile: DabblerDetailHeaderTile.amber,
            child: const SizedBox(height: 100),
          ),
        ),
      );
      final page = effective(tester);
      expect(page.statusBarColor, isNot(DabblerColors.tileAmber.surface));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final hero = effective(tester);
      expect(hero.statusBarColor, DabblerColors.tileAmber.surface);
      // The bottom has no declared surface: still the page ground.
      expect(hero.systemNavigationBarColor, page.systemNavigationBarColor);
      // Icon brightness follows the effective colour's luminance.
      expect(
        hero.statusBarIconBrightness,
        ThemeData.estimateBrightnessForColor(DabblerColors.tileAmber.surface) ==
                Brightness.light
            ? Brightness.dark
            : Brightness.light,
      );

      Navigator.of(tester.element(find.byType(Scaffold))).pop();
      await tester.pumpAndSettle();
      final back = effective(tester);
      expect(back.statusBarColor, page.statusBarColor);
      expect(back.statusBarIconBrightness, page.statusBarIconBrightness);
    });

    testWidgets('icon brightness follows the colour, not the theme', (
      tester,
    ) async {
      await pumpApp(
        tester,
        (_) => const SystemChromeSurface(
          top: Color(0xFF101010),
          bottom: Color(0xFFFAFAFA),
          child: Scaffold(body: SizedBox()),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final s = effective(tester);
      expect(
        s.statusBarIconBrightness,
        Brightness.light,
      ); // light theme, dark surface
      expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });

  group('platform files', () {
    test('web: bars are the page ground from the first byte, no purple', () {
      final html = File('web/index.html').readAsStringSync();
      expect(
        html,
        contains(
          'name="theme-color" media="(prefers-color-scheme: light)" content="#F5F0E6"',
        ),
      );
      expect(
        html,
        contains(
          'name="theme-color" media="(prefers-color-scheme: dark)" content="#141414"',
        ),
      );
      expect(html, contains('<meta name="color-scheme" content="light dark">'));
      expect(
        html,
        contains('html, body { margin: 0; background-color: #F5F0E6; }'),
      );
      expect(html, contains('html, body { background-color: #141414; }'));
      expect(html, contains('status-bar-style" content="default"'));
      // No purple theme-color or html/body ground: the splash draws its own.
      final live = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      expect(live, isNot(contains('#7328CE')));
      expect(live, isNot(contains('#7228CC')));
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"theme_color": "#F5F0E6"'));
      expect(manifest, contains('"background_color": "#F5F0E6"'));
    });

    test('web: the runtime swap updates both metas and color-scheme', () {
      final src = File(
        'lib/core/system_ui/web_chrome_web.dart',
      ).readAsStringSync();
      expect(src, contains('meta[name="theme-color"]'));
      expect(src, contains("'content'.toJS, hex.toJS"));
      expect(src, contains("style?['colorScheme']"));
      expect(src, contains('Brightness brightness'));
    });

    test('android: NormalTheme bars and window are the page ground', () {
      for (final d in [
        'values',
        'values-v31',
        'values-night',
        'values-night-v31',
      ]) {
        final s = File(
          'android/app/src/main/res/$d/styles.xml',
        ).readAsStringSync();
        final normal = s.substring(s.indexOf('name="NormalTheme"'));
        expect(normal, isNot(contains('splash_purple')), reason: d);
        expect(
          normal,
          contains('android:statusBarColor">@color/page_background'),
          reason: d,
        );
        expect(
          normal,
          contains('android:navigationBarColor">@color/page_background'),
          reason: d,
        );
        final light = !d.contains('night');
        expect(normal, contains('windowLightStatusBar">$light'), reason: d);
        expect(normal, contains('windowLightNavigationBar">$light'), reason: d);
        // The launch theme keeps the purple.
        expect(
          s.substring(0, s.indexOf('name="NormalTheme"')),
          anyOf(contains('splash_purple'), contains('launch_background')),
          reason: d,
        );
      }
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('page_background">#F5F0E6'),
      );
      expect(
        File(
          'android/app/src/main/res/values-night/colors.xml',
        ).readAsStringSync(),
        contains('page_background">#141414'),
      );
    });

    test(
      'ios: status bar style is set; running appearance is view-controller based',
      () {
        final plist = File('ios/Runner/Info.plist').readAsStringSync();
        expect(plist, contains('UIStatusBarStyleDefault'));
        expect(
          plist,
          contains(
            '<key>UIViewControllerBasedStatusBarAppearance</key>\n\t<true/>',
          ),
        );
      },
    );
  });
}
