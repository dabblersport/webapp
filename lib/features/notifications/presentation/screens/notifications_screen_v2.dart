import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import '../providers/notification_center_badge_providers.dart';
import '../widgets/notif_chips.dart';
import '../widgets/notif_list_states.dart';
import '../widgets/notif_section_header.dart';
import '../widgets/activity_log_slivers.dart';
import '../widgets/notif_prefs_sheet.dart';
import '../widgets/notif_top_bar.dart';
import '../widgets/notif_empty_state.dart';
import '../widgets/notif_row.dart';
import '../widgets/activity_summary_card.dart';
import '../widgets/activity_search_row.dart';
import '../widgets/activity_security_footer.dart';

class NotificationsScreenV2 extends ConsumerStatefulWidget {
  const NotificationsScreenV2({super.key});

  @override
  ConsumerState<NotificationsScreenV2> createState() =>
      _NotificationsScreenV2State();
}

class _NotificationsScreenV2State extends ConsumerState<NotificationsScreenV2> {
  final AuthService _authService = AuthService();
  String _selectedFilter = 'all';
  ViewMode _mode = ViewMode.notifications;

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
      _selectedFilter = 'all';
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return _buildWideLayout(
        context,
        userId,
        notificationState,
        activityState,
      );
    }
    return _buildMobileLayout(
      context,
      userId,
      notificationState,
      activityState,
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    String userId,
    dynamic notificationState,
    ActivityLogState activityState,
  ) {
    // KAN-420: the adaptive scaffold (side rail + header) is gone with the
    // design-system migration; the two lists keep their side-by-side panes.
    return DabblerPage(
      body: Row(
        children: [
          Expanded(
            child: _buildScrollBody(
              userId,
              notificationState,
              activityState,
              hideToggle: true,
              forceMode: ViewMode.notifications,
            ),
          ),
          const DabblerDivider.vertical(),
          Expanded(
            child: _buildScrollBody(
              userId,
              notificationState,
              activityState,
              hideToggle: true,
              forceMode: ViewMode.activity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    String userId,
    dynamic notificationState,
    ActivityLogState activityState,
  ) {
    return DabblerPage(
      body: _buildScrollBody(userId, notificationState, activityState),
    );
  }

  Widget _buildScrollBody(
    String userId,
    dynamic notificationState,
    ActivityLogState activityState, {
    bool hideToggle = false,
    ViewMode? forceMode,
  }) {
    final mode = forceMode ?? _mode;
    final isNotif = mode == ViewMode.notifications;

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
                  ? AppLocalizations.of(context).notif_title_notifications
                  : AppLocalizations.of(context).notif_title_activity_log,
              mode: mode,
              onModeChanged: hideToggle ? null : _setMode,
              onOpenSettings: () => showNotifPrefsSheet(context),
              onMarkAllRead:
                  (isNotif && (notificationState.unreadCount as int) > 0)
                  ? () => ref
                        .read(notificationsControllerProvider(userId).notifier)
                        .markAllRead()
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: ChipsRow(
              chips: isNotif
                  ? _notifChips(notificationState)
                  : _activityChips(),
              activeKey: _selectedFilter,
              onChanged: (key) {
                setState(() => _selectedFilter = key);
                if (!isNotif) {
                  final cat = key == 'all' ? null : key;
                  ref
                      .read(activityLogControllerProvider.notifier)
                      .changeCategory(cat);
                }
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
            ..._buildNotificationsSlivers(userId, notificationState)
          else
            ..._buildActivitySlivers(activityState),
          if (isNotif)
            SliverToBoxAdapter(
              child: notificationState.hasMore
                  ? LoadMoreButton(
                      onPressed: () => ref
                          .read(
                            notificationsControllerProvider(userId).notifier,
                          )
                          .loadMore(),
                    )
                  : const DabblerGap.v(DabblerSpacing.listBottomInset),
            )
          else
            const SliverToBoxAdapter(child: ActivitySecurityFooter()),
          const DabblerGap.sliver(DabblerSpacing.floatingBarClearance),
        ],
      ),
    );
  }

  List<ChipData> _notifChips(dynamic state) {
    final notifs = (state.notifications as List<AppNotification>);
    final l10n = AppLocalizations.of(context);
    // KAN-978: a kind's chip comes from the registry.
    int countOf(String chip) => notifs
        .where(
          (n) =>
              !n.isRead && NotificationKinds.currentChipOf(n.kindKey) == chip,
        )
        .length;
    return [
      ChipData('all', l10n.notif_chip_all, 'message', count: state.unreadCount),
      ChipData('games', l10n.notif_chip_games, 'game', count: countOf('games')),
      ChipData(
        'bookings',
        l10n.notif_chip_bookings,
        'calendar',
        count: countOf('bookings'),
      ),
      ChipData(
        'social',
        l10n.notif_chip_social,
        'people',
        count: countOf('social'),
      ),
      ChipData(
        'achieve',
        l10n.notif_chip_achievements,
        'cup',
        count: countOf('achieve'),
      ),
    ];
  }

  List<ChipData> _activityChips() {
    final l10n = AppLocalizations.of(context);
    return [
      ChipData('all', l10n.notif_chip_all, 'activity'),
      ChipData('me', l10n.notif_chip_you, 'edit'),
      ChipData('game', l10n.notif_chip_games, 'game'),
      ChipData('booking', l10n.notif_chip_bookings, 'calendar'),
      ChipData('social', l10n.notif_chip_social, 'people'),
      ChipData('reward', l10n.notif_chip_rewards, 'coin'),
      ChipData('security', l10n.notif_chip_security, 'security'),
    ];
  }

  List<Widget> _buildNotificationsSlivers(String userId, dynamic state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const [SliverToBoxAdapter(child: NotifLoadingView())];
    }
    if (state.error != null && state.notifications.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            message: state.error.toString(),
            onRetry: () => ref
                .read(notificationsControllerProvider(userId).notifier)
                .refresh(),
          ),
        ),
      ];
    }

    final filtered = _filterNotifications(
      state.notifications as List<AppNotification>,
    );
    if (filtered.isEmpty) {
      return const [SliverToBoxAdapter(child: NotifEmptyState())];
    }

    final groups = <String, List<AppNotification>>{};
    for (final n in filtered) {
      final key = _bucketLabel(n.createdAt);
      groups.putIfAbsent(key, () => []).add(n);
    }

    final widgets = <Widget>[];
    final l10n = AppLocalizations.of(context);
    final bucketLabels = <String, String>{
      'today': l10n.notif_section_today,
      'yesterday': l10n.notif_section_yesterday,
      'earlier': l10n.notif_section_earlier,
    };
    for (final key in const ['today', 'yesterday', 'earlier']) {
      final items = groups[key];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        SliverToBoxAdapter(
          child: NotifSectionHeader(
            title: bucketLabels[key]!,
            count: items.length,
          ),
        ),
      );
      widgets.add(
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => NotificationRow(
            notification: items[i],
            onTap: () => _handleNotificationTap(userId, items[i]),
          ),
        ),
      );
    }
    return widgets;
  }

  List<AppNotification> _filterNotifications(List<AppNotification> items) {
    if (_selectedFilter == 'all') return items;
    // KAN-978: a kind's chip comes from the registry.
    return items
        .where(
          (n) => NotificationKinds.currentChipOf(n.kindKey) == _selectedFilter,
        )
        .toList();
  }

  String _bucketLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(dtDay).inDays;
    if (diffDays <= 0) return 'today';
    if (diffDays == 1) return 'yesterday';
    return 'earlier';
  }

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

  Future<void> _handleNotificationTap(
    String userId,
    AppNotification notification,
  ) async {
    final controller = ref.read(
      notificationsControllerProvider(userId).notifier,
    );
    if (!notification.isRead) controller.markAsRead(notification.id);
    controller.markClicked(notification.id);
    final route = _resolveNotificationRoute(notification);
    if (route != null && mounted) context.push(route);
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

  Future<void> _refresh(String userId) =>
      ref.read(notificationsControllerProvider(userId).notifier).refresh();

  Future<void> _refreshActivity() =>
      ref.read(activityLogControllerProvider.notifier).refresh();
}
