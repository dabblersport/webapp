// KAN-998: the check-in row in the game and meetup details shows only for an
// eligible participant, and opens /check-in/:eventId.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_entry.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Repo implements AttendanceRepository {
  _Repo(this.state);
  final String state;
  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) async {
    final now = DateTime.now();
    return Ok(
      MyAttendance.fromJson({
        'state': state,
        'opens_at': now.toUtc().toIso8601String(),
        'closes_at': now
            .add(const Duration(minutes: 45))
            .toUtc()
            .toIso8601String(),
      }),
    );
  }

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) async =>
      const Ok(null);
}

Future<List<String>> _pump(WidgetTester t, String state) async {
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: CheckInEntry(eventId: 'e1')),
      ),
      GoRoute(
        path: '/check-in/:eventId',
        builder: (_, s) {
          pushed.add(s.uri.toString());
          return const SizedBox();
        },
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [attendanceRepositoryProvider.overrideWithValue(_Repo(state))],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return pushed;
}

void main() {
  testWidgets('an eligible player sees the row and it opens the screen', (
    t,
  ) async {
    final pushed = await _pump(t, 'open');
    expect(find.byKey(const ValueKey('check-in-entry')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('check-in-entry')));
    await t.pumpAndSettle();
    expect(pushed.single, RoutePaths.checkIn('e1'));
  });

  for (final s in ['not_eligible', 'closed', 'cancelled']) {
    testWidgets('no row when $s', (t) async {
      await _pump(t, s);
      expect(find.byKey(const ValueKey('check-in-entry')), findsNothing);
    });
  }
}
