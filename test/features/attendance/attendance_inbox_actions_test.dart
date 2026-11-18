// KAN-999: the inbox's attendance actions run through the live handler —
// Request review opens the no-show screen; Accept / Keep decide the review
// for the player the server named. A missing id fails, never succeeds.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notif_row_support.dart' show notif;
import 'attendance_review_fakes.dart';

void main() {
  late FakeReviewRepo repo;
  late List<String> opened;
  late ProviderContainer c;
  late NotifActionHandler handler;

  setUp(() {
    repo = FakeReviewRepo();
    opened = <String>[];
    final h = Provider<NotifActionHandler>(
      (ref) => SupabaseNotifActionHandler(
        ref,
        SupabaseClient('http://localhost', 'anon'),
        open: opened.add,
      ),
    );
    c = ProviderContainer(
      overrides: [attendanceReviewRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    handler = c.read(h);
  });

  const review = 'activity.review_requested';
  final full = <String, dynamic>{'event_id': 'e1', 'player_user_id': 'p1'};

  test('Request review opens the no-show screen', () async {
    final o = await handler.run(
      NotificationActionId.requestReview,
      notif('activity.no_show_pending', payload: {'event_id': 'e1'}),
    );
    expect(o.status, NotifActionStatus.success);
    expect(opened, [RoutePaths.noShow('e1')]);
  });

  test('Request review without event_id fails and opens nothing', () async {
    final o = await handler.run(
      NotificationActionId.requestReview,
      notif('activity.no_show_pending', payload: const {}),
    );
    expect(o.status, NotifActionStatus.failed);
    expect(opened, isEmpty);
  });

  test('Accept decides accept for the named player', () async {
    final o = await handler.run(
      NotificationActionId.accept,
      notif(review, payload: full),
    );
    expect(o.status, NotifActionStatus.success);
    expect(repo.calls, ['decide:p1:accept']);
  });

  test('Keep decides keep for the named player', () async {
    final o = await handler.run(
      NotificationActionId.keepDecision,
      notif(review, payload: full),
    );
    expect(o.status, NotifActionStatus.success);
    expect(repo.calls, ['decide:p1:keep']);
  });

  for (final missing in ['event_id', 'player_user_id']) {
    test('Accept / Keep without $missing fail without a call', () async {
      final p = Map<String, dynamic>.from(full)..remove(missing);
      for (final a in [
        NotificationActionId.accept,
        NotificationActionId.keepDecision,
      ]) {
        final o = await handler.run(a, notif(review, payload: p));
        expect(o.status, NotifActionStatus.failed);
      }
      expect(repo.calls, isEmpty);
    });
  }

  test('a decided review is already handled; another refusal fails', () async {
    repo.decideFailure = const Failure(code: 'no_open_review');
    expect(
      (await handler.run(
        NotificationActionId.accept,
        notif(review, payload: full),
      )).status,
      NotifActionStatus.alreadyHandled,
    );
    repo.decideFailure = const Failure(code: 'not_organiser');
    expect(
      (await handler.run(
        NotificationActionId.keepDecision,
        notif(review, payload: full),
      )).status,
      NotifActionStatus.failed,
    );
  });

  test('refusal text is per RPC', () {
    final l = AppLocalizationsEn();
    String t(AttendanceCall call, String code) =>
        attendanceRefusalText(l, call, Failure(code: code), 'fallback');
    expect(
      t(AttendanceCall.decide, 'no_open_review'),
      l.g06_err_already_decided,
    );
    expect(t(AttendanceCall.decide, 'invalid_decision'), 'fallback');
    expect(t(AttendanceCall.decide, 'attendance_finalized'), 'fallback');
    expect(
      t(AttendanceCall.finalize, 'event_did_not_happen'),
      l.g05_err_did_not_happen,
    );
    expect(t(AttendanceCall.correct, 'event_did_not_happen'), 'fallback');
    expect(
      t(AttendanceCall.correct, 'attendance_finalized'),
      l.g05_err_finalized,
    );
    expect(
      t(AttendanceCall.requestReview, 'review_window_closed'),
      l.g06_err_closed,
    );
    expect(t(AttendanceCall.requestReview, 'not_organiser'), 'fallback');
  });

  for (final (code, reloads) in [
    ('no_open_review', true),
    ('attendance_finalized', true),
    ('not_organiser', false),
  ]) {
    test('a $code refusal ${reloads ? 'reloads' : 'keeps'} the list', () async {
      repo.listResult = Ok(AttendanceList(rows: const [], closesAt: kNow));
      final ctrl = AttendanceListController(repo, 'e1');
      await Future<void>.delayed(Duration.zero);
      final before = repo.listCalls;
      repo.decideFailure = Failure(code: code);
      final f = await ctrl.decide('p1', accept: true);
      expect(f?.code, code);
      expect(repo.listCalls - before, reloads ? 1 : 0);
      ctrl.dispose();
    });
  }
}
