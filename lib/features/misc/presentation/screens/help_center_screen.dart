import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// Help centre — the destination of the Settings information action. No
/// design frame and no content yet: the design-system empty state under the
/// titled bar.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.help_center_title,
        border: true,
        onBack: () => Navigator.maybePop(context),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DabblerSpacing.space6),
          child: DabblerEmptyState(
            icon: 'message-question',
            title: l10n.help_center_empty_title,
            text: l10n.help_center_empty_text,
          ),
        ),
      ),
    );
  }
}
