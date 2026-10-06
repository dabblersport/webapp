import 'dart:io';
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import 'home_test_harness.dart' show FakeFeed;

/// KAN-433 — the bottom bar of the app shell, measured with `tester.getRect`
/// against the Home Feed design (`home-design-measure.md`, section 8), in LTR
/// and in RTL. Every delta is zero or a named exception whose app value is
/// pinned here, so a regression in either direction fails.
///
/// Optional run defines: `NAV_MEASURE_MD=<file>` writes the delta table;
/// `NAV_SHOTS_DIR=<dir>` writes the app renders (`nav-app-*.png`, 2x).

const String _mdOut = String.fromEnvironment('NAV_MEASURE_MD');
const String _shotsDir = String.fromEnvironment('NAV_SHOTS_DIR');
const double _tol = 0.02;

// ---------------------------------------------------------------- the design

/// A measured design rect, `x,y w×h` (design px, 393x852 frame).
Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// One row of the delta table.
class _Row {
  _Row(this.element, this.design, this.app, {this.exception});
  final String element;
  final Rect? design;
  final Rect? app;
  final String? exception;
}

class _Exception {
  const _Exception(this.name, this.pinnedApp);

  /// The named reason the app differs from the design.
  final String name;

  /// The app value this exception is pinned to.
  final Rect pinnedApp;
}

// ------------------------------------------------------------------ harness

/// The test binding paints box shadows hard-edged (`debugDisableShadows`); a
/// render must show the real soft ones. Rects are unaffected either way. The
/// binding checks the flag is back at its default when a test ends.
void _softShadows(bool on) {
  if (_shotsDir.isNotEmpty) debugDisableShadows = !on;
}

Future<void> _loadFonts() async {
  final List<String> dirs = <String>[
    '${Directory.current.parent.path}/dabbler-design-system/fonts',
    '${Directory.current.path}/../ds-luxor/fonts',
  ];
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    var any = false;
    for (final String f in files) {
      for (final String d in dirs) {
        final File file = File('$d/$f');
        if (file.existsSync()) {
          loader.addFont(
            file.readAsBytes().then((b) => ByteData.sublistView(b)),
          );
          any = true;
          break;
        }
      }
    }
    if (any) await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  Key? boundaryKey,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget branch(String label) => const SizedBox.expand();
  final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: <StatefulShellBranch>[
          for (final String p in <String>[
            '/home',
            '/community',
            '/venues',
            '/games',
          ])
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: p, builder: (_, __) => branch(p)),
              ],
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
        // No profile in the shell harness, so the provider chain never reaches the live Supabase client.
        meetupActorProfileIdProvider.overrideWithValue(null),
        // The measured menu is the three-tile one: a persona that may create.
        activePersonaProvider.overrideWithValue(PersonaType.player),
        feedNotifierProvider.overrideWith(
          (ref) => FakeFeed(const FeedLoading()),
        ),
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

// ------------------------------------------------------------- measurements

Finder get _bar => find.byType(DabblerNavigationBottomBar);

Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

List<Rect> _hits(WidgetTester t) => t
    .elementList(
      find.descendant(
        of: _bar,
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is GestureDetector && w.behavior == HitTestBehavior.opaque,
        ),
      ),
    )
    .map((Element e) => t.getRect(find.byElementPredicate((x) => x == e)))
    .toList();

Rect _pill(WidgetTester t) {
  final DabblerColors colors = DabblerColors.of(t.element(_bar));
  return t
      .elementList(
        find.descendant(
          of: _bar,
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == colors.brandPrimary,
          ),
        ),
      )
      .map((Element e) => t.getRect(find.byElementPredicate((x) => x == e)))
      .firstWhere((Rect r) => r.width > DabblerSizing.navBarHeight);
}

List<Rect> _icons(WidgetTester t) => t
    .elementList(find.descendant(of: _bar, matching: find.byType(DabblerIcon)))
    .map((Element e) => t.getRect(find.byElementPredicate((x) => x == e)))
    .toList();

Rect _menuCard(WidgetTester t) {
  final DabblerColors colors = DabblerColors.of(t.element(_bar));
  return t.getRect(
    find.byWidgetPredicate(
      (Widget w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == colors.surfaceCard &&
          (w.decoration! as BoxDecoration).borderRadius == DabblerRadius.xxlAll,
    ),
  );
}

List<Rect> _plates(WidgetTester t) => t
    .elementList(
      find.descendant(
        of: _bar,
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.constraints?.maxHeight == DabblerSizing.navCreateTile,
        ),
      ),
    )
    .map((Element e) => t.getRect(find.byElementPredicate((x) => x == e)))
    .toList();

