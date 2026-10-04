import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Socialiser profile's sports block (Profiles design, "Socialiser — own
/// profile"): a muted label over static, unselectable sport tags. A socialiser
/// follows sports for feeds and results only, so there is no picker and no
/// per-sport scope.
class OwnProfileFollowedSports extends StatelessWidget {
  const OwnProfileFollowedSports({super.key, required this.sports});

  final List<Sport> sports;

  @override
  Widget build(BuildContext context) {
    if (sports.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DabblerText(
            l10n.profile_sports_followed_note,
            style: DabblerType.footnote,
            weight: DabblerTextWeight.semibold,
            tone: DabblerTextTone.tertiary,
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: <Widget>[
              for (final Sport s in sports)
                DabblerChip(label: s.nameEn, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
