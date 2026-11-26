// KAN-1052: the "Browse all sports" entry each scoped section carries, so
// sports outside the viewer's own list stay discoverable.
//
// Off: a header action ("Browse all sports"). On: a rail chip ("All sports")
// whose remove goes back to the viewer's sports. Neither shows while the
// section is unscoped or has no other sports to add.

import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The header action that turns "Browse all sports" on, or null when it has
/// nothing to offer ([hasMore] false) or is already on.
DabblerPageHeaderAction? browseAllSportsAction(
  BuildContext context,
  WidgetRef ref,
  SportSection section, {
  required bool hasMore,
}) {
  if (!hasMore || ref.watch(browseAllSportsProvider(section))) return null;
  return DabblerPageHeaderAction(
    icon: 'global',
    semanticLabel: AppLocalizations.of(context).sports_browse_all,
    onPressed: () =>
        ref.read(browseAllSportsProvider(section).notifier).state = true,
  );
}

/// The rail chip shown while "Browse all sports" is on; removing it goes back
/// to the viewer's sports. Null while off.
DabblerFilterRailItem? browseAllSportsRailItem(
  BuildContext context,
  WidgetRef ref,
  SportSection section,
) {
  if (!ref.watch(browseAllSportsProvider(section))) return null;
  final l = AppLocalizations.of(context);
  return DabblerFilterRailItem(
    label: l.listing_all_sports,
    removeSemanticLabel: l.sports_show_mine,
    onRemove: () =>
        ref.read(browseAllSportsProvider(section).notifier).state = false,
  );
}
