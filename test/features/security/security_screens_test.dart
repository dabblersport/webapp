// KAN-1003 (W2-F6): every state of the security review and the sign-in list,
// EN and AR. New sign-in: device, time, approximate city; "This was me" ->
// resolved; "Secure my account" -> that device signed out, password change
// opened. Password and email change: time, "Wasn't you? Secure your
// account". The list: this device marked, others with Sign out (one device).
// A refusal never shows success; a double tap sends one call; no mute or
// toggle exists for security notices.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/activities/domain/activity_last_sign_in.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_security_footer.dart';
import 'package:dabbler/features/activities/domain/activity_log_time.dart';
import 'package:dabbler/features/security/data/security_repository.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/features/security/presentation/security_review_screen.dart';
import 'package:dabbler/features/security/presentation/sign_ins_controller.dart';
import 'package:dabbler/features/security/presentation/sign_ins_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'security_fakes.dart';

void _noop() {}

Widget _review(String id) => SecurityReviewScreen(
  kind: SecurityNoticeKind.newSignIn,
  signInId: id,
  onBack: _noop,
);

const Widget _list = SignInsScreen(onBack: _noop);

Finder get _passwordOpened => byKey('at:${RoutePaths.settingsAccountPassword}');

void main() {
  test('ledger rows parse; kinds parse from key and wire', () {
    final s = SecuritySignIn.fromJson(<String, dynamic>{
      'id': 'a',
      'device_label': 'Chrome on macOS',
      'signed_in_at': '2026-11-18T05:12:00Z',
      'state': 'new',
      'place_city': 'Dubai',
      'place_country': null,
      'is_current': false,
      'is_active': true,
    });
    expect(s.state, SignInState.newDevice);
    expect(s.place, 'Dubai');
    expect(s.isActive, isTrue);
    expect(SignInState.parse('secured'), SignInState.secured);
    expect(
      SecurityNoticeKind.parse('security.email_changed'),
      SecurityNoticeKind.emailChanged,
    );
    expect(
      SecurityNoticeKind.parse('password_changed'),
      SecurityNoticeKind.passwordChanged,
    );
  });

  test('a double tap sends one call', () async {
    final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')])
      ..gate = Completer<void>();
    final c = ProviderContainer(
      overrides: [securityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(signInsProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    final ctrl = c.read(signInsProvider.notifier);
    final first = ctrl.notMe('s1');
    final second = await ctrl.confirm('s1');
    expect(second?.code, 'busy');
    repo.gate!.complete();
    expect(await first, isNull);
    expect(repo.calls.where((x) => x != 'load'), <String>['notMe:s1']);
  });

  for (final locale in kLocales) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;
    final ar = tag == 'ar';
    String iso(String s) => ar ? '\u2068$s\u2069' : s;
    String clock(DateTime t, bool h24) => DabblerType.toWesternDigits(
      formatActivityClock(t, use24h: h24, locale: l.localeName),
    );

    testWidgets('[$tag] new sign-in: device, time, city; This was me', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')]);
      await pumpSecurity(tester, repo, _review('s1'), locale: locale);
      expect(byKey('security-new'), findsOneWidget);
      expect(text(iso('iPhone 15')), findsOneWidget);
      expect(text(clock(DateTime(2026, 11, 18, 9, 12), false)), findsOneWidget);
      expect(text(l.sec6_place_unknown), findsNothing);
      expect(text(l.sec6_secure), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNothing);

      await tester.tap(text(l.notif_action_this_was_me));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'confirm:s1');
      expect(byKey('security-confirmed'), findsOneWidget);
      expect(text(l.sec6_confirmed), findsWidgets);
      expect(text(l.sec6_secure), findsNothing);
    });

    testWidgets('[$tag] a known city shows; 24h clock follows the device', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[
        signIn('s1', city: 'Dubai', at: DateTime(2026, 11, 18, 17, 5)),
      ]);
      await pumpSecurity(
        tester,
        repo,
        _review('s1'),
        locale: locale,
        use24h: true,
      );
      expect(text(iso('Dubai')), findsOneWidget);
      expect(text(clock(DateTime(2026, 11, 18, 17, 5), true)), findsOneWidget);
      expect(text(l.sec6_place_unknown), findsNothing);
    });

    testWidgets('[$tag] a known other device: resolved, no buttons', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[
        signIn('s1', state: SignInState.known),
      ]);
      await pumpSecurity(tester, repo, _review('s1'), locale: locale);
      expect(byKey('security-known'), findsOneWidget);
      expect(text(l.sec6_known), findsOneWidget);
      expect(text(l.notif_action_this_was_me), findsNothing);
      expect(text(l.sec6_secure), findsNothing);
    });

    testWidgets('[$tag] Secure my account: that device out, password opens', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')]);
      await pumpSecurity(tester, repo, _review('s1'), locale: locale);
      await tester.tap(text(l.sec6_secure));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'notMe:s1');
      expect(_passwordOpened, findsOneWidget);
    });

    testWidgets('[$tag] a refusal never shows success', (tester) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')])
        ..answerFail = const Failure(code: '42501');
      await pumpSecurity(tester, repo, _review('s1'), locale: locale);
      await tester.tap(text(l.notif_action_this_was_me));
      await tester.pumpAndSettle();
      expect(byKey('security-confirmed'), findsNothing);
      expect(byKey('security-new'), findsOneWidget);
      expect(text(l.sec6_confirm_elsewhere), findsOneWidget);

      repo.answerFail = const Failure(code: 'XX000');
      await tester.tap(text(l.sec6_secure));
      await tester.pumpAndSettle();
      expect(_passwordOpened, findsNothing);
      expect(byKey('security-secured'), findsNothing);
      expect(text(l.sec6_failed), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] while sending: no actions, one call', (tester) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')])
        ..gate = Completer<void>();
      await pumpSecurity(tester, repo, _review('s1'), locale: locale);
      await tester.tap(text(l.notif_action_this_was_me));
      await tester.pump();
      expect(text(l.sec6_sending), findsOneWidget);
      expect(text(l.notif_action_this_was_me), findsNothing);
      expect(text(l.sec6_secure), findsNothing);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.calls.where((x) => x != 'load'), <String>['confirm:s1']);
    });

    testWidgets('[$tag] resolved, secured and this-device states', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[
        signIn('c', state: SignInState.confirmed),
        signIn('x', state: SignInState.secured, active: false),
        signIn('me', current: true),
      ]);
      await pumpSecurity(tester, repo, _review('c'), locale: locale);
      expect(byKey('security-confirmed'), findsOneWidget);
      expect(text(l.notif_action_this_was_me), findsNothing);

      await pumpSecurity(tester, repo, _review('x'), locale: locale);
      expect(byKey('security-secured'), findsOneWidget);
      expect(text(l.sec6_secured), findsWidgets);
      await tester.tap(text(l.sec6_change_password));
      await tester.pumpAndSettle();
      expect(_passwordOpened, findsOneWidget);

      await pumpSecurity(tester, repo, _review('me'), locale: locale);
      expect(byKey('security-current'), findsOneWidget);
      expect(text(l.sec6_current_note), findsOneWidget);
      expect(text(l.sec6_secure), findsNothing);
      // No "signed out every other device" copy and no Face ID anywhere.
      expect(text('every other device'), findsNothing);
      expect(text('Face ID'), findsNothing);
    });

    testWidgets('[$tag] not found and load error', (tester) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[signIn('s1')]);
      await pumpSecurity(tester, repo, _review('gone'), locale: locale);
      expect(text(l.sec6_not_found), findsOneWidget);

      final bad = FakeSecurityRepo(const <SecuritySignIn>[])
        ..loadFail = const Failure(code: 'net');
      await pumpSecurity(tester, bad, _review('s1'), locale: locale);
      expect(text(l.sec6_load_failed), findsOneWidget);
      bad
        ..loadFail = null
        ..rows = <SecuritySignIn>[signIn('s1')];
      await tester.tap(text(l.feed_retry));
      await tester.pumpAndSettle();
      expect(byKey('security-new'), findsOneWidget);
    });

    for (final kind in <SecurityNoticeKind>[
      SecurityNoticeKind.passwordChanged,
      SecurityNoticeKind.emailChanged,
    ]) {
      testWidgets('[$tag] ${kind.wire}: time and Secure your account', (
        tester,
      ) async {
        final repo = FakeSecurityRepo(const <SecuritySignIn>[]);
        await pumpSecurity(
          tester,
          repo,
          SecurityReviewScreen(
            kind: kind,
            changedAt: DateTime(2026, 11, 18, 9, 12),
            onBack: _noop,
          ),
          locale: locale,
        );
        expect(byKey('security-${kind.wire}'), findsOneWidget);
        expect(
          text(
            kind == SecurityNoticeKind.passwordChanged
                ? l.sec_t_security_password_changed
                : l.sec_t_security_email_changed,
          ),
          findsOneWidget,
        );
        expect(
          text(clock(DateTime(2026, 11, 18, 9, 12), false)),
          findsOneWidget,
        );
        expect(text(l.notif_action_this_was_me), findsNothing);
        expect(find.byType(DabblerToggle), findsNothing);
        await tester.tap(text(l.sec6_wasnt_you));
        await tester.pumpAndSettle();
        expect(_passwordOpened, findsOneWidget);
        expect(repo.calls.where((x) => x != 'load'), isEmpty);
      });
    }

    testWidgets('[$tag] list: this device marked, others listed, sign out', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[
        signIn('me', device: 'Dabbler app', current: true),
        signIn('o', device: 'Chrome on macOS'),
        signIn('old', device: 'Safari on iOS', active: false),
      ]);
      await pumpSecurity(tester, repo, _list, locale: locale);
      expect(text(l.sec6_active), findsOneWidget);
      expect(text(l.sec6_recent), findsOneWidget);
      expect(text(l.sec6_this_device), findsOneWidget);
      expect(text(iso('Safari on iOS')), findsOneWidget);
      expect(text(l.sec6_always_on), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNothing);
      // Only the other live device can be signed out.
      expect(find.text(l.sec6_sign_out), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('sign-in-me'),
          matching: find.text(l.sec6_sign_out),
        ),
        findsNothing,
      );

      await tester.tap(find.text(l.sec6_sign_out));
      await tester.pumpAndSettle();
      expect(repo.calls.where((x) => x != 'load'), <String>['notMe:o']);
      expect(
        find.descendant(
          of: byKey('sign-in-o'),
          matching: text(l.sec6_signed_out),
        ),
        findsOneWidget,
      );
      expect(find.text(l.sec6_sign_out), findsNothing);
      // This device stays signed in; no password screen from the list.
      expect(byKey('sign-in-me'), findsOneWidget);
      expect(_passwordOpened, findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] list: a refused sign out stays signed in', (
      tester,
    ) async {
      final repo = FakeSecurityRepo(<SecuritySignIn>[
        signIn('me', current: true),
        signIn('o', device: 'Chrome on macOS'),
      ])..answerFail = const Failure(code: 'XX000');
      await pumpSecurity(tester, repo, _list, locale: locale);
      await tester.tap(find.text(l.sec6_sign_out));
      await tester.pumpAndSettle();
      expect(text(l.sec6_signed_out), findsNothing);
      expect(find.text(l.sec6_sign_out), findsOneWidget);
      expect(text(l.sec6_failed), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] list: empty and load error', (tester) async {
      await pumpSecurity(
        tester,
        FakeSecurityRepo(const <SecuritySignIn>[]),
        _list,
        locale: locale,
      );
      expect(text(l.sec6_empty), findsOneWidget);
      final bad = FakeSecurityRepo(const <SecuritySignIn>[])
        ..loadFail = const Failure(code: 'net');
      await pumpSecurity(tester, bad, _list, locale: locale);
      expect(text(l.sec6_load_failed), findsOneWidget);
    });

    testWidgets('[$tag] Activity log security card links to the list', (
      tester,
    ) async {
      await pumpSecurity(
        tester,
        FakeSecurityRepo(const <SecuritySignIn>[]),
        const SingleChildScrollView(child: ActivitySecurityFooter()),
        locale: locale,
        overrides: <Override>[
          activityLastSignInProvider.overrideWith(
            (ref) async => ActivityLastSignIn(
              at: DateTime(2026, 11, 18, 9, 12),
              device: 'iPhone 15',
            ),
          ),
        ],
      );
      expect(byKey('activity-security-card'), findsOneWidget);
      expect(text(iso('iPhone 15')), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNothing);
      await tester.tap(text(l.sec6_review_sign_ins));
      await tester.pumpAndSettle();
      expect(byKey('at:${RoutePaths.securitySignIns}'), findsOneWidget);
    });
  }
}
