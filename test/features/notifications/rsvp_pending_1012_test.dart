// KAN-1012: Going from a notification on a request-policy meetup comes back
// `pending`; the row says the request was sent, never "You're going".
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notif_row_support.dart';

void main() {
  test('rpc pending maps to requested, going to plain success', () {
    expect(notifRsvpOutcome('pending').isRequested, isTrue);
    expect(notifRsvpOutcome('going').isRequested, isFalse);
    expect(notifRsvpOutcome('going').status, NotifActionStatus.success);
    expect(notifRsvpOutcome(null).isRequested, isFalse);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('going answered pending shows Request sent — '
        '${locale.languageCode}', (tester) async {
      final h = FakeNotifActions(outcome: NotifActionOutcome.requested);
      final soon = DateTime.now().add(const Duration(hours: 4));
      final (l, _) = await pumpRows(
        tester,
        [
          notif(
            'meetup.confirm_attendance',
            id: 'g',
            payload: {
              'title': 'Run',
              'time': '6:30 PM',
              'entity_id': 'm1',
              'start_at': soon.toUtc().toIso8601String(),
            },
          ),
        ],
        locale: locale,
        handler: h,
      );
      await tester.tap(
        find.descendant(
          of: rowOf('g'),
          matching: find.text(l.notif_action_going),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<DabblerNotificationCard>(
        inRow('g', find.byType(DabblerNotificationCard)),
      );
      expect(card.result!.text, l.listing_request_sent);
      expect(card.result!.text, isNot(l.notif_res_going));
    });
  }
}
