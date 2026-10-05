import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Simple rewards screen for navigation tab
/// This serves as the main entry point for the rewards system
///
/// Built from the design system: a [DabblerPage] with a titled top bar and a
/// [DabblerEmptyState] body. No design frame exists for it.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: AppLocalizations.of(context).notif_chip_rewards,
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null,
      ),
      body: Center(
        child: DabblerEmptyState(
          icon: 'medal-star',
          title: AppLocalizations.of(context).notif_chip_rewards,
          text: 'Rewards Screen - Under Construction',
          size: DabblerEmptyStateSize.page,
        ),
      ),
    );
  }
}
