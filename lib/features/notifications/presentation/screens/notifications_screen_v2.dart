import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/notifications/utils/notification_localizer.dart';
import 'package:intl/intl.dart';
import '../providers/notification_center_badge_providers.dart';
import 'package:dabbler/widgets/app_background.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show isFollowingProvider, profileIdByUserIdProvider, myProfileIdProvider;

/// Whether the "Follow back" CTA should show on a follow notification —
/// false when the recipient already follows the notification's sender.
/// KAN-101: the CTA must not render on an already-mutual follow.
final _followBackVisibleProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, actorUserId) async {
      final myProfileId = await ref.watch(myProfileIdProvider.future);
      if (myProfileId == null) return true;
      final targetProfileId = await ref.watch(
        profileIdByUserIdProvider(actorUserId).future,
      );
      if (targetProfileId == null) return true;
      final alreadyFollowing = await ref.watch(
        isFollowingProvider((
          currentProfileId: myProfileId,
          targetProfileId: targetProfileId,
        )).future,
      );
      return !alreadyFollowing;
    });

class NotificationsScreenV2 extends ConsumerStatefulWidget {
  const NotificationsScreenV2({super.key});

  @override
  ConsumerState<NotificationsScreenV2> createState() =>
      _NotificationsScreenV2State();
}

enum _ViewMode { notifications, activity }

