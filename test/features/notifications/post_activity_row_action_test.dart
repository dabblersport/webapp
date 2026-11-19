// The post-activity row ("How did <game> go? ...") inline actions.
// Root cause: the server writes `event_id` into `args`, not `context`; the
// handler read only `context`, failed with `no_target`, and the row showed
// "Check your connection". Server refusals now read as refused (no Retry);
// only network failures keep the connection copy.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_row.dart';
import 'package:dabbler/features/post_activity/data/post_activity_repository.dart'
    show postActivityRepositoryProvider;
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../post_activity/post_activity_fakes.dart';
import 'notif_row_support.dart';

const _kind = 'activity.post_activity';
const _game = 'ce49dd33-5187-4b5b-b531-a9b48136dc85';

/// The row exactly as the server writes it (context has no event_id).
final _row = notif(
  _kind,
  title: 'How did Not-ended test game go?',
  payload: const {'entity_id': _game, 'entity_type': 'game'},
  args: const {'title': 'Not-ended test game', 'event_id': _game},
);

void main() {
  group('live handler', () {
    late FakePostRepo repo;
    late List<String> opened;
    late NotifActionHandler handler;

    setUp(() {
      repo = FakePostRepo(
        flowValue: flowOf(RatingFlowState.notStarted),
        tally: const Err(Failure()),
      );
      opened = <String>[];
      final h = Provider<NotifActionHandler>(
        (ref) => SupabaseNotifActionHandler(
          ref,
          SupabaseClient('http://localhost', 'anon'),
          open: opened.add,
        ),
      );
      final c = ProviderContainer(
        overrides: [postActivityRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      handler = c.read(h);
    });

    test(
      'Enter score opens the post-activity flow (event_id in args)',
      () async {
        final o = await handler.run(NotificationActionId.enterScore, _row);
        expect(o.status, NotifActionStatus.opened);
        expect(opened, [
          RoutePaths.postActivity(_game, title: 'Not-ended test game'),
        ]);
      },
    );

    test('Dismiss reaches the server with the args event id', () async {
      final o = await handler.run(NotificationActionId.dismissRating, _row);
      expect(o.status, NotifActionStatus.success);
      expect(repo.calls.single, startsWith('dismiss'));
    });

    test('a server refusal is refused, not a connection failure', () async {
      repo.failure = const Failure(code: 'not_ended');
      final o = await handler.run(NotificationActionId.dismissRating, _row);
      expect(o.status, NotifActionStatus.refused);
      expect(o.detail, 'not_ended');
    });

    test('a network failure keeps the connection copy (failed)', () async {
      repo.failure = const Failure(category: FailureCode.noInternet);
      expect(
        (await handler.run(NotificationActionId.dismissRating, _row)).status,
        NotifActionStatus.failed,
      );
      repo.failure = const Failure(category: FailureCode.timeout);
      expect(
        (await handler.run(NotificationActionId.dismissRating, _row)).status,
        NotifActionStatus.failed,
      );
    });

    test('no event id at all is refused', () async {
      final o = await handler.run(
        NotificationActionId.enterScore,
        notif(_kind, payload: const {}),
      );
      expect(o.status, NotifActionStatus.refused);
      expect(opened, isEmpty);
    });
  });

  group('row', () {
    testWidgets('opened: the row stays, actions still offered', (tester) async {
      final h = FakeNotifActions(outcome: NotifActionOutcome.opened);
      final (l, _) = await pumpRows(tester, [_row], handler: h);
      await tester.tap(find.text(l.notif_action_enter_score));
      await tester.pumpAndSettle();
      expect(h.calls, ['run:enterScore:n1']);
      expect(find.text(l.notif_res_failed), findsNothing);
      expect(find.text(l.notif_res_unavailable), findsNothing);
      expect(find.text(l.notif_action_enter_score), findsOneWidget);
    });

    testWidgets('refused: accurate copy, no Retry', (tester) async {
      final h = FakeNotifActions(
        outcome: const NotifActionOutcome(NotifActionStatus.refused, 'x'),
      );
      final (l, _) = await pumpRows(tester, [_row], handler: h);
      await tester.tap(find.text(l.notif_action_enter_score));
      await tester.pumpAndSettle();
      expect(find.text(l.notif_res_refused), findsOneWidget);
      expect(find.text(l.notif_res_failed), findsNothing);
      expect(find.text(l.notif_res_retry), findsNothing);
    });

    testWidgets('failed (network): connection copy with Retry', (tester) async {
      final h = FakeNotifActions(
        outcome: const NotifActionOutcome(NotifActionStatus.failed, 'net'),
      );
      final (l, _) = await pumpRows(tester, [_row], handler: h);
      await tester.tap(find.text(l.notif_action_enter_score));
      await tester.pumpAndSettle();
      expect(find.text(l.notif_res_failed), findsOneWidget);
      expect(find.text(l.notif_res_retry), findsOneWidget);
    });

    testWidgets('Retry has a real DefaultTextStyle without a Scaffold', (
      tester,
    ) async {
      final h = FakeNotifActions(
        outcome: const NotifActionOutcome(NotifActionStatus.failed, 'net'),
      );
      // No Scaffold / Material above the row, as in the Center shell.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notifActionHandlerProvider.overrideWithValue(h),
            myProfileIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
            home: SingleChildScrollView(
              child: NotificationRow(notification: _row, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(NotificationRow)),
      );
      await tester.tap(find.text(l.notif_action_enter_score));
      await tester.pumpAndSettle();
      final link = find.text(l.notif_res_retry);
      expect(link, findsOneWidget);
      final inherited = DefaultTextStyle.of(tester.element(link)).style;
      expect(inherited.decorationStyle, isNot(TextDecorationStyle.double));
      expect(inherited.decorationColor, isNot(const Color(0xFFFFFF00)));
    });
  });
}
