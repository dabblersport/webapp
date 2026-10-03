import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';

/// Screen displaying the Terms of Service — a design-system page with the
/// titled navigation bar over the shared [LegalDocContent] body.
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Terms of Service',
        onBack: () => context.pop(),
      ),
      body: const LegalDocContent(
        intro: kTermsIntro,
        sections: kTermsOfServiceSections,
      ),
    );
  }
}
