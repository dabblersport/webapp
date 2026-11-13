import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// KAN-622: the entry from a sport tile (the selected sport chip in Sports and
/// in the Sports library) to that sport's page. Drawn only behind
/// `FeatureFlags.sportOverview` and only for a sport the catalog knows by id,
/// so it is never a dead control.
class SportPageLink extends StatelessWidget {
  const SportPageLink({super.key, required this.sportName});

  final String sportName;

  @override
  Widget build(BuildContext context) {
    final String? sportId = SportIdMapping.getSportId(sportName.trim());
    if (!FeatureFlags.sportOverview || sportId == null) {
      return const SizedBox.shrink();
    }
    return DabblerButton.icon(
      icon: 'arrow-right-3',
      mirrorInRtl: true,
      size: DabblerButtonSize.small,
      semanticLabel: AppLocalizations.of(
        context,
      ).sport_overview_open_page(sportName),
      onPressed: () => context.push(RoutePaths.sportOverviewFor(sportId)),
    );
  }
}
