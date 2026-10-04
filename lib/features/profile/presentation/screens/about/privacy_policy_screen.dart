import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Screen displaying the Privacy Policy — a design-system page with the titled
/// navigation bar (and its Privacy Settings shortcut) over [LegalDocContent].
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: settingsInnerTopBar(
        context,
        title: l10n.settings_item_privacy_policy_title,
        extraActions: [
          DabblerNavigationAction(
            icon: 'setting-2',
            label: l10n.about_privacy_settings_tooltip,
            onPressed: () => context.push('/settings/privacy'),
          ),
        ],
      ),
      body: LegalDocContent(
        intro: l10n.about_privacy_intro,
        sections: kPrivacyPolicySections,
      ),
    );
  }
}
