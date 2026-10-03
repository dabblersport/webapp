import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Community screen with Following, Followers, and People (discover) tabs.
/// Social data uses profile_follows; blocking via user_blocks (see block_providers.dart).
///
/// When [profileId] is provided, shows that user's Following/Followers (2 tabs).
/// When [profileId] is null, shows the logged-in user's data with 3 tabs
/// (Following, Followers, People).
///
/// [initialTab] selects the starting tab: 0 = Following, 1 = Followers, 2 = People.
class RealFriendsScreen extends ConsumerStatefulWidget {
  final String? profileId;
  final int initialTab;

  const RealFriendsScreen({super.key, this.profileId, this.initialTab = 0});

  @override
  ConsumerState<RealFriendsScreen> createState() => _RealFriendsScreenState();
}

class _RealFriendsScreenState extends ConsumerState<RealFriendsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late int _tab;

  /// Whether we're viewing another user's data (no People tab).
  bool get _isViewingOther => widget.profileId != null;

  /// Number of tabs: 2 for other users, 3 for self.
  int get _tabCount => _isViewingOther ? 2 : 3;

  /// Resolved profile ID — either the explicit one or the logged-in user's.
  String? get _resolvedProfileId {
    if (widget.profileId != null) return widget.profileId;
    // Use myProfileIdProvider for the logged-in user (not profileControllerProvider
    // which can be overwritten by UserProfileScreen).
    return ref
        .read(myProfileIdProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
  }

  void _openProfile(String userId) {
    if (userId.isEmpty) return;
    context.push('${RoutePaths.userProfile}/$userId');
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabCount - 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch myProfileIdProvider reactively so it resolves on first load
    if (!_isViewingOther) {
      ref.watch(myProfileIdProvider);
    }

    final canPop = Navigator.of(context).canPop();
    final labels = ['Following', 'Followers', if (!_isViewingOther) 'People'];

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Community',
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DabblerSpacing.space6,
              ),
              child: DabblerTabs(
                items: [
                  for (var i = 0; i < labels.length; i++)
                    DabblerTabItem(id: '$i', label: labels[i]),
                ],
                value: '$_tab',
                fullWidth: true,
                label: 'Community',
                onChanged: (id) {
                  final i = int.parse(id);
                  if (_tab != i) setState(() => _tab = i);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DabblerSpacing.space6,
                vertical: DabblerSpacing.space4,
              ),
              child: DabblerSearchField(
                controller: _searchController,
                placeholder: 'Search by name or username',
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                onCleared: () => setState(() => _searchQuery = ''),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                DabblerSpacing.space6,
                0,
                DabblerSpacing.space6,
                DabblerSpacing.space8,
              ),
              child: _buildBottomSection(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM SECTION ROUTER
  // ---------------------------------------------------------------------------

  Widget _buildBottomSection() {
    final profileId = _resolvedProfileId;
    if (profileId == null) return _buildSkeleton(6);

    // If searching globally (People tab behaviour)
    if (_searchQuery.length >= 2) {
      return _buildSearchResults(profileId);
    }

    switch (_tab) {
      case 0:
        return _buildFollowingTab(profileId);
      case 1:
        return _buildFollowersTab(profileId);
      case 2:
        return _buildPeopleTab(profileId);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFollowingTab(String profileId) {
    final async = ref.watch(followingListProvider(profileId));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Could not load following'),
      data: (profiles) {
        final filtered = _localFilter(profiles);
        if (filtered.isEmpty) {
          return const DabblerEmptyState(
            icon: 'people',
            title: 'Not following anyone yet',
            text: 'Discover people in the People tab!',
          );
        }
        return _buildProfileList(filtered, profileId);
      },
    );
  }

  Widget _buildFollowersTab(String profileId) {
    final async = ref.watch(followersListProvider(profileId));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Could not load followers'),
      data: (profiles) {
        final filtered = _localFilter(profiles);
        if (filtered.isEmpty) {
          return const DabblerEmptyState(
            icon: 'profile-2user',
            title: 'No followers yet',
            text: 'Share your profile to get followers!',
          );
        }
        return _buildProfileList(filtered, profileId);
      },
    );
  }

  Widget _buildPeopleTab(String profileId) {
    if (_searchQuery.length >= 2) {
      return _buildSearchResults(profileId);
    }

    return const DabblerEmptyState(
      icon: 'search-normal',
      title: 'Discover People',
      text: 'Type a name or username above to find people to follow.',
    );
  }

  Widget _buildSearchResults(String profileId) {
    final params = (query: _searchQuery, currentProfileId: profileId);
    final async = ref.watch(searchProfilesProvider(params));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Search failed'),
      data: (profiles) {
        if (profiles.isEmpty) {
          return const DabblerEmptyState(
            icon: 'search-normal',
            title: 'No results',
            text: 'Try a different name or username.',
          );
        }
        return _buildProfileList(profiles, profileId);
      },
    );
  }

  Widget _buildProfileList(
    List<Map<String, dynamic>> profiles,
    String currentProfileId,
  ) {
    return Column(
      children: [
        for (final profile in profiles)
          Padding(
            padding: const EdgeInsets.only(bottom: DabblerSpacing.space2),
            child: _ProfileTile(
              profile: profile,
              currentProfileId: currentProfileId,
              onTap: () {
                final userId = profile['user_id'] as String? ?? '';
                _openProfile(userId);
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Local client-side filter for the search query within already-loaded lists.
  List<Map<String, dynamic>> _localFilter(List<Map<String, dynamic>> list) {
    if (_searchQuery.length < 2) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((p) {
      final name = (p['display_name'] as String? ?? '').toLowerCase();
      final uname = (p['username'] as String? ?? '').toLowerCase();
      return name.contains(q) || uname.contains(q);
    }).toList();
  }

  Widget _buildSkeleton(int count) {
    return Column(
      children: List.generate(count, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: DabblerSpacing.space4),
          child: Row(
            children: [
              DabblerSkeleton.circle(width: DabblerAvatarSize.md.diameter),
              const DabblerGap.h(DabblerSpacing.space4),
              const Expanded(child: DabblerSkeleton.text(lines: 2)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildError(String message) {
    return DabblerEmptyState.error(
      title: message,
      size: DabblerEmptyStateSize.inline,
      retryLabel: 'Retry',
      onRetry: () {
        final pid = _resolvedProfileId;
        if (pid != null) {
          ref.invalidate(followingListProvider(pid));
          ref.invalidate(followersListProvider(pid));
        }
      },
    );
  }
}

// =============================================================================
// PROFILE ROW WITH FOLLOW / UNFOLLOW
// =============================================================================

class _ProfileTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final String currentProfileId;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.profile,
    required this.currentProfileId,
    required this.onTap,
  });

  @override
  ConsumerState<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends ConsumerState<_ProfileTile> {
  bool _isProcessing = false;

  String get _targetProfileId => widget.profile['id'] as String? ?? '';
  String get _displayName =>
      widget.profile['display_name'] as String? ?? 'Unknown';
  String get _username => widget.profile['username'] as String? ?? 'user';
  String? get _avatarUrl => widget.profile['avatar_url'] as String?;
  bool get _verified => widget.profile['verified'] as bool? ?? false;

  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    if (_isProcessing || _targetProfileId.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      if (isCurrentlyFollowing) {
        // User-level unfollow: removes every follow edge between the two
        // users' persona profiles, not just the active-profile pair.
        await supabase.rpc(
          SupabaseConfig.rpcUnfollowUserFn,
          params: {'p_target_profile_id': _targetProfileId},
        );
      } else {
        await supabase.from(SupabaseConfig.profileFollowsTable).insert({
          'follower_profile_id': widget.currentProfileId,
          'following_profile_id': _targetProfileId,
        });
      }

      // Invalidate relevant providers so lists refresh
      ref.invalidate(
        isFollowingProvider((
          currentProfileId: widget.currentProfileId,
          targetProfileId: _targetProfileId,
        )),
      );
      ref.invalidate(followingListProvider(widget.currentProfileId));
      ref.invalidate(followingCountProvider(widget.currentProfileId));
      ref.invalidate(followersCountProvider(_targetProfileId));
    } catch (_) {
      // The request failed (e.g. a 409 because the check that drove this
      // button's label was stale/wrong) — never claim success. Re-check the
      // real server state instead of trusting the label the user just acted
      // on, and tell them nothing happened.
      ref.invalidate(
        isFollowingProvider((
          currentProfileId: widget.currentProfileId,
          targetProfileId: _targetProfileId,
        )),
      );
      if (mounted) {
        DabblerToastProvider.of(context).show(
          const DabblerToastSpec(
            message: 'Something went wrong. Please try again.',
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _targetProfileId == widget.currentProfileId;

    final isFollowingAsync = ref.watch(
      isFollowingProvider((
        currentProfileId: widget.currentProfileId,
        targetProfileId: _targetProfileId,
      )),
    );

    // Never collapse "still checking" or "check failed" into a confident
    // false — that renders as "Follow" for someone the user already follows
    // (KAN-91). Only a resolved value drives the button; anything else
    // shows a neutral loading state.
    final isFollowing = isFollowingAsync.valueOrNull;

    final Widget? action = isSelf
        ? null
        : (_isProcessing || isFollowing == null)
        ? const DabblerSpinner(size: DabblerSpinnerSize.sm)
        : isFollowing
        ? DabblerButton(
            label: 'Unfollow',
            tone: DabblerButtonTone.outlined,
            size: DabblerButtonSize.small,
            onPressed: () => _toggleFollow(true),
          )
        : DabblerButton(
            label: 'Follow',
            size: DabblerButtonSize.small,
            onPressed: () => _toggleFollow(false),
          );

    return DabblerInputRow(
      onTap: widget.onTap,
      leading: DabblerAvatar(
        seed: _displayName,
        imageUrl: _avatarUrl,
        size: DabblerAvatarSize.md,
      ),
      title: _displayName,
      verified: _verified,
      subtitle: '@$_username',
      trailing: action,
    );
  }
}
