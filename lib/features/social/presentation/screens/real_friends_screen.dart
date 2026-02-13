import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/design_system/design_system.dart';
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

class _RealFriendsScreenState extends ConsumerState<RealFriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    final clamped = widget.initialTab.clamp(0, _tabCount - 1);
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: clamped,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Watch myProfileIdProvider reactively so it resolves on first load
    if (!_isViewingOther) {
      ref.watch(myProfileIdProvider);
    }

    return FutureBuilder<ColorScheme>(
      future: AppTheme.getColorScheme('social', brightness),
      builder: (context, snapshot) {
        final socialScheme =
            snapshot.data ?? context.getCategoryTheme('social');
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          colorScheme: socialScheme,
          cardTheme: baseTheme.cardTheme.copyWith(
            color: socialScheme.surfaceContainerLow,
          ),
        );

        return Theme(
          data: themed,
          child: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;

              return TwoSectionLayout(
                category: 'social',
                topSection: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAppBar(colorScheme),
                      _buildTabSwitcher(colorScheme),
                      const SizedBox(height: 12),
                      _buildSearchBar(colorScheme),
                    ],
                  ),
                ),
                bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                bottomSection: _buildBottomSection(),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  Widget _buildAppBar(ColorScheme colorScheme) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () {
            context.canPop() ? context.pop() : context.go(RoutePaths.home);
          },
          iconSize: 24,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onSecondaryContainer,
          ),
          icon: const Icon(Iconsax.arrow_left_copy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Community',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB SWITCHER
  // ---------------------------------------------------------------------------

  Widget _buildTabSwitcher(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    final socialScheme = context.getCategoryTheme('social');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: [
            const ButtonSegment(
              value: 0,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Following')],
              ),
            ),
            const ButtonSegment(
              value: 1,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Followers')],
              ),
            ),
            if (!_isViewingOther)
              const ButtonSegment(
                value: 2,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('People')],
                ),
              ),
          ],
          selected: <int>{_tabController.index},
          onSelectionChanged: (Set<int> s) {
            final idx = s.first;
            if (_tabController.index != idx) {
              setState(() => _tabController.index = idx);
            }
          },
          style: ButtonStyle(
            side: WidgetStateProperty.all(
              const BorderSide(color: Colors.transparent),
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return socialScheme.primary;
              }
              return socialScheme.primary.withValues(alpha: 0.08);
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return socialScheme.onPrimary;
              }
              return socialScheme.onSurfaceVariant;
            }),
            textStyle: WidgetStateProperty.all(
              textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: colorScheme.primary.withValues(alpha: 0.12),
          hintText: 'Search by name or username',
          hintStyle: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: const Icon(Iconsax.search_normal_copy),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Iconsax.close_circle_copy),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
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

    switch (_tabController.index) {
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

  // ---------------------------------------------------------------------------
  // FOLLOWING TAB
  // ---------------------------------------------------------------------------

  Widget _buildFollowingTab(String profileId) {
    final async = ref.watch(followingListProvider(profileId));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Could not load following'),
      data: (profiles) {
        final filtered = _localFilter(profiles);
        if (filtered.isEmpty) {
          return _buildEmpty(
            icon: Iconsax.people_copy,
            title: 'Not following anyone yet',
            subtitle: 'Discover people in the People tab!',
          );
        }
        return _buildProfileList(filtered, profileId);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FOLLOWERS TAB
  // ---------------------------------------------------------------------------

  Widget _buildFollowersTab(String profileId) {
    final async = ref.watch(followersListProvider(profileId));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Could not load followers'),
      data: (profiles) {
        final filtered = _localFilter(profiles);
        if (filtered.isEmpty) {
          return _buildEmpty(
            icon: Iconsax.profile_2user_copy,
            title: 'No followers yet',
            subtitle: 'Share your profile to get followers!',
          );
        }
        return _buildProfileList(filtered, profileId);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PEOPLE (DISCOVER) TAB
  // ---------------------------------------------------------------------------

  Widget _buildPeopleTab(String profileId) {
    if (_searchQuery.length >= 2) {
      return _buildSearchResults(profileId);
    }

    return _buildEmpty(
      icon: Iconsax.search_normal_copy,
      title: 'Discover People',
      subtitle: 'Type a name or username above to find people to follow.',
    );
  }

  // ---------------------------------------------------------------------------
  // GLOBAL SEARCH RESULTS
  // ---------------------------------------------------------------------------

  Widget _buildSearchResults(String profileId) {
    final params = (query: _searchQuery, currentProfileId: profileId);
    final async = ref.watch(searchProfilesProvider(params));
    return async.when(
      loading: () => _buildSkeleton(6),
      error: (_, __) => _buildError('Search failed'),
      data: (profiles) {
        if (profiles.isEmpty) {
          return _buildEmpty(
            icon: Iconsax.search_normal_copy,
            title: 'No results',
            subtitle: 'Try a different name or username.',
          );
        }
        return _buildProfileList(profiles, profileId);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED PROFILE LIST
  // ---------------------------------------------------------------------------

  Widget _buildProfileList(
    List<Map<String, dynamic>> profiles,
    String currentProfileId,
  ) {
    return Column(
      children: [
        for (final profile in profiles)
          _ProfileTile(
            profile: profile,
            currentProfileId: currentProfileId,
            onTap: () {
              final userId = profile['user_id'] as String? ?? '';
              _openProfile(userId);
            },
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(count, (_) {
        return Card.filled(
          color: colorScheme.primary.withValues(alpha: 0.08),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                        width: 160,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 120,
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
      }),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.danger_copy,
            size: 64,
            color: colorScheme.error.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final pid = _resolvedProfileId;
              if (pid != null) {
                ref.invalidate(followingListProvider(pid));
                ref.invalidate(followersListProvider(pid));
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE TILE WITH FOLLOW / UNFOLLOW
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
        await supabase
            .from('profile_follows')
            .delete()
            .eq('follower_profile_id', widget.currentProfileId)
            .eq('following_profile_id', _targetProfileId);
      } else {
        await supabase.from('profile_follows').insert({
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
      // Silently fail — UI will stay stale until next refresh
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelf = _targetProfileId == widget.currentProfileId;

    final isFollowingAsync = ref.watch(
      isFollowingProvider((
        currentProfileId: widget.currentProfileId,
        targetProfileId: _targetProfileId,
      )),
    );

    final isFollowing = isFollowingAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return Card.filled(
      color: colorScheme.primary.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: widget.onTap,
        leading: DSAvatar.small(
          imageUrl: _avatarUrl,
          displayName: _displayName,
          context: AvatarContext.social,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(_displayName, overflow: TextOverflow.ellipsis),
            ),
            if (_verified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified, size: 16, color: colorScheme.primary),
            ],
          ],
        ),
        subtitle: Text('@$_username'),
        trailing: isSelf
            ? null
            : _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isFollowing
            ? OutlinedButton(
                onPressed: () => _toggleFollow(true),
                child: const Text('Unfollow'),
              )
            : FilledButton(
                onPressed: () => _toggleFollow(false),
                child: const Text('Follow'),
              ),
      ),
    );
  }
}
