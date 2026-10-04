import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../providers/notification_center_badge_providers.dart';
import '../widgets/notif_chips.dart';
import '../widgets/notif_list_states.dart';
import '../widgets/notif_section_header.dart';
import '../widgets/notif_top_bar.dart';
import '../widgets/notif_empty_state.dart';
import '../widgets/notif_row.dart';
import '../widgets/activity_summary_card.dart';
import '../widgets/activity_search_row.dart';
import '../widgets/activity_row.dart';
import '../widgets/activity_security_footer.dart';
import '../widgets/activity_empty_state.dart';

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
      ref.read(activityFeedControllerProvider.notifier).loadActivities('all');
    });
  }

  void _setMode(ViewMode mode) {
    setState(() {
      _mode = mode;
      _selectedFilter = 'all';
    });
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
    final activityState = ref.watch(activityFeedControllerProvider);
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
    dynamic activityState,
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
    dynamic activityState,
  ) {
    return DabblerPage(
      body: _buildScrollBody(userId, notificationState, activityState),
    );
  }

  Widget _buildScrollBody(
    String userId,
    dynamic notificationState,
    dynamic activityState, {
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
                      .read(activityFeedControllerProvider.notifier)
                      .changeCategory(cat);
                }
              },
            ),
          ),
          if (!isNotif) ...[
            SliverToBoxAdapter(
              child: ActivitySummaryCard(state: activityState),
            ),
            const SliverToBoxAdapter(child: ActivitySearchRow()),
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
    int countOf(bool Function(AppNotification) test) =>
        notifs.where((n) => !n.isRead && test(n)).length;
    return [
      ChipData('all', l10n.notif_chip_all, 'message', count: state.unreadCount),
      ChipData(
        'games',
        l10n.notif_chip_games,
        'game',
        count: countOf((n) => n.kindKey.startsWith('game')),
      ),
      ChipData(
        'bookings',
        l10n.notif_chip_bookings,
        'calendar',
        count: countOf(
          (n) =>
              n.kindKey.startsWith('booking') || n.kindKey.startsWith('arena'),
        ),
      ),
      ChipData(
        'social',
        l10n.notif_chip_social,
        'people',
        count: countOf(
          (n) =>
              n.kindKey.startsWith('social') || n.kindKey.startsWith('friend'),
        ),
      ),
      ChipData(
        'achieve',
        l10n.notif_chip_achievements,
        'cup',
        count: countOf(
          (n) =>
              n.kindKey.startsWith('achievement') ||
              n.kindKey.startsWith('reward') ||
              n.kindKey.startsWith('loyalty'),
        ),
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
    return items.where((n) {
      switch (_selectedFilter) {
        case 'games':
          return n.kindKey.startsWith('game');
        case 'bookings':
          return n.kindKey.startsWith('booking') ||
              n.kindKey.startsWith('arena');
        case 'social':
          return n.kindKey.startsWith('social') ||
              n.kindKey.startsWith('friend');
        case 'achieve':
          return n.kindKey.startsWith('achievement') ||
              n.kindKey.startsWith('reward') ||
              n.kindKey.startsWith('loyalty');
        default:
          return true;
      }
    }).toList();
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

  List<Widget> _buildActivitySlivers(dynamic state) {
    if (state.isLoading && state.activities.isEmpty) {
      return const [SliverToBoxAdapter(child: NotifLoadingView())];
    }
    final activities = state.filteredActivities as List<ActivityFeedEvent>;
    if (activities.isEmpty) {
      return const [SliverToBoxAdapter(child: ActivityEmptyState())];
    }

    final grouped = <String, List<ActivityFeedEvent>>{};
    for (final a in activities) {
      final label = _activityDayLabel(a.happenedAt);
      grouped.putIfAbsent(label, () => []).add(a);
    }

    final widgets = <Widget>[];
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
            onTap: () => _handleActivityTap(items[i]),
          ),
        ),
      );
    });
    return widgets;
  }

  String _activityDayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final weekday = DateFormat.E(localeCode).format(dt);
    final month = DateFormat.MMM(localeCode).format(dt);
    if (diff == 0)
      return '${l10n.notif_section_today} · $weekday ${dt.day} $month';
    if (diff == 1)
      return '${l10n.notif_section_yesterday} · $weekday ${dt.day} $month';
    return '$weekday ${dt.day} $month';
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
    return _routeFromKindKey(n.kindKey, ctx);
  }

  String? _routeFromKindKey(String kindKey, Map<String, dynamic>? ctx) {
    switch (kindKey) {
      case 'social.post_liked':
      case 'social.post_commented':
      case 'social.mentioned_in_post':
        final id = _ctxString(ctx, 'entity_id') ?? _ctxString(ctx, 'post_id');
        if (id != null) return '${RoutePaths.socialPostDetail}/$id';
        return null;
      case 'social.comment_liked':
      case 'social.mentioned_in_comment':
        final postId = _ctxString(ctx, 'post_id');
        if (postId != null) return '${RoutePaths.socialPostDetail}/$postId';
        final entityId = _ctxString(ctx, 'entity_id');
        if (entityId != null) return '${RoutePaths.socialPostDetail}/$entityId';
        return null;
      case 'social.followed':
      case 'social.circle_joined':
        final actorId =
            _ctxString(ctx, 'actor_user_id') ??
            _ctxFirstInList(ctx, 'follower_user_ids') ??
            _ctxFirstInList(ctx, 'actor_user_ids');
        if (actorId != null) return '${RoutePaths.userProfile}/$actorId';
        return null;
      case 'friend.requested':
        return RoutePaths.socialFriends;
      case 'friend.accepted':
        final actorId = _ctxString(ctx, 'actor_user_id');
        if (actorId != null) return '${RoutePaths.userProfile}/$actorId';
        return RoutePaths.socialFriends;
      case 'game.invited':
      case 'game.updated':
      case 'game.join_request':
      case 'game.waitlist_promoted':
      case 'game.reminder':
      case 'game.player_joined':
      case 'game.join_accepted':
      case 'game.removed':
        // Game detail lives at /sports/games/:id — RoutePaths.games ('/games')
        // has no route registered. Join requests land on the requests card.
        final id = _ctxString(ctx, 'entity_id') ?? _ctxString(ctx, 'game_id');
        if (id != null) {
          final base = RoutePaths.gameDetail(id);
          return kindKey == 'game.join_request' ? '$base?focus=requests' : base;
        }
        return RoutePaths.gamesTab;
      case 'arena.payment_required':
        final id = _ctxString(ctx, 'entity_id');
        if (id != null) return RoutePaths.gameDetail(id);
        return null;
      case 'reward.badge_awarded':
        return RoutePaths.profile;
      default:
        return null;
    }
  }

  String? _ctxString(Map<String, dynamic>? ctx, String key) {
    if (ctx == null) return null;
    final v = ctx[key];
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    return s.trim().isNotEmpty ? s : null;
  }

  String? _ctxFirstInList(Map<String, dynamic>? ctx, String key) {
    if (ctx == null) return null;
    final v = ctx[key];
    if (v is List && v.isNotEmpty) {
      final first = v.first;
      if (first == null) return null;
      final s = first is String ? first : first.toString();
      return s.trim().isNotEmpty ? s : null;
    }
    return null;
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
      ref.read(activityFeedControllerProvider.notifier).refresh();
}