Rect _centred(Rect r, double h) =>
    Rect.fromLTWH(r.left, r.center.dy - h / 2, r.width, h);

// ------------------------------------------------------------------- tables

final List<_Row> _doc = <_Row>[];

/// A non-rect fact: `element | design | app | token or exception`.
final List<List<String>> _facts = <List<String>>[];

void _fact(
  String state,
  String element,
  String design,
  String app,
  String note,
) => _facts.add(<String>['$state | $element', design, app, note]);

void _check(List<_Row> rows, Map<String, _Exception> exceptions) {
  for (final _Row row in rows) {
    final Rect? d = row.design;
    final Rect? a = row.app;
    final _Exception? ex = exceptions[row.element];
    if (d == null || a == null) {
      expect(ex, isNotNull, reason: '${row.element}: no counterpart, no name');
      continue;
    }
    final bool zero =
        (a.left - d.left).abs() <= _tol &&
        (a.top - d.top).abs() <= _tol &&
        (a.width - d.width).abs() <= _tol &&
        (a.height - d.height).abs() <= _tol;
    if (ex == null) {
      expect(zero, isTrue, reason: '${row.element}: design $d, app $a');
    } else {
      expect(zero, isFalse, reason: '${row.element}: exception is stale');
      expect(
        (a.left - ex.pinnedApp.left).abs() <= _tol &&
            (a.top - ex.pinnedApp.top).abs() <= _tol &&
            (a.width - ex.pinnedApp.width).abs() <= _tol &&
            (a.height - ex.pinnedApp.height).abs() <= _tol,
        isTrue,
        reason: '${row.element}: pinned ${ex.pinnedApp}, app $a (${ex.name})',
      );
    }
  }
}

String _fmt(Rect? r) => r == null
    ? '-'
    : '${r.left.toStringAsFixed(2)},${r.top.toStringAsFixed(2)} '
          '${r.width.toStringAsFixed(2)}x${r.height.toStringAsFixed(2)}';

String _delta(Rect? d, Rect? a) {
  if (d == null || a == null) return 'n/a';
  String f(double v) => v.abs() < _tol ? '0' : v.toStringAsFixed(2);
  return 'x ${f(a.left - d.left)}, y ${f(a.top - d.top)}, '
      'w ${f(a.width - d.width)}, h ${f(a.height - d.height)}';
}

/// The DS token behind a row that matches the design exactly.
String _tokenFor(String element) {
  if (element.startsWith('fade wrapper')) {
    return 'DabblerSizing.navFadeHeight 80 (navBarHeight 56 + space8 24), '
        'DabblerFade';
  }
  if (element == 'pill') {
    return 'DabblerSizing.navBarHeight, space2/space3 padding, '
        'DabblerRadius.pill';
  }
  if (element.startsWith('glyph ')) {
    return 'DabblerSizing.iconMd 24';
  }
  if (element.startsWith('item ')) {
    return element.contains('active')
        ? 'space6 padding, activeGap 8, 44 high (navItem)'
        : 'DabblerSizing.navItem 44';
  }
  if (element.startsWith('create button')) {
    return 'DabblerSizing.navBarHeight 56 (DabblerFab.size)';
  }
  if (element.startsWith('create glyph')) {
    return 'DabblerSizing.navGlyphLarge 26';
  }
  if (element.startsWith('label')) {
    return 'DabblerType.subheadline w500 (centre line)';
  }
  if (element.startsWith('plate')) {
    return 'DabblerSizing.navCreateTile 62, DabblerRadius.xl';
  }
  return 'DS default';
}

void _record(String state, List<_Row> rows, Map<String, _Exception> ex) {
  for (final _Row r in rows) {
    final _Exception? e = ex[r.element];
    final bool zero =
        r.design != null &&
        r.app != null &&
        _delta(r.design, r.app) == 'x 0, y 0, w 0, h 0';
    _doc.add(
      _Row(
        '$state | ${r.element}',
        r.design,
        r.app,
        exception: e?.name ?? (zero ? 'token: ${_tokenFor(r.element)}' : null),
      ),
    );
  }
}

