// KAN-878: the Activity log's answer to a search that matched nothing, with
// nothing older left to page in. Same DabblerEmptyState family as
// ActivityEmptyState, but a search glyph and its own copy so "no matches"
// never reads as "no activity".

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivityNoMatchState extends StatelessWidget {
  const ActivityNoMatchState({
    super.key,
    required this.query,
    required this.category,
  });

  /// The search text as typed; trimmed for display.
  final String query;

  /// The ActivityLogState category key ('all', 'me', 'game', ...).
  final String category;

  /// The label of the category chip for [category]. Mirrors the keys and l10n
  /// getters of the Activity chips row (notifications_screen_v2.dart
  /// `_activityChips`); an unknown key reads as All.
  static String categoryLabel(AppLocalizations l10n, String category) =>
      switch (category) {
        'me' => l10n.notif_chip_you,
        'game' => l10n.notif_chip_games,
        'booking' => l10n.notif_chip_bookings,
        'social' => l10n.notif_chip_social,
        'reward' => l10n.notif_chip_rewards,
        'security' => l10n.notif_chip_security,
        _ => l10n.notif_chip_all,
      };

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
        text: l10n.activity_search_no_match_body(
          query.trim(),
          categoryLabel(l10n, category),
        ),
        size: DabblerEmptyStateSize.page,
      ),
    );
  }
}
