import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Screen displaying the Terms of Service — a design-system page with the
/// titled navigation bar over the shared [LegalDocContent] body.
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: settingsInnerTopBar(context, title: l10n.settings_item_terms_title),
      body: LegalDocContent(
        intro: l10n.about_terms_intro,
        sections: kTermsOfServiceSections,
      ),
    );
  }
}