// ----------------------------------------------------- the design (frame px)

// LTR, English frame. `home-design-measure.md` section 8a/8b.
const Map<String, List<double>> _dLtrClosed = <String, List<double>>{
  'fade wrapper': <double>[0, 772, 393, 80],
  'pill': <double>[18, 772, 269.11, 56],
  'item Feeds (active)': <double>[27, 778, 101.11, 44],
  'glyph Feeds (bold 24)': <double>[45, 788, 24, 24],
  'label Feeds (15/15 w500)': <double>[77, 792.5, 33.11, 15],
  'item Venues': <double>[134.11, 778, 44, 44],
  'glyph Venues (linear 24)': <double>[144.11, 788, 24, 24],
  'item Games': <double>[184.11, 778, 44, 44],
  'glyph Games (linear 24)': <double>[194.11, 788, 24, 24],
  'item Meetups': <double>[234.11, 778, 44, 44],
  'glyph Meetups (linear 24)': <double>[244.11, 788, 24, 24],
  'create button': <double>[319, 772, 56, 56],
  'create glyph (bold 26)': <double>[334, 787, 26, 26],
};

// RTL, Arabic frame: UNMIRRORED (same side of the screen as LTR).
const Map<String, List<double>> _dRtlClosed = <String, List<double>>{
  'fade wrapper': <double>[0, 772, 393, 80],
  'pill': <double>[18, 772, 282.98, 56],
  'item Feeds (active)': <double>[27, 778, 114.98, 44],
  'glyph Feeds (bold 24)': <double>[45, 788, 24, 24],
  'label Feeds (15/15 w500)': <double>[77, 792.5, 46.98, 15],
  'item Venues': <double>[147.98, 778, 44, 44],
  'glyph Venues (linear 24)': <double>[157.98, 788, 24, 24],
  'item Games': <double>[197.98, 778, 44, 44],
  'glyph Games (linear 24)': <double>[207.98, 788, 24, 24],
  'item Meetups': <double>[247.98, 778, 44, 44],
  'glyph Meetups (linear 24)': <double>[257.98, 788, 24, 24],
  'create button': <double>[319, 772, 56, 56],
  'create glyph (bold 26)': <double>[334, 787, 26, 26],
};

const Map<String, List<double>> _dLtrOpen = <String, List<double>>{
  'fade wrapper (open)': <double>[0, 719.38, 393, 132.63],
  'create menu card': <double>[18, 719.38, 289, 108.63],
  'menu item 1 Create post': <double>[30, 731.38, 83, 84.63],
  'plate 1 (83x62)': <double>[30, 731.38, 83, 62],
  'label 1 (12.5/15.63 w500)': <double>[43.52, 800.38, 55.97, 15.63],
  'menu item 2 Create game': <double>[121, 731.38, 83, 84.63],
  'plate 2 (83x62)': <double>[121, 731.38, 83, 62],
  'menu item 3 Create meetup': <double>[212, 731.38, 83, 84.63],
  'plate 3 (83x62)': <double>[212, 731.38, 83, 62],
  'create button (open)': <double>[319, 772, 56, 56],
};

const Map<String, List<double>> _dRtlOpen = <String, List<double>>{
  'fade wrapper (open)': <double>[0, 719.38, 393, 132.63],
  'create menu card': <double>[18, 719.38, 289, 108.63],
  'menu item 1 Create post': <double>[30, 731.38, 83, 84.63],
  'plate 1 (83x62)': <double>[30, 731.38, 83, 62],
  'label 1 (12.5/15.63 w500)': <double>[42.48, 800.38, 58.02, 15.63],
  'menu item 2 Create game': <double>[121, 731.38, 83, 84.63],
  'plate 2 (83x62)': <double>[121, 731.38, 83, 62],
  'menu item 3 Create meetup': <double>[212, 731.38, 83, 84.63],
  'plate 3 (83x62)': <double>[212, 731.38, 83, 62],
  'create button (open)': <double>[319, 772, 56, 56],
};

Rect? _d(Map<String, List<double>> m, String k) =>
    m[k] == null ? null : _r(m[k]![0], m[k]![1], m[k]![2], m[k]![3]);

