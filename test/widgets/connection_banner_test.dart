import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/widgets/connection_banner.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivity extends ConnectivityNotifier {
  _FakeConnectivity(ConnectionStatus s)
    : super(
        changes: const Stream<List<ConnectivityResult>>.empty(),
        check: () async => <ConnectivityResult>[],
      ) {
    state = s;
  }
}

Widget _host({
  required ConnectionStatus status,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  Key? key,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withTokens(
      ThemeData(brightness: brightness),
    ),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Column(
        children: <Widget>[
          const SizedBox(key: Key('chip'), height: 40),
          ConnectionBanner(key: key, status: status),
          const SizedBox(key: Key('tabs'), height: 48),
        ],
      ),
    ),
  );
}

const String _en = 'No internet connection – offline mode';
const String _enPoor = 'Poor connection – updates may be slow';

void main() {
  testWidgets('offline shows the error banner between chip and tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_host(status: ConnectionStatus.offline));
    await tester.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    final double chipBottom = tester
        .getBottomLeft(find.byKey(const Key('chip')))
        .dy;
    final double bannerTop = tester.getTopLeft(find.byType(DabblerBanner)).dy;
    final double bannerBottom = tester
        .getBottomLeft(find.byType(DabblerBanner))
        .dy;
    final double tabsTop = tester.getTopLeft(find.byKey(const Key('tabs'))).dy;
    expect(bannerTop, greaterThanOrEqualTo(chipBottom));
    // Bottom spacing 12 sits between the banner and the tabs: in flow, no overlay.
    expect(tabsTop - bannerBottom, 12);
    final DabblerBanner b = tester.widget(find.byType(DabblerBanner));
    expect(b.tone, DabblerBannerTone.error);
    expect(b.onDismiss, isNull);
    expect(b.action, isNull);
  });

  testWidgets('poor shows the warning banner', (tester) async {
    await tester.pumpWidget(_host(status: ConnectionStatus.poor));
    await tester.pumpAndSettle();
    expect(find.text(_enPoor), findsOneWidget);
    expect(
      tester.widget<DabblerBanner>(find.byType(DabblerBanner)).tone,
      DabblerBannerTone.warning,
    );
  });

  testWidgets('online has no footprint and no semantics', (tester) async {
    await tester.pumpWidget(_host(status: ConnectionStatus.online));
    await tester.pumpAndSettle();
    final double chipBottom = tester
        .getBottomLeft(find.byKey(const Key('chip')))
        .dy;
    final double tabsTop = tester.getTopLeft(find.byKey(const Key('tabs'))).dy;
    expect(tabsTop, chipBottom);
    expect(find.bySemanticsLabel(_en), findsNothing);
  });

  testWidgets('reconnect collapses smoothly over 220ms, keeping the content', (
    tester,
  ) async {
    await tester.pumpWidget(_host(status: ConnectionStatus.offline));
    await tester.pumpAndSettle();
    final double full = tester.getTopLeft(find.byKey(const Key('tabs'))).dy;
    await tester.pumpWidget(_host(status: ConnectionStatus.online));
    await tester.pump(const Duration(milliseconds: 100));
    final double mid = tester.getTopLeft(find.byKey(const Key('tabs'))).dy;
    expect(mid, lessThan(full));
    expect(mid, greaterThan(40));
    // Last visible content is still there while collapsing.
    expect(find.text(_en), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('tabs'))).dy, 40);
    // Once collapsed the notice is gone from the tree, not just hidden.
    expect(find.byType(DabblerBanner), findsNothing);
  });

  testWidgets('reduced motion collapses at once', (tester) async {
    await tester.pumpWidget(
      _host(status: ConnectionStatus.offline, reduceMotion: true),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _host(status: ConnectionStatus.online, reduceMotion: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.getTopLeft(find.byKey(const Key('tabs'))).dy, 40);
  });

  testWidgets('does not block taps on the tabs', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const ConnectionBanner(status: ConnectionStatus.offline),
              GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(
                  key: Key('tabs'),
                  color: Color(0x00000000),
                  child: SizedBox(height: 48, width: 200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tabs')));
    expect(taps, 1);
  });

  testWidgets('screen reader gets one polite live label', (tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await tester.pumpWidget(_host(status: ConnectionStatus.offline));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(_en), findsOneWidget);
    h.dispose();
  });

  testWidgets('RTL: Arabic text, icon on the start (right) side', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(status: ConnectionStatus.offline, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    const String ar = 'لا يوجد اتصال بالإنترنت – وضع عدم الاتصال';
    expect(find.text(ar), findsOneWidget);
    final double iconX = tester.getCenter(find.byType(DabblerIcon)).dx;
    final double textX = tester.getCenter(find.text(ar)).dx;
    expect(iconX, greaterThan(textX));
    // And poor, in Arabic.
    await tester.pumpWidget(
      _host(status: ConnectionStatus.poor, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('الاتصال ضعيف – قد يتأخر التحديث'), findsOneWidget);
  });

  testWidgets('dark theme renders both states', (tester) async {
    for (final ConnectionStatus s in <ConnectionStatus>[
      ConnectionStatus.offline,
      ConnectionStatus.poor,
    ]) {
      await tester.pumpWidget(_host(status: s, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.byType(DabblerBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reads the KAN-603 provider when no status is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith(
            (ref) => _FakeConnectivity(ConnectionStatus.offline),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ConnectionBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
  });

  test('icons resolve in the design system', () {
    for (final String n in <String>['cloud-cross', 'wifi']) {
      expect(
        DabblerIconRegistry.resolve(n, weight: DabblerIconWeight.bold).outcome,
        DabblerIconOutcome.resolved,
      );
    }
  });

  test('Home mounts the banner under the header, above reminders and tabs', () {
    final String src = File(
      'lib/features/home/presentation/screens/home_screen.dart',
    ).readAsStringSync();
    final int banner = src.indexOf('const ConnectionBanner()');
    expect(banner, isNonNegative);
    expect(banner, lessThan(src.indexOf('const HomeUpcoming()')));
    expect(banner, lessThan(src.indexOf('DabblerTabPager(')));
  });
}
