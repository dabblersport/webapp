import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/account_management_screen.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import 'settings_render_support.dart';

/// Stores what the server "has"; a save either succeeds or fails.
class _AutosavePrivacy extends PrivacyController {
  _AutosavePrivacy(this.stored) {
    state = PrivacyState(settings: stored);
  }

  PrivacySettings stored;
  bool failSave = false;
  int saves = 0;
  int reloads = 0;

  @override
  Future<void> loadPrivacySettings(String userId) async {
    reloads++;
    state = state.copyWith(settings: stored, hasUnsavedChanges: false);
  }

  @override
  Future<bool> saveAllChanges(String userId) async {
    saves++;
    if (failSave) {
      state = state.copyWith(errorMessage: 'offline');
      return false;
    }
    stored = state.settings!;
    state = state.copyWith(hasUnsavedChanges: false);
    return true;
  }
}

Future<_AutosavePrivacy> _pump(WidgetTester tester) async {
  final fake = _AutosavePrivacy(const PrivacySettings());
  await pumpSettings(
    tester,
    const AccountManagementScreen(),
    const Locale('en'),
    size: const Size(393, 1100),
    overrides: [
      currentUserIdProvider.overrideWithValue('user-1'),
      privacyControllerProvider.overrideWith((ref) => fake),
      blockedUsersWithProfilesProvider.overrideWith((ref) async => const []),
    ],
  );
  return fake;
}

bool _checked(WidgetTester tester, int index) =>
    tester.widget<DabblerToggle>(find.byType(DabblerToggle).at(index)).checked;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadSettingsFonts();
  });

  testWidgets('a toggle saves at once and keeps the new value', (tester) async {
    final fake = await _pump(tester);
    await settleSettings(tester);
    final before = _checked(tester, 0);
    final loads = fake.reloads;

    await tester.tap(find.byType(DabblerToggle).at(0));
    await settleSettings(tester);

    expect(fake.saves, 1, reason: 'the save callback fires on toggle');
    expect(_checked(tester, 0), !before);
    expect(fake.reloads, loads, reason: 'a good save reloads nothing');
  });

  testWidgets('a failed save puts the toggle back to the stored value', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await settleSettings(tester);
    final before = _checked(tester, 0);
    final loads = fake.reloads;
    fake.failSave = true;

    await tester.tap(find.byType(DabblerToggle).at(0));
    await settleSettings(tester);

    expect(fake.saves, 1);
    expect(fake.reloads, loads + 1, reason: 'stored settings are reloaded');
    expect(
      _checked(tester, 0),
      before,
      reason: 'the toggle must not show a value that was never saved',
    );
  });
}
