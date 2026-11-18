// KAN-1003: the inbox row's security answers run the KAN-985 RPCs ("Not me"
// then opens the password change), a refusal is never success, and no
// security kind offers a mute, EN and AR.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler/features/security/data/security_repository.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notif_row_support.dart';
import 'security_fakes.dart';

void main() {
  (NotifActionHandler, List<String>) handler(FakeSecurityRepo repo) {
    final opened = <String>[];
    final c = ProviderContainer(
      overrides: [securityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final p = Provider<NotifActionHandler>(
      (ref) => SupabaseNotifActionHandler(
        ref,
        SupabaseClient('http://localhost', 'test'),
        open: opened.add,
      ),
    );
    return (c.read(p), opened);
  }

  final row = notif(
    'security.new_signin',
    payload: {'entity_type': 'security_sign_in', 'entity_id': 's1'},
  );

  test('This was me confirms; Not me signs out and opens password', () async {
    final repo = FakeSecurityRepo(const []);
    final (h, opened) = handler(repo);
    expect(
      (await h.run(NotificationActionId.thisWasMe, row)).status,
      NotifActionStatus.success,
    );
    expect(opened, isEmpty);
    expect(
      (await h.run(NotificationActionId.notMe, row)).status,
      NotifActionStatus.success,
    );
    expect(repo.calls, <String>['confirm:s1', 'notMe:s1']);
    expect(opened, <String>[RoutePaths.settingsAccountPassword]);
  });

  test('a refusal is failed or already, never success', () async {
    final repo = FakeSecurityRepo(const [])
      ..answerFail = const Failure(code: '42501');
    final (h, opened) = handler(repo);
    expect(
      (await h.run(NotificationActionId.thisWasMe, row)).status,
      NotifActionStatus.failed,
    );
    repo.answerFail = const Failure(code: '22023');
    expect(
      (await h.run(NotificationActionId.notMe, row)).status,
      NotifActionStatus.alreadyHandled,
    );
    expect(opened, isEmpty);
    expect(
      (await h.run(
        NotificationActionId.notMe,
        notif('security.new_signin'),
      )).status,
      NotifActionStatus.failed,
    );
  });

  for (final locale in kLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('no security kind offers a mute — $dir', (tester) async {
      final (l, _) = await pumpRows(tester, [
        notif('security.new_signin', id: 'a'),
        notif('security.password_changed', id: 'b'),
        notif('security.email_changed', id: 'c'),
      ], locale: locale);
      for (final id in const ['a', 'b', 'c']) {
        await tester.tap(
          inRow(id, find.byKey(const ValueKey('notif-card-menu'))),
        );
        await tester.pump();
        final card = tester.widget<DabblerNotificationCard>(
          inRow(id, find.byType(DabblerNotificationCard)),
        );
        expect(
          card.menu!.map((m) => m.label),
          isNot(contains(l.notif_menu_mute_kind)),
        );
        await tester.tap(
          inRow(id, find.byKey(const ValueKey('notif-card-menu'))),
        );
        await tester.pump();
      }
      expect(find.byType(DabblerToggle), findsNothing);
    });
  }
}