/// The app's closed bar, keyed like the design table.
Map<String, Rect?> _appClosed(WidgetTester t, {required String active}) {
  final List<Rect> hits = _hits(t);
  final List<Rect> icons = _icons(t);
  return <String, Rect?>{
    'fade wrapper': _rect(t, find.byType(DabblerFade)),
    'pill': _pill(t),
    'item Feeds (active)': hits[0],
    'glyph Feeds (bold 24)': icons[0],
    // Label: its centre line is compared; the app draws the DS `subheadline`
    // 15/20 line box where the frame's is 15/15 (no DS role at 15/15).
    'label Feeds (15/15 w500)': _centred(_rect(t, find.text(active)), 15),
    'item Venues': hits[1],
    'glyph Venues (linear 24)': icons[1],
    'item Games': hits[2],
    'glyph Games (linear 24)': icons[2],
    'item Meetups': hits[3],
    'glyph Meetups (linear 24)': icons[3],
    'create button': hits[4],
    'create glyph (bold 26)': icons[4],
  };
}

Map<String, Rect?> _appOpen(WidgetTester t, {required String caption}) {
  final List<Rect> hits = _hits(t);
  final List<Rect> plates = _plates(t);
  return <String, Rect?>{
    'fade wrapper (open)': _rect(t, find.byType(DabblerFade)),
    'create menu card': _menuCard(t),
    'menu item 1 Create post': hits[0],
    'plate 1 (83x62)': plates[0],
    'label 1 (12.5/15.63 w500)': _rect(t, find.text(caption)),
    'menu item 2 Create game': hits[1],
    'plate 2 (83x62)': plates[1],
    'menu item 3 Create meetup': hits[2],
    'plate 3 (83x62)': plates[2],
    'create button (open)': hits[3],
  };
}

List<_Row> _rows(Map<String, List<double>> design, Map<String, Rect?> app) =>
    <_Row>[for (final String k in design.keys) _Row(k, _d(design, k), app[k])];

// ---------------------------------------------------------------- exceptions

void main() {
  setUpAll(_loadFonts);
  tearDownAll(() {
    if (_mdOut.isEmpty) return;
    final StringBuffer b = StringBuffer()
      ..writeln('| element | design px | app px | delta | token / exception |')
      ..writeln('|---|---|---|---|---|');
    for (final _Row r in _doc) {
      b.writeln(
        '| ${r.element} | ${_fmt(r.design)} | ${_fmt(r.app)} | '
        '${_delta(r.design, r.app)} | ${r.exception ?? '-'} |',
      );
    }
    b
      ..writeln()
      ..writeln('| fact | design | app | token / exception |')
      ..writeln('|---|---|---|---|');
    for (final List<String> f in _facts) {
      b.writeln('| ${f[0]} | ${f[1]} | ${f[2]} | ${f[3]} |');
    }
    File(_mdOut).writeAsStringSync(b.toString());
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final bool rtl = locale.languageCode == 'ar';
    final String dir = rtl ? 'RTL' : 'LTR';
    final String active = rtl ? 'الرئيسية' : 'Feeds';
    final String caption = rtl ? 'منشور جديد' : 'Create post';
    final Map<String, List<double>> dClosed = rtl ? _dRtlClosed : _dLtrClosed;
    final Map<String, List<double>> dOpen = rtl ? _dRtlOpen : _dLtrOpen;

    testWidgets('closed bar vs the Home Feed frame — $dir', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      _softShadows(true);
      const Key key = Key('nav-shot');
      await _pump(tester, locale: locale, boundaryKey: key);
      await _settle(tester);
      await _shoot(tester, key, 'nav-app-closed-${dir.toLowerCase()}');

      final List<_Row> rows = _rows(
        dClosed,
        _appClosed(tester, active: active),
      );
      final Map<String, _Exception> ex = <String, _Exception>{
        ..._pillExceptions(rtl),
      };
      _record('closed $dir', rows, ex);
      _check(rows, ex);

      _closedFacts(tester, dir, rtl, active);
      // Inactive items carry accessible names.
      expect(find.bySemanticsLabel(rtl ? 'ملاعب' : 'Venues'), findsOneWidget);
      expect(find.bySemanticsLabel(rtl ? 'مباريات' : 'Games'), findsOneWidget);
      // The pill is on the frame's physical side in both directions.
      expect(_pill(tester).left, 18);
      expect(_hits(tester).last.right, 393 - 18);
      expect(tester.takeException(), isNull);
      _softShadows(false);
      semantics.dispose();
    });

    for (final ({String id, String en, String ar}) item
        in const <({String id, String en, String ar})>[
          (id: 'venues', en: 'Venues', ar: 'ملاعب'),
          (id: 'games', en: 'Games', ar: 'مباريات'),
        ]) {
      testWidgets('active ${item.id}: one white chip with its label — $dir', (
        tester,
      ) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        _softShadows(true);
        const Key key = Key('nav-shot');
        await _pump(tester, locale: locale, boundaryKey: key);
        final String name = rtl ? item.ar : item.en;
        await tester.tap(find.bySemanticsLabel(name));
        await _settle(tester);
        await _shoot(tester, key, 'nav-app-${item.id}-${dir.toLowerCase()}');
        // Exactly one label is visible: the active one.
        expect(find.text(name), findsOneWidget);
        expect(find.text(active), findsNothing);
        final List<Rect> hits = _hits(tester);
        // The active chip is the 44-high one wider than 44; the others are 44.
        expect(
          hits.sublist(0, 3).where((Rect r) => r.width > 44),
          hasLength(1),
        );
        for (final Rect r in hits.sublist(0, 3)) {
          expect(r.height, 44);
        }
        expect(_pill(tester).left, 18);
        expect(_hits(tester).last, _r(319, 772, 56, 56));
        _softShadows(false);
        semantics.dispose();
      });
    }

    testWidgets('create menu open vs the frame — $dir', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      _softShadows(true);
      const Key key = Key('nav-shot');
      await _pump(tester, locale: locale, boundaryKey: key);
      await tester.tap(
        find.bySemanticsLabel('Create').first,
        warnIfMissed: false,
      );
      await _settle(tester);
      await _shoot(tester, key, 'nav-app-open-${dir.toLowerCase()}');

      final List<_Row> rows = _rows(dOpen, _appOpen(tester, caption: caption));
      final Map<String, _Exception> ex = <String, _Exception>{
        // The meet-up tile is offered whenever the flag is on (Alpha test
        // build, CEO 2026-10-06), so the third tile is measured like the
        // other two: no exception.
        ..._openExceptions(rtl),
      };
      _record('open $dir', rows, ex);
      _check(rows, ex);
      _openFacts(tester, dir, rtl, caption);
      expect(tester.takeException(), isNull);
      _softShadows(false);
      semantics.dispose();
    });
  }
}

