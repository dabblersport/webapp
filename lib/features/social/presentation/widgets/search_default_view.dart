import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

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

  static const _filters = [
    (label: 'Near me', icon: 'location', active: true),
    (label: 'Today', icon: 'clock', active: false),
    (label: 'This week', icon: '', active: false),
    (label: 'Friends only', icon: '', active: false),
    (label: 'Popular', icon: '', active: false),
    (label: 'Free entry', icon: '', active: false),
  ];

  static const _shortcuts = [
    (icon: 'people', title: 'People nearby', sub: 'Find players near you'),
    (icon: 'game', title: 'Popular games', sub: 'Open spots today'),
    (icon: 'activity', title: 'Trending posts', sub: 'What everyone’s on'),
  ];

  @override
  Widget build(BuildContext context) {
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
                title: 'Recent',
                action: DabblerTextLink(
                  label: 'Clear',
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
                          label: q,
                          leadingIcon: const DabblerIcon(
                            'clock',
                            size: DabblerSizing.iconXs,
                          ),
                          onTap: () => onPickRecent(q),
                          onRemove: () => onRemoveRecent(q),
                          removeSemanticLabel: 'Remove $q',
                        ),
                    ],
                  ),
                ],
              ),
            DabblerSection(
              compact: true,
              icon: 'filter',
              title: 'Quick filters',
              children: [
                Wrap(
                  spacing: DabblerSpacing.space2,
                  runSpacing: DabblerSpacing.space2,
                  children: [
                    for (final f in _filters)
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
                for (final s in _shortcuts)
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
