import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/widgets/thoughts_input.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/social/presentation/widgets/feed/post_card.dart';
import 'package:dabbler/features/social/services/social_service.dart';
import 'package:dabbler/features/social/services/realtime_likes_service.dart';
import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_center_badge_providers.dart';

/// Modern home screen for Dabbler
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;
  String _selectedPostFilter = 'all'; // all, moment, dab, kickin
  final Map<String, StreamSubscription<PostLikeUpdate>> _likeSubscriptions = {};
  Timer? _refreshDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    // Cancel all realtime subscriptions
    for (final subscription in _likeSubscriptions.values) {
      subscription.cancel();
    }
    _likeSubscriptions.clear();
    super.dispose();
  }

  Future<void> _checkNotificationPermission() async {
    // Only check on mobile platforms
    if (!defaultTargetPlatform.toString().contains('android') &&
        !defaultTargetPlatform.toString().contains('iOS')) {
      return;
    }

    final notificationService = PushNotificationService.instance;
    final shouldShow = await notificationService.shouldShowNotificationPrompt();

    if (!shouldShow || !mounted) return;

    final status = await notificationService.checkPermissionStatus();

    // Only show drawer if permission is not already granted
    if (status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional) {
      // Wait for first frame to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNotificationDrawer();
        }
      });
    }
  }

  Future<void> _showNotificationDrawer() async {
    final didTakeAction = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return NotificationPermissionDrawer(
          onEnableNotifications: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            final granted = await notificationService
                .requestNotificationPermission();

            if (!mounted) return;

            if (granted) {
              await notificationService.saveNotificationPreference('allow');
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications enabled!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              // Don't mark as "allow" unless permission is actually granted.
              // Also avoid re-prompting immediately.
              await notificationService.saveNotificationPreference(
                'remind_later',
              );
            }
          },
          onRemindLater: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference(
              'remind_later',
            );
          },
          onNoThanks: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference('never');
          },
        );
      },
    );

    // If the user dismissed the sheet (tap outside / swipe down) without
    // choosing any explicit action, apply the remind-later cooldown to avoid
    // showing it again immediately when they return to Home.
    if (!mounted) return;
    if (didTakeAction != true) {
      await PushNotificationService.instance.saveNotificationPreference(
        'remind_later',
      );
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {}
  }

  Future<void> _handleRefresh() async {
    // Reload user profile
    await _loadUserProfile();

    // Invalidate providers to refresh data
    ref.invalidate(profileControllerProvider);
    ref.invalidate(userUpcomingGamesProvider);
    ref.invalidate(latestFeedPostsProvider);

    // Small delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    final userId = _authService.getCurrentUserId();
    final hasUnreadNotifications = userId == null
        ? false
        : ref.watch(
            notificationsControllerProvider(
              userId,
            ).select((s) => s.unreadCount > 0),
          );

    final lastSeenActivityAt = ref.watch(lastSeenActivityAtProvider);
    final latestActivityAtAsync = ref.watch(latestActivityAtProvider);
    final hasNewActivity = latestActivityAtAsync.maybeWhen(
      data: (latestAt) =>
          latestAt != null &&
          (lastSeenActivityAt == null || latestAt.isAfter(lastSeenActivityAt)),
      orElse: () => false,
    );

    final showNotificationCenterIndicator =
        hasUnreadNotifications || hasNewActivity;

    // Extract initials from display name
    String? getInitials(String? displayName) {
      if (displayName == null || displayName.isEmpty) return null;
      final parts = displayName.trim().split(' ');
      if (parts.isEmpty) return null;
      if (parts.length == 1) {
        return parts[0][0].toUpperCase();
      }
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push(RoutePaths.profile),
            child: DSAvatar.size48(
              imageUrl: resolveAvatarUrl(
                _userProfile?['avatar_url'] as String?,
              ),
              initials: getInitials(_userProfile?['display_name']),
              backgroundColor: colorScheme.categoryMain.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                'assets/images/logoTypo.svg',
                height: 18,
                fit: BoxFit.contain,
                semanticsLabel: 'Dabbler',
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (FeatureFlags.enableNotificationCenter)
            IconButton.filledTonal(
              onPressed: () => context.push(RoutePaths.notifications),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Iconsax.direct_copy),
                  if (showNotificationCenterIndicator)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primaryContainer,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimaryContainer,
                minimumSize: const Size(48, 48),
              ),
            ),
          if (FeatureFlags.enableNotificationCenter) const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => context.push(RoutePaths.socialFriends),
            icon: const Icon(Iconsax.people_copy),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: colorScheme.onPrimaryContainer,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TwoSectionLayout(
      category: 'main',
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildUpcomingGameSection(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: ThoughtsInput(
              onTap: () => context.push('/social-create-post'),
            ),
          ),
          // Post filters
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildPostFilters(),
          ),
        ],
      ),
      bottomSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickAccessSection(),
          // _buildNewlyJoinedSection(),
          // Main Social Feed - Primary feature
          _buildSocialFeedSection(),
          // Padding(
          //   padding: const EdgeInsets.only(top: 36),
          //   child: _buildRecentGamesSection(),
          // ),
        ],
      ),
      onRefresh: _handleRefresh,
    );
  }

  Widget _buildQuickAccessSection() {
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  Widget _buildNewlyJoinedSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRecentPlayers(),
      builder: (context, snapshot) {
        // Show placeholder avatars even while loading
        final players = snapshot.hasData ? snapshot.data! : [];

        // If no data, show 6 placeholder avatars
        final displayPlayers = players.isEmpty
            ? List.generate(
                6,
                (index) => {
                  'avatar_url': null,
                  'display_name': null,
                  'sport_key': null,
                },
              )
            : players;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Newly joined',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 6),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 44),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayPlayers.length > 6
                    ? 6
                    : displayPlayers.length,
                itemBuilder: (context, index) {
                  final player = displayPlayers[index];
                  final avatarUrl = resolveAvatarUrl(
                    player['avatar_url']?.toString(),
                  );
                  final displayName = (player['display_name'] ?? 'U')
                      .toString()
                      .trim();
                  final initial = displayName.isNotEmpty
                      ? displayName.substring(0, 1).toUpperCase()
                      : 'U';
                  return GestureDetector(
                    onTap: () {
                      if (player['user_id'] != null) {
                        context.push(
                          '${RoutePaths.userProfile}/${player['user_id']}',
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(initial)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostFilters() {
    final postsAsync = ref.watch(latestFeedPostsProvider);

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 24),
                _buildFilterChip(
                  label: 'Most recent',
                  value: 'all',
                  count: posts.length,
                ),
                _buildFilterChip(
                  label: 'Moments',
                  value: 'moment',
                  count: posts
                      .where((p) => p.kind.toLowerCase() == 'moment')
                      .length,
                ),
                _buildFilterChip(
                  label: 'Dabs',
                  value: 'dab',
                  count: posts
                      .where((p) => p.kind.toLowerCase() == 'dab')
                      .length,
                ),
                _buildFilterChip(
                  label: 'Kick-ins',
                  value: 'kickin',
                  count: posts
                      .where((p) => p.kind.toLowerCase() == 'kickin')
                      .length,
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final mainScheme = context.getCategoryTheme('main');
    final isSelected = _selectedPostFilter == value;

    final chipForeground = isSelected
        ? mainScheme.onPrimary
        : mainScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPostFilter = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: chipForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getFilterLabel() {
    switch (_selectedPostFilter) {
      case 'moment':
        return 'Moments';
      case 'dab':
        return 'Dabs';
      case 'kickin':
        return 'Kick-ins';
      default:
        return '';
    }
  }

  Widget _buildSocialFeedSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final postsAsync = ref.watch(latestFeedPostsProvider);

    return postsAsync.when(
      data: (posts) {
        // Filter posts based on selected filter
        final filteredPosts = _selectedPostFilter == 'all'
            ? posts
            : posts
                  .where(
                    (post) => post.kind.toLowerCase() == _selectedPostFilter,
                  )
                  .toList();

        if (posts.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/document-text.svg',
                          width: 48,
                          height: 48,
                          colorFilter: ColorFilter.mode(
                            colorScheme.outline,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to share something with the community.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Posts list
            if (filteredPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No ${_getFilterLabel()} posts yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: filteredPosts.map((post) {
                    // Subscribe to realtime updates for each post
                    _subscribeToPostLikes(post.id);

                    return PostCard(
                      post: post,
                      onLike: () => _handleLikePost(post.id),
                      onComment: () => _handleCommentPost(post.id),
                      onDelete: () {
                        // Refresh feed after deletion
                        ref.invalidate(latestFeedPostsProvider);
                      },
                      onPostTap: () => context.pushNamed(
                        RouteNames.socialPostDetail,
                        pathParameters: {'postId': post.id},
                      ),
                      onProfileTap: () {
                        context.push(
                          '${RoutePaths.userProfile}/${post.authorId}',
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: const [
                _FeedLoadingPlaceholder(),
                _FeedLoadingPlaceholder(),
                _FeedLoadingPlaceholder(),
              ],
            ),
          ),
        ],
      ),
      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to load posts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.refresh(latestFeedPostsProvider),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/refresh.svg',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Retry'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Subscribe to realtime like updates for a specific post
  void _subscribeToPostLikes(String postId) {
    // Don't subscribe twice
    if (_likeSubscriptions.containsKey(postId)) return;

    final subscription = RealtimeLikesService().postUpdates(postId).listen((
      update,
    ) {
      if (!mounted) return;
      // Debounce provider invalidation to batch multiple rapid updates
      _refreshDebounceTimer?.cancel();
      _refreshDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.invalidate(latestFeedPostsProvider);
        }
      });
    });

    _likeSubscriptions[postId] = subscription;
  }

  Future<void> _handleLikePost(String postId) async {
    try {
      final socialService = SocialService();
      await socialService.toggleLike(postId);

      // Realtime service will automatically update all subscribed screens
      // No need to manually refresh - the subscription will trigger updates
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like post: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleCommentPost(String postId) {
    context.pushNamed(
      RouteNames.socialPostDetail,
      pathParameters: {'postId': postId},
    );
  }

  /// Ensure session is fresh before making Supabase queries
  Future<void> _ensureValidSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      // Check if session expires in less than 5 minutes
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (session.expiresAt ?? 0) * 1000,
      );
      final now = DateTime.now();
      final timeToExpiry = expiresAt.difference(now);

      if (timeToExpiry.inMinutes < 5) {
        await _authService.refreshSession();
      }
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> _fetchRecentPlayers() async {
    try {
      await _ensureValidSession();

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select(
            'user_id, display_name, avatar_url, preferred_sport, created_at',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false, nullsFirst: false)
          .limit(6);

      return (response as List).map((item) {
        return {
          'user_id': item['user_id'],
          'display_name': item['display_name'],
          'avatar_url': item['avatar_url'],
          'sport_key': item['preferred_sport'],
          'created_at': item['created_at'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Builds the upcoming game section with real Supabase data
  Widget _buildUpcomingGameSection() {
    final gamesAsync = ref.watch(userUpcomingGamesProvider);

    return gamesAsync.when(
      data: (games) {
        if (games.isEmpty) {
          // Hide section when no upcoming games
          return const SizedBox.shrink();
        }

        // Show collapsible reminder cards (Apple Wallet style)
        return _buildCollapsibleReminderCards(games);
      },
      loading: () {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      },
      error: (error, stack) {
        return const SizedBox.shrink();
      },
    );
  }

  /// Builds upcoming game cards using design system component
  Widget _buildCollapsibleReminderCards(List<Game> games) {
    return Column(
      children: List.generate(games.length, (index) {
        final game = games[index];
        final isFirst = index == 0;

        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: _StatefulUpcomingGameCard(
            game: game,
            isFirst: isFirst,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GameDetailScreen(gameId: game.id),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

/// Stateful wrapper for UpcomingGameCard to handle expand/collapse
class _StatefulUpcomingGameCard extends StatefulWidget {
  final Game game;
  final bool isFirst;
  final VoidCallback onTap;

  const _StatefulUpcomingGameCard({
    required this.game,
    required this.isFirst,
    required this.onTap,
  });

  @override
  State<_StatefulUpcomingGameCard> createState() =>
      _StatefulUpcomingGameCardState();
}

class _StatefulUpcomingGameCardState extends State<_StatefulUpcomingGameCard> {
  bool _isExpanded = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // First card is expanded by default
    _isExpanded = widget.isFirst;
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  String _getCountdownLabel() {
    final now = DateTime.now();
    final gameDateTime = DateTime(
      widget.game.scheduledDate.year,
      widget.game.scheduledDate.month,
      widget.game.scheduledDate.day,
      _parseTime(widget.game.startTime).hour,
      _parseTime(widget.game.startTime).minute,
    );
    final difference = gameDateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  TimeOfDay _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String _getSportEmoji(String? sport) {
    if (sport == null) return '⚽';
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'cricket':
        return '🏏';
      case 'padel':
        return '🎾';
      case 'volleyball':
        return '🏐';
      default:
        return '⚽';
    }
  }

  @override
  Widget build(BuildContext context) {
    final countdownLabel = _getCountdownLabel();
    final dateTime =
        '${DateFormat('EEE, MMM d').format(widget.game.scheduledDate)} - ${widget.game.startTime} - ${widget.game.endTime}';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: _isExpanded
          ? UpcomingGameCard.expanded(
              title: 'Upcoming Game',
              gameName: widget.game.title,
              timeRemaining: countdownLabel,
              sportIcon: AppSportIcon.size18(
                emoji: _getSportEmoji(widget.game.sport),
              ),
              dateTime: dateTime,
              location: widget.game.venueName ?? 'Location TBD',
              width: double.infinity,
            )
          : UpcomingGameCard.collapsed(
              title: 'Upcoming Game',
              gameName: widget.game.title,
              timeRemaining: countdownLabel,
              sportIcon: AppSportIcon.size18(
                emoji: _getSportEmoji(widget.game.sport),
              ),
              width: double.infinity,
            ),
    );
  }
}

class _FeedLoadingPlaceholder extends StatelessWidget {
  const _FeedLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
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
