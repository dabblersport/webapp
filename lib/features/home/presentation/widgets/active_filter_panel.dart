import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';

/// The label of a type chip.
String activeTypeLabel(AppLocalizations l, ActiveType? type) => switch (type) {
  null => l.act_filter_all,
  ActiveType.games => l.act_filter_games,
  ActiveType.meetups => l.act_filter_meetups,
  ActiveType.venues => l.act_filter_venues,
  ActiveType.players => l.act_filter_players,
};

/// The one-line summary of the active filters, or null when none is on.
String? activeFilterSummary(AppLocalizations l, ActiveFilter f) {
  if (!f.isActive) return null;
  final parts = <String>[
    if (f.type != null) activeTypeLabel(l, f.type),
    if (f.city != null) f.city!,
  ];
  return l.act_summary(parts.join(' · '));
}

/// KAN-957: the Active filter panel (`Home Feed.dc.html:282-310`), between
/// the tab rail and the list, scrolling with the feed: the city chip, a
/// divider, the type chips, and — only while a filter is on — the summary and
/// "Reset filters".
class ActiveFilterPanel extends ConsumerWidget {
  const ActiveFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(activeFilterProvider);
    final summary = activeFilterSummary(l, filter);
    void setType(ActiveType? t) =>
        ref.read(activeFilterProvider.notifier).state = filter.withType(t);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: DabblerSpacing.space4,
        bottom: DabblerSpacing.space3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            key: const ValueKey<String>('active-filter-rail'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: DabblerInsets.feedScreen.left,
            ),
            child: Row(
              children: <Widget>[
                DabblerChip(
                  key: const ValueKey<String>('active-city-chip'),
                  label: filter.city ?? l.act_city_all,
                  selected: filter.city != null,
                  metrics: DabblerFeedMetrics.drawn,
                  leadingIcon: const DabblerIcon(
                    'location',
                    weight: DabblerIconWeight.bold,
                  ),
                  trailingIcon: const DabblerIcon('arrow-circle-down'),
                  onTap: () => showActiveCitySheet(context),
                ),
                const DabblerGap.h(DabblerSpacing.space2),
                const SizedBox(
                  height: DabblerHomeFrame.listRowGlyph,
                  child: DabblerDivider.vertical(strong: true),
                ),
                for (final ActiveType? t in <ActiveType?>[
                  null,
                  ...ActiveType.values,
                ]) ...<Widget>[
                  const DabblerGap.h(DabblerSpacing.space2),
                  DabblerChip(
                    key: ValueKey<String>('active-type-${t?.name ?? 'all'}'),
                    label: activeTypeLabel(l, t),
                    selected: filter.type == t,
                    metrics: DabblerFeedMetrics.drawn,
                    leadingIcon: t == null
                        ? null
                        : DabblerIcon(t.icon, weight: DabblerIconWeight.bold),
                    onTap: () => setType(t),
                  ),
                ],
              ],
            ),
          ),
          if (summary != null) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space3),
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: DabblerInsets.feedScreen.left,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: DabblerText(
                      summary,
                      key: const ValueKey<String>('active-filter-summary'),
                      style: DabblerType.caption1,
                      tone: DabblerTextTone.tertiary,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const DabblerGap.h(DabblerSpacing.space3),
                  _ResetLink(
                    label: l.act_reset_filters,
                    onTap: () => ref.read(activeFilterProvider.notifier).state =
                        const ActiveFilter(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Reset filters" with its close-circle glyph, in the brand ink.
class _ResetLink extends StatelessWidget {
  const _ResetLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const ValueKey<String>('active-reset-filters'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: DabblerSpacing.space9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DabblerIcon(
                'close-circle',
                size: DabblerHomeFrame.subChipGlyph,
                color: colors.brandPrimary,
              ),
              const SizedBox(width: DabblerHomeFrame.locationGap),
              DabblerText(
                label,
                style: DabblerType.footnote,
                tone: DabblerTextTone.brand,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens "Filter by city" (`Home Feed.dc.html:495-516`). Choosing a row sets
/// the city filter and closes the sheet.
Future<void> showActiveCitySheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    title: AppLocalizations.of(context).act_city_sheet_title,
    detent: DabblerSheetDetent.content,
    builder: (_) => const ActiveCitySheet(),
  );
}

/// The sheet's body: the note, then "All cities" and every city.
class ActiveCitySheet extends ConsumerWidget {
  const ActiveCitySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(activeFilterProvider).city;
    final cities = ref.watch(activeCitiesProvider);
    void choose(String? city) {
      final f = ref.read(activeFilterProvider);
      ref.read(activeFilterProvider.notifier).state = f.withCity(city);
      Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerText(
          l.act_city_sheet_note,
          style: DabblerType.caption1,
          tone: DabblerTextTone.tertiary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        const DabblerDivider(),
        const DabblerGap.v(DabblerSpacing.space2),
        _CityRow(
          label: l.act_city_all,
          on: current == null,
          onTap: () => choose(null),
        ),
        ...cities.when(
          data: (list) => <Widget>[
            for (final c in list)
              _CityRow(label: c, on: current == c, onTap: () => choose(c)),
          ],
          loading: () => const <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.all(DabblerSpacing.space4),
              child: Center(child: DabblerSpinner()),
            ),
          ],
          error: (_, __) => <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: DabblerSpacing.space4,
              ),
              child: DabblerText(
                l.act_city_sheet_loading_failed,
                style: DabblerType.caption1,
                tone: DabblerTextTone.tertiary,
              ),
            ),
          ],
        ),
        const DabblerGap.v(DabblerSpacing.space8),
      ],
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        key: ValueKey<String>('active-city-row-$label'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: DabblerSpacing.space11 - DabblerSizing.borderDefault,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: DabblerSpacing.space2,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DabblerText(
                        label,
                        style: DabblerType.subheadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (on) ...<Widget>[
                      const DabblerGap.h(DabblerSpacing.space4),
                      DabblerIcon(
                        'tick-circle',
                        key: const ValueKey<String>('active-city-tick'),
                        size: DabblerHomeFrame.listRowGlyph,
                        weight: DabblerIconWeight.bold,
                        color: colors.brandPrimary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const DabblerDivider(),
          ],
        ),
      ),
    );
  }
}
