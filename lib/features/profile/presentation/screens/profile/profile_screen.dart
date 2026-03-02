// import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import '../../../../../app/app_router.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';

import '../../../../../utils/constants/route_constants.dart';

import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsProvider, userPostsProvider;
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';
// Extracted widgets for hero and basics live alongside this screen for now.
// If you re-enable them, ensure the import paths match actual file locations.

import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider that checks if a profile is under takedown
/// Uses autoDispose.family to cache per profileId and clean up when not needed
final profileTakedownProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, profileId) async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      return await moderationService.isContentTakedown(
        ModTarget.profile,
        profileId,
      );
    } catch (e) {
      // If check fails, assume not takedown to avoid blocking content
      return false;
    }
  },
);

/// Provider to get current user's posts count
final myPostsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;

  try {
    final response = await supabase
        .from('posts')
        .select('id')
        .eq('author_user_id', userId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false);

    return (response as List).length;
  } catch (e) {
    return 0;
  }
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin, RouteAware {
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  String? _selectedProfileType; // 'player' or 'organiser'

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    _animationController.forward();

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
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
    AppRouter.routeObserver.unsubscribe(this);
    _animationController.dispose();
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    // Clear cache and refresh profile data to sync with any changes made (e.g., profile edits)
    _refreshProfileWithCacheClear();
  }

  /// Clears the profile cache and reloads fresh data from the server
  Future<void> _refreshProfileWithCacheClear() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Clear the cached profile data to force a fresh fetch
      await clearProfileCache(ref, user.id);

      // Invalidate dependent providers to refresh their data
      ref.invalidate(myPostsCountProvider);
      ref.invalidate(sportProfileHeaderProvider(user.id));
    }
    // Load fresh profile data
    await _loadProfileData();
  }

  Future<void> _loadProfileData({String? profileType}) async {
    final profileController = ref.read(profileControllerProvider.notifier);
    final sportsController = ref.read(sportsProfileControllerProvider.notifier);
    final organiserController = ref.read(
      organiserProfileControllerProvider.notifier,
    );
    final user = ref.read(currentUserProvider);

    if (user != null) {
      // Use selected persona type, or check if activeProfileTypeProvider was
      // updated externally (e.g. from settings), then fall back to local state
      final activeType = ref.read(activeProfileTypeProvider);
      final typeToLoad = profileType ?? activeType ?? _selectedProfileType;

      await profileController.loadProfile(user.id, profileType: typeToLoad);

      // Update selected profile type based on loaded profile's persona_type
      final profileState = ref.read(profileControllerProvider);
      final profile = profileState.profile;
      if (profile != null) {
        final effectiveType = profile.personaType ?? profile.profileType;
        _selectedProfileType = effectiveType;
        ref.read(activeProfileTypeProvider.notifier).state = effectiveType;

        // Load profile-specific data using profile_id
        final profileId = profile.id;
        if (effectiveType == 'organiser') {
          await organiserController.loadOrganiserProfiles(
            user.id,
            profileId: profileId,
          );
        } else {
          await sportsController.loadSportsProfiles(
            user.id,
            profileId: profileId,
          );
        }
      }

      await _loadAverageRating();
    }
  }

  Future<void> _switchProfileType(String profileType) async {
    if (_selectedProfileType == profileType) return;

    setState(() {
      _selectedProfileType = profileType;
    });

    // Update is_active in the database: deactivate old, activate new
    await ref
        .read(personaServiceProvider.notifier)
        .switchActiveProfile(profileType);

    await _loadProfileData(profileType: profileType);
  }

  Future<void> _loadAverageRating() async {
    // Rating data loading (not displayed in top section)
  }

  Future<void> _onRefresh() async {
    _refreshController.reset();
    _refreshController.forward();
    // Clear cache and reload fresh data on pull-to-refresh
    await _refreshProfileWithCacheClear();
  }

  void _showManageProfiles() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageProfilesSheet(),
    ).then((selectedProfileType) {
      if (selectedProfileType != null &&
          selectedProfileType != _selectedProfileType) {
        _switchProfileType(selectedProfileType);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final profileId = profileState.profile?.id;

    // Watch the takedown provider once per profileId
    final takedownAsync = profileId != null
        ? ref.watch(profileTakedownProvider(profileId))
        : const AsyncData<bool>(false);

    // Takedown short-circuit
    if (profileId != null) {
      final isTakedown = takedownAsync.maybeWhen(
        data: (v) => v,
        orElse: () => false,
      );
      if (isTakedown) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: _buildTakedownPlaceholder(context, colorScheme),
          ),
        );
      }
    }

    // Loading spinner while takedown check is in flight
    if (profileId != null && takedownAsync is AsyncLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return _buildWideLayout(context, colorScheme, profileState, sportsState);
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Hero section ──
            SliverToBoxAdapter(
              child: Container(
                color: colorScheme.surface,
                padding: EdgeInsets.only(
                  top: isWide ? 16 : MediaQuery.of(context).padding.top + 12,
                  bottom: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header: only on mobile (desktop has side nav) ──
                        if (!isWide) _buildHeader(context),
                        if (!isWide) const SizedBox(height: 12),
                        _buildProfileHeroCard(
                          context,
                          profileState,
                          sportsState,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Posts section ──
            SliverToBoxAdapter(
              child: Container(
                color: colorScheme.surface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: profileId == null
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _buildTabbedPostsSection(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide-screen layout (AdaptiveScaffold, matching home_screen) ─────────────

  Widget _buildWideLayout(
    BuildContext context,
    ColorScheme colorScheme,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    return AdaptiveScaffold(
      currentIndex: 5, // Profile is index 5
      onDestinationSelected: (i) => _onDesktopNav(context, i),
      destinations: const [
        AdaptiveDestination(
          icon: Iconsax.home_2_copy,
          selectedIcon: Iconsax.home_2,
          label: "What's New",
        ),
        AdaptiveDestination(
          icon: Iconsax.add_circle_copy,
          selectedIcon: Iconsax.add_circle,
          label: 'Create',
          isAction: true,
        ),
        AdaptiveDestination(
          icon: Iconsax.search_status_copy,
          selectedIcon: Iconsax.search_status,
          label: 'Sports',
        ),
        AdaptiveDestination(
          icon: Iconsax.search_normal_1_copy,
          selectedIcon: Iconsax.search_normal_1,
          label: 'Search',
        ),
        AdaptiveDestination(
          icon: Iconsax.notification_copy,
          selectedIcon: Iconsax.notification,
          label: 'Notifications',
        ),
        AdaptiveDestination(
          icon: Iconsax.profile_circle_copy,
          selectedIcon: Iconsax.profile_circle,
          label: 'Profile',
        ),
      ],
      headerWidget: SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
      ),
      body: _buildWideBody(context, colorScheme),
      rightPanel: _buildWideRightPanel(
        context,
        colorScheme,
        profileState,
        sportsState,
      ),
    );
  }

  void _onDesktopNav(BuildContext context, int destIndex) {
    switch (destIndex) {
      case 0:
        context.go(RoutePaths.home);
        break;
      case 1:
        context.push(RoutePaths.socialCreatePost);
        break;
      case 2:
        context.go(RoutePaths.sports);
        break;
      case 3:
        context.push(RoutePaths.socialSearch);
        break;
      case 4:
        context.push(RoutePaths.notifications);
        break;
      case 5:
        // Already on Profile — no-op
        break;
    }
  }

  /// Center column on wide screens: tabbed posts + refresh.
  Widget _buildWideBody(BuildContext context, ColorScheme colorScheme) {
    final profileId = ref.watch(profileControllerProvider).profile?.id;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: profileId == null
                      ? const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _buildTabbedPostsSection(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right panel on wide screens: profile hero card as a floating card on surface.
  Widget _buildWideRightPanel(
    BuildContext context,
    ColorScheme colorScheme,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _buildProfileHeroCard(context, profileState, sportsState),
      ),
    );
  }

  // ── Mobile / shared widgets ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Iconsax.home_copy),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.0),
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(48, 48),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final profileState = ref.watch(profileControllerProvider);
                    final username = profileState.profile?.username;
                    return Text(
                      (username != null && username.isNotEmpty)
                          ? username
                          : 'Profile',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: () => _showManageProfiles(),
            icon: const Icon(Iconsax.convert_copy),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.0),
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(48, 48),
            ),
            tooltip: 'Manage profiles',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Iconsax.setting_copy),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.0),
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeroCard(
    BuildContext context,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = profileState.profile;
    final onTop = colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── Avatar + Name/Pills/Location row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name ──
                    Text(
                      profile?.getDisplayName().isNotEmpty == true
                          ? profile!.getDisplayName()
                          : 'Complete your profile',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Pills: persona type + primary sport ──
                    _buildInfoPills(context, profile, colorScheme, textTheme),
                    const SizedBox(height: 8),

                    // ── Location & Age ──
                    _buildLocationAgeRow(
                      context,
                      profile,
                      colorScheme,
                      textTheme,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildAvatar(context, profile),
            ],
          ),
          const SizedBox(height: 8),

          // ── Bio ──
          Text(
            profile?.bio?.isNotEmpty == true
                ? profile!.bio!
                : 'Add a short bio so teammates know what to expect.',
            style: textTheme.bodyMedium?.copyWith(color: onTop),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // ── Posts / Following / Followers counters ──
          _buildPostsAndFriendsCounter(
            context,
            colorScheme,
            textTheme,
            colorScheme.onSurface,
          ),
          const SizedBox(height: 16),

          // ── Edit profile + Share profile buttons ──
          _buildEditShareButtons(context, colorScheme, textTheme),
          const SizedBox(height: 20),

          // ── Sports section ──
          _buildSportsChipsSection(
            context,
            sportsState,
            colorScheme,
            textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserProfile? profile) {
    final displayName = profile?.getDisplayName();
    final fallbackText = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName
        : 'User';

    return DSAvatar.large(
      imageUrl: profile?.avatarUrl,
      displayName: fallbackText,
      context: AvatarContext.profile,
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color baseOnTop,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: baseOnTop,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPills(
    BuildContext context,
    UserProfile? profile,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final baseOnTop = colorScheme.onSurface;
    final primarySportId = profile?.preferredSport;

    // Look up the Sport object from sportsProvider using the UUID
    final sportsAsync = ref.watch(sportsProvider);
    final allSports = sportsAsync.valueOrNull ?? [];
    final matchedSport = (primarySportId != null && primarySportId.isNotEmpty)
        ? allSports.cast<dynamic>().firstWhere(
            (s) => s.id == primarySportId,
            orElse: () => null,
          )
        : null;

    final sportName = matchedSport?.nameEn as String?;
    final sportEmoji = matchedSport?.emoji as String?;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Persona type pill
        if (profile?.personaType != null && profile!.personaType!.isNotEmpty)
          _buildInfoPill(
            context,
            icon: Iconsax.profile_circle_copy,
            label:
                profile.personaType![0].toUpperCase() +
                profile.personaType!.substring(1),
            colorScheme: colorScheme,
            textTheme: textTheme,
            baseOnTop: baseOnTop,
          ),
        // Primary sport pill with emoji (resolved from public.sports)
        if (sportName != null && sportName.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sportEmoji != null && sportEmoji.isNotEmpty) ...[
                  Text(sportEmoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ],
                Text(
                  sportName,
                  style: textTheme.labelMedium?.copyWith(
                    color: baseOnTop,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPostsAndFriendsCounter(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color baseOnTop,
  ) {
    final postsCountAsync = ref.watch(myPostsCountProvider);
    final profileId = ref.watch(profileControllerProvider).profile?.id;
    final followingCountAsync = profileId != null
        ? ref.watch(followingCountProvider(profileId))
        : const AsyncData<int>(0);
    final followersCountAsync = profileId != null
        ? ref.watch(followersCountProvider(profileId))
        : const AsyncData<int>(0);

    final postsCount = postsCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    final followingCount = followingCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    final followersCount = followersCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return Row(
      children: [
        // Posts counter
        InkWell(
          onTap: () {
            // Scroll to posts tab
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$postsCount ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: postsCount == 1 ? 'Post' : 'Posts',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Following counter
        InkWell(
          onTap: profileId != null
              ? () => context.pushNamed(
                  RouteNames.following,
                  pathParameters: {'profileId': profileId},
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$followingCount ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: 'Following',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Followers counter
        InkWell(
          onTap: profileId != null
              ? () => context.pushNamed(
                  RouteNames.followers,
                  pathParameters: {'profileId': profileId},
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$followersCount ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: followersCount == 1 ? 'Follower' : 'Followers',
                    style: textTheme.bodyMedium?.copyWith(
                      color: baseOnTop,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Location + Age row matching the design (icon + text inline)
  Widget _buildLocationAgeRow(
    BuildContext context,
    UserProfile? profile,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final onTop = colorScheme.onSurface;
    final city = profile?.city;
    final age = profile?.age;

    if ((city == null || city.isEmpty) && age == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (city != null && city.isNotEmpty) ...[
          Icon(Iconsax.location_copy, size: 16, color: onTop),
          const SizedBox(width: 4),
          Text(city, style: textTheme.bodySmall?.copyWith(color: onTop)),
        ],
        if (city != null && city.isNotEmpty && age != null)
          const SizedBox(width: 12),
        if (age != null) ...[
          Icon(Iconsax.calendar_1_copy, size: 16, color: onTop),
          const SizedBox(width: 4),
          Text('$age yo', style: textTheme.bodySmall?.copyWith(color: onTop)),
        ],
      ],
    );
  }

  /// Edit profile + Share profile buttons as shown in the design
  Widget _buildEditShareButtons(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: Icon(
              Iconsax.edit_copy,
              size: 18,
              color: colorScheme.onSurface,
            ),
            label: Text(
              'Edit profile',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement share profile
            },
            icon: Icon(
              Iconsax.share_copy,
              size: 18,
              color: colorScheme.onSurface,
            ),
            label: Text(
              'Share profile',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Sports chips section with label, add button, and horizontal scroll chips
  Widget _buildSportsChipsSection(
    BuildContext context,
    SportsProfileState sportsState,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final onTop = colorScheme.onSurface;
    final profile = ref.watch(profileControllerProvider).profile;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sports',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onTop,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  final profileType =
                      profile?.personaType ?? profile?.profileType ?? 'player';
                  context.push(
                    '/profile/sports-preferences',
                    extra: {'profileType': profileType},
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Icon(Iconsax.add_copy, size: 24, color: onTop),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // Resolve interests UUIDs to Sport objects from public.sports
              final interestIds = profile?.interests ?? [];
              final sportsAsync = ref.watch(sportsProvider);
              final allSports = sportsAsync.valueOrNull ?? [];

              // Build a map of id -> Sport for quick lookup
              final sportsById = {for (final s in allSports) s.id: s};

              final resolvedSports = interestIds
                  .where((id) => sportsById.containsKey(id))
                  .map((id) => sportsById[id]!)
                  .toList();

              if (resolvedSports.isNotEmpty) {
                final isWide = MediaQuery.sizeOf(context).width >= 600;
                final chips = resolvedSports.map((sport) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sport.emoji != null && sport.emoji!.isNotEmpty) ...[
                          Text(
                            sport.emoji!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          sport.nameEn,
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();

                if (isWide) {
                  return Wrap(spacing: 8, runSpacing: 8, children: chips);
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: chips
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: c,
                          ),
                        )
                        .toList(),
                  ),
                );
              }

              return Text(
                'No sports added yet',
                style: textTheme.bodySmall?.copyWith(
                  color: onTop.withValues(alpha: 0.6),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Tabbed posts section for the bottom part of the profile
  Widget _buildTabbedPostsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileId = ref.watch(profileControllerProvider).profile?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab bar
        TabBar(
          controller: _tabController,
          labelColor: colorScheme.onSurface,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Replies'),
            Tab(text: 'Liked'),
            Tab(text: 'Reposts'),
          ],
        ),
        const SizedBox(height: 4),
        // Tab content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildTabContent(context, profileId),
        ),
      ],
    );
  }

  /// Content for the selected tab
  Widget _buildTabContent(BuildContext context, String? profileId) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPostsTabContent(context, profileId);
      case 1:
        return _buildEmptyTabContent(context, 'No replies yet');
      case 2:
        return _buildEmptyTabContent(context, 'No liked posts yet');
      case 3:
        return _buildEmptyTabContent(context, 'No reposts yet');
      default:
        return _buildPostsTabContent(context, profileId);
    }
  }

  Widget _buildPostsTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _buildEmptyTabContent(context, 'No posts yet');
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: posts.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FeedPostCard(post: post),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: Text('Failed to load posts.')),
      ),
    );
  }

  Widget _buildEmptyTabContent(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakedownPlaceholder(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.close_square_copy,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Content Removed',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This content has been removed due to a violation of our community guidelines.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ManageProfilesSheet extends ConsumerStatefulWidget {
  const ManageProfilesSheet({super.key});

  @override
  ConsumerState<ManageProfilesSheet> createState() =>
      _ManageProfilesSheetState();
}

class _ManageProfilesSheetState extends ConsumerState<ManageProfilesSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch user personas when sheet opens
    Future.microtask(() {
      ref.read(personaServiceProvider.notifier).fetchUserPersonas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final personaState = ref.watch(personaServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Manage Profiles',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle_copy),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              availableProfilesAsync.when(
                data: (profiles) {
                  if (profiles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No profiles found',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  // Get available persona options (only if not at limit)
                  final availablePersonas = personaState.canAddNewProfile
                      ? personaState.availablePersonas
                            .where((p) => p.canProceed)
                            .toList()
                      : <PersonaAvailability>[];

                  // Check if at profile limit
                  final isAtLimit = personaState.isAtProfileLimit;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Existing profiles section
                      ...profiles.map((profile) {
                        final effectiveType =
                            profile.personaType ?? profile.profileType;
                        final isActive =
                            effectiveType?.toLowerCase() ==
                            activeProfileType?.toLowerCase();
                        return _ProfileListTile(
                          profile: profile,
                          isActive: isActive,
                          onTap: () {
                            // Pop the sheet and return the persona type
                            // The parent ProfileScreen will handle the full switch
                            Navigator.pop(context, effectiveType);
                          },
                        );
                      }),

                      // Add persona options section (only if not at limit)
                      if (availablePersonas.isNotEmpty && !isAtLimit) ...[
                        const SizedBox(height: 24),
                        Divider(color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Add Profile',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...availablePersonas.map((availability) {
                          return _PersonaOptionTile(
                            availability: availability,
                            onTap: () => _startPersonaFlow(availability),
                          );
                        }),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error loading profiles',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPersonaFlow(PersonaAvailability availability) {
    final personaState = ref.read(personaServiceProvider);

    // Re-check active profile count before navigation
    if (personaState.isAtProfileLimit &&
        availability.actionType == PersonaActionType.add) {
      Navigator.pop(context); // Close the sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PersonaRules.profileLimitMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final primaryProfile = personaState.primaryProfile;

    // Initialize add persona data with shared attributes
    ref
        .read(addPersonaDataProvider.notifier)
        .init(
          targetPersona: availability.targetPersona,
          actionType: availability.actionType,
          convertFrom: availability.convertFrom,
          age: primaryProfile?.age,
          gender: primaryProfile?.gender,
          existingProfileId:
              availability.actionType == PersonaActionType.convert
              ? personaState.activeProfiles
                    .firstWhere(
                      (p) => p.personaType == availability.convertFrom,
                      orElse: () => personaState.activeProfiles.first,
                    )
                    .profileId
              : null,
        );

    Navigator.pop(context); // Close the sheet first

    // Show confirmation for conversion, otherwise start flow directly
    if (availability.actionType == PersonaActionType.convert) {
      _showConversionConfirmDialog(availability);
    } else {
      // Navigate to first screen of add flow (interests selection)
      context.push(RoutePaths.addPersonaInterests);
    }
  }

  void _showConversionConfirmDialog(PersonaAvailability availability) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Convert to ${availability.targetPersona.displayName}?'),
        content: Text(
          'This will deactivate your ${availability.convertFrom?.displayName} profile and create a new ${availability.targetPersona.displayName} profile.\n\n'
          'Your account data (age, gender) will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Navigate to first screen of add flow
              context.push(RoutePaths.addPersonaInterests);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// Tile for displaying an available persona option
class _PersonaOptionTile extends StatelessWidget {
  final PersonaAvailability availability;
  final VoidCallback onTap;

  const _PersonaOptionTile({required this.availability, required this.onTap});

  IconData get _personaIcon {
    switch (availability.targetPersona) {
      case PersonaType.player:
        return Iconsax.user_copy;
      case PersonaType.organiser:
        return Iconsax.calendar_copy;
      case PersonaType.hoster:
        return Iconsax.building_copy;
      case PersonaType.socialiser:
        return Iconsax.people_copy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isConversion = availability.actionType == PersonaActionType.convert;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isConversion
                        ? colorScheme.tertiaryContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _personaIcon,
                    color: isConversion
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            availability.targetPersona.displayName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (isConversion) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Convert',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        availability.targetPersona.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3_copy,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileListTile extends StatelessWidget {
  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileListTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DSAvatar.medium(
                imageUrl: profile.avatarUrl,
                displayName: profile.getDisplayName().isNotEmpty
                    ? profile.getDisplayName()
                    : 'Profile',
                context: AvatarContext.profile,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.getDisplayName().isNotEmpty
                          ? profile.getDisplayName()
                          : 'Profile',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (profile.personaType ?? profile.profileType)
                                ?.toUpperCase() ??
                            'PLAYER',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Radio<bool>(
                value: true,
                groupValue: isActive,
                onChanged: (_) => onTap(),
                activeColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
