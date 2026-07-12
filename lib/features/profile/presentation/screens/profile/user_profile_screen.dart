import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import '../../../../../utils/constants/route_constants.dart';
import '../../widgets/profile/player_sport_profile_header.dart';
import '../../models/sport_profile_route_args.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show
        userPostsProvider,
        sportsProvider,
        userLikedPostsProvider,
        userCommentedPostsProvider,
        userRepostedPostsProvider;
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/public_activity_card.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  /// Optional profile ID — when provided the screen shows this exact profile
  /// and will NOT redirect to [ProfileScreen] even if [userId] belongs to the
  /// current user (handles the "view own inactive profile" case).
  final String? profileId;

  const UserProfileScreen({super.key, required this.userId, this.profileId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final _activitiesKey = GlobalKey();

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

    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    _animationController.forward();

    // Check if viewing own profile and load data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfileData();
      _checkOwnProfile();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkOwnProfile() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || currentUser.id != widget.userId) return;

    // A specific profileId was requested — if it is not the active profile
    // the caller explicitly wants to view an inactive persona, so stay here.
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!mounted) return;

    if (widget.profileId != null && widget.profileId != myProfileId) {
      // Viewing own inactive profile — do NOT redirect to ProfileScreen.
      return;
    }

    final loaded = ref.read(profileControllerProvider);
    final viewedProfileId = loaded.profile?.id;

    // If the loaded profile matches the active profile, redirect to own screen.
    if (viewedProfileId != null && viewedProfileId == myProfileId) {
      context.go(RoutePaths.profile);
    }
  }

  Future<void> _loadProfileData() async {
    final profileController = ref.read(profileControllerProvider.notifier);
    final sportsController = ref.read(sportsProfileControllerProvider.notifier);

    await Future.wait<void>([
      profileController.loadProfile(
        widget.userId,
        filterActive: false,
        profileId: widget.profileId,
      ),
      sportsController.loadSportsProfiles(widget.userId),
    ]);
  }

  Future<void> _onRefresh() async {
    _refreshController.reset();
    _refreshController.forward();
    await _loadProfileData();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final sportProfileHeaderAsync = ref.watch(
      sportProfileHeaderProvider(widget.userId),
    );

    // Show loading state
    if (profileState.isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state
    if (profileState.errorMessage != null && profileState.profile == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.danger_copy, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).user_profile_error_not_found_title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  profileState.errorMessage ?? AppLocalizations.of(context).user_profile_error_unable_to_load,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Iconsax.arrow_left_copy),
                  label: Text(AppLocalizations.of(context).user_profile_btn_go_back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return _buildWideLayout(
        context,
        colorScheme,
        profileState,
        sportsState,
        sportProfileHeaderAsync,
      );
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
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 12),
                        _buildProfileHeroCard(
                          context,
                          profileState,
                          sportsState,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildActionButtons(context),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildSportProfileHeaderSection(
                            context,
                            sportProfileHeaderAsync,
                          ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: _buildTabbedPostsSection(context),
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

  // ── Wide-screen layout ───────────────────────────────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    ColorScheme colorScheme,
    ProfileState profileState,
    SportsProfileState sportsState,
    AsyncValue<SportProfileHeaderData?> sportProfileHeaderAsync,
  ) {
    return AdaptiveScaffold(
      currentIndex: -1, // Viewing another user's profile — no nav item selected
      onDestinationSelected: (i) => onAdaptiveDestinationSelected(context, i),
      destinations: kAdaptiveDestinations,
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
        sportProfileHeaderAsync,
      ),
    );
  }

  /// Center column on wide screens: tabbed posts.
  Widget _buildWideBody(BuildContext context, ColorScheme colorScheme) {
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
                  child: _buildTabbedPostsSection(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right panel on wide screens: profile hero + action buttons + sport header.
  Widget _buildWideRightPanel(
    BuildContext context,
    ColorScheme colorScheme,
    ProfileState profileState,
    SportsProfileState sportsState,
    AsyncValue<SportProfileHeaderData?> sportProfileHeaderAsync,
  ) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeroCard(context, profileState, sportsState),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildActionButtons(context),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSportProfileHeaderSection(
                context,
                sportProfileHeaderAsync,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Iconsax.arrow_left_copy),
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
                if (profile?.username != null && profile!.username!.isNotEmpty)
                  Text(
                    '${profile.username}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _showMoreOptions(context),
            icon: const Icon(Iconsax.more_copy),
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

          // ── Avatar + Name/Pills/Meta row ──
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
                          : 'User',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onTop,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Pills: persona type + primary sport ──
                    _buildInfoPills(context, profile, colorScheme, textTheme),
                    const SizedBox(height: 8),

                    // ── Location, Age, Online indicator ──
                    _buildUserMetaRow(context, profile, textTheme, colorScheme),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildAvatar(context, profile),
            ],
          ),
          const SizedBox(height: 8),

          // ── Bio ──
          if (profile?.bio?.isNotEmpty == true)
            Text(
              profile!.bio!,
              style: textTheme.bodyMedium?.copyWith(color: onTop),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),

          // ── Posts / Following / Followers counters ──
          _buildPostsAndFollowingCounter(
            context,
            colorScheme,
            textTheme,
            onTop,
          ),
          const SizedBox(height: 20),

          // ── Stats ──
          _buildUnifiedStats(context, profileState, sportsState),
          const SizedBox(height: 20),

          // ── Sports section ──
          _buildSportsChipsSection(context, profile, colorScheme, textTheme),
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
      context: AvatarContext.social,
    );
  }

  Widget _buildPostsAndFollowingCounter(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color baseOnTop,
  ) {
    final profileId = ref.watch(profileControllerProvider).profile?.id;
    final postsAsync = profileId != null
        ? ref.watch(userPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);
    final followingCountAsync = profileId != null
        ? ref.watch(followingCountProvider(profileId))
        : const AsyncData<int>(0);
    final followersCountAsync = profileId != null
        ? ref.watch(followersCountProvider(profileId))
        : const AsyncData<int>(0);

    final postsCount = postsAsync.maybeWhen(
      data: (posts) => posts.length,
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
            final ctx = _activitiesKey.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$postsCount',
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).profile_post_count(postsCount),
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop.withValues(alpha: 0.8),
                  ),
                ),
              ],
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$followingCount',
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).profile_following_label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop.withValues(alpha: 0.8),
                  ),
                ),
              ],
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$followersCount',
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).profile_follower_count(followersCount),
                  style: textTheme.bodyMedium?.copyWith(
                    color: baseOnTop.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMetaRow(
    BuildContext context,
    UserProfile? profile,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final baseOnTop = colorScheme.onSurface;

    return Wrap(
      spacing: 9,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Online / Last seen indicator
        if (profile != null)
          _buildOnlineIndicator(profile, textTheme, baseOnTop),
        if (profile?.username != null && profile!.username!.isNotEmpty)
          Text(
            '@${profile.username}',
            style: textTheme.labelSmall?.copyWith(
              color: baseOnTop.withValues(alpha: 0.7),
            ),
          ),
        if (profile?.city?.isNotEmpty == true ||
            profile?.country?.isNotEmpty == true)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.location_copy,
                size: 16,
                color: baseOnTop.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                _formatLocation(profile!.city, profile.country),
                style: textTheme.labelSmall?.copyWith(
                  color: baseOnTop.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        if (profile?.age != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.cake_copy,
                size: 16,
                color: baseOnTop.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '${profile!.age!} ${AppLocalizations.of(context).user_profile_age_suffix}',
                style: textTheme.bodySmall?.copyWith(
                  color: baseOnTop.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOnlineIndicator(
    UserProfile profile,
    TextTheme textTheme,
    Color baseOnTop,
  ) {
    final isOnline = profile.isOnline;
    final lastSeenText = profile.getLastSeenText();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing dot for online, static grey dot for offline
        _OnlineStatusDot(isOnline: isOnline),
        const SizedBox(width: 4),
        Text(
          lastSeenText,
          style: textTheme.labelSmall?.copyWith(
            color: isOnline
                ? const Color(0xFF4CAF50)
                : baseOnTop.withValues(alpha: 0.5),
            fontWeight: isOnline ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
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

    // Resolve UUID → Sport object to get name_en and emoji
    final sportsAsync = ref.watch(sportsProvider);
    final allSports = sportsAsync.valueOrNull ?? [];
    final matchedSport = (primarySportId != null && primarySportId.isNotEmpty)
        ? allSports.cast<dynamic>().firstWhere(
            (s) => s.id == primarySportId,
            orElse: () => null,
          )
        : null;
    final sportName = matchedSport != null ? matchedSport.localizedName(context) as String : null;
    final sportEmoji = matchedSport?.emoji as String?;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Persona type pill
        if (profile?.personaType != null && profile!.personaType!.isNotEmpty)
          _buildInfoPill(
            context,
            label: personaLabel(context, profile.personaType),
            colorScheme: colorScheme,
            textTheme: textTheme,
            baseOnTop: baseOnTop,
          ),
        // Primary sport pill — resolved from public.sports via name_en
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

  Widget _buildUnifiedStats(
    BuildContext context,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    final profile = profileState.profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    final statistics = profile.statistics;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final l10n = AppLocalizations.of(context);
    final allStats = [
      _StatItem(
        label: l10n.user_profile_stat_games,
        value: statistics.totalGamesPlayed.toString(),
        icon: Iconsax.medal_star_copy,
      ),
      _StatItem(
        label: l10n.user_profile_stat_win_rate,
        value: statistics.winRateFormatted,
        icon: Iconsax.cup_copy,
      ),
      _StatItem(
        label: l10n.user_profile_stat_sports,
        value: sportsState.profiles.length.toString(),
        icon: Iconsax.game_copy,
      ),
      _StatItem(
        label: l10n.user_profile_stat_reliability,
        value: '${statistics.getReliabilityScore().round()}%',
        icon: Iconsax.verify_copy,
      ),
      _StatItem(
        label: l10n.user_profile_stat_activity,
        value: statistics.getActivityLevel(),
        icon: Iconsax.flash_copy,
      ),
      _StatItem(
        label: l10n.user_profile_stat_last_play,
        value: statistics.lastActiveFormatted,
        icon: Iconsax.clock_copy,
      ),
    ];

    return Column(
      children: [
        Row(
          children: allStats
              .sublist(0, 3)
              .map(
                (stat) => Expanded(
                  child: _buildStatCard(stat, colorScheme, textTheme),
                ),
              )
              .toList(),
        ),
        Row(
          children: allStats
              .sublist(3)
              .map(
                (stat) => Expanded(
                  child: _buildStatCard(stat, colorScheme, textTheme),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    _StatItem stat,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final baseOnTop = colorScheme.onSurface;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stat.value,
              style: textTheme.labelMedium?.copyWith(
                color: baseOnTop,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: textTheme.labelSmall?.copyWith(
                color: baseOnTop,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportsChipsSection(
    BuildContext context,
    UserProfile? profile,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final onTop = colorScheme.onSurface;
    final interestIds = profile?.interests ?? [];
    final sportsAsync = ref.watch(sportsProvider);
    final allSports = sportsAsync.valueOrNull ?? [];
    final sportsById = {for (final s in allSports) s.id: s};
    final resolvedSports = interestIds
        .where((id) => sportsById.containsKey(id))
        .map((id) => sportsById[id]!)
        .toList();

    if (resolvedSports.isEmpty) return const SizedBox.shrink();

    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final chips = resolvedSports.map((sport) {
      final profileId = profile?.id;
      final userId = profile?.userId;
      final personaType = profile?.personaType ?? profile?.profileType ?? '';

      return Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap:
              profileId == null ||
                  userId == null ||
                  (personaType != 'player' && personaType != 'organiser')
              ? null
              : () {
                  context.push(
                    RoutePaths.sportProfile,
                    extra: SportProfileRouteArgs(
                      profileId: profileId,
                      userId: userId,
                      displayName: profile?.displayName ?? '',
                      personaType: personaType,
                      sportId: sport.id,
                      sportKey:
                          sport.sportKey ??
                          sport.nameEn.toLowerCase().replaceAll(' ', '_'),
                      sportName: sport.nameEn,
                      avatarUrl: profile?.avatarUrl,
                      sportEmoji: sport.emoji,
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  Text(sport.emoji!, style: const TextStyle(fontSize: 16)),
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
          ),
        ),
      );
    }).toList();

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
          Text(
            AppLocalizations.of(context).profile_section_sports,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: onTop,
            ),
          ),
          const SizedBox(height: 12),
          if (isWide)
            Wrap(spacing: 8, runSpacing: 8, children: chips)
          else
            SingleChildScrollView(
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
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final myProfileIdAsync = ref.watch(myProfileIdProvider);
    final buttonTextStyle = Theme.of(context).textTheme.labelMedium;

    final myProfileId = myProfileIdAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );
    // Use the same profile ID displayed on screen (from profileControllerProvider)
    // to ensure counters, follow state, and follow actions all reference the same profile.
    final targetProfileId = ref.watch(profileControllerProvider).profile?.id;

    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: OutlinedButton(
            onPressed: () => _sendMessage(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: colorScheme.onSurface,
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Iconsax.message_copy, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: (myProfileId == null || targetProfileId == null)
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: Text(AppLocalizations.of(context).user_profile_btn_loading),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      textStyle: buttonTextStyle,
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : _buildFollowButton(
                    context,
                    myProfileId: myProfileId,
                    targetProfileId: targetProfileId,
                  ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(
    BuildContext context, {
    required String myProfileId,
    required String targetProfileId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonTextStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w600);

    final isBlockedAsync = ref.watch(
      isBlockedProvider((
        currentProfileId: myProfileId,
        targetProfileId: targetProfileId,
      )),
    );
    final isBlocked = isBlockedAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    if (isBlocked) {
      return OutlinedButton.icon(
        onPressed: () => _unblockUser(context),
        icon: const Icon(Iconsax.slash_copy),
        label: Flexible(
          child: Text(
            AppLocalizations.of(context).user_profile_btn_unblock,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          textStyle: buttonTextStyle,
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final isFollowingAsync = ref.watch(
      isFollowingProvider((
        currentProfileId: myProfileId,
        targetProfileId: targetProfileId,
      )),
    );
    final isFollowing = isFollowingAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: () => _toggleFollow(
          context,
          myProfileId: myProfileId,
          targetProfileId: targetProfileId,
          currentlyFollowing: true,
        ),
        icon: const Icon(Iconsax.user_tick_copy),
        label: Flexible(
          child: Text(
            AppLocalizations.of(context).user_profile_btn_following,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: OutlinedButton.styleFrom(
          // minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          textStyle: buttonTextStyle,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _toggleFollow(
        context,
        myProfileId: myProfileId,
        targetProfileId: targetProfileId,
        currentlyFollowing: false,
      ),
      icon: const Icon(Iconsax.user_add_copy),
      label: Flexible(
        child: Text(
          AppLocalizations.of(context).user_profile_btn_follow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: OutlinedButton.styleFrom(
        // minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: buttonTextStyle,
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Tabbed posts section
  Widget _buildTabbedPostsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileId = ref.watch(profileControllerProvider).profile?.id;

    return Column(
      key: _activitiesKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
          tabs: [
            Tab(text: AppLocalizations.of(context).profile_tab_posts),
            Tab(text: AppLocalizations.of(context).profile_tab_replies),
            Tab(text: AppLocalizations.of(context).profile_tab_liked),
            Tab(text: AppLocalizations.of(context).profile_tab_reposts),
            Tab(text: AppLocalizations.of(context).profile_tab_activity),
          ],
        ),
        const SizedBox(height: 4),
        _buildTabContent(context, profileId),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, String? profileId) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPostsTabContent(context, profileId);
      case 1:
        return _buildRepliesTabContent(context, profileId);
      case 2:
        return _buildLikedTabContent(context, profileId);
      case 3:
        return _buildRepostsTabContent(context, profileId);
      case 4:
        return _buildActivityTabContent(context, profileId);
      default:
        return _buildPostsTabContent(context, profileId);
    }
  }

  Widget _buildActivityTabContent(BuildContext context, String? profileId) {
    if (profileId == null) return const SizedBox.shrink();
    final state = ref.watch(userActivitiesProvider(profileId));

    if (state.isLoading && state.activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.activities.isEmpty) {
      return _buildEmptyTabContent(context, AppLocalizations.of(context).profile_empty_no_activity);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: state.activities.map((activity) {
        return PublicActivityCard(activity: activity);
      }).toList(),
    );
  }

  Widget _buildPostsTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(postsAsync, AppLocalizations.of(context).profile_empty_no_posts);
  }

  Widget _buildRepliesTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userCommentedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(postsAsync, AppLocalizations.of(context).profile_empty_no_replies);
  }

  Widget _buildLikedTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userLikedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(postsAsync, AppLocalizations.of(context).profile_empty_no_liked);
  }

  Widget _buildRepostsTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userRepostedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(postsAsync, AppLocalizations.of(context).profile_empty_no_reposts);
  }

  Widget _buildPostsList(
    AsyncValue<List<Post>> postsAsync,
    String emptyMessage,
  ) {
    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _buildEmptyTabContent(context, emptyMessage);
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
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(48),
        child: Center(child: Text(AppLocalizations.of(context).profile_error_failed_load_posts)),
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

  Widget _buildSportProfileHeaderSection(
    BuildContext context,
    AsyncValue<SportProfileHeaderData?> headerData,
  ) {
    return headerData.when(
      data: (data) {
        if (data == null) {
          return _buildSportProfileEmptyState(context);
        }
        return PlayerSportProfileHeader(
          profile: data.profile,
          tier: data.tier,
          badges: data.badges,
        );
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _buildSportProfileEmptyState(context),
    );
  }

  Widget _buildSportProfileEmptyState(BuildContext context) {
    return const SizedBox.shrink();
  }

  String _formatLocation(String? city, String? country) {
    final cityStr = city?.trim();
    final countryStr = country?.trim();

    if (cityStr != null &&
        cityStr.isNotEmpty &&
        countryStr != null &&
        countryStr.isNotEmpty) {
      return '$cityStr, $countryStr';
    } else if (cityStr != null && cityStr.isNotEmpty) {
      return cityStr;
    } else if (countryStr != null && countryStr.isNotEmpty) {
      return countryStr;
    }
    return '';
  }

  void _sendMessage(BuildContext context) {
    final userId = widget.userId;
    // Gate chat entry on block status
    final isBlocked = ref.read(isUserBlockedProvider(userId));
    isBlocked.whenData((blocked) {
      if (blocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).user_profile_cannot_message_blocked)),
        );
        return;
      }
      context.push('${RoutePaths.socialChat}/$userId');
    });
  }

  Future<void> _toggleFollow(
    BuildContext context, {
    required String myProfileId,
    required String targetProfileId,
    required bool currentlyFollowing,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      if (currentlyFollowing) {
        // User-level unfollow: removes every follow edge between the two
        // users' persona profiles, not just the active-profile pair —
        // otherwise followers-only content stays visible after unfollowing.
        await supabase.rpc(
          SupabaseConfig.rpcUnfollowUserFn,
          params: {'p_target_profile_id': targetProfileId},
        );
      } else {
        await supabase.from(SupabaseConfig.profileFollowsTable).insert({
          'follower_profile_id': myProfileId,
          'following_profile_id': targetProfileId,
        });
      }

      // Invalidate relevant providers
      ref.invalidate(
        isFollowingProvider((
          currentProfileId: myProfileId,
          targetProfileId: targetProfileId,
        )),
      );
      ref.invalidate(followingListProvider(myProfileId));
      ref.invalidate(followingCountProvider(myProfileId));
      ref.invalidate(followersCountProvider(targetProfileId));
    } catch (_) {
      // Silently fail — providers will stay stale until next refresh
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(AppLocalizations.of(ctx).user_profile_block_dialog_title),
        content: Text(AppLocalizations.of(ctx).user_profile_block_dialog_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).profile_btn_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(ctx).user_profile_block_btn_block),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final targetUserId = widget.userId;
    final repo = ref.read(blockRepositoryProvider);
    final result = await repo.blockUser(targetUserId);

    result.fold(
      (err) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${err.message}')));
        }
      },
      (_) {
        // Invalidate all block-dependent providers
        ref.invalidate(blockedUserIdsProvider);
        ref.invalidate(blockedUsersWithProfilesProvider);
        ref.invalidate(isUserBlockedProvider(targetUserId));
        final myProfileId = ref
            .read(myProfileIdProvider)
            .maybeWhen(data: (v) => v, orElse: () => null);
        if (myProfileId != null) {
          ref.invalidate(
            isBlockedProvider((
              currentProfileId: myProfileId,
              targetProfileId:
                  ref.read(profileControllerProvider).profile?.id ?? '',
            )),
          );
          ref.invalidate(followingListProvider(myProfileId));
          ref.invalidate(followersListProvider(myProfileId));
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).user_profile_blocked_snack)));
        }
      },
    );
  }

  Future<void> _unblockUser(BuildContext context) async {
    final targetUserId = widget.userId;
    final repo = ref.read(blockRepositoryProvider);
    final result = await repo.unblockUser(targetUserId);

    result.fold(
      (err) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${err.message}')));
        }
      },
      (_) {
        ref.invalidate(blockedUserIdsProvider);
        ref.invalidate(blockedUsersWithProfilesProvider);
        ref.invalidate(isUserBlockedProvider(targetUserId));
        final myProfileId = ref
            .read(myProfileIdProvider)
            .maybeWhen(data: (v) => v, orElse: () => null);
        if (myProfileId != null) {
          ref.invalidate(
            isBlockedProvider((
              currentProfileId: myProfileId,
              targetProfileId:
                  ref.read(profileControllerProvider).profile?.id ?? '',
            )),
          );
          ref.invalidate(followingListProvider(myProfileId));
          ref.invalidate(followersListProvider(myProfileId));
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).user_profile_unblocked_snack)));
        }
      },
    );
  }

  void _reportUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ReportDialog(
        targetType: ReportTargetType.user,
        targetId: widget.userId,
        targetUserId: widget.userId,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetUserId = widget.userId;
    final isBlocked = ref.read(isUserBlockedProvider(targetUserId));
    final blocked = isBlocked.valueOrNull ?? false;

    showAdaptiveSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      showDragHandle: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocked)
              ListTile(
                leading: const Icon(Iconsax.close_circle_copy),
                title: Text(AppLocalizations.of(context).user_profile_menu_unblock_user),
                onTap: () async {
                  Navigator.pop(context);
                  await _unblockUser(this.context);
                },
              )
            else
              ListTile(
                leading: const Icon(Iconsax.close_circle_copy),
                title: Text(AppLocalizations.of(context).user_profile_menu_block_user),
                onTap: () async {
                  Navigator.pop(context);
                  await _blockUser(this.context);
                },
              ),
            ListTile(
              leading: const Icon(Iconsax.warning_2_copy),
              title: Text(AppLocalizations.of(context).user_profile_menu_report_user),
              onTap: () {
                Navigator.pop(context);
                _reportUser(this.context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Animated pulsing dot for online status
class _OnlineStatusDot extends StatefulWidget {
  final bool isOnline;
  const _OnlineStatusDot({required this.isOnline});

  @override
  State<_OnlineStatusDot> createState() => _OnlineStatusDotState();
}

class _OnlineStatusDotState extends State<_OnlineStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isOnline) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _OnlineStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline
        ? const Color(0xFF4CAF50)
        : Colors.grey.withValues(alpha: 0.5);

    if (!widget.isOnline) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 4 * _animation.value,
                spreadRadius: 1 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