const String _kArabicType =
    'DS Arabic type rule (Latin size minus 0.9, cxo ruling): label 14.1 vs frame 15';
const String _kLineRounding =
    'Flutter rounds a text line to whole px (frame 15.625 -> 16): +0.375';

void _closedFacts(WidgetTester t, String dir, bool rtl, String active) {
  final DabblerColors colors = DabblerColors.of(t.element(_bar));
  final Text label = t.widget<Text>(find.text(active));
  final TextStyle st = label.style!;
  expect(st.fontWeight, FontWeight.w500);
  expect(st.color, colors.brandPrimary);
  expect(st.fontSize, rtl ? closeTo(14.1, 0.01) : 15);
  _fact(
    'closed $dir',
    'active label type',
    rtl ? 'Meral Sans 15/15 w500 brand' : 'Glory 15/15 w500 brand',
    '${st.fontFamily} ${st.fontSize!.toStringAsFixed(1)}/${(st.fontSize! * (st.height ?? 1)).toStringAsFixed(1)} w500 brand',
    rtl
        ? _kArabicType
        : 'DS has no 15/15 role: subheadline 15/20 w500, centre line equal',
  );
  final List<DabblerIcon> icons = t
      .widgetList<DabblerIcon>(
        find.descendant(of: _bar, matching: find.byType(DabblerIcon)),
      )
      .toList();
  expect(icons[0].weight, DabblerIconWeight.bold);
  expect(icons[0].color, colors.brandPrimary);
  expect(icons[1].weight, DabblerIconWeight.linear);
  expect(icons[1].color, colors.borderDefault);
  // The Meetups destination draws the design's dot-grid calendar, which is
  // `calendar-1` in iconsax_flutter (plain `calendar` draws an "8").
  expect(icons[3].name, 'calendar-1');
  expect(icons[3].weight, DabblerIconWeight.linear);
  expect(icons[3].color, colors.borderDefault);
  expect(icons[4].weight, DabblerIconWeight.bold);
  expect(icons[4].name, 'add');
  expect(icons[4].color, colors.onBrand);
  _fact(
    'closed $dir',
    'active glyph',
    'home-2 bold 24 brand',
    '${icons[0].name} ${icons[0].weight.name} ${icons[0].size} brand',
    'DabblerSizing.iconMd',
  );
  _fact(
    'closed $dir',
    'inactive glyph',
    'linear 24 neutral-400',
    '${icons[1].name} ${icons[1].weight.name} ${icons[1].size} borderDefault',
    'DabblerColors.borderDefault',
  );
  _fact(
    'closed $dir',
    'create glyph',
    'add bold 26 on-brand',
    '${icons[4].name} ${icons[4].weight.name} ${icons[4].size} onBrand',
    'DabblerSizing.navGlyphLarge',
  );
  final BoxDecoration fab = t
      .widgetList<Container>(
        find.descendant(of: _bar, matching: find.byType(Container)),
      )
      .map((Container c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere(
        (BoxDecoration d) => d.boxShadow != null && d.boxShadow!.isNotEmpty,
      );
  expect(fab.boxShadow, DabblerFab.shadow);
  _fact(
    'closed $dir',
    'create button shadow',
    '0 10 15 -3 / 0 4 6 -4, black 10%',
    'DabblerFab.shadow (same pair)',
    'token: DabblerFab.shadow',
  );
  _fact(
    'closed $dir',
    'pill shadow / border',
    'none / none',
    'none / none',
    'token: flat',
  );
  _fact(
    'closed $dir',
    'layout direction',
    rtl
        ? 'unmirrored: pill left, button right (Arabic PNG)'
        : 'pill left, button right',
    'pill left, button right',
    rtl
        ? 'mirrorInRtl: false (frame quirk: the frame places the nav physically, not mirrored)'
        : 'token: 0',
  );
  _fact(
    'closed $dir',
    'inactive item accessible names',
    'none in the frame (no aria-label)',
    rtl ? 'ملاعب, مباريات' : 'Venues, Games',
    'DS supplies Semantics(button, label) per item',
  );
  _fact(
    'closed $dir',
    'create button accessible name',
    'Create',
    'Create',
    'DS actionLabel default; the app passes none, so it is English in Arabic too (see difference list)',
  );
}

void _openFacts(WidgetTester t, String dir, bool rtl, String caption) {
  final DabblerColors colors = DabblerColors.of(t.element(_bar));
  final Text label = t.widget<Text>(find.text(caption));
  final TextStyle st = label.style!;
  expect(st.fontSize, 12.5);
  expect(st.fontWeight, FontWeight.w500);
  expect(st.color, colors.textPrimary);
  _fact(
    'open $dir',
    'caption type',
    'Glory 12.5/15.625 w500 #000000 (undefined --text-body)',
    '${st.fontFamily} 12.5/${(12.5 * (st.height ?? 1)).toStringAsFixed(3)} w500 textPrimary',
    'frame quirk: --text-body undefined renders pure black; DS body ink (D-007(1))',
  );
  final List<DabblerIcon> icons = t
      .widgetList<DabblerIcon>(
        find.descendant(of: _bar, matching: find.byType(DabblerIcon)),
      )
      .toList();
  // The CEO's `ceo-design-menu.png`: while open the action shows the
  // close-circle (a light disc carrying a brand x), upright, on-brand.
  expect(icons.last.name, 'close-circle');
  expect(icons.last.weight, DabblerIconWeight.bold);
  expect(icons.last.size, DabblerSizing.navGlyphLarge);
  expect(icons.last.color, colors.onBrand);
  expect(
    t
        .widget<AnimatedRotation>(
          find.descendant(of: _bar, matching: find.byType(AnimatedRotation)),
        )
        .turns,
    0,
  );
  for (final DabblerIcon tile in icons.sublist(0, 2)) {
    expect(tile.size, DabblerSizing.navGlyphLarge);
    expect(tile.weight, DabblerIconWeight.linear);
  }
  _fact(
    'open $dir',
    'create button glyph',
    'close-circle bold 26 on-brand, upright (ceo-design-menu.png)',
    '${icons.last.name} ${icons.last.weight.name} ${icons.last.size}',
    'actionOpenIcon: close-circle, rotateActionOnOpen: false',
  );
  _fact(
    'open $dir',
    'tile glyphs',
    'linear 26 ink',
    '${icons[0].name}, ${icons[1].name} linear ${icons[0].size}',
    'DabblerSizing.navGlyphLarge',
  );
  final Iterable<BoxDecoration> decos = t
      .widgetList<Container>(
        find.descendant(of: _bar, matching: find.byType(Container)),
      )
      .map((Container c) => c.decoration)
      .whereType<BoxDecoration>();
  final BoxDecoration menu = decos.firstWhere(
    (BoxDecoration d) =>
        d.borderRadius == DabblerRadius.xxlAll && d.color == colors.surfaceCard,
  );
  expect(menu.boxShadow, DabblerElevation.dialogFor(colors.brightness));
  _fact(
    'open $dir',
    'menu card radius / fill',
    '24 / surface-card',
    'DabblerRadius.xxl / surfaceCard',
    'token: 0',
  );
  _fact(
    'open $dir',
    'menu card shadow',
    '0 10 15 -3 / 0 4 6 -4, black 10% (same pair as the button)',
    'DabblerElevation.dialogFor (--elevation-2)',
    'DS ruling D-031: the create menu carries --elevation-2, not the FAB pair',
  );
  final Set<Color?> fills = decos
      .where((BoxDecoration d) => d.borderRadius == DabblerRadius.xlAll)
      .map((BoxDecoration d) => d.color)
      .toSet();
  expect(
    fills,
    containsAll(<Color>[
      DabblerColors.tileInfo.surface,
      colors.success.surface,
    ]),
  );
  _fact(
    'open $dir',
    'tile plate fills',
    'tile-info #DCEAFB / success-surface #DCFCE7 / tile-accent #FBE0EC',
    'tileInfo.surface / success.surface (accent absent)',
    'token: 0 (DabblerNavigationIconTone info / success); accent tile = no feature',
  );
}

Map<String, _Exception> _pillExceptions(bool rtl) => rtl
    ? <String, _Exception>{
        'pill': _Exception(
          _kArabicType,
          _r(18, 772, 280.16, 56),
        ),
        'item Feeds (active)': _Exception(
          _kArabicType,
          _r(27, 778, 112.16, 44),
        ),
        'label Feeds (15/15 w500)': _Exception(
          _kArabicType,
          _r(77, 792.5, 44.16, 15),
        ),
        'item Venues': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(145.16, 778, 44, 44),
        ),
        'glyph Venues (linear 24)': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(155.16, 788, 24, 24),
        ),
        'item Games': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(195.16, 778, 44, 44),
        ),
        'glyph Games (linear 24)': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(205.16, 788, 24, 24),
        ),
        'item Meetups': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(245.16, 778, 44, 44),
        ),
        'glyph Meetups (linear 24)': _Exception(
          '$_kArabicType (shifts the items after it)',
          _r(255.16, 788, 24, 24),
        ),
      }
    : <String, _Exception>{};

