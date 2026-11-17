// KAN-989 (W1-F3): the Notifications tab's slivers — chips' rows grouped by
// day with highlights under All, and every list state (design A.1).

import 'package:flutter/widgets.dart';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';

import 'notif_center_feed.dart';
import 'notif_empty_state.dart';
import 'notif_list_states.dart';
import 'notif_row.dart';
import 'notif_section_header.dart';

/// The slivers below the chips.
List<Widget> buildNotificationCenterSlivers(
  BuildContext context, {
  required NotificationsState state,
  required List<ActivityFeedEvent> activities,
  required NotificationChip chip,
  required String chipLabel,
  required bool offline,
  required bool refreshing,
  required bool loadingMore,
  required DateTime now,
  required VoidCallback onRetry,
  required VoidCallback onShowAll,
  required VoidCallback onLoadMore,
  required ValueChanged<AppNotification> onTapNotification,
  required ValueChanged<ActivityFeedEvent> onTapActivity,
}) {
  final hasRows = state.notifications.isNotEmpty;
  if (!hasRows && state.isLoading) {
    return const [SliverToBoxAdapter(child: NotifLoadingView())];
  }
  if (!hasRows && state.error != null && !offline) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: NotifLoadFailedView(onRetry: onRetry),
      ),
    ];
  }

  final slivers = <Widget>[
    if (offline)
      SliverToBoxAdapter(child: NotifOfflineBanner(savedAt: state.loadedAt))
    else if (hasRows && state.error != null)
      SliverToBoxAdapter(child: NotifRefreshFailedBanner(onRetry: onRetry)),
    if (refreshing || (hasRows && state.isLoading && !loadingMore))
      const SliverToBoxAdapter(child: NotifRefreshingRow()),
  ];

  final rows = buildCenterRows(
    notifications: state.notifications,
    activities: activities,
    chip: chip,
  );
  if (rows.isEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: chip == NotificationChip.all
            ? const NotifEmptyState()
            : NotifFilterEmptyState(
                filterLabel: chipLabel,
                onShowAll: onShowAll,
              ),
      ),
    );
    return slivers;
  }

  for (final g in groupCenterRows(rows, now)) {
    slivers.add(
      SliverToBoxAdapter(
        child: NotifSectionHeader(
          key: ValueKey<String>('notif-group-${g.key}'),
          title: centerGroupLabel(context, g, now),
          count: g.rows.length,
        ),
      ),
    );
    slivers.add(
      SliverList.builder(
        itemCount: g.rows.length,
        itemBuilder: (context, i) => switch (g.rows[i]) {
          NotificationCenterRow(:final notification) => NotificationRow(
            key: ValueKey<String>(g.rows[i].key),
            notification: notification,
            onTap: () => onTapNotification(notification),
          ),
          ActivityHighlightRow(:final event) => NotifHighlightRow(
            key: ValueKey<String>(g.rows[i].key),
            event: event,
            onTap: () => onTapActivity(event),
          ),
        },
      ),
    );
  }
  slivers.add(
    SliverToBoxAdapter(
      child: NotifListFooter(
        hasMore: state.hasMore && !offline,
        loading: loadingMore,
        onLoadMore: onLoadMore,
      ),
    ),
  );
  return slivers;
}
