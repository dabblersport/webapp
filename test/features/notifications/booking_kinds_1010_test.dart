// KAN-1010 (W4-1, F-12): the booking and payment kinds are in the registry
// with their EN and AR templates, and their cards stay hidden behind
// FeatureFlags.bookingNotifications (off). With the flag off nothing shows:
// no card, no chip match, no pop-up, no Booking chip, category or settings
// row. With it on (in a test), every booking and payment card renders in EN
// and AR.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/feedback/notification_popup_rules.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/domain/notification_kind_bodies.dart';
import 'package:dabbler/features/notifications/domain/notification_kind_titles.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notif_row_support.dart';

const List<String> _bookingKinds = <String>[
  'booking.pending',
  'booking.confirmed',
  'booking.rejected',
  'booking.hold_expiring',
  'booking.changed',
  'booking.cancelled',
  'venue.feedback_request',
  'payment.pending',
  'payment.succeeded',
  'payment.failed',
  'refund.processing',
  'refund.completed',
  'refund.failed',
];

const Map<String, dynamic> _args = <String, dynamic>{
  'venue': 'Zayed Sports City',
  'slot': 'Thu 7:00 PM',
  'when': 'in 15 minutes',
  'old': '7:00 PM',
  'new': '8:00 PM',
  'amount': 'AED 120',
};

AppNotification _row(String kind, int i) => AppNotification(
  id: 'b$i',
  toUserId: 'me',
  kindKey: kind,
  title: 'Server title',
  args: _args,
  schemaVersion: 2,
  createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
);

void main() {
  tearDown(
    () => NotificationKinds.bookingCardsEnabled =
        FeatureFlags.bookingNotifications,
  );

  group('registry', () {
    test('the flag is off by default', () {
      expect(FeatureFlags.bookingNotifications, isFalse);
      expect(NotificationKinds.bookingCardsEnabled, isFalse);
    });

    test('13 booking kinds: category booking, inactive, no route, no CTA', () {
      for (final k in _bookingKinds) {
        final s = NotificationKinds.of(k);
        expect(s, isNotNull, reason: k);
        expect(s!.category, NotificationCategory.booking, reason: k);
        expect(s.active, isFalse, reason: k);
        expect(s.ctas, isEmpty, reason: k);
        expect(s.needsAction, isFalse, reason: k);
        expect(NotificationKinds.route(k, const {'entity_id': 'x'}), isNull);
        expect(NotificationKinds.isBookingKind(k), isTrue);
      }
    });

    test('breaks quiet: the hold, a change and a cancellation (I-3)', () {
      final quiet = {
        for (final k in _bookingKinds)
          if (NotificationKinds.of(k)!.breaksQuiet) k,
      };
      expect(quiet, {
        'booking.hold_expiring',
        'booking.changed',
        'booking.cancelled',
      });
    });

    test('arena.payment_required: inactive, an alias of payment.pending', () {
      final s = NotificationKinds.of('arena.payment_required')!;
      expect(s.active, isFalse);
      expect(s.aliasOf, 'payment.pending');
      expect(NotificationKinds.isBookingKind('arena.payment_required'), isTrue);
    });

    test('templates in EN and AR fill every argument', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      String a(String name) => '${_args[name]}';
      for (final k in _bookingKinds) {
        for (final l in [en, ar]) {
          final t = notificationTitleTemplate(l, k, a);
          final b = notificationBodyTemplate(l, k, a);
          expect(t, isNotNull, reason: k);
          expect(b, isNotNull, reason: k);
          expect('$t $b', isNot(contains('{')), reason: k);
        }
      }
      expect(
        notificationTitleTemplate(en, 'booking.confirmed', a),
        'Booking confirmed by Zayed Sports City',
      );
      expect(
        notificationBodyTemplate(en, 'booking.changed', a),
        'Was 7:00 PM, now 8:00 PM.',
      );
    });
  });

  group('flag off: nothing shows', () {
    test('under no chip, and no Booking chip, category or settings row', () {
      for (final k in _bookingKinds) {
        final n = _row(k, 0);
        expect(NotificationKinds.isShown(k), isFalse, reason: k);
        for (final chip in NotificationChip.values) {
          expect(
            NotificationKinds.inChip(chip, n),
            isFalse,
            reason: '$k $chip',
          );
        }
      }
      expect(
        NotificationChip.values.map((c) => c.name),
        isNot(contains('booking')),
      );
      expect(NotifCategoryKey.shown, isNot(contains(NotifCategoryKey.booking)));
      // Other kinds are not affected.
      expect(NotificationKinds.isShown('game.updated'), isTrue);
    });

    test('no pop-up', () {
      expect(
        decideNotificationPopup(
          n: _row('payment.failed', 0),
          location: '/home',
          now: DateTime(2026, 11, 18, 12),
          foreground: true,
          settings: NotificationSettings.defaults('me'),
        ),
        NotificationPopupDecision.hiddenKind,
      );
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('no card — ${locale.languageCode}', (tester) async {
        await pumpRows(tester, [
          for (var i = 0; i < _bookingKinds.length; i++)
            _row(_bookingKinds[i], i),
          _row('arena.payment_required', 99),
        ], locale: locale);
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerNotificationCard), findsNothing);
      });
    }
  });

  group('flag on: every card renders', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('13 cards — ${locale.languageCode}', (tester) async {
        NotificationKinds.bookingCardsEnabled = true;
        final rows = [
          for (var i = 0; i < _bookingKinds.length; i++)
            _row(_bookingKinds[i], i),
        ];
        final (l, _) = await pumpRows(tester, rows, locale: locale);
        expect(tester.takeException(), isNull);
        expect(
          find.byType(DabblerNotificationCard),
          findsNWidgets(_bookingKinds.length),
        );
        String a(String name) => '${_args[name]}';
        for (var i = 0; i < rows.length; i++) {
          final c = tester.widget<DabblerNotificationCard>(
            inRow('b$i', find.byType(DabblerNotificationCard)),
          );
          final line = '${c.actor} ${c.verb}'.replaceAll(RegExp(r'\s+'), ' ');
          final want = notificationTitleTemplate(
            l,
            rows[i].kindKey,
            a,
          )!.replaceAll(RegExp(r'\s+'), ' ');
          expect(line.trim(), want.trim(), reason: rows[i].kindKey);
          expect(c.actions, isEmpty, reason: rows[i].kindKey);
        }
        expect(
          NotificationKinds.inChip(NotificationChip.all, rows.first),
          isTrue,
        );
      });
    }
  });
}
