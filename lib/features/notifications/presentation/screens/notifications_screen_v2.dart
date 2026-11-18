import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/notification_model.dart';
import '../controllers/notifications_controller.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import '../providers/notification_center_badge_providers.dart';
import '../widgets/notif_center_list.dart';
import '../widgets/notif_chips.dart';
import '../widgets/notif_list_states.dart';
import '../widgets/notif_target_states.dart';
import '../widgets/activity_category_chips.dart';
import '../widgets/activity_log_slivers.dart';
import '../widgets/notif_prefs_sheet.dart';
import '../widgets/notif_top_bar.dart';
import '../widgets/activity_summary_card.dart';
import '../widgets/activity_search_row.dart';
import '../widgets/activity_security_footer.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_card.dart';

/// KAN-989 (W1-F3): the Notification Center shell — the Notifications and
/// Activity log tabs, the chips, activity highlights under All, every list
/// state and the tapped-target sheet (design A.1).
class NotificationsScreenV2 extends ConsumerStatefulWidget {
  const NotificationsScreenV2({super.key});

  @override
  ConsumerState<NotificationsScreenV2> createState() =>
      _NotificationsScreenV2State();
}

class _NotificationsScreenV2State extends ConsumerState<NotificationsScreenV2> {
  final AuthService _authService = AuthService();

  /// The Activity log's chip.
  String _activityFilter = 'all';

