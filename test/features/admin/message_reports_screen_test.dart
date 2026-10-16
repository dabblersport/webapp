// KAN-552: the admin-only Reports screen. FAKES ONLY: a fake messaging
// repository seeded with three message reports, a fake admin check and fake
// flags. Nothing real is called. Each scenario runs in LTR and RTL and at 200
// percent text scale.
import 'package:dabbler/features/admin/presentation/providers/message_reports_providers.dart';
import 'package:dabbler/features/admin/presentation/screens/message_reports_screen.dart';
import 'package:dabbler/features/admin/presentation/screens/moderation_queue_screen.dart'
    show isAdminProvider;
import 'package:dabbler/features/admin/presentation/screens/safety_overview_screen.dart';
import 'package:dabbler/features/admin/presentation/widgets/reported_message_panel.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/message_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

// Clearly-fake fixtures.
const _id1 = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _id2 = '22222222-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _id3 = '33333333-cccc-4ccc-8ccc-cccccccccccc';
const _secret1 = 'FAKE-REPORTED-TEXT-ONE';
const _secret2 = 'FAKE-REPORTED-TEXT-TWO';
const _secret3 = 'FAKE-REPORTED-TEXT-THREE';

/// Seeded out of order; the fake returns them newest first.
List<MessageReport> _seed() => [
  MessageReport(
    reportId: _id2,
    reason: 'abuse',
    createdAt: DateTime.utc(2026, 10, 14, 9),
    status: 'triage',
  ),
  MessageReport(
    reportId: _id1,
    reason: 'spam',
    createdAt: DateTime.utc(2026, 10, 15, 9),
    status: 'open',
  ),
  MessageReport(
    reportId: _id3,
    reason: 'scam',
    createdAt: DateTime.utc(2026, 10, 13, 9),
    status: 'resolved',
  ),
];

const _texts = {_id1: _secret1, _id2: _secret2, _id3: _secret3};

FakeMessagingRepository _repo() =>
    FakeMessagingRepository()..seedMessageReports(_seed(), texts: _texts);

