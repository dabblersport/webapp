/// KAN-596: bottom drawers slide the panel only; the scrim stays put and fades.
///
/// The DS route (`showDabblerSheet`) slides its whole page, scrim included.
/// [showAppSheet] must keep the scrim at y = 0 the whole time, fade its
/// opacity monotonically, and move only the panel. The "before" group runs the
/// same probe against the DS route to record the defect it replaces.
library;

import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Opener = Future<void> Function(BuildContext context, String body);

Future<void> openApp(BuildContext c, String body) => showAppSheet<void>(
  context: c,
  detent: DabblerSheetDetent.content,
  title: 'Sheet $body',
  builder: (_) => Text(body),
);

Future<void> openDs(BuildContext c, String body) => showDabblerSheet<void>(
  context: c,
  detent: DabblerSheetDetent.content,
  title: 'Sheet $body',
  builder: (_) => Text(body),
);

late BuildContext _host;

Future<void> pumpHost(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  TextDirection dir = TextDirection.ltr,
  bool disableAnimations = false,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: DabblerDesignSystemTheme.withTokens(
        ThemeData(brightness: brightness),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Directionality(textDirection: dir, child: child!),
      ),
      home: Builder(
        builder: (context) {
          _host = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
}

/// The scrim wash of the [index]-th sheet: the ColoredBox painted in the DS
/// scrim colour.
Finder scrim([int index = 0]) {
  final Color c = DabblerColors.of(_host).scrim;
  return find
      .byWidgetPredicate((w) => w is ColoredBox && w.color == c)
      .at(index);
}

double scrimOpacity([int index = 0]) {
  final FadeTransition f = find
      .ancestor(of: scrim(index), matching: find.byType(FadeTransition))
      .evaluate()
      .map((e) => e.widget as FadeTransition)
      .first;
  return f.opacity.value;
}

class Sample {
  Sample(this.t, this.scrimTop, this.opacity, this.panelTop);
  final int t;
  final double scrimTop;
  final double opacity;
  final double panelTop;
  @override
  String toString() =>
      't=${t}ms scrimTop=${scrimTop.toStringAsFixed(1)} '
      'opacity=${opacity.toStringAsFixed(3)} '
      'panelTop=${panelTop.toStringAsFixed(1)}';
}

Future<List<Sample>> sampleOpen(
  WidgetTester tester,
  Opener open, {
  String body = 'A',
}) async {
  open(_host, body);
  final List<Sample> out = <Sample>[];
  await tester.pump();
  for (int t = 0; t <= 400; t += 50) {
    out.add(
      Sample(
        t,
        tester.getTopLeft(scrim()).dy,
        scrimOpacity(),
        tester.getTopLeft(find.text(body)).dy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  return out;
}

void main() {
  group('before (DS showDabblerSheet) — records the defect', () {
    testWidgets('scrim is translated with the panel while opening', (
      tester,
    ) async {
      await pumpHost(tester);
      final s = await sampleOpen(tester, openDs);
      // ignore: avoid_print
      print('BEFORE ${s.join(' | ')}');
      expect(s.any((x) => x.scrimTop > 1), isTrue);
    });
  });

  group('after (showAppSheet)', () {
    testWidgets('open: scrim fixed at y=0, opacity rises from 0, panel rises', (
      tester,
    ) async {
      await pumpHost(tester);
      final s = await sampleOpen(tester, openApp);
      // ignore: avoid_print
      print('AFTER-OPEN ${s.join(' | ')}');
      for (final x in s) {
        expect(x.scrimTop, 0, reason: '$x');
      }
      expect(s.first.opacity, lessThan(0.05));
      for (int i = 1; i < s.length; i++) {
        expect(s[i].opacity, greaterThanOrEqualTo(s[i - 1].opacity));
        expect(s[i].panelTop, lessThanOrEqualTo(s[i - 1].panelTop));
      }
      expect(s.last.opacity, 1);
      expect(s.first.panelTop, greaterThan(s.last.panelTop + 20));
    });

    testWidgets('dismiss via scrim tap: scrim fades in place, panel slides', (
      tester,
    ) async {
      await pumpHost(tester);
      await sampleOpen(tester, openApp);
      final double restTop = tester.getTopLeft(find.text('A')).dy;
      await tester.tapAt(const Offset(200, 20));
      await tester.pump();
      final List<Sample> s = <Sample>[];
      for (int t = 0; t <= 400; t += 50) {
        if (find.text('A').evaluate().isEmpty) break;
        s.add(
          Sample(
            t,
            tester.getTopLeft(scrim()).dy,
            scrimOpacity(),
            tester.getTopLeft(find.text('A')).dy,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      // ignore: avoid_print
      print('AFTER-DISMISS ${s.join(' | ')}');
      for (final x in s) {
        expect(x.scrimTop, 0);
      }
      for (int i = 1; i < s.length; i++) {
        expect(s[i].opacity, lessThanOrEqualTo(s[i - 1].opacity));
      }
      expect(s.last.panelTop, greaterThan(restTop));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('dismiss via back (Navigator.maybePop)', (tester) async {
      await pumpHost(tester);
      await sampleOpen(tester, openApp);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('dismiss via drag on the handle', (tester) async {
      await pumpHost(tester);
      await sampleOpen(tester, openApp);
      final Offset handle =
          tester.getTopLeft(find.text('Sheet A')) - const Offset(0, 20);
      await tester.dragFrom(Offset(200, handle.dy), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('keyboard lifts the panel, not the scrim', (tester) async {
      await pumpHost(tester);
      await sampleOpen(tester, openApp);
      final double panelNoKb = tester.getBottomLeft(find.text('A')).dy;
      await pumpHost(tester, keyboard: 300);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(scrim()).dy, 0);
      final double panelKb = tester.getBottomLeft(find.text('A')).dy;
      // ignore: avoid_print
      print('KEYBOARD panel bottom $panelNoKb -> $panelKb, scrim top 0');
      expect(panelNoKb - panelKb, closeTo(300, 1));
    });

    testWidgets('nested sheet: both scrims stay at y=0', (tester) async {
      await pumpHost(tester);
      await sampleOpen(tester, openApp);
      openApp(_host, 'B');
      await tester.pump();
      for (int t = 0; t <= 400; t += 50) {
        expect(tester.getTopLeft(scrim(0)).dy, 0);
        expect(tester.getTopLeft(scrim(1)).dy, 0);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('reduced motion: no slide, still dismissible', (tester) async {
      await pumpHost(tester, disableAnimations: true);
      openApp(_host, 'A');
      await tester.pump();
      final double hidden = tester.getTopLeft(find.text('A')).dy;
      final List<double> tops = <double>[];
      for (int t = 0; t < 10; t++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(find.text('A')).dy);
        expect(tester.getTopLeft(scrim()).dy, 0);
      }
      // ignore: avoid_print
      print('REDUCED hidden=$hidden tops=$tops');
      // A cut, not a slide: every sampled frame is at rest.
      expect(tops.toSet().length, 1);
      expect(tops.first, lessThan(hidden));
      expect(tester.getTopLeft(scrim()).dy, 0);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    for (final (Brightness b, TextDirection d) in [
      (Brightness.dark, TextDirection.ltr),
      (Brightness.light, TextDirection.rtl),
      (Brightness.dark, TextDirection.rtl),
    ]) {
      testWidgets('renders in $b / $d with a fixed scrim', (tester) async {
        await pumpHost(tester, brightness: b, dir: d);
        final s = await sampleOpen(tester, openApp);
        expect(s.every((x) => x.scrimTop == 0), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
