import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/admin/presentation/screens/moderation_queue_screen.dart';
import 'package:dabbler/features/admin/presentation/screens/safety_overview_screen.dart';
import 'package:dabbler/features/misc/presentation/screens/transactions_parts.dart';
import 'package:dabbler/features/misc/presentation/screens/transactions_screen.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Writes PNGs only with `--dart-define=MISC_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('MISC_SHOTS_DIR');

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
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

final List<ModerationReportSummary> _reports = [
  ModerationReportSummary(
    reportId: 'rep-1',
    status: ReportStatus.open,
    reason: ReportReason.spam,
    createdAt: DateTime(2026, 9, 30, 14, 5),
    targetType: ModTarget.post,
    targetId: 'post-8812',
    details: 'Repeated promotional links in every comment.',
  ),
  ModerationReportSummary(
    reportId: 'rep-2',
    status: ReportStatus.escalated,
    reason: ReportReason.hate,
    createdAt: DateTime(2026, 9, 29, 9, 40),
    targetType: ModTarget.user,
    targetId: 'user-31',
  ),
];

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  const locales = <String, Locale>{'ltr': Locale('en'), 'rtl': Locale('ar')};

  for (final entry in locales.entries) {
    final dir = entry.key;
    final locale = entry.value;

    testWidgets('moderation queue renders ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const ModerationQueueScreen(),
        locale,
        key,
        overrides: [
          isAdminProvider.overrideWith((ref) async => true),
          moderationQueueProvider.overrideWith((ref) async => _reports),
        ],
      );
      expect(find.text('Moderation Queue'), findsOneWidget);
      expect(find.text('Take Action'), findsNWidgets(2));
      expect(find.text('Dismiss'), findsNWidgets(2));
      await _shoot(tester, key, 'moderation-queue-$dir');
    });

    testWidgets('safety overview renders ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const SafetyOverviewScreen(),
        locale,
        key,
        overrides: [
          isAdminProvider.overrideWith((ref) async => true),
          safetyOverviewProvider.overrideWith(
            (ref) async => SafetyOverview(
              reportsOpen: 12,
              activeEnforcements: 4,
              takedownsActive: 2,
              audits24h: 37,
              asOf: DateTime(2026, 10, 1, 8, 30),
            ),
          ),
        ],
      );
      expect(find.text('Overview Information'), findsOneWidget);
      expect(find.text('37'), findsNWidgets(2));
      await _shoot(tester, key, 'safety-overview-$dir');
    });

    testWidgets('report dialog renders ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const ReportDialog(targetType: ReportTargetType.post, targetId: 'p1'),
        locale,
        key,
      );
      await tester.tap(find.text('Harassment'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Report post'), findsOneWidget);
      await _shoot(tester, key, 'report-dialog-$dir');
    });

    testWidgets('transactions renders ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const DabblerPage(body: TransactionsHistoryView()),
        locale,
        key,
      );
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Court Booking'), findsOneWidget);
      await _shoot(tester, key, 'transactions-$dir');
    });

    testWidgets('transactions empty renders ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const DabblerPage(body: TransactionsHistoryView()),
        locale,
        key,
      );
      await tester.enterText(find.byType(EditableText), 'zzz');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('No transactions found'), findsOneWidget);
      await _shoot(tester, key, 'transactions-empty-$dir');
    });
  }

  testWidgets('transactions signed out shows sign-in prompt', (tester) async {
    await initHomeTestSupabase();
    final key = GlobalKey();
    await _pump(tester, const TransactionsScreen(), const Locale('en'), key);
    expect(find.text('Sign in to view transactions'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