  /// The Notifications tab's chip.
  NotificationChip _chip = NotificationChip.all;
  ViewMode _mode = ViewMode.notifications;
  bool _refreshing = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityLogControllerProvider.notifier).load();
    });
  }

  void _setMode(ViewMode mode) {
    setState(() {
      _mode = mode;
      _activityFilter = 'all';
      _chip = NotificationChip.all;
    });
    // The chip row shows All again, so the list must be the full list too.
    ref.read(activityLogControllerProvider.notifier).changeCategory('all');
    if (mode == ViewMode.activity) {
      ref.read(lastSeenActivityAtProvider.notifier).markNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUserId();

    if (userId == null) {
      return DabblerPage(
        body: Center(
          child: DabblerText(
            AppLocalizations.of(context).notif_signin_required,
            style: DabblerType.body,
          ),
        ),
      );
    }

    final notificationState = ref.watch(
      notificationsControllerProvider(userId),
    );
    final activityState = ref.watch(activityLogControllerProvider);
    final offline = ref.watch(connectivityProvider) == ConnectionStatus.offline;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    Widget body(ViewMode? force) => _buildScrollBody(
      userId,
      notificationState,
      activityState,
      offline: offline,
      hideToggle: force != null,
      forceMode: force,
    );

    // KAN-420: the adaptive scaffold (side rail + header) is gone with the
    // design-system migration; on wide screens the two lists keep their
    // side-by-side panes.
    return DabblerPage(
      body: NotifCenterScope(
        actionsEnabled: !offline,
        child: isWide
            ? Row(
                children: [
                  Expanded(child: body(ViewMode.notifications)),
                  const DabblerDivider.vertical(),
                  Expanded(child: body(ViewMode.activity)),
                ],
              )
            : body(null),
      ),
    );
  }

  Widget _buildScrollBody(
    String userId,
    NotificationsState notificationState,
    ActivityLogState activityState, {
    required bool offline,
    bool hideToggle = false,
    ViewMode? forceMode,
  }) {
    final mode = forceMode ?? _mode;
    final isNotif = mode == ViewMode.notifications;
    final l10n = AppLocalizations.of(context);
    final chips = _notifChips(notificationState);

    return DabblerRefresh(
      onRefresh: () => isNotif ? _refresh(userId) : _refreshActivity(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: TopBar(
              title: isNotif
                  ? l10n.notif_title_notifications
                  : l10n.notif_title_activity_log,
              mode: mode,
              onModeChanged: hideToggle ? null : _setMode,
              onOpenSettings: () => showNotifPrefsSheet(context),
              onRefresh: () =>
                  isNotif ? _refreshFromHeader(userId) : _refreshActivity(),
              refreshing: isNotif && _refreshing,
              unreadCount: notificationState.unreadCount,
              // NC-02: mark all read clears the dots of notifications only.
              onMarkAllRead:
                  (isNotif && !offline && notificationState.unreadCount > 0)
                  ? () => ref
                        .read(notificationsControllerProvider(userId).notifier)
                        .markAllRead()
                  : null,
            ),
          ),
          const SliverToBoxAdapter(child: OngoingCardSlot()),
          SliverToBoxAdapter(
            child: ChipsRow(
              chips: isNotif
                  ? [for (final c in chips) c.data]
                  : _activityChips(),
              activeKey: isNotif ? _chip.name : _activityFilter,
              onChanged: (key) {
                if (isNotif) {
                  setState(() => _chip = NotificationChip.values.byName(key));
                  return;
                }
                setState(() => _activityFilter = key);
                ref
                    .read(activityLogControllerProvider.notifier)
                    .changeCategory(key == 'all' ? null : key);
              },
            ),
          ),
          if (!isNotif) ...[
            SliverToBoxAdapter(
              child: ActivitySummaryCard(state: activityState),
            ),
            // KAN-873: search is wired to the controller; the category is kept.
            SliverToBoxAdapter(
              child: ActivitySearchRow(
                query: activityState.query,
                onChanged: (String q) => ref
                    .read(activityLogControllerProvider.notifier)
                    .changeQuery(q),
                onClear: () => ref
                    .read(activityLogControllerProvider.notifier)
                    .changeQuery(''),
              ),
            ),
          ],
          if (isNotif)
            ...buildNotificationCenterSlivers(
              context,
              state: notificationState,
              activities: _highlightSource(activityState),
              chip: _chip,
              chipLabel: chips.firstWhere((c) => c.chip == _chip).data.label,
              offline: offline,
              refreshing: _refreshing,
              loadingMore: _loadingMore,
              now: DateTime.now(),
              onRetry: () => _refreshFromHeader(userId),
              onShowAll: () => setState(() => _chip = NotificationChip.all),
              onLoadMore: () => _loadMore(userId),
              onTapNotification: (n) => _handleNotificationTap(userId, n),
              onTapActivity: _handleActivityTap,
            )
          else ...[
            ..._buildActivitySlivers(activityState),
            const SliverToBoxAdapter(child: ActivitySecurityFooter()),
          ],
          const DabblerGap.sliver(DabblerSpacing.floatingBarClearance),
        ],
      ),
    );
  }

  /// The Activity log rows highlights come from: its loaded list, when it is
  /// not narrowed by a category or a search (F-19: one source, no second
  /// fetch).
  List<ActivityFeedEvent> _highlightSource(ActivityLogState s) =>
      (s.category == 'all' && s.query.isEmpty) ? s.activities : const [];

  /// The Notifications chips (W1-F3): All, Unread and Needs action with
  /// their counts, then the kind chips. There is no Booking chip (F-12).
  List<({NotificationChip chip, ChipData data})> _notifChips(
    NotificationsState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    // NC-03: Needs action counts open decisions, not unread rows.
    final open = state.notifications.where((n) => isOpenDecision(n, now));
    ({NotificationChip chip, ChipData data}) c(
      NotificationChip chip,
      String label,
      String icon, {
      int? count,
    }) => (chip: chip, data: ChipData(chip.name, label, icon, count: count));
    return [
      c(NotificationChip.all, l10n.notif_chip_all, 'message'),
      c(
        NotificationChip.unread,
        l10n.notif_chip_unread,
        'notification',
        count: state.unreadCount,
      ),
      c(
        NotificationChip.needsAction,
        l10n.notif_chip_needs_action,
        'flash',
        count: open.length,
      ),
      c(NotificationChip.social, l10n.notif_chip_social, 'people'),
      c(NotificationChip.messages, l10n.notif_chip_messages, 'messages'),
      c(NotificationChip.games, l10n.notif_chip_games, 'game'),
      c(NotificationChip.meetups, l10n.notif_chip_meetups, 'people'),
      c(NotificationChip.system, l10n.notif_chip_system, 'setting-2'),
    ];
  }

  // KAN-990: the Activity log chips live with the Activity widgets.
  List<ChipData> _activityChips() =>
      activityCategoryChips(AppLocalizations.of(context));

  List<Widget> _buildActivitySlivers(ActivityLogState state) {
    final controller = ref.read(activityLogControllerProvider.notifier);
    return buildActivityLogSlivers(
      context,
      state,
      onTap: _handleActivityTap,
      onRetry: controller.refresh,
      onLoadMore: controller.loadMore,
    );
  }

  /// A tap: the row is marked read and its target checked; a target that
  /// opens is pushed, any other state shows its sheet (design A.1).
  Future<void> _handleNotificationTap(
    String userId,
    AppNotification notification,
  ) async {
    final controller = ref.read(
      notificationsControllerProvider(userId).notifier,
    );
    if (!notification.isRead) controller.markAsRead(notification.id);
    controller.markClicked(notification.id);
    final target = await ref.read(notifTargetProbeProvider)(notification);
    if (!mounted) return;
    if (target == NotifTargetState.available) {
      final route = _resolveNotificationRoute(notification);
      if (route != null) context.push(route);
      return;
    }
    await showNotifTargetSheet(
      context,
      target,
      onRetry: target == NotifTargetState.failed
          ? () => _handleNotificationTap(userId, notification)
          : null,
    );
  }

  String? _resolveNotificationRoute(AppNotification n) {
    final direct = n.actionRoute;
    if (direct != null && direct.trim().isNotEmpty) return direct;
    final ctx = n.payload;
    if (ctx != null && ctx.isNotEmpty) {
      final embedded = ctx['action_route'];
      if (embedded is String && embedded.trim().isNotEmpty) return embedded;
    }
    return NotificationKinds.route(n.kindKey, ctx);
  }

  void _handleActivityTap(ActivityFeedEvent activity) {
    final payload = activity.payload ?? {};
    if (payload['action_route'] is String) {
      context.push(payload['action_route'] as String);
      return;
    }
    switch (activity.subjectType) {
      case 'game':
        context.push(RoutePaths.gameDetail(activity.subjectId));
        break;
      case 'social':
        context.push('/profile');
        break;
    }
  }

  Future<void> _loadMore(String userId) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await ref
          .read(notificationsControllerProvider(userId).notifier)
          .loadMore();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Header Refresh and the banners' Retry: the spinner shows while it runs.
  Future<void> _refreshFromHeader(String userId) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _refresh(userId);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _refresh(String userId) =>
      ref.read(notificationsControllerProvider(userId).notifier).refresh();

  Future<void> _refreshActivity() =>
      ref.read(activityLogControllerProvider.notifier).refresh();
}
