import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/admin/presentation/admin_message_reports_route.dart';
import 'package:dabbler/features/admin/presentation/providers/admin_message_reports_providers.dart';
import 'package:dabbler/features/admin/presentation/screens/admin_message_reports_screen.dart';
import 'package:dabbler/features/admin/presentation/screens/moderation_queue_screen.dart';
import 'package:dabbler/features/admin/presentation/screens/safety_overview_screen.dart';
import 'package:dabbler/features/admin/presentation/widgets/admin_reported_message_panel.dart';
import 'package:dabbler/features/messaging/data/fake_moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

// KAN-552. Everything is a fake: no network, no Supabase.
typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

const _fakeText = 'FAKE reported message text for KAN-552';
final _boundary = GlobalKey();

List<ReportRow> _seed() => [
  ReportRow(
    reportId: '11111111-0000-4000-8000-000000000001',
    reason: 'spam',
    createdAt: DateTime.utc(2026, 10, 13, 9),
    status: 'resolved',
    targetMessageId: 'm1',
  ),
  ReportRow(
    reportId: '33333333-0000-4000-8000-000000000003',
    reason: 'harassment',
    createdAt: DateTime.utc(2026, 10, 15, 9),
    status: 'open',
    targetMessageId: 'm3',
  ),
  ReportRow(
    reportId: '22222222-0000-4000-8000-000000000002',
    reason: 'scam',
    createdAt: DateTime.utc(2026, 10, 14, 9),
    status: 'triage',
    targetMessageId: 'm2',
  ),
];

const _newest = '33333333-0000-4000-8000-000000000003';

FakeModerationReportsRepository _repo() => FakeModerationReportsRepository()
  ..seedReports(_seed())
  ..seedBody(_newest, _fakeText);

Widget _app(
  FakeModerationReportsRepository repo,
  _Variant v, {
  bool admin = true,
  bool enabled = true,
  String initial = RoutePaths.adminMessageReports,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (c, s) => const SizedBox(key: ValueKey('home')),
      ),
      GoRoute(
        path: RoutePaths.adminSafetyOverview,
        builder: (c, s) => const SafetyOverviewScreen(),
      ),
      adminMessageReportsRoute(
        hasSession: () => true,
        enabled: () => enabled,
        isAdmin: () async => admin,
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      moderationReportsRepositoryProvider.overrideWithValue(repo),
      adminMessageReportsFlagsProvider.overrideWithValue((
        messaging: enabled,
        reporting: enabled,
      )),
      isAdminProvider.overrideWith((ref) async => admin),
      safetyOverviewProvider.overrideWith(
        (ref) async => SafetyOverview(
          reportsOpen: 1,
          activeEnforcements: 0,
          takedownsActive: 0,
          audits24h: 0,
          asOf: DateTime.utc(2026, 10, 15),
        ),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: v.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: v.locale,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(v.scale)),
        child: RepaintBoundary(key: _boundary, child: child),
      ),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan552/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Navigator).first));

