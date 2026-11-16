import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_tags.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';

/// KAN-959 / KAN-962: whether [tab] has a filter row, and so a filter pill
/// while selected (`TAGS`): For you, Nearby, Active and News.
bool feedTabHasFilters(FeedTab tab) =>
    tab == FeedTab.active || homeTabTags(tab).isNotEmpty;

/// KAN-959: the number of filters applied on the Active tab — the type and
/// the city each count once.
int activeFilterCount(ActiveFilter f) =>
    (f.type != null ? 1 : 0) + (f.city != null ? 1 : 0);

/// KAN-962: the number of filters applied on [tab] (`fc`): Active counts its
/// type and city; every other tab counts its picks. Watches the filter state.
int watchFeedTabFilterCount(WidgetRef ref, FeedTab tab) => tab == FeedTab.active
    ? activeFilterCount(ref.watch(activeFilterProvider))
    : ref.watch(homeTabPicksProvider)[tab]?.length ?? 0;

/// KAN-959 / KAN-962: the filter pill after the selected tab's label
/// (`Home Feed.dc.html:262`): the `setting-4` glyph and, once a filter is
/// applied, their count. Transparent with ink at rest (`fBg`/`fFg`); brand
/// with onBrand once [count] is above zero.
class HomeTabFilterPill extends StatelessWidget {
  const HomeTabFilterPill({super.key, required this.count});

  final int count;

  /// Whether the pill paints its brand state.
  bool get highlighted => count > 0;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final fg = highlighted ? colors.onBrand : colors.textPrimary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: DabblerSpacing.space1,
      children: <Widget>[
        DabblerIcon('setting-4', size: DabblerSizing.iconXs, color: fg),
        if (highlighted)
          DabblerText(
            '$count',
            key: const ValueKey<String>('home-tab-filter-count'),
            style: DabblerType.caption2,
            weight: DabblerTextWeight.semibold,
            tone: DabblerTextTone.onBrand,
            maxLines: 1,
          ),
      ],
    );
    const padding = EdgeInsetsDirectional.symmetric(
      horizontal: DabblerHomeFrame.postMetaGap,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: DabblerHomeFrame.listRowGlyph,
      ),
      child: highlighted
          ? DabblerSurface(
              variant: DabblerSurfaceVariant.grey,
              fill: colors.brandPrimary,
              borderWidth: 0,
              radius: DabblerRadius.pill,
              height: DabblerHomeFrame.listRowGlyph,
              padding: padding,
              child: content,
            )
          : SizedBox(
              height: DabblerHomeFrame.listRowGlyph,
              child: Padding(padding: padding, child: content),
            ),
    );
  }
}
