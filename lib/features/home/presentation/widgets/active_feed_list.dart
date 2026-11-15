import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'active_event_card.dart';

/// One date group of the Active list: its label and its items, newest first.
typedef ActiveGroup = ({String label, List<ActiveItem> items});

/// Groups [items] (already newest first) by the local day of `event_at`:
/// "Today", "Yesterday", then the weekday and date.
List<ActiveGroup> groupActiveByDay(
  List<ActiveItem> items,
  AppLocalizations l,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  String label(DateTime d) {
    final days = today.difference(d).inDays;
    if (days == 0) return l.act_group_today;
    if (days == 1) return l.act_group_yesterday;
    return d.year == now.year
        ? DateFormat.MMMEd(l.localeName).format(d)
        : DateFormat.yMMMEd(l.localeName).format(d);
  }

  final groups = <ActiveGroup>[];
  DateTime? current;
  for (final e in items) {
    final at = e.eventAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    if (current != day) {
      current = day;
      groups.add((label: label(day), items: <ActiveItem>[]));
    }
    groups.last.items.add(e);
  }
  return groups;
}

/// KAN-957: the Active tab's list as a sliver (`Home Feed.dc.html:360-460`):
/// date groups of cards ending in "You're all caught up", or the loading
/// skeleton, the empty state (worded for the filters when one is on) or the
/// error state.
class ActiveFeedSliver extends ConsumerWidget {
  const ActiveFeedSliver({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final ActiveFeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filtered = ref.watch(activeFilterProvider).isActive;

    if (state.isLoading && state.events.isEmpty) {
      return const SliverToBoxAdapter(child: ActiveSkeletonList());
    }
    if (state.error != null && state.events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
          child: DabblerEmptyState.error(
            icon: 'wifi-square',
            title: l.act_error_title,
            text: l.act_error_text,
            size: DabblerEmptyStateSize.inline,
            onRetry: onRetry,
            retryLabel: l.act_error_retry,
          ),
        ),
      );
    }
    if (state.events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
          child: DabblerEmptyState(
            icon: filtered ? 'filter-search' : 'activity',
            title: filtered ? l.act_empty_filtered_title : l.act_empty_title,
            text: filtered ? l.act_empty_filtered_text : l.act_empty_text,
            action: DabblerButton(
              label: filtered ? l.act_reset_filters : l.act_empty_refresh,
              tone: DabblerButtonTone.secondary,
              size: DabblerButtonSize.small,
              onPressed: filtered
                  ? () => ref.read(activeFilterProvider.notifier).state =
                        const ActiveFilter()
                  : onRetry,
            ),
          ),
        ),
      );
    }

    final groups = groupActiveByDay(
      state.events,
      l,
      ref.watch(homeNowProvider)(),
    );
    final rows = <Widget>[
      for (final g in groups) ...<Widget>[
        ActiveGroupHeader(label: g.label),
        for (final e in g.items) ActiveEventCard(key: ValueKey(e.id), event: e),
      ],
      if (state.isLoadingMore)
        const Padding(
          padding: EdgeInsetsDirectional.symmetric(
            vertical: DabblerSpacing.space5,
          ),
          child: Center(child: DabblerSpinner()),
        )
      else if (!state.hasMore)
        const ActiveCaughtUpRow(),
    ];
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}

/// A date group's label and the hairline that runs to the end
/// (`Home Feed.dc.html:363-366`).
class ActiveGroupHeader extends StatelessWidget {
  const ActiveGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space3,
      ),
      child: Row(
        children: <Widget>[
          Semantics(
            header: true,
            child: DabblerText(
              label,
              style: DabblerType.caption1,
              tone: DabblerTextTone.tertiary,
              maxLines: 1,
            ),
          ),
          const DabblerGap.h(DabblerSpacing.space3),
          const Expanded(child: DabblerDivider()),
        ],
      ),
    );
  }
}

/// KAN-956: the end of the Active list with nothing left to load
/// (`Home Feed.dc.html:434`, `padding:12px 0`, 12/16 `--subtle`).
class ActiveCaughtUpRow extends StatelessWidget {
  const ActiveCaughtUpRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space4),
      child: DabblerText(
        AppLocalizations.of(context).feed_all_caught_up,
        textAlign: TextAlign.center,
        style: DabblerType.caption1,
        tone: DabblerTextTone.tertiary,
      ),
    );
  }
}

/// The loading skeleton: three card outlines (`Home Feed.dc.html:436-447`).
class ActiveSkeletonList extends StatelessWidget {
  const ActiveSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    Widget card() => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
      child: DabblerSurface.card(
        radius: DabblerRadius.xl,
        fill: colors.surfaceCard,
        borderColor: colors.borderDefault,
        borderWidth: DabblerSizing.borderDefault,
        padding: const EdgeInsetsDirectional.all(activeCardInset),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: 0.4,
              child: DabblerSkeleton.text(lines: 1),
            ),
            DabblerGap.v(DabblerSpacing.space4),
            Row(
              children: <Widget>[
                DabblerSkeleton.rect(
                  width: DabblerSizing.tileMd,
                  height: DabblerSizing.tileMd,
                  radius: DabblerRadius.md,
                ),
                DabblerGap.h(DabblerSpacing.space4),
                Expanded(child: DabblerSkeleton.text(lines: 2)),
              ],
            ),
          ],
        ),
      ),
    );
    return KeyedSubtree(
      key: const ValueKey<String>('active-skeleton'),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
        child: Column(children: <Widget>[card(), card(), card()]),
      ),
    );
  }
}
