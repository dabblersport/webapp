// KAN-878: the Activity log's search states. Same visual family as
// ActivityEmptyState (activity_empty_state.dart), which still owns the
// no-query empty log; these two only appear while a search is active.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The localized label of the Activity log chip [category], mirroring the
/// chips the notifications screen builds (`all`, `me`, `game`, `booking`,
/// `social`, `reward`, `security`). Unknown keys fall back to "All".
String activityLogCategoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'me' => l10n.notif_chip_you,
      'game' => l10n.notif_chip_games,
      'booking' => l10n.notif_chip_bookings,
      'social' => l10n.notif_chip_social,
      'reward' => l10n.notif_chip_rewards,
      'security' => l10n.notif_chip_security,
      _ => l10n.notif_chip_all,
    };

/// A search ran over the whole history and nothing matched.
class ActivityNoMatchState extends StatelessWidget {
  const ActivityNoMatchState({
    super.key,
    required this.query,
    required this.categoryLabel,
  });

  final String query;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space11,
        horizontal: DabblerSpacing.space8,
      ),
      child: DabblerEmptyState(
        icon: 'search-normal',
        title: l10n.activity_search_no_match_title,
        text: l10n.activity_search_no_match_body(query.trim(), categoryLabel),
        size: DabblerEmptyStateSize.page,
      ),
    );
  }
}

/// No match yet, but older pages are still being searched.
class ActivitySearchingOlderIndicator extends StatelessWidget {
  const ActivitySearchingOlderIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label = l10n.activity_search_loading_older;
    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerSpinner(label: label),
          const SizedBox(height: DabblerSpacing.space3),
          ExcludeSemantics(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DabblerType.smallRelaxed
                  .resolveForDirection(Directionality.of(context))
                  .copyWith(color: DabblerColors.of(context).textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
