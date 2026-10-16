// KAN-552: the Reports route gate and a source check that the message text is
// never logged, tracked, stored or copied. Fakes only; nothing real is called.
import 'dart:io';

import 'package:dabbler/features/admin/presentation/message_reports_route.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('messageReportsRedirect', () {
    Future<bool> yes() async => true;
    Future<bool> no() async => false;
    Future<bool> boom() async => throw StateError('rpc down');

    test('a non-admin is sent Home', () async {
      expect(
        await messageReportsRedirect(
          flagsOn: true,
          hasSession: true,
          isAdmin: no,
        ),
        RoutePaths.home,
      );
    });

    test(
      'flags off sends everyone Home, admin or not, without asking',
      () async {
        var asked = false;
        final r = await messageReportsRedirect(
          flagsOn: false,
          hasSession: true,
          isAdmin: () async {
            asked = true;
            return true;
          },
        );
        expect(r, RoutePaths.home);
        expect(asked, isFalse);
      },
    );

    test('no session goes to landing without asking', () async {
      var asked = false;
      final r = await messageReportsRedirect(
        flagsOn: true,
        hasSession: false,
        isAdmin: () async {
          asked = true;
          return true;
        },
      );
      expect(r, RoutePaths.landing);
      expect(asked, isFalse);
    });

    test('a failing admin check sends Home', () async {
      expect(
        await messageReportsRedirect(
          flagsOn: true,
          hasSession: true,
          isAdmin: boom,
        ),
        RoutePaths.home,
      );
    });

    test('only a confirmed admin with the flags on stays', () async {
      expect(
        await messageReportsRedirect(
          flagsOn: true,
          hasSession: true,
          isAdmin: yes,
        ),
        isNull,
      );
    });

    testWidgets(
      'a non-admin deep link lands on Home and the screen is never built',
      (tester) async {
        var built = false;
        final router = GoRouter(
          initialLocation: RoutePaths.adminMessageReports,
          routes: [
            GoRoute(
              path: RoutePaths.home,
              builder: (c, s) => const SizedBox(key: ValueKey('home')),
            ),
            GoRoute(
              path: RoutePaths.adminMessageReports,
              redirect: (c, s) => messageReportsRedirect(
                flagsOn: true,
                hasSession: true,
                isAdmin: () async => false,
              ),
              builder: (c, s) {
                built = true;
                return const SizedBox(key: ValueKey('reports'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          WidgetsApp.router(
            color: const Color(0xFFFFFFFF),
            routerConfig: router,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('home')), findsOneWidget);
        expect(find.byKey(const ValueKey('reports')), findsNothing);
        expect(built, isFalse);
      },
    );
  });

  group('the message text never leaves memory', () {
    // Every file KAN-552 adds that handles the text, plus the repository code
    // that parses it.
    const files = [
      'lib/features/admin/presentation/screens/message_reports_screen.dart',
      'lib/features/admin/presentation/widgets/reported_message_panel.dart',
      'lib/features/admin/presentation/providers/message_reports_providers.dart',
      'lib/features/admin/presentation/message_reports_route.dart',
      'lib/features/messaging/domain/message_reports_repository.dart',
      'lib/features/messaging/domain/models/reported_message.dart',
      'lib/features/messaging/domain/models/message_report.dart',
    ];
    const forbidden = [
      'print(',
      'debugPrint',
      'developer.log',
      'log(',
      'Logger',
      'Clipboard',
      'SharedPreferences',
      'FlutterSecureStorage',
      'Hive',
      'sqflite',
      'File(',
      'writeAs',
      'analytics',
      'Analytics',
      'Crashlytics',
      'Sentry',
      'FirebaseCrash',
      'SelectableText',
      'localStorage',
    ];

    for (final path in files) {
      test('$path has no logging, tracking, storage or clipboard call', () {
        final source = File(path).readAsStringSync();
        for (final token in forbidden) {
          expect(source.contains(token), isFalse, reason: '$path uses $token');
        }
      });
    }

    test(
      'the worker repository read path passes the text only into ReportedMessage',
      () {
        final source = File(
          'lib/features/messaging/data/worker_messaging_repository.dart',
        ).readAsStringSync();
        final start = source.indexOf(
          'Future<Result<ReportedMessage, Failure>> readReportedMessage',
        );
        final end = source.indexOf(
          'static MessageReportsFailure _reportsFailure',
        );
        final read = source.substring(start, end);
        for (final token in [
          'print(',
          'debugPrint',
          'log(',
          'Clipboard',
          'cause:',
        ]) {
          expect(
            read.contains(token),
            isFalse,
            reason: 'read path uses $token',
          );
        }
        expect(
          RegExp(r'\btext\b').allMatches(read).length,
          lessThanOrEqualTo(6),
        );
      },
    );
  });
}