class _NotificationsScreenV2State extends ConsumerState<NotificationsScreenV2> {
  final AuthService _authService = AuthService();
  String _selectedFilter = 'all';
  _ViewMode _mode = _ViewMode.notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityFeedControllerProvider.notifier).loadActivities('all');
    });
  }

  void _setMode(_ViewMode mode) {
    setState(() {
      _mode = mode;
      _selectedFilter = 'all';
    });
    if (mode == _ViewMode.activity) {
      ref.read(lastSeenActivityAtProvider.notifier).markNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUserId();

    if (userId == null) {
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).notif_signin_required)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      currentIndex: 6,
      onDestinationSelected: (i) =>
          onAdaptiveDestinationSelected(context, i, activeIndex: 6),
      destinations: kAdaptiveDestinations,
      headerWidget: SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
      ),
      body: _buildScrollBody(
        userId,
        notificationState,
        activityState,
        hideToggle: true,
        forceMode: _ViewMode.notifications,
      ),
      rightPanel: _buildScrollBody(
        userId,
        notificationState,
        activityState,
        hideToggle: true,
        forceMode: _ViewMode.activity,
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    String userId,
    dynamic notificationState,
    dynamic activityState,
  ) {
    return Scaffold(
      backgroundColor: context.appScaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: _buildScrollBody(userId, notificationState, activityState),
      ),
    );
  }

  Widget _buildScrollBody(
    String userId,
    dynamic notificationState,
    dynamic activityState, {
    bool hideToggle = false,
    _ViewMode? forceMode,
  }) {
    final mode = forceMode ?? _mode;
    final isNotif = mode == _ViewMode.notifications;

    return RefreshIndicator(
      onRefresh: () => isNotif ? _refresh(userId) : _refreshActivity(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              title: isNotif ? AppLocalizations.of(context).notif_title_notifications : AppLocalizations.of(context).notif_title_activity_log,
              mode: mode,
              onModeChanged: hideToggle ? null : _setMode,
            ),
          ),
          SliverToBoxAdapter(
            child: _ChipsRow(
              chips:
                  isNotif ? _notifChips(notificationState) : _activityChips(),
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
          if (isNotif)
            SliverToBoxAdapter(
              child: _UnreadCounterRow(
                state: notificationState,
                onMarkAll: () => ref
                    .read(notificationsControllerProvider(userId).notifier)
                    .markAllRead(),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: _ActivitySummaryCard(state: activityState),
            ),
            const SliverToBoxAdapter(child: _ActivitySearchRow()),
          ],
          if (isNotif)
            ..._buildNotificationsSlivers(userId, notificationState)
          else
            ..._buildActivitySlivers(activityState),
          if (isNotif)
            SliverToBoxAdapter(
              child: notificationState.hasMore
                  ? _LoadMoreButton(
                      onPressed: () => ref
                          .read(notificationsControllerProvider(userId).notifier)
                          .loadMore(),
                    )
                  : const SizedBox(height: 24),
            )
          else
            const SliverToBoxAdapter(child: _ActivitySecurityFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  List<_ChipData> _notifChips(dynamic state) {
    final notifs = (state.notifications as List<AppNotification>);
    final l10n = AppLocalizations.of(context);
    int countOf(bool Function(AppNotification) test) =>
        notifs.where((n) => !n.isRead && test(n)).length;
    return [
      _ChipData('all', l10n.notif_chip_all, Iconsax.message_copy, count: state.unreadCount),
      _ChipData(
        'games',
        l10n.notif_chip_games,
        Iconsax.game_copy,
        count: countOf((n) => n.kindKey.startsWith('game')),
      ),
      _ChipData(
        'bookings',
        l10n.notif_chip_bookings,
        Iconsax.calendar_copy,
        count: countOf((n) =>
            n.kindKey.startsWith('booking') || n.kindKey.startsWith('arena')),
      ),
      _ChipData(
        'social',
        l10n.notif_chip_social,
        Iconsax.people_copy,
        count: countOf((n) =>
            n.kindKey.startsWith('social') || n.kindKey.startsWith('friend')),
      ),
      _ChipData(
        'achieve',
        l10n.notif_chip_achievements,
        Iconsax.cup_copy,
        count: countOf((n) =>
            n.kindKey.startsWith('achievement') ||
            n.kindKey.startsWith('reward') ||
            n.kindKey.startsWith('loyalty')),
      ),
    ];
  }

  List<_ChipData> _activityChips() {
    final l10n = AppLocalizations.of(context);
    return [
      _ChipData('all', l10n.notif_chip_all, Iconsax.activity_copy),
      _ChipData('me', l10n.notif_chip_you, Iconsax.edit_copy),
      _ChipData('game', l10n.notif_chip_games, Iconsax.game_copy),
      _ChipData('booking', l10n.notif_chip_bookings, Iconsax.calendar_copy),
      _ChipData('social', l10n.notif_chip_social, Iconsax.people_copy),
      _ChipData('reward', l10n.notif_chip_rewards, Iconsax.coin_copy),
      _ChipData('security', l10n.notif_chip_security, Iconsax.security_copy),
    ];
  }

  List<Widget> _buildNotificationsSlivers(String userId, dynamic state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.error != null && state.notifications.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorView(
            message: state.error.toString(),
            onRetry: () => ref
                .read(notificationsControllerProvider(userId).notifier)
                .refresh(),
          ),
        ),
      ];
    }

    final filtered =
        _filterNotifications(state.notifications as List<AppNotification>);
    if (filtered.isEmpty) {
      return const [SliverToBoxAdapter(child: _NotifEmptyState())];
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
      widgets.add(SliverToBoxAdapter(
        child: _SectionHeader(title: bucketLabels[key]!, count: items.length),
      ));
      widgets.add(SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => _NotificationRow(
          notification: items[i],
          onTap: () => _handleNotificationTap(userId, items[i]),
        ),
      ));
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
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final activities = state.filteredActivities as List<ActivityFeedEvent>;
    if (activities.isEmpty) {
      return const [SliverToBoxAdapter(child: _ActivityEmptyState())];
    }

    final grouped = <String, List<ActivityFeedEvent>>{};
    for (final a in activities) {
      final label = _activityDayLabel(a.happenedAt);
      grouped.putIfAbsent(label, () => []).add(a);
    }

    final widgets = <Widget>[];
    grouped.forEach((day, items) {
      widgets.add(SliverToBoxAdapter(
        child: _SectionHeader(
          title: day,
          count: items.length,
          suffix: 'events',
        ),
      ));
      widgets.add(SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => _ActivityRow(
          event: items[i],
          isLast: i == items.length - 1,
          onTap: () => _handleActivityTap(items[i]),
        ),
      ));
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
    if (diff == 0) return '${l10n.notif_section_today} · $weekday ${dt.day} $month';
    if (diff == 1) return '${l10n.notif_section_yesterday} · $weekday ${dt.day} $month';
    return '$weekday ${dt.day} $month';
  }

  Future<void> _handleNotificationTap(
    String userId,
    AppNotification notification,
  ) async {
    final controller =
        ref.read(notificationsControllerProvider(userId).notifier);
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
        final actorId = _ctxString(ctx, 'actor_user_id') ??
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
      case 'booking':
        context.push('/bookings/${activity.subjectId}');
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

class _TopBar extends StatelessWidget {
  final String title;
  final _ViewMode mode;
  final ValueChanged<_ViewMode>? onModeChanged;

  const _TopBar({
    required this.title,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Row(
        children: [
          _SquareIconButton(
            icon: Iconsax.arrow_left_2_copy,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (onModeChanged != null)
            _ModeToggle(mode: mode, onChanged: onModeChanged!),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.10),
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 22, color: cs.onSurface),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.10),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(
            context,
            icon: Iconsax.notification_copy,
            active: mode == _ViewMode.notifications,
            color: scheme.primary,
            onTap: () => onChanged(_ViewMode.notifications),
          ),
          const SizedBox(width: 2),
          _toggleBtn(
            context,
            icon: Iconsax.activity_copy,
            active: mode == _ViewMode.activity,
            color: scheme.primary,
            onTap: () => onChanged(_ViewMode.activity),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(
    BuildContext context, {
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 34,
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ChipData {
  final String key;
  final String label;
  final IconData icon;
  final int? count;
  const _ChipData(this.key, this.label, this.icon, {this.count});
}

class _ChipsRow extends StatelessWidget {
  final List<_ChipData> chips;
  final String activeKey;
  final ValueChanged<String> onChanged;
  const _ChipsRow({
    required this.chips,
    required this.activeKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = chips[i];
          return _Chip(
            data: c,
            active: c.key == activeKey,
            onTap: () => onChanged(c.key),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final _ChipData data;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.data, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final bg = active ? scheme.primary : cs.onSurface.withValues(alpha: 0.04);
    final fg = active ? cs.onPrimary : cs.onSurface;
    final borderColor =
        active ? Colors.transparent : cs.onSurface.withValues(alpha: 0.10);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.33),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 15,
              color: active ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 7),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (data.count != null && data.count! > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: active
                      ? cs.onPrimary.withValues(alpha: 0.22)
                      : cs.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.count}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String? suffix;
  const _SectionHeader({
    required this.title,
    required this.count,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: muted,
              ),
            ),
          ),
          Text(
            suffix == null ? '$count' : '$count $suffix',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadCounterRow extends StatelessWidget {
  final dynamic state;
  final VoidCallback onMarkAll;
  const _UnreadCounterRow({required this.state, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final accent = cs.error;
    final unread = state.unreadCount as int;
    final total = (state.notifications as List).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Iconsax.notification_copy,
                size: 15,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '$unread unread',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: onMarkAll,
              icon: Icon(
                Iconsax.tick_circle_copy,
                size: 14,
                color: scheme.primary,
              ),
              label: Text(
                AppLocalizations.of(context).notif_mark_all_read,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$total total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final visual = _visualForKind(notification.kindKey, context);
    final unread = !notification.isRead;
    final actor = _actorFromPayload(notification.payload);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: unread ? cs.primaryContainer.withValues(alpha: 0.18) : null,
          border: BorderDirectional(
            bottom: BorderSide(color: context.colorTokens.stroke, width: 1),
            start: BorderSide(
              color: unread ? cs.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.color.withValues(alpha: 0.20),
                          visual.color.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: visual.color.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 20),
                  ),
                  if (actor != null)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: _AvatarChip(name: actor),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedNotificationTitle(context, notification),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: unread ? 1 : 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (notification.body != null &&
                      notification.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(context, ref, notification),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: visual.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns the quick-action chip for [n], or an empty widget when no
  /// action applies — or, for a follow notification, when the recipient
  /// already follows the sender back (KAN-101).
  Widget _buildQuickAction(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    final label = _actionLabelFor(context, n.kindKey);
    if (label == null) return const SizedBox.shrink();

    if (n.kindKey.startsWith('social.followed')) {
      final actorId = _actorUserId(n.payload);
      if (actorId == null) return _quickAction(context, label);
      final visible = ref.watch(_followBackVisibleProvider(actorId));
      if (visible.valueOrNull != true) return const SizedBox.shrink();
    }

    return _quickAction(context, label);
  }

  String? _actorUserId(Map<String, dynamic>? ctx) {
    if (ctx == null) return null;
    final direct = ctx['actor_user_id'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    for (final key in const ['follower_user_ids', 'actor_user_ids']) {
      final list = ctx[key];
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      }
    }
    return null;
  }

  Widget _quickAction(BuildContext context, String label) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final isPrimary = notification.kindKey.contains('invited') ||
        notification.kindKey.contains('reminder');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: isPrimary
            ? null
            : Border.all(
                color: cs.onSurface.withValues(alpha: 0.10),
                width: 1.5,
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isPrimary ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }

  String? _actionLabelFor(BuildContext context, String kindKey) {
    final l10n = AppLocalizations.of(context);
    if (kindKey.startsWith('friend.requested')) return l10n.notif_action_respond;
    if (kindKey.startsWith('social.followed')) return l10n.notif_action_follow_back;
    if (kindKey.startsWith('game.invited')) return l10n.notif_action_view;
    if (kindKey.startsWith('social.circle_joined')) return l10n.notif_action_see_circle;
    return null;
  }

  String? _actorFromPayload(Map<String, dynamic>? p) {
    if (p == null) return null;
    for (final k in const ['actor_username', 'actor_name', 'actor_user_name']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

class _NotifVisual {
  final IconData icon;
  final Color color;
  const _NotifVisual(this.icon, this.color);
}

_NotifVisual _visualForKind(String kindKey, BuildContext context) {
  final cs = context.colorScheme;
  if (kindKey.startsWith('social.post_liked') ||
      kindKey.startsWith('social.comment_liked')) {
    return _NotifVisual(Iconsax.heart_copy, cs.error);
  }
  if (kindKey.startsWith('social.post_commented') ||
      kindKey.startsWith('social.mentioned')) {
    return _NotifVisual(Iconsax.message_copy, cs.tertiary);
  }
  if (kindKey.startsWith('social.followed') || kindKey.startsWith('friend')) {
    return _NotifVisual(Iconsax.user_add_copy, cs.primary);
  }
  if (kindKey.startsWith('social.circle_joined')) {
    return _NotifVisual(Iconsax.people_copy, cs.primary);
  }
  if (kindKey.startsWith('booking') || kindKey.startsWith('arena')) {
    return const _NotifVisual(Iconsax.ticket_copy, DesignTokens.success);
  }
  if (kindKey.startsWith('game')) {
    return const _NotifVisual(Iconsax.game_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('achievement') || kindKey.startsWith('reward')) {
    return const _NotifVisual(Iconsax.cup_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('loyalty')) {
    return const _NotifVisual(Iconsax.coin_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('system')) {
    return _NotifVisual(Iconsax.warning_2_copy, cs.error);
  }
  return _NotifVisual(Iconsax.notification_copy, cs.primary);
}

class _AvatarChip extends StatelessWidget {
  final String name;
  static const double size = 22;
  const _AvatarChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+|_'))
            .where((s) => s.isNotEmpty)
            .map((s) => s[0])
            .take(2)
            .join()
            .toUpperCase();
    final hue = (name.codeUnits.fold<int>(0, (a, b) => a + b) % 360);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.55).toColor(),
            HSLColor.fromAHSL(1, ((hue + 50) % 360).toDouble(), 0.7, 0.45)
                .toColor(),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final dynamic state;
  const _ActivitySummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final activities = (state.activities as List<ActivityFeedEvent>);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent =
        activities.where((a) => a.happenedAt.isAfter(cutoff)).toList();
    final total = recent.length;
    final rewards = recent.where((a) => a.subjectType == 'reward').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primaryContainer, cs.surfaceContainerHigh],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).activity_last_7_days,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statColumn(
                        context,
                        value: '$total',
                        label: 'events',
                        valueSize: 26,
                        valueColor: cs.onSurface,
                      ),
                      const SizedBox(width: 16),
                      _statColumn(
                        context,
                        value: '+$rewards',
                        label: 'rewards',
                        valueSize: 18,
                        valueColor: DesignTokens.success,
                      ),
                      const SizedBox(width: 16),
                      _statColumn(
                        context,
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.flash_1_copy,
                              size: 14,
                              color: DesignTokens.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_streak(activities)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.warning,
                              ),
                            ),
                          ],
                        ),
                        label: AppLocalizations.of(context).activity_day_streak,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 84,
              height: 46,
              child: CustomPaint(
                painter: _SparklinePainter(
                  color: scheme.primary,
                  data: _bucketByDay(activities, days: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _streak(List<ActivityFeedEvent> all) {
    if (all.isEmpty) return 0;
    final daysWithActivity = all
        .map((a) =>
            DateTime(a.happenedAt.year, a.happenedAt.month, a.happenedAt.day))
        .toSet();
    int streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (daysWithActivity.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<int> _bucketByDay(List<ActivityFeedEvent> all, {required int days}) {
    final buckets = List<int>.filled(days, 0);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    for (final a in all) {
      final d = DateTime(
          a.happenedAt.year, a.happenedAt.month, a.happenedAt.day);
      final diff = d.difference(start).inDays;
      if (diff >= 0 && diff < days) buckets[diff] += 1;
    }
    return buckets;
  }

  Widget _statColumn(
    BuildContext context, {
    String? value,
    Widget? valueWidget,
    required String label,
    double valueSize = 18,
    Color? valueColor,
  }) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        valueWidget ??
            Text(
              value!,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.6,
                color: valueColor ?? cs.onSurface,
              ),
            ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<int> data;
  _SparklinePainter({required this.color, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.fold<int>(1, (a, b) => b > a ? b : a);
    final w = size.width;
    final h = size.height;
    final stepX = data.length > 1 ? w / (data.length - 1) : w;
    final points = <Offset>[
      for (int i = 0; i < data.length; i++)
        Offset(i * stepX, h - (data[i] / maxV) * (h - 6) - 3),
    ];

    final fillPath = Path()..moveTo(0, h);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(w, h);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotFill = Paint()..color = const Color(0xFF000000);
    final dotStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotFill);
      canvas.drawCircle(p, 2.5, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class _ActivitySearchRow extends StatelessWidget {
  const _ActivitySearchRow();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.search_normal_copy,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).activity_search_hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Icon(Iconsax.filter_copy, size: 16, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityFeedEvent event;
  final bool isLast;
  final VoidCallback onTap;
  const _ActivityRow({
    required this.event,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final visual = _activityVisual(event, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.color.withValues(alpha: 0.20),
                          visual.color.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: visual.color.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(visual.icon, size: 16, color: visual.color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: cs.onSurface.withValues(alpha: 0.10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _activityTitle(event),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatHM(event.happenedAt),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                        if (_activityMeta(context, event) != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            _activityMeta(context, event)!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                        if (_activityPill(context, event) != null ||
                            event.timeBucket != 'past') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_activityPill(context, event) != null)
                                _Pill(
                                  label: _activityPill(context, event)!,
                                  color: visual.color,
                                ),
                              if (event.timeBucket == 'upcoming')
                                _Pill(label: AppLocalizations.of(context).activity_pill_upcoming, color: cs.primary),
                              if (event.timeBucket == 'present')
                                _Pill(label: AppLocalizations.of(context).activity_pill_live, color: cs.error),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activityTitle(ActivityFeedEvent a) {
    final p = a.payload ?? {};
    if (p['title'] is String) return p['title'] as String;
    final verb = a.verb.replaceAll('_', ' ');
    final subj = a.subjectType;
    return '${verb[0].toUpperCase()}${verb.substring(1)} $subj';
  }

  String? _activityMeta(BuildContext context, ActivityFeedEvent a) {
    final p = a.payload ?? {};
    final parts = <String>[];
    for (final key in const [
      'description',
      'game_name',
      'venue_name',
      'user_name',
    ]) {
      final v = p[key];
      if (v is String && v.trim().isNotEmpty) {
        parts.add(v.trim());
        break;
      }
    }
    if (p['location'] is String) parts.add('at ${p['location']}');
    if (p['participants_count'] != null) {
      parts.add(AppLocalizations.of(context).activity_participants_count(p['participants_count'] as int));
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? _activityPill(BuildContext context, ActivityFeedEvent a) {
    final p = a.payload ?? {};
    if (p['pill'] is String) return p['pill'] as String;
    final l10n = AppLocalizations.of(context);
    if (a.subjectType == 'reward') return l10n.activity_subject_reward;
    if (a.subjectType == 'security') return l10n.activity_subject_security;
    return null;
  }

  String _formatHM(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

_NotifVisual _activityVisual(ActivityFeedEvent e, BuildContext context) {
  final cs = context.colorScheme;
  switch (e.subjectType) {
    case 'game':
      return const _NotifVisual(Iconsax.game_copy, DesignTokens.warning);
    case 'booking':
      return const _NotifVisual(Iconsax.ticket_copy, DesignTokens.success);
    case 'social':
      return _NotifVisual(Iconsax.people_copy, cs.primary);
    case 'reward':
      return const _NotifVisual(Iconsax.coin_copy, DesignTokens.warning);
    case 'security':
      return const _NotifVisual(Iconsax.security_copy, DesignTokens.success);
    case 'payment':
      return const _NotifVisual(Iconsax.card_copy, DesignTokens.success);
    case 'post':
      return _NotifVisual(Iconsax.edit_copy, cs.primary);
    default:
      return _NotifVisual(
        Iconsax.info_circle_copy,
        cs.onSurface.withValues(alpha: 0.5),
      );
  }
}

class _ActivitySecurityFooter extends StatelessWidget {
  const _ActivitySecurityFooter();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    const green = DesignTokens.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: green.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Iconsax.security_copy, size: 18, color: green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).activity_all_normal_title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                      children: [
                        TextSpan(
                          text: AppLocalizations.of(context).activity_all_normal_body,
                        ),
                        TextSpan(
                          text: AppLocalizations.of(context).activity_manage_devices,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LoadMoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Center(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            side: BorderSide(
              color: cs.onSurface.withValues(alpha: 0.10),
              width: 1.5,
            ),
          ),
          child: Text(
            AppLocalizations.of(context).notif_load_older,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifEmptyState extends StatelessWidget {
  const _NotifEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Iconsax.notification_bing_copy,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).notif_empty_no_notifications,
            style: context.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).notif_empty_subtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Iconsax.activity_copy,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).activity_empty_no_activity,
            style: context.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).activity_empty_subtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(AppLocalizations.of(context).notif_error_prefix(message), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).notif_btn_retry)),
        ],
      ),
    );
  }
}

String _formatTime(BuildContext context, DateTime dateTime) {
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return l10n.time_just_now;
  if (diff.inHours < 1) return l10n.time_minutes_ago(diff.inMinutes);
  if (diff.inDays < 1) return l10n.time_hours_ago(diff.inHours);
  if (diff.inDays < 7) return l10n.time_days_ago(diff.inDays);
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
