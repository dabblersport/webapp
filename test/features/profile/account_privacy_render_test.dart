import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/account_management_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_settings_screen.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import 'settings_render_support.dart';

class _FakePrivacy extends PrivacyController {
  _FakePrivacy(PrivacyState initial) {
    state = initial;
  }
}

List<Override> _overrides(
  PrivacyState state, {
  List<Map<String, dynamic>> blocked = const [],
}) => [
  currentUserIdProvider.overrideWithValue(null),
  privacyControllerProvider.overrideWith((ref) => _FakePrivacy(state)),
  blockedUsersWithProfilesProvider.overrideWith((ref) async => blocked),
];

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadSettingsFonts();
  });

  const tall = Size(393, 1100);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final bool ar = locale.languageCode == 'ar';
    final String dir = ar ? 'rtl' : 'ltr';

    String t(String en, String arabic) => ar ? arabic : en;

    testWidgets('account screen — $dir', (tester) async {
      await pumpSettings(
        tester,
        const AccountManagementScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(t('Sign-in', 'تسجيل الدخول')), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNWidgets(2));
      expect(find.text(t('Delete account', 'حذف الحساب')), findsOneWidget);
      await shootSettings(tester, 'account-default-$dir');
    });

    testWidgets('account email sheet — $dir', (tester) async {
      await pumpSettings(
        tester,
        const AccountManagementScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(find.text(t('Email address', 'البريد الإلكتروني')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsOneWidget);
      expect(find.byType(DabblerButton), findsOneWidget);
      await shootSettings(tester, 'account-email-sheet-$dir');
    });

    testWidgets('account password sheet — $dir', (tester) async {
      await pumpSettings(
        tester,
        const AccountManagementScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(find.text(t('Password', 'كلمة المرور')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      // No session: the account has no password yet, so the form is the "set"
      // form — a new password and its confirmation.
      expect(find.byType(DabblerTextField), findsNWidgets(2));
      await shootSettings(tester, 'account-password-sheet-$dir');
    });

    testWidgets('account delete sheet — $dir', (tester) async {
      await pumpSettings(
        tester,
        const AccountManagementScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(find.text(t('Delete account', 'حذف الحساب')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsOneWidget);
      expect(find.byType(DabblerButton), findsNWidgets(2));
      await shootSettings(tester, 'account-delete-sheet-$dir');
    });

    testWidgets('privacy hub — $dir', (tester) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        size: const Size(393, 1500),
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerPresetCard), findsNWidgets(3));
      expect(find.byType(DabblerRowHint), findsOneWidget);
      await shootSettings(tester, 'privacy-hub-$dir');
    });

    testWidgets('privacy loading — $dir', (tester) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        overrides: _overrides(const PrivacyState(isLoading: true)),
      );
      expect(find.byType(DabblerSpinner), findsOneWidget);
    });

    testWidgets('privacy profile page, switch makes the preset custom — $dir', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(find.text(t('Profile & identity', 'الملف والهوية')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerToggle), findsNWidgets(8));
      await shootSettings(tester, 'privacy-profile-$dir');

      await tester.tap(find.byType(DabblerToggle).first);
      await settleSettings(tester);
      // Back to the hub: the preset the switch broke is now Custom.
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(find.byType(DabblerPresetCard), findsNWidgets(4));
      await shootSettings(tester, 'privacy-hub-custom-$dir');
    });

    testWidgets('privacy contact page and audience sheet — $dir', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(
        find.text(t('Who can contact you', 'من يمكنه التواصل معك')),
      );
      await settleSettings(tester);
      await shootSettings(tester, 'privacy-contact-$dir');
      await tester.tap(find.text(t('Direct messages', 'الرسائل المباشرة')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(t('No one', 'لا أحد')), findsOneWidget);
      await shootSettings(tester, 'privacy-contact-sheet-$dir');
    });

    testWidgets('privacy blocked page — $dir', (tester) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        size: tall,
        overrides: _overrides(
          const PrivacyState(settings: PrivacySettings()),
          blocked: const [
            {
              'user_id': 'b1',
              'display_name': 'Youssef El Khatib',
              'username': 'youssef.elkhatib',
            },
            {
              'user_id': 'b2',
              'display_name': 'Priya Nair',
              'username': 'priya.nair.dxb',
            },
          ],
        ),
      );
      await tester.tap(find.text(t('Blocked accounts', 'الحسابات المحظورة')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(t('Unblock', 'إلغاء الحظر')), findsNWidgets(2));
      await shootSettings(tester, 'privacy-blocked-$dir');
    });

    testWidgets('privacy blocked page, empty — $dir', (tester) async {
      await pumpSettings(
        tester,
        const PrivacySettingsScreen(),
        locale,
        size: tall,
        overrides: _overrides(const PrivacyState(settings: PrivacySettings())),
      );
      await tester.tap(find.text(t('Blocked accounts', 'الحسابات المحظورة')));
      await settleSettings(tester);
      expect(find.byType(DabblerRowHint), findsOneWidget);
      await shootSettings(tester, 'privacy-blocked-empty-$dir');
    });
  }
}
