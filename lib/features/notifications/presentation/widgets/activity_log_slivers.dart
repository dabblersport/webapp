// KAN-852: the Activity log list, extracted from notifications_screen_v2.dart.
// Loading, error-with-Retry, partial failure, genuine empty, date-grouped rows
// and Load more — over the merged personal log.
// KAN-878: a search with no match shows one "searching older" indicator while
// older pages may still match, then ActivityNoMatchState — never the empty
// state, and never a Load more button beside the indicator.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'activity_empty_state.dart';
import 'activity_no_match_state.dart';
import 'activity_row.dart';
import 'notif_list_states.dart';
import 'notif_section_header.dart';

List<Widget> buildActivityLogSlivers(
  BuildContext context,
  ActivityLogState state, {
  required void Function(ActivityFeedEvent) onTap,
  required VoidCallback onRetry,
  required VoidCallback onLoadMore,
}) {
  if (!state.loaded || (state.isLoading && state.activities.isEmpty)) {
    return const [SliverToBoxAdapter(child: NotifLoadingView())];
  }
  final String? error = state.error;
  // Nothing to show and a source failed: an error, never "empty".
  if (state.activities.isEmpty && error != null) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(message: error, onRetry: onRetry),
      ),
    ];
  }
  final List<ActivityFeedEvent> activities = state.filteredActivities;
  final List<Widget> widgets = <Widget>[
    // One source failed, the other answered: keep its rows, say so.
    if (error != null)
      SliverToBoxAdapter(
        child: ActivityLogPartialError(message: error, onRetry: onRetry),
      ),
  ];
  if (activities.isEmpty) {
    if (state.query.trim().isEmpty) {
      widgets.add(const SliverToBoxAdapter(child: ActivityEmptyState()));
    } else {
      // A searched miss owns the whole tail: older pages that may still match
      // get one indicator (the search loop drives loadMore() itself, so no
      // Load more and no second spinner); nothing left means no match.
      final bool olderMayMatch = state.isSearchingOlder || state.hasMore;
      widgets.add(
        SliverToBoxAdapter(
          child: olderMayMatch
              ? const ActivitySearchingOlder()
              : ActivityNoMatchState(
                  query: state.query,
                  category: state.category,
                ),
        ),
      );
      return widgets;
    }
  }

  final Map<String, List<ActivityFeedEvent>> grouped =
      <String, List<ActivityFeedEvent>>{};
  for (final ActivityFeedEvent a in activities) {
    grouped.putIfAbsent(_dayLabel(context, a.happenedAt), () => []).add(a);
  }
  grouped.forEach((day, items) {
    widgets.add(
      SliverToBoxAdapter(
        child: NotifSectionHeader(
          title: day,
          count: items.length,
          suffix: 'events',
        ),
      ),
    );
    widgets.add(
      SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => ActivityRow(
          event: items[i],
          isLast: i == items.length - 1,
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  });

  if (state.isLoadingMore) {
    widgets.add(
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(DabblerSpacing.space6),
          child: Center(child: DabblerSpinner()),
        ),
      ),
    );
  } else if (state.hasMore) {
    widgets.add(
      SliverToBoxAdapter(child: LoadMoreButton(onPressed: onLoadMore)),
    );
  }
  return widgets;
}

String _dayLabel(BuildContext context, DateTime dt) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
  final AppLocalizations l10n = AppLocalizations.of(context);
  final String localeCode = Localizations.localeOf(context).languageCode;
  final String date =
      '${DateFormat.E(localeCode).format(dt)} ${dt.day} '
      '${DateFormat.MMM(localeCode).format(dt)}';
  if (diff == 0) return '${l10n.notif_section_today} · $date';
  if (diff == 1) return '${l10n.notif_section_yesterday} · $date';
  return date;
}

/// Inline failure above rows that did load.
class ActivityLogPartialError extends StatelessWidget {
  const ActivityLogPartialError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space2,
      ),
      child: DabblerEmptyState.error(
        title: l10n.notif_error_prefix(message),
        size: DabblerEmptyStateSize.inline,
        onRetry: onRetry,
        retryLabel: l10n.notif_btn_retry,
      ),
    );
  }
}

/// KAN-878: the search found nothing yet, but older pages may still match.
class ActivitySearchingOlder extends StatelessWidget {
  const ActivitySearchingOlder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DabblerSpinner(),
          const SizedBox(height: DabblerSpacing.space3),
          DabblerText(
            AppLocalizations.of(context).activity_search_loading_older,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
