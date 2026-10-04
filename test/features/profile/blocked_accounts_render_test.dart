import 'package:dabbler/features/profile/presentation/widgets/blocked_accounts_group.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

/// Blocked accounts list, LTR and RTL, with people and empty.
void main() {
  setUpAll(loadProfileFonts);

  final states = <String, List<Map<String, dynamic>>>{
    'list': [
      {'user_id': 'a', 'display_name': 'Youssef El Khatib', 'username': 'youssef.elkhatib'},
      {'user_id': 'b', 'display_name': 'Priya Nair', 'username': 'priya.nair.dxb'},
      {'user_id': 'c', 'display_name': 'Ahmed Al Seed', 'username': 'seed_dubai_001'},
    ],
    'empty': [],
  };
  for (final entry in states.entries) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('blocked ${entry.key} — ${locale.languageCode}', (tester) async {
        await pumpProfileScreen(
          tester,
          Builder(
            builder: (context) => DabblerPage(
              topBar: settingsInnerTopBar(
                context,
                title: lookupAppLocalizations(locale).settings_tile_blocked,
              ),
              body: const Padding(
                padding: EdgeInsets.all(DabblerSpacing.space5),
                child: BlockedAccountsGroup(),
              ),
            ),
          ),
          locale,
          overrides: [
            blockedUsersWithProfilesProvider.overrideWith((ref) async => entry.value),
          ],
        );
        expect(tester.takeException(), isNull);
        await shootProfile(
          tester,
          kShotKey,
          'blocked-${entry.key}-${locale.languageCode == 'ar' ? 'rtl' : 'ltr'}',
        );
      });
    }
  }
}