Map<String, _Exception> _openExceptions(bool rtl) {
  // Three tiles, as the frame draws them: the meet-up tile is offered
  // whenever the flag is on (Alpha test build, CEO 2026-10-06), so the
  // two-column pins this map carried are gone.
  return <String, _Exception>{
    'fade wrapper (open)': _Exception(_kLineRounding, _r(0, 719, 393, 133)),
    'create menu card': _Exception(_kLineRounding, _r(18, 719, 289, 109)),
    'menu item 1 Create post': _Exception(_kLineRounding, _r(30, 731, 83, 85)),
    'menu item 2 Create game': _Exception(_kLineRounding, _r(121, 731, 83, 85)),
    'menu item 3 Create meetup': _Exception(
      _kLineRounding,
      _r(212, 731, 83, 85),
    ),
    'plate 1 (83x62)': _Exception(_kLineRounding, _r(30, 731, 83, 62)),
    'plate 2 (83x62)': _Exception(_kLineRounding, _r(121, 731, 83, 62)),
    'plate 3 (83x62)': _Exception(_kLineRounding, _r(212, 731, 83, 62)),
    'label 1 (12.5/15.63 w500)': rtl
        ? _Exception(_kLineRounding, _r(42.49, 800, 58.01, 16))
        : _Exception(_kLineRounding, _r(43.53, 800, 55.94, 16)),
  };
}
