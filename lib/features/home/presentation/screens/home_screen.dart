import 'dart:async';

import 'package:dabbler/data/models/feed/feed_item.dart';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/services/auth_service.dart';

import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'package:dabbler/core/config/notification_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Modern home screen for Dabbler
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  final AuthService _authService = AuthService();
  UserProfile? _userProfile;

  // ── Tab controller ──────────────────────────────────────────────────────────
  int _activeIndex = 0;
  static const List<FeedTab> _tabs = FeedTab.values;

  // One scroll controller per tab for independent pagination.
  late final List<ScrollController> _scrollControllers;

  FeedTab get _activeTab => _tabs[_activeIndex];

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(_tabs.length, (_) => ScrollController());

    // Attach pagination listeners to each scroll controller.
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      final sc = _scrollControllers[i];
      sc.addListener(() => _onScroll(tab, sc));
    }

    _loadUserProfile();
    _checkNotificationPermission();

    // For You is the default tab — pre-load it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedNotifierProvider.notifier).load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      AppRouter.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to home screen from another screen
    // Reload user profile to sync any changes (e.g., avatar updates from profile edit)
    _loadUserProfile();
  }

  Future<void> _checkNotificationPermission() async {
    // Mobile and web (Chrome) both support push now.
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
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
    final didTakeAction = await showDabblerSheet<bool>(
      context: context,
      detents: const <double>[0.6],
      builder: (context) {
        return NotificationPermissionDrawer(
          onEnableNotifications: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            final granted = await notificationService
                .requestNotificationPermission();

            if (!mounted) return;

            if (granted) {
              await notificationService.saveNotificationPreference(
                NotificationPreference.allow,
              );
              if (!mounted) return;
              DabblerToastProvider.of(
                this.context,
              ).show(const DabblerToastSpec(message: 'Notifications enabled!'));
            } else {
              // Don't mark as "allow" unless permission is actually granted.
              // Also avoid re-prompting immediately.
              await notificationService.saveNotificationPreference(
                NotificationPreference.remindLater,
              );
            }
          },
          onRemindLater: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference(
              NotificationPreference.remindLater,
            );
          },
          onNoThanks: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference(
              NotificationPreference.never,
            );
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
        NotificationPreference.remindLater,
      );
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      // Pass the active persona type so the avatar matches the currently
      // selected persona (player vs organiser) in multi-profile scenarios.
      final activeType = ref.read(activeProfileTypeProvider);
      final raw = await _authService.getUserProfile(personaType: activeType);
      UserProfile? parsed;
      if (raw != null) {
        // UserProfile.fromJson does strict non-null casts on id/user_id/
        // created_at/updated_at; degrade gracefully on a malformed row rather
        // than crashing the home header.
        try {
          parsed = UserProfile.fromJson(raw);
        } catch (e) {
          debugPrint('HomeScreen: failed to parse user profile: $e');
        }
      }
      if (mounted) {
        setState(() {
          _userProfile = parsed;
        });
      }
    } catch (e) {
      debugPrint('HomeScreen: failed to load user profile: $e');
    }
  }

  /// A tab became visible — remember it and lazily load it the first time.
  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    final tab = _activeTab;
    // Lazily load each tab the first time it is shown.
    switch (tab) {
      case FeedTab.forYou:
        // Already loaded in initState; re-load only if empty.
        final s = ref.read(feedNotifierProvider);
        if (s.items.isEmpty && !s.isLoading) {
          ref.read(feedNotifierProvider.notifier).load();
        }
      case FeedTab.following:
        ref.read(followingFeedProvider.notifier).ensureLoaded();
        ref.read(followingActivitiesProvider.notifier).ensureLoaded();
      case FeedTab.nearby:
        ref.read(nearbyFeedProvider.notifier).ensureLoaded();
      case FeedTab.active:
        ref.read(activeFeedProvider.notifier).ensureLoaded();
      case FeedTab.news:
        ref.read(newsTabFeedProvider.notifier).ensureLoaded();
    }
  }

  void _onScroll(FeedTab tab, ScrollController sc) {
    if (!sc.hasClients) return;
    if (sc.position.extentAfter > 500) return;

    switch (tab) {
      case FeedTab.forYou:
        final s = ref.read(feedNotifierProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(feedNotifierProvider.notifier).loadMore();
        }
      case FeedTab.following:
        final s = ref.read(followingFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(followingFeedProvider.notifier).loadMore();
        }
        final sa = ref.read(followingActivitiesProvider);
        if (!sa.isLoading && !sa.isLoadingMore && sa.hasMore) {
          ref.read(followingActivitiesProvider.notifier).loadMore();
        }
      case FeedTab.nearby:
        final s = ref.read(nearbyFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(nearbyFeedProvider.notifier).loadMore();
        }
      case FeedTab.active:
        final s = ref.read(activeFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(activeFeedProvider.notifier).loadMore();
        }
      case FeedTab.news:
        final s = ref.read(newsTabFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(newsTabFeedProvider.notifier).loadMore();
        }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserProfile();
    ref.invalidate(profileControllerProvider);
    switch (_activeTab) {
      case FeedTab.forYou:
        await ref.read(feedNotifierProvider.notifier).load();
      case FeedTab.following:
        await ref.read(followingFeedProvider.notifier).load();
        ref.read(followingActivitiesProvider.notifier).load();
      case FeedTab.nearby:
        await ref.read(nearbyFeedProvider.notifier).load();
      case FeedTab.active:
        await ref.read(activeFeedProvider.notifier).load();
      case FeedTab.news:
        await ref.read(newsTabFeedProvider.notifier).load();
    }
    await Future.delayed(DabblerMotion.delaySettle);
  }

  Widget _buildHeader() {
    return _HomeHeader(
      displayName: _userProfile?.getFullName(),
      avatarUrl: _userProfile?.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final forYouState = ref.watch(feedNotifierProvider);

    return DabblerPage(
      topBar: _buildHeader(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                // The DS rows and tabs carry no screen gutter of their own.
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: DabblerSpacing.space6,
                  ),
                  child: DabblerTabPager(
                    scrollable: true,
                    onChanged: _onTabChanged,
                    items: <DabblerTabItem>[
                      for (final tab in _tabs)
                        DabblerTabItem(id: tab.name, label: tab.label(l)),
                    ],
                    pages: [
                      _ForYouTabBody(
                        state: forYouState,
                        scrollController: _scrollControllers[0],
                        onRefresh: _handleRefresh,
                        onRetry: () =>
                            ref.read(feedNotifierProvider.notifier).load(),
                        onClearBadge: () => ref
                            .read(feedNotifierProvider.notifier)
                            .clearNewPostsBadge(),
                      ),
                      _FollowingFeedTabBody(
                        scrollController: _scrollControllers[1],
                        onRefresh: _handleRefresh,
                        onRetry: () {
                          ref.read(followingFeedProvider.notifier).load();
                          ref.read(followingActivitiesProvider.notifier).load();
                        },
                      ),
                      _NearbyFeedTabBody(
                        state: ref.watch(nearbyFeedProvider),
                        scrollController: _scrollControllers[2],
                        onRefresh: _handleRefresh,
                        onRetry: () =>
                            ref.read(nearbyFeedProvider.notifier).load(),
                      ),
                      _ActiveFeedTabBody(
                        state: ref.watch(activeFeedProvider),
                        scrollController: _scrollControllers[3],
                        onRefresh: _handleRefresh,
                        onRetry: () =>
                            ref.read(activeFeedProvider.notifier).load(),
                      ),
                      _NewsFeedTabBody(
                        state: ref.watch(newsTabFeedProvider),
                        scrollController: _scrollControllers[4],
                        onRefresh: _handleRefresh,
                        onRetry: () =>
                            ref.read(newsTabFeedProvider.notifier).load(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // New-posts indicator floats over the For You tab.
          if (forYouState.hasNewPosts && _activeIndex == 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: DabblerButton(
                  label: 'New posts',
                  icon: 'arrow-circle-up',
                  size: DabblerButtonSize.small,
                  onPressed: () {
                    ref
                        .read(feedNotifierProvider.notifier)
                        .clearNewPostsBadge();
                    _scrollControllers[0].animateTo(
                      0,
                      duration: DabblerMotion.durationOf(
                        context,
                        DabblerMotion.scrollTo,
                      ),
                      curve: DabblerMotion.easeOut,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
} // end _HomeScreenState

// ────────────────────────────────────────────────────────────────────────────
// For You tab — wraps existing FeedState (PostFeed + badge)
// ────────────────────────────────────────────────────────────────────────────
class _ForYouTabBody extends ConsumerWidget {
  const _ForYouTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onClearBadge,
  });

  final FeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onClearBadge;

  Future<void> _confirmUnsubscribe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDabblerSheet<bool>(
      context: context,
      detents: const <double>[0.45],
      builder: (ctx) => _NewsUnsubscribeSheet(
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed == true) {
      await ref.read(updateNewsPreferenceProvider)();
      if (context.mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).news_hidden_snack,
            duration: DabblerMotion.toastLong,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showNews = ref.watch(newsEnabledProvider);

    if (state.isLoading && state.items.isEmpty) {
      return const _FeedSkeletonList();
    }

    final l = AppLocalizations.of(context);
    if (state.error != null && state.items.isEmpty) {
      return _ErrorView(message: l.feed_could_not_load, onRetry: onRetry);
    }

    if (state.items.isEmpty) {
      return _EmptyView(
        iconName: 'document-text',
        message: l.feed_empty_no_posts,
        hint: l.feed_empty_no_posts_hint,
      );
    }

    final feedItems = state.items
        .where((item) => item is! FeedNewsItem || showNews)
        .toList();
    final itemCount = feedItems.length + (state.isLoadingMore ? 1 : 0);

    return DabblerRefresh(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DabblerInsets.listBottom,
        itemCount: itemCount,
        separatorBuilder: (_, index) => const DabblerDivider(),
        itemBuilder: (_, index) {
          if (index == feedItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner()),
            );
          }
          final item = feedItems[index];
          if (item is FeedPostItem) return HomePostRow.resolve(item.post);
          if (item is FeedNewsItem) {
            return HomeNewsCard(
              item: item,
              onDismiss: () => _confirmUnsubscribe(context, ref),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// News unsubscribe confirmation sheet
// ────────────────────────────────────────────────────────────────────────────
class _NewsUnsubscribeSheet extends StatelessWidget {
  const _NewsUnsubscribeSheet({
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space8,
        DabblerSpacing.space5,
        DabblerSpacing.space8,
        DabblerSpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerIcon(
            'notification-status',
            size: DabblerSizing.iconXl,
            color: colors.brandPrimary,
          ),
          const SizedBox(height: DabblerSpacing.space4),
          DabblerText(l.news_hide_sheet_title, style: DabblerType.headline),
          const SizedBox(height: DabblerSpacing.space2),
          DabblerText(
            l.news_hide_sheet_body,
            textAlign: TextAlign.center,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          const SizedBox(height: DabblerSpacing.space8),
          Row(
            children: [
              Expanded(
                child: DabblerButton(
                  label: l.news_hide_cancel,
                  tone: DabblerButtonTone.secondary,
                  fullWidth: true,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: DabblerButton(
                  label: l.news_hide_confirm,
                  fullWidth: true,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowingFeedTabBody extends ConsumerWidget {
  const _FollowingFeedTabBody({
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postState = ref.watch(followingFeedProvider);

    final isLoading = postState.isLoading && postState.posts.isEmpty;

    if (isLoading) return const _FeedSkeletonList();

    // The Following tab shows ONLY posts and reposts from followed users.
    // Activity-log entries (likes, comments, game/meetup creates) are
    // intentionally excluded — followingFeedProvider already returns
    // posts + reposts.
    final merged = <_MergedEntry>[
      for (final p in postState.posts) _PostEntry(p),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (merged.isEmpty) {
      if (postState.error != null) {
        return _ErrorView(message: postState.error!, onRetry: onRetry);
      }
      return const _EmptyView(
        iconName: 'document-text',
        message: 'No posts from people you follow yet.',
        hint: 'Follow more people to see their posts here.',
      );
    }

    final isLoadingMore = postState.isLoadingMore;
    final itemCount = merged.length + (isLoadingMore ? 1 : 0);

    return DabblerRefresh(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DabblerInsets.listBottom,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const DabblerDivider(),
        itemBuilder: (_, index) {
          if (index == merged.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner()),
            );
          }
          final entry = merged[index];
          return switch (entry) {
            _ActivityEntry(:final activity) => HomeActivityRow(
              activity: activity,
            ),
            _PostEntry(:final post) => HomePostRow.resolve(post),
          };
        },
      ),
    );
  }
}

/// One entry in the merged following timeline — either a social [Post] or a
/// [PublicActivity]. Sealed so the render switch is exhaustive (no `as dynamic`).
sealed class _MergedEntry {
  const _MergedEntry();
  DateTime get createdAt;
}

final class _PostEntry extends _MergedEntry {
  const _PostEntry(this.post);
  final Post post;
  @override
  DateTime get createdAt => post.createdAt;
}

final class _ActivityEntry extends _MergedEntry {
  const _ActivityEntry(this.activity);
  final PublicActivity activity;
  @override
  DateTime get createdAt => activity.createdAt;
}

// ────────────────────────────────────────────────────────────────────────────
// Active feed tab — event-type-routed cards
// ────────────────────────────────────────────────────────────────────────────
class _ActiveFeedTabBody extends StatelessWidget {
  const _ActiveFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final ActiveFeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.events.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.events.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.events.isEmpty) {
      return const _EmptyView(
        iconName: 'document-text',
        message: 'Nothing active right now.',
        hint: 'Check back when games or events kick off near you.',
      );
    }

    final events = state.events;
    final itemCount = events.length + (state.isLoadingMore ? 1 : 0);

    return DabblerRefresh(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DabblerInsets.rowVertical,
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          if (index < events.length && events[index] is PostCreatedEvent) {
            return const DabblerDivider();
          }
          return const SizedBox(height: DabblerSpacing.space2);
        },
        itemBuilder: (_, index) {
          if (index == events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner()),
            );
          }
          return ActiveEventCard(event: events[index]);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Nearby feed tab — original post cards with "Near you" chip
// ────────────────────────────────────────────────────────────────────────────
class _NearbyFeedTabBody extends StatelessWidget {
  const _NearbyFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final TabFeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.posts.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.posts.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.posts.isEmpty) {
      return const _EmptyView(
        iconName: 'document-text',
        message: 'Nothing nearby yet.',
        hint: 'Check back when more activity pops up near you.',
      );
    }

    final posts = state.posts;
    final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);

    return DabblerRefresh(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DabblerInsets.listBottom,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const DabblerDivider(),
        itemBuilder: (_, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner()),
            );
          }
          return HomePostRow.resolve(
            posts[index],
            showNearbyChipInHeader: true,
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared empty / error helpers
// ────────────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.iconName,
    required this.message,
    required this.hint,
  });

  final String iconName;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space10),
        child: DabblerEmptyState(icon: iconName, title: message, text: hint),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space8),
        child: DabblerEmptyState(
          title: message,
          action: DabblerButton(
            label: AppLocalizations.of(context).feed_retry,
            tone: DabblerButtonTone.secondary,
            onPressed: onRetry,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Skeleton loader — shown while the initial feed page is fetching
// ────────────────────────────────────────────────────────────────────────────

/// Single skeleton row that matches the approximate layout of a post card.
class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerSkeleton.circle(width: DabblerAvatarSize.md.diameter),
          SizedBox(width: DabblerSpacing.space3),
          Expanded(child: DabblerSkeleton.text(lines: 3)),
        ],
      ),
    );
  }
}

/// Renders a fixed list of [_PostCardSkeleton] items separated by dividers.
/// Used as the initial loading state for all feed tabs.
class _FeedSkeletonList extends StatelessWidget {
  const _FeedSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space8),
      itemCount: 6,
      separatorBuilder: (_, __) => const DabblerDivider(),
      itemBuilder: (_, __) => const _PostCardSkeleton(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// News feed tab — renders NewsCard widgets from published_news
// ────────────────────────────────────────────────────────────────────────────
class _NewsFeedTabBody extends ConsumerWidget {
  const _NewsFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final NewsTabState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.items.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.items.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    final l = AppLocalizations.of(context);
    if (state.items.isEmpty) {
      return _EmptyView(
        iconName: 'document-text',
        message: l.news_empty_title,
        hint: l.news_empty_hint,
      );
    }

    final filtered = state.filteredItems;
    final isUnsubscribed = !ref.watch(newsEnabledProvider);
    // index 0 = filter chips, index 1 = resubscribe banner (when unsubscribed),
    // remaining = news items
    final headerCount = isUnsubscribed ? 2 : 1;
    final itemCount = filtered.length + (state.isLoadingMore ? 1 : 0);

    return DabblerRefresh(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DabblerInsets.listBottom,
        itemCount: itemCount + headerCount,
        itemBuilder: (_, index) {
          if (index == 0) return _NewsFilterChips(state: state);
          if (isUnsubscribed && index == 1) {
            return _NewsResubscribeBanner(
              onResubscribe: () async {
                await ref.read(resubscribeNewsProvider)();
                if (context.mounted) {
                  DabblerToastProvider.of(context).show(
                    DabblerToastSpec(
                      message: AppLocalizations.of(
                        context,
                      ).news_resubscribed_snack,
                      duration: DabblerMotion.toastLong,
                    ),
                  );
                }
              },
            );
          }
          final i = index - headerCount;
          if (i == filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner()),
            );
          }
          return HomeNewsCard(item: filtered[i]);
        },
      ),
    );
  }
}

// Resubscribe banner — shown in News tab when profiles.news == false
class _NewsResubscribeBanner extends StatelessWidget {
  const _NewsResubscribeBanner({required this.onResubscribe});

  final Future<void> Function() onResubscribe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        DabblerSpacing.space1,
        0,
        DabblerSpacing.space2,
      ),
      child: DabblerBanner(
        icon: const DabblerIcon('notification-status'),
        message: l.news_resubscribe_banner,
        action: DabblerBannerAction(
          label: l.news_resubscribe_action,
          onPressed: onResubscribe,
        ),
      ),
    );
  }
}

// Filter chips: one chip per user interest sport + region chips.
// Chips come from profile.interests, not from what's in the news list.
class _NewsFilterChips extends ConsumerWidget {
  const _NewsFilterChips({required this.state});

  final NewsTabState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(newsTabFeedProvider.notifier);

    final interestIds =
        ref.watch(currentUserProfileProvider)?.interests ?? const [];
    final allSports = ref.watch(sportsProvider).valueOrNull ?? [];

    // Sports the user cares about, in interest order
    final interestSports = interestIds
        .map((id) => allSports.where((s) => s.id == id).firstOrNull)
        .whereType<Sport>()
        .toList();

    // Distinct regions from loaded news
    final regions = state.items.expand((e) => e.regions).toSet().toList()
      ..sort();

    if (interestSports.isEmpty && regions.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: DabblerSpacing.space2),
      child: DabblerChip(label: label, selected: selected, onTap: onTap),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        DabblerSpacing.space3,
        0,
        DabblerSpacing.space2,
      ),
      child: Row(
        children: [
          // ── All chip ────────────────────────────────────────────────
          if (interestSports.isNotEmpty)
            chip(
              'All',
              state.selectedSportId == null,
              () => notifier.setFilterSport(null),
            ),

          // ── One chip per interest sport ──────────────────────────────
          ...interestSports.map((sport) {
            final selected = state.selectedSportId == sport.id;
            return chip(
              '${sport.emoji ?? ''} ${sport.localizedName(context)}'.trim(),
              selected,
              () => notifier.setFilterSport(selected ? null : sport.id),
            );
          }),

          // ── Divider before region chips ──────────────────────────────
          if (interestSports.isNotEmpty && regions.isNotEmpty)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: DabblerSpacing.space2),
              child: SizedBox(
                height: DabblerSpacing.space8,
                child: DabblerDivider.vertical(),
              ),
            ),

          // ── Region chips ─────────────────────────────────────────────
          ...regions.map((region) {
            final selected = state.selectedRegion == region;
            return chip(
              region,
              selected,
              () => notifier.setFilterRegion(selected ? null : region),
            );
          }),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Header — wordmark + location row, search / notifications / avatar
// ────────────────────────────────────────────────────────────────────────────
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({this.displayName, this.avatarUrl});

  final String? displayName;

  /// The user's photo; falls back to the profile controller's.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final profile = ref.watch(profileControllerProvider).profile;
    final name =
        displayName ?? profile?.displayName ?? profile?.username ?? 'User';
    final unread = ref.watch(unreadNotificationCountProvider);
    final locState = ref.watch(activeLocationProvider).valueOrNull;
    final locationName = locState is ActiveLocationReady
        ? locState.location.area.name
        : 'Set location';

    final leading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerWordmark(color: colors.brandPrimary),
        const SizedBox(height: DabblerSpacing.space1),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLocationPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerIcon(
                'location',
                weight: DabblerIconWeight.bold,
                size: DabblerSizing.iconXs,
                color: colors.brandPrimary,
              ),
              const SizedBox(width: DabblerSpacing.space1),
              Flexible(
                child: DabblerText(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.caption2,
                  tone: DabblerTextTone.secondary,
                ),
              ),
              const SizedBox(width: DabblerSpacing.space1),
              DabblerIcon(
                'arrow-circle-down',
                size: DabblerSizing.iconXs,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );

    return DabblerNavigationTopBar(
      leading: leading,
      actions: [
        DabblerNavigationAction(
          icon: 'search-normal',
          label: 'Search',
          onPressed: () => context.push(RoutePaths.socialSearch),
        ),
        DabblerNavigationAction(
          icon: 'notification-bing',
          label: 'Notifications',
          unread: unread > 0,
          unreadLabel: unread > 0 ? '$unread unread' : null,
          onPressed: () => context.push(RoutePaths.notifications),
        ),
      ],
      avatarSeed: name,
      avatarImageUrl: avatarUrl ?? profile?.avatarUrl,
      avatarLabel: name,
      onAvatarPressed: () => context.push(RoutePaths.profile),
    );
  }

  void _openLocationPicker(BuildContext context) {
    showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.85],
      builder: (_) => const _LocationPickerHost(),
    );
  }
}

/// Owns the scroll controller [HomeLocationPickerSheet] expects from its host.
class _LocationPickerHost extends StatefulWidget {
  const _LocationPickerHost();

  @override
  State<_LocationPickerHost> createState() => _LocationPickerHostState();
}

class _LocationPickerHostState extends State<_LocationPickerHost> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HomeLocationPickerSheet(scrollController: _controller);
}
