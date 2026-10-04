import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// The empty-query state (`Search_default`): recent searches, quick filters and
/// the three shortcut cards.
class SearchDefaultView extends StatelessWidget {
  const SearchDefaultView({
    super.key,
    required this.recentSearches,
    required this.onPickRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onPickRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = [
      (label: l10n.sfx_near_me, icon: 'location', active: true),
      (label: l10n.sfx_today, icon: 'clock', active: false),
      (label: l10n.sfx_this_week, icon: '', active: false),
      (label: l10n.sfx_friends_only, icon: '', active: false),
      (label: l10n.sfx_popular, icon: '', active: false),
      (label: l10n.sfx_free_entry, icon: '', active: false),
    ];
    final shortcuts = [
      (
        icon: 'people',
        title: l10n.sfx_people_nearby,
        sub: l10n.sfx_people_nearby_sub,
      ),
      (
        icon: 'game',
        title: l10n.sfx_popular_games,
        sub: l10n.sfx_popular_games_sub,
      ),
      (
        icon: 'activity',
        title: l10n.sfx_trending_posts,
        sub: l10n.sfx_trending_posts_sub,
      ),
    ];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space10,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DabblerSpacing.space8,
          children: [
            if (recentSearches.isNotEmpty)
              DabblerSection(
                compact: true,
                icon: 'clock',
                iconWeight: DabblerIconWeight.linear,
                iconColor: DabblerColors.of(context).textPrimary,
                title: l10n.sfx_recent,
                action: DabblerTextLink(
                  label: l10n.sfx_clear,
                  underline: false,
                  onPressed: onClearRecent,
                ),
                children: [
                  Wrap(
                    spacing: DabblerSpacing.space2,
                    runSpacing: DabblerSpacing.space2,
                    children: [
                      for (final q in recentSearches)
                        DabblerChip(
                          key: ValueKey('recent-$q'),
                          label: '\u2066$q\u2069',
                          leadingIcon: DabblerIcon(
                            'clock',
                            size: DabblerSizing.iconXs,
                            color: DabblerColors.of(context).textTertiary,
                          ),
                          onTap: () => onPickRecent(q),
                          onRemove: () => onRemoveRecent(q),
                          mutedRemove: true,
                          dense: true,
                          removeSemanticLabel: l10n.sfx_remove_recent(q),
                        ),
                    ],
                  ),
                ],
              ),
            DabblerSection(
              compact: true,
              icon: 'filter',
              title: l10n.sfx_quick_filters,
              children: [
                Wrap(
                  spacing: DabblerSpacing.space2,
                  runSpacing: DabblerSpacing.space2,
                  children: [
                    for (final f in filters)
                      DabblerChip(
                        label: f.label,
                        selected: f.active,
                        leadingIcon: f.icon.isEmpty
                            ? null
                            : DabblerIcon(f.icon, size: DabblerSizing.iconXs),
                      ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DabblerSpacing.space3,
              children: [
                for (final s in shortcuts)
                  DabblerCard(
                    variant: DabblerCardVariant.white,
                    radius: DabblerRadius.lg,
                    padding: const EdgeInsets.all(DabblerSpacing.space4),
                    child: Row(
                      spacing: DabblerSpacing.space4,
                      children: [
                        DabblerIconTile.named(
                          s.icon,
                          weight: DabblerIconWeight.bold,
                          tone: DabblerIconTileTone.sunken,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DabblerText(
                                s.title,
                                style: DabblerType.subheadline,
                                weight: DabblerTextWeight.semibold,
                              ),
                              DabblerText(
                                s.sub,
                                style: DabblerType.footnote,
                                tone: DabblerTextTone.secondary,
                              ),
                            ],
                          ),
                        ),
                        DabblerIcon(
                          'arrow-circle-right',
                          mirrorInRtl: true,
                          size: DabblerSizing.iconSm,
                          color: DabblerColors.of(context).textTertiary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
