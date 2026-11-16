import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/for_you_sport_filter.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-959: whether [tab] has a filter row (and so a filter pill).
bool feedTabHasFilters(FeedTab tab) =>
    tab == FeedTab.forYou || tab == FeedTab.active;

/// KAN-959: the number of filters applied on the Active tab — the type and
/// the city each count once.
int activeFilterCount(ActiveFilter f) =>
    (f.type != null ? 1 : 0) + (f.city != null ? 1 : 0);

/// KAN-959: the number of filters applied on [tab]. Watches the filter state.
int watchFeedTabFilterCount(WidgetRef ref, FeedTab tab) => switch (tab) {
  FeedTab.forYou => ref.watch(forYouSportProvider) != null ? 1 : 0,
  FeedTab.active => activeFilterCount(ref.watch(activeFilterProvider)),
  _ => 0,
};

/// KAN-959: the filter pill after a tab's label (`Home Feed.dc.html:262`):
/// the `setting-4` glyph and, once a filter is applied, their count. Neutral
/// at rest; highlighted when a filter is applied or the row is [open].
class HomeTabFilterPill extends StatelessWidget {
  const HomeTabFilterPill({super.key, required this.count, required this.open});

  final int count;
  final bool open;

  /// Whether the pill paints its highlighted state.
  bool get highlighted => count > 0 || open;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final fg = highlighted ? colors.onBrand : colors.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: DabblerHomeFrame.listRowGlyph,
      ),
      child: DabblerSurface(
        variant: DabblerSurfaceVariant.grey,
        fill: highlighted ? colors.brandPrimary : null,
        borderWidth: 0,
        radius: DabblerRadius.pill,
        height: DabblerHomeFrame.listRowGlyph,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerHomeFrame.postMetaGap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: DabblerSpacing.space1,
          children: <Widget>[
            DabblerIcon('setting-4', size: DabblerSizing.iconXs, color: fg),
            if (count > 0)
              DabblerText(
                '$count',
                key: const ValueKey<String>('home-tab-filter-count'),
                style: DabblerType.caption2,
                weight: DabblerTextWeight.semibold,
                tone: highlighted
                    ? DabblerTextTone.onBrand
                    : DabblerTextTone.secondary,
                maxLines: 1,
              ),
          ],
        ),
      ),
    );
  }
}

/// KAN-959: the For you filter row (`Home Feed.dc.html:267-281`): "All
/// sports", then every active sport, in the locale's name. Choosing one sets
/// [forYouSportProvider]; "All sports" clears it.
class ForYouSportRail extends ConsumerWidget {
  const ForYouSportRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(forYouSportProvider);
    final sports = ref.watch(sportsProvider).valueOrNull ?? const <Sport>[];
    void choose(String? id) =>
        ref.read(forYouSportProvider.notifier).state = id;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space4,
      ),
      child: SingleChildScrollView(
        key: const ValueKey<String>('for-you-sport-rail'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: DabblerInsets.feedScreen.left,
        ),
        child: Row(
          spacing: DabblerSpacing.space2,
          children: <Widget>[
            DabblerChip(
              key: const ValueKey<String>('for-you-sport-all'),
              label: l.home_sport_all,
              selected: selected == null,
              metrics: DabblerFeedMetrics.drawn,
              onTap: () => choose(null),
            ),
            for (final s in sports)
              DabblerChip(
                key: ValueKey<String>('for-you-sport-${s.id}'),
                label: s.localizedName(context),
                selected: selected == s.id,
                metrics: DabblerFeedMetrics.drawn,
                onTap: () => choose(s.id),
              ),
          ],
        ),
      ),
    );
  }
}
