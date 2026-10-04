import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';

/// Screen displaying the Privacy Policy — a design-system page with the titled
/// navigation bar (and its Privacy Settings shortcut) over [LegalDocContent].
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        border: true,
        title: 'Privacy Policy',
        onBack: () => context.pop(),
        actions: [
          DabblerNavigationAction(
            icon: 'setting-2',
            label: 'Privacy Settings',
            onPressed: () => context.push('/settings/privacy'),
          ),
        ],
      ),
      body: const LegalDocContent(
        intro: kPrivacyIntro,
        sections: kPrivacyPolicySections,
      ),
    );
  }
}