Future<void> _tapRead(WidgetTester tester, String id) async {
  final f = find.byKey(AdminMessageReportsScreen.readKey(id));
  await tester.ensureVisible(f);
  await tester.tap(f);
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('redirect', () {
    test('no session -> landing; flags off or non-admin -> home', () async {
      Future<String?> r({bool s = true, bool e = true, bool a = true}) =>
          adminMessageReportsRedirect(
            hasSession: s,
            enabled: e,
            isAdmin: () async => a,
          );
      expect(await r(s: false), RoutePaths.landing);
      expect(await r(e: false), RoutePaths.home);
      expect(await r(a: false), RoutePaths.home);
      expect(await r(), isNull);
      expect(
        await adminMessageReportsRedirect(
          hasSession: true,
          enabled: true,
          isAdmin: () async => throw Exception('rpc'),
        ),
        RoutePaths.home,
      );
    });
  });

  for (final v in _variants) {
    group('[${v.name}]', () {
      testWidgets('non-admin: deep link lands Home, no overview row', (
        tester,
      ) async {
        final repo = _repo();
        await tester.pumpWidget(_app(repo, v, admin: false));
        await _settle(tester);
        expect(find.byKey(const ValueKey('home')), findsOneWidget);
        expect(find.byType(AdminMessageReportsScreen), findsNothing);
        expect(repo.listCalls, 0);

        await tester.pumpWidget(
          _app(repo, v, admin: false, initial: RoutePaths.adminSafetyOverview),
        );
        await _settle(tester);
        expect(
          find.byKey(SafetyOverviewScreen.messageReportsRowKey),
          findsNothing,
        );
        // The screen itself draws nothing for a non-admin.
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              isAdminProvider.overrideWith((ref) async => false),
              adminMessageReportsFlagsProvider.overrideWithValue((
                messaging: true,
                reporting: true,
              )),
              moderationReportsRepositoryProvider.overrideWithValue(repo),
            ],
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: AdminMessageReportsScreen(),
            ),
          ),
        );
        await _settle(tester);
        expect(find.byType(DabblerPage), findsNothing);
        expect(repo.listCalls, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('flags off: admin gets no row and no screen', (tester) async {
        final repo = _repo();
        await tester.pumpWidget(
          _app(
            repo,
            v,
            enabled: false,
            initial: RoutePaths.adminSafetyOverview,
          ),
        );
        await _settle(tester);
        expect(
          find.byKey(SafetyOverviewScreen.messageReportsRowKey),
          findsNothing,
        );
        await tester.pumpWidget(_app(repo, v, enabled: false));
        await _settle(tester);
        expect(find.byKey(const ValueKey('home')), findsOneWidget);
      });

      testWidgets('admin: overview row opens Reports', (tester) async {
        final repo = _repo();
        await tester.pumpWidget(
          _app(repo, v, initial: RoutePaths.adminSafetyOverview),
        );
        await _settle(tester);
        final row = find.byKey(SafetyOverviewScreen.messageReportsRowKey);
        await tester.scrollUntilVisible(
          row,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _settle(tester);
        await _shot(tester, 'overview-row-${v.name}');
        await tester.tap(row);
        await _settle(tester);
        expect(find.byType(AdminMessageReportsScreen), findsOneWidget);
        expect(find.byKey(AdminMessageReportsScreen.listKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('loading shows skeleton rows', (tester) async {
        final repo = _repo()..listDelay = const Duration(seconds: 2);
        await tester.pumpWidget(_app(repo, v));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(AdminMessageReportsScreen.loadingKey),
          findsOneWidget,
        );
        expect(find.byType(DabblerSkeleton), findsWidgets);
        await _shot(tester, 'loading-${v.name}');
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        expect(find.byKey(AdminMessageReportsScreen.listKey), findsOneWidget);
      });

      testWidgets('empty state', (tester) async {
        final repo = FakeModerationReportsRepository();
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.byKey(AdminMessageReportsScreen.emptyKey), findsOneWidget);
        expect(
          find.text(l10n.admin_message_reports_empty_title),
          findsOneWidget,
        );
        await _shot(tester, 'empty-${v.name}');
      });

      testWidgets('error with Retry; Retry reloads', (tester) async {
        final repo = _repo()
          ..failNextList(MessagingFailure(reason: MessagingReason.offline));
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.byKey(AdminMessageReportsScreen.errorKey), findsOneWidget);
        await _shot(tester, 'error-${v.name}');
        expect(repo.listCalls, 1);
        await tester.tap(find.text(l10n.admin_message_reports_error_retry));
        await _settle(tester);
        expect(repo.listCalls, 2);
        expect(find.byKey(AdminMessageReportsScreen.listKey), findsOneWidget);
      });

      testWidgets('populated: newest first, ids/reason/time/status only', (
        tester,
      ) async {
        final repo = _repo();
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        await _shot(tester, 'populated-${v.name}');
        final rows = tester
            .widgetList<DabblerListRow>(
              find.byType(DabblerListRow, skipOffstage: false),
            )
            .toList();
        expect(rows.map((r) => r.overline).toList(), [
          l10n.admin_message_reports_row_id('33333333'),
          l10n.admin_message_reports_row_id('22222222'),
          l10n.admin_message_reports_row_id('11111111'),
        ]);
        expect(rows.first.title, l10n.admin_message_reports_reason_harassment);
        expect(
          rows.first.subtitle,
          adminReportTime(DateTime.utc(2026, 10, 15, 9), v.locale.languageCode),
        );
        expect(
          find.text(l10n.admin_message_reports_status_open),
          findsOneWidget,
        );
        expect(find.textContaining('FAKE'), findsNothing);
        expect(repo.readCalls, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Read: one call per tap, panel only, cleared on close', (
        tester,
      ) async {
        final repo = _repo()..readDelay = const Duration(milliseconds: 300);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        await _tapRead(tester, _newest);
        await tester.pump();
        // A second tap while the first is in flight is ignored.
        await tester.tap(
          find.byKey(AdminMessageReportsScreen.readKey(_newest)),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(
          find.byKey(AdminReportedMessagePanel.loadingKey),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(repo.readCalls, 1);
        expect(repo.readIds, [_newest]);
        expect(find.byKey(AdminReportedMessagePanel.bodyKey), findsOneWidget);
        expect(find.text(_fakeText), findsOneWidget);
        // Not in the list behind the panel.
        expect(
          find.descendant(
            of: find.byKey(AdminMessageReportsScreen.listKey),
            matching: find.text(_fakeText),
          ),
          findsNothing,
        );
        await _shot(tester, 'panel-${v.name}');
        final close = find.byKey(AdminReportedMessagePanel.closeKey);
        await tester.ensureVisible(close);
        await tester.tap(close);
        await _settle(tester);
        expect(find.text(_fakeText), findsNothing);
        expect(find.byType(AdminReportedMessagePanel), findsNothing);
        // Reopening fetches again.
        await _tapRead(tester, _newest);
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(repo.readCalls, 2);
        expect(find.text(_fakeText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      final refusals = <String, Failure Function()>{
        'not_a_moderator': () => NotAModeratorFailure(),
        'not_found': () =>
            MessagingFailure(reason: MessagingReason.notFound, httpStatus: 404),
        'rate_limited': () => MessagingFailure(
          reason: MessagingReason.rateLimited,
          httpStatus: 429,
        ),
      };
      for (final e in refusals.entries) {
        testWidgets('refusal ${e.key}: plain message, no text', (tester) async {
          final repo = _repo()..failReads(e.value());
          await tester.pumpWidget(_app(repo, v));
          await _settle(tester);
          final l10n = _l10n(tester);
          await _tapRead(tester, _newest);
          await _settle(tester);
          final expected = switch (e.key) {
            'not_a_moderator' =>
              l10n.admin_message_reports_refusal_not_a_moderator,
            'not_found' => l10n.admin_message_reports_refusal_not_found,
            _ => l10n.admin_message_reports_refusal_rate_limited,
          };
          expect(find.text(expected), findsOneWidget);
          expect(find.byKey(AdminReportedMessagePanel.bodyKey), findsNothing);
          expect(find.text(_fakeText), findsNothing);
          expect(repo.readCalls, 1);
          await _shot(tester, 'refusal-${e.key}-${v.name}');
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