Widget _app(
  FakeMessagingRepository repo,
  _Variant v, {
  bool admin = true,
  bool flagsOn = true,
  Widget? home,
  List<GoRoute> extraRoutes = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => home ?? const MessageReportsScreen(),
      ),
      ...extraRoutes,
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messageReportsRepositoryProvider.overrideWithValue(repo),
      messageReportsFlagsProvider.overrideWithValue((
        messaging: flagsOn,
        reporting: flagsOn,
      )),
      isAdminProvider.overrideWith((ref) async => admin),
      safetyOverviewProvider.overrideWith(
        (ref) async => SafetyOverview(
          reportsOpen: 1,
          activeEnforcements: 0,
          takedownsActive: 0,
          audits24h: 0,
          asOf: DateTime(2026, 10, 15, 8),
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
      builder: (context, child) => DabblerToastProvider(
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(v.scale)),
          child: child!,
        ),
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
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

  for (final v in _variants) {
    final l10n = lookupAppLocalizations(v.locale);

    group('[${v.name}]', () {
      testWidgets(
        'a non-admin never sees the screen and nothing is requested',
        (tester) async {
          final repo = _repo();
          await tester.pumpWidget(_app(repo, v, admin: false));
          await _settle(tester);
          expect(find.byType(DabblerPage), findsNothing);
          expect(find.byType(DabblerCard), findsNothing);
          expect(find.text(l10n.admin_message_reports_title), findsNothing);
          expect(repo.messageReportsListCalls, 0);
          expect(repo.reportedMessageReads, isEmpty);
        },
      );

      testWidgets('an admin with the flags off sees nothing either', (
        tester,
      ) async {
        final repo = _repo();
        await tester.pumpWidget(_app(repo, v, flagsOn: false));
        await _settle(tester);
        expect(find.byType(DabblerPage), findsNothing);
        expect(repo.messageReportsListCalls, 0);
      });

      testWidgets('loading shows a spinner, then the rows newest first', (
        tester,
      ) async {
        final repo = _repo()..messageReportsDelay = const Duration(seconds: 2);
        await tester.pumpWidget(_app(repo, v));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byKey(MessageReportsScreen.loadingKey), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        expect(find.byKey(MessageReportsScreen.loadingKey), findsNothing);

        final tops = [
          for (final id in [_id1, _id2, _id3])
            tester.getTopLeft(find.byKey(MessageReportsScreen.rowKey(id))).dy,
        ];
        expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
        // Id-only rows: the short id, reason, status; no text, no names.
        expect(
          find.text(l10n.admin_message_reports_report_id('11111111')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.admin_message_reports_status_open),
          findsOneWidget,
        );
        expect(find.textContaining('FAKE-REPORTED'), findsNothing);
        expect(find.textContaining(_id1), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an empty list says there are no message reports', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMessageReports(const []);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        expect(find.byKey(MessageReportsScreen.emptyKey), findsOneWidget);
        expect(find.text(l10n.admin_message_reports_empty), findsOneWidget);
      });

      testWidgets('a failed list shows an error and Retry reloads it', (
        tester,
      ) async {
        final repo = _repo()
          ..failNextMessageReportsList(MessageReportsRefusal.failed);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        expect(find.byKey(MessageReportsScreen.errorKey), findsOneWidget);
        expect(find.byKey(MessageReportsScreen.rowKey(_id1)), findsNothing);
        await _tap(tester, find.text(l10n.admin_message_reports_retry));
        expect(find.byKey(MessageReportsScreen.errorKey), findsNothing);
        expect(find.byKey(MessageReportsScreen.rowKey(_id1)), findsOneWidget);
        expect(repo.messageReportsListCalls, 2);
      });

      testWidgets(
        'Read this message: one read per tap with the right id, the text only in the panel, cleared on close',
        (tester) async {
          final repo = _repo();
          await tester.pumpWidget(_app(repo, v));
          await _settle(tester);
          expect(repo.reportedMessageReads, isEmpty); // no auto-read
          expect(find.text(_secret1), findsNothing);

          await _tap(tester, find.byKey(MessageReportsScreen.readKey(_id1)));
          expect(repo.reportedMessageReads, [_id1]);
          expect(find.byKey(ReportedMessagePanelKeys.sheet), findsOneWidget);
          expect(find.text(_secret1), findsOneWidget);
          expect(find.text(_secret2), findsNothing);
          // The text is not selectable (no copy affordance).
          expect(find.byType(SelectableText), findsNothing);

          await _tap(tester, find.byKey(ReportedMessagePanelKeys.close));
          expect(find.byKey(ReportedMessagePanelKeys.sheet), findsNothing);
          expect(find.text(_secret1), findsNothing);
          expect(repo.reportedMessageReads, [_id1]); // closing reads nothing

          // Again: a second tap fetches again, for the row tapped.
          await _tap(tester, find.byKey(MessageReportsScreen.readKey(_id1)));
          expect(repo.reportedMessageReads, [_id1, _id1]);
          await _tap(tester, find.byKey(ReportedMessagePanelKeys.close));
          await _tap(tester, find.byKey(MessageReportsScreen.readKey(_id2)));
          expect(repo.reportedMessageReads, [_id1, _id1, _id2]);
          expect(find.text(_secret2), findsOneWidget);
          expect(find.text(_secret1), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      for (final c
          in <(MessageReportsRefusal, String Function(AppLocalizations))>[
            (
              MessageReportsRefusal.notAModerator,
              (l) => l.admin_message_reports_refusal_not_moderator,
            ),
            (
              MessageReportsRefusal.notFound,
              (l) => l.admin_message_reports_refusal_not_found,
            ),
            (
              MessageReportsRefusal.rateLimited,
              (l) => l.admin_message_reports_refusal_rate_limited,
            ),
            (
              MessageReportsRefusal.failed,
              (l) => l.admin_message_reports_refusal_failed,
            ),
          ]) {
        testWidgets(
          'a ${c.$1.name} refusal shows a plain message and no text',
          (tester) async {
            final repo = _repo()..failNextReportedMessageRead(c.$1);
            await tester.pumpWidget(_app(repo, v));
            await _settle(tester);
            await _tap(tester, find.byKey(MessageReportsScreen.readKey(_id1)));
            expect(repo.reportedMessageReads, [_id1]);
            expect(find.byKey(MessageReportsScreen.refusalKey), findsOneWidget);
            expect(find.text(c.$2(l10n)), findsOneWidget);
            expect(find.byKey(ReportedMessagePanelKeys.sheet), findsNothing);
            expect(find.textContaining('FAKE-REPORTED'), findsNothing);
            // The next tap clears the refusal and reads again.
            await _tap(tester, find.byKey(MessageReportsScreen.readKey(_id1)));
            expect(find.byKey(MessageReportsScreen.refusalKey), findsNothing);
            expect(find.text(_secret1), findsOneWidget);
          },
        );
      }
    });
  }

  group('entry row in the safety overview', () {
    Future<void> overview(
      WidgetTester tester,
      _Variant v, {
      required bool admin,
      required bool flagsOn,
      List<String>? pushed,
    }) async {
      await tester.pumpWidget(
        _app(
          _repo(),
          v,
          admin: admin,
          flagsOn: flagsOn,
          home: const SafetyOverviewScreen(),
          extraRoutes: [
            GoRoute(
              path: RoutePaths.adminMessageReports,
              builder: (c, s) {
                pushed?.add(s.uri.path);
                return const SizedBox(key: ValueKey('reports-route'));
              },
            ),
          ],
        ),
      );
      await _settle(tester);
    }

    for (final v in _variants.take(2)) {
      testWidgets(
        '[${v.name}] an admin with the flags on sees the row and it opens the route',
        (tester) async {
          final pushed = <String>[];
          await overview(tester, v, admin: true, flagsOn: true, pushed: pushed);
          final row = find.byKey(messageReportsEntryKey);
          expect(row, findsOneWidget);
          await _tap(tester, row);
          expect(pushed, [RoutePaths.adminMessageReports]);
        },
      );

      testWidgets('[${v.name}] no row for a non-admin or with the flags off', (
        tester,
      ) async {
        await overview(tester, v, admin: false, flagsOn: true);
        expect(find.byKey(messageReportsEntryKey), findsNothing);
        await overview(tester, v, admin: true, flagsOn: false);
        expect(find.byKey(messageReportsEntryKey), findsNothing);
      });
    }
  });
}
