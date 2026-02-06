// import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../app/app_router.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../controllers/organiser_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/organiser_profile.dart';
import 'package:dabbler/data/models/profile/profile_statistics.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_rewards_widget.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_check_in_widget.dart';
import '../../widgets/profile/player_sport_profile_header.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/data/models/sport_tags.dart';
import 'package:dabbler/core/design_system/layouts/two_section_layout.dart';
// Extracted widgets for hero and basics live alongside this screen for now.
// If you re-enable them, ensure the import paths match actual file locations.

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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin, RouteAware {
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

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
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    // Refresh profile data to sync with any changes made (e.g., sports preferences)
    _loadProfileData();
  }

  Future<void> _loadProfileData({String? profileType}) async {
    final profileController = ref.read(profileControllerProvider.notifier);
    final sportsController = ref.read(sportsProfileControllerProvider.notifier);
    final organiserController = ref.read(
      organiserProfileControllerProvider.notifier,
    );
    final user = ref.read(currentUserProvider);

    if (user != null) {
      // Use selected profile type or default to current profile's type
      final typeToLoad = profileType ?? _selectedProfileType;

      await profileController.loadProfile(user.id, profileType: typeToLoad);

      // Update selected profile type based on loaded profile
      final profileState = ref.read(profileControllerProvider);
      final profile = profileState.profile;
      if (profile != null) {
        _selectedProfileType = profile.profileType;
        ref.read(activeProfileTypeProvider.notifier).state =
            profile.profileType;

        // Load profile-specific data using profile_id
        final profileId = profile.id;
        if (profile.profileType == 'organiser') {
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

    await _loadProfileData(profileType: profileType);
  }

  Future<void> _loadAverageRating() async {
    // Rating data loading (not displayed in top section)
  }

  Future<void> _onRefresh() async {
    _refreshController.reset();
    _refreshController.forward();
    await _loadProfileData();
  }

  void _showManageProfiles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageProfilesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
    final organiserState = ref.watch(organiserProfileControllerProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userId = profileState.profile?.userId ?? currentUser?.id ?? '';
    final profileType = profileState.profile?.profileType ?? 'player';
    final sportProfileHeaderAsync = userId.isEmpty
        ? const AsyncData<SportProfileHeaderData?>(null)
        : ref.watch(sportProfileHeaderProvider(userId));

    final colorScheme = Theme.of(context).colorScheme;
    final profileId = profileState.profile?.id;

    // Watch the takedown provider once per profileId
    final takedownAsync = profileId != null
        ? ref.watch(profileTakedownProvider(profileId))
        : const AsyncData<bool>(false);

    return profileId != null
        ? takedownAsync.when(
            data: (isTakedown) {
              if (isTakedown) {
                return Scaffold(
                  backgroundColor: colorScheme.surface,
                  body: SafeArea(
                    child: _buildTakedownPlaceholder(context, colorScheme),
                  ),
                );
              }

              return TwoSectionLayout(
                category: 'profile',
                onRefresh: _onRefresh,
                topSection: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _buildProfileHeroCard(context, profileState, sportsState),
                    const SizedBox(height: 16),
                    _buildSportProfileHeaderSection(
                      context,
                      sportProfileHeaderAsync,
                    ),
                  ],
                ),
                bottomSection: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickActions(context),
                        // const SizedBox(height: 24),
                        _buildProfileCompletion(context, profileState),
                        _buildBasicInfo(context, profileState),
                        if (FeatureFlags.enableRewards)
                          _buildRewardsSection(context),
                        _buildSportsProfiles(context, sportsState),
                        _buildStatisticsSummary(context, profileState),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => Scaffold(
              backgroundColor: colorScheme.surface,
              body: const SafeArea(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => TwoSectionLayout(
              category: 'profile',
              onRefresh: _onRefresh,
              topSection: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildProfileTypeSwitcher(context),
                  const SizedBox(height: 24),
                  _buildProfileHeroCard(context, profileState, sportsState),
                ],
              ),
              bottomSection: const SizedBox(),
            ),
          )
        : TwoSectionLayout(
            category: 'profile',
            onRefresh: _onRefresh,
            topSection: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildProfileTypeSwitcher(context),
                  const SizedBox(height: 24),
                  _buildProfileHeroCard(context, profileState, sportsState),
                  if (profileType == 'player') ...[
                    const SizedBox(height: 16),
                    _buildSportProfileHeaderSection(
                      context,
                      sportProfileHeaderAsync,
                    ),
                  ],
                  if (profileType == 'organiser') ...[
                    const SizedBox(height: 16),
                    _buildOrganiserProfileSection(context, organiserState),
                  ],
                ],
              ),
            ),
            bottomSection: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      _buildProfileCompletion(context, profileState),
                      if (profileType == 'organiser' &&
                          FeatureFlags.enableOrganiserGameCreation)
                        _buildGameManagementCard(context),
                      _buildBasicInfo(context, profileState),
                      if (FeatureFlags.enableRewards)
                        _buildRewardsSection(context),
                      if (profileType == 'player')
                        _buildSportsProfiles(context, sportsState),
                      if (profileType == 'organiser')
                        _buildOrganiserProfilesList(context, organiserState),
                      _buildStatisticsSummary(context, profileState),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildProfileTypeSwitcher(BuildContext context) {
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return availableProfilesAsync.when(
      data: (profiles) {
        final hasPlayer = profiles.any(
          (p) => p.profileType?.toLowerCase() == 'player',
        );
        final hasOrganiser = profiles.any(
          (p) => p.profileType?.toLowerCase() == 'organiser',
        );

        final currentType =
            activeProfileType ?? _selectedProfileType ?? 'player';

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileTypeChip(
                context,
                label: 'Player',
                type: 'player',
                isSelected: hasPlayer && currentType.toLowerCase() == 'player',
                isAvailable: hasPlayer,
                onTap: () {
                  if (hasPlayer) {
                    _switchProfileType('player');
                  } else {
                    // No player profile yet – start player profile creation flow
                    context.push(RoutePaths.intentSelection);
                  }
                },
              ),
              const SizedBox(width: 4),
              _buildProfileTypeChip(
                context,
                label: 'Organiser',
                type: 'organiser',
                isSelected:
                    hasOrganiser && currentType.toLowerCase() == 'organiser',
                isAvailable: hasOrganiser,
                onTap: () {
                  if (hasOrganiser) {
                    _switchProfileType('organiser');
                  } else {
                    // No organiser profile yet – start organiser profile creation flow
                    context.push(RoutePaths.createUserInfo);
                  }
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildProfileTypeChip(
    BuildContext context, {
    required String label,
    required String type,
    required bool isSelected,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              isAvailable ? label : '$label (+)',
              style: textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Iconsax.home_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categoryProfile.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () => _showManageProfiles(),
          icon: const Icon(Iconsax.convert_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categoryProfile.withValues(alpha: 0.0),
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
            backgroundColor: colorScheme.categoryProfile.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        // color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(context, profile),
              const SizedBox(width: 20),
              Expanded(
                child: _buildHeroDetails(
                  context,
                  profileState,
                  textTheme,
                  colorScheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildUnifiedStats(context, profileState, sportsState),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserProfile? profile) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.categoryProfile.withValues(alpha: 0.35),
          width: 3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
          ? Image.network(profile.avatarUrl!, fit: BoxFit.cover)
          : Container(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              child: Icon(
                Iconsax.profile_circle_copy,
                size: 42,
                color: const Color(0xFFFEFEFE),
              ),
            ),
    );
  }

  Widget _buildHeroDetails(
    BuildContext context,
    ProfileState profileState,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final profile = profileState.profile;

    final subtitle = profile?.bio?.isNotEmpty == true
        ? profile!.bio!
        : 'Add a short bio so teammates know what to expect.';

    final textColor = colorScheme.brightness == Brightness.dark
        ? const Color(0xFFFEFEFE).withValues(alpha: 0.92)
        : const Color(0xFF1A1A1A).withValues(alpha: 0.92);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.getDisplayName().isNotEmpty == true
              ? profile!.getDisplayName()
              : 'Complete your profile',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: textColor),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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

    final allStats = [
      _StatItem(
        icon: Iconsax.medal_star_copy,
        label: 'Games',
        value: statistics.totalGamesPlayed.toString(),
      ),
      _StatItem(
        icon: Iconsax.cup_copy,
        label: 'Win rate',
        value: statistics.winRateFormatted,
      ),
      _StatItem(
        icon: Iconsax.game_copy,
        label: 'Sports',
        value: sportsState.profiles.length.toString(),
      ),
      _StatItem(
        icon: Iconsax.verify_copy,
        label: 'Reliability',
        value: '${statistics.getReliabilityScore().round()}%',
      ),
      _StatItem(
        icon: Iconsax.flash_copy,
        label: 'Activity',
        value: statistics.getActivityLevel(),
      ),
      _StatItem(
        icon: Iconsax.clock_copy,
        label: 'Last play',
        value: statistics.lastActiveFormatted,
      ),
    ];

    return Column(
      children: [
        // First row: 3 stats
        Row(
          children: allStats.sublist(0, 3).asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                child: _buildStatCard(stat, colorScheme, textTheme),
              ),
            );
          }).toList(),
        ),
        // Second row: 3 stats
        Row(
          children: allStats.sublist(3, 6).asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                child: _buildStatCard(stat, colorScheme, textTheme),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    _StatItem stat,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(stat.icon, size: 20, color: colorScheme.categoryProfile),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stat.value,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

  Widget _buildOrganiserProfileSection(
    BuildContext context,
    OrganiserProfileState organiserState,
  ) {
    if (organiserState.isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (organiserState.profiles.isEmpty) {
      return _buildOrganiserProfileEmptyState(context);
    }

    return _buildOrganiserProfilesList(context, organiserState);
  }

  Widget _buildSportProfileEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Iconsax.medal_star_copy, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No sport profile yet',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a sport profile to track your level, positions, and achievements.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    // Start player profile creation flow
                    context.push(RoutePaths.intentSelection);
                  },
                  icon: const Icon(Iconsax.profile_circle_copy),
                  label: const Text('Create player profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganiserProfilesList(
    BuildContext context,
    OrganiserProfileState organiserState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Organiser Profiles',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 20),
            if (organiserState.profiles.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: organiserState.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final organiserProfile = organiserState.profiles[index];
                    return _buildOrganiserCard(context, organiserProfile);
                  },
                ),
              )
            else
              _buildOrganiserProfileEmptyState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganiserCard(BuildContext context, OrganiserProfile profile) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportTag = getSportTag(profile.sport);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatSportName(profile.sport),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sportTag,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Iconsax.star_copy, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Level ${profile.organiserLevel}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (profile.isVerified) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Iconsax.verify_copy,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (profile.commissionValue > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${profile.commissionValue}% commission',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrganiserProfileEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Iconsax.note_copy, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No organiser profile yet',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create an organiser profile to start hosting games and events.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    // Start organiser profile creation flow
                    context.push(RoutePaths.createUserInfo);
                  },
                  icon: const Icon(Iconsax.calendar_copy),
                  label: const Text('Create organiser profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildGameManagementCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.categoryProfile.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.calendar_copy,
                    color: colorScheme.categoryProfile,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Management',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create and manage your games',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.createGame),
              icon: const Icon(Iconsax.add_copy),
              label: const Text('Create New Game'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.categoryProfile,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // Navigate to my games / game management screen
                context.push('/my-games');
              },
              icon: const Icon(Iconsax.note_copy),
              label: const Text('View My Games'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.categoryProfile,
                side: BorderSide(
                  color: colorScheme.categoryProfile.withValues(alpha: 0.3),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCompletion(
    BuildContext context,
    ProfileState profileState,
  ) {
    final completion =
        profileState.profile?.calculateProfileCompletion() ?? 0.0;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.chart_copy, color: colorScheme.categoryProfile),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile completion',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        completion >= 80
                            ? 'Looking great! Keep your info fresh.'
                            : 'Finish a few more details to unlock better matches.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${completion.toInt()}%',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.categoryProfile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completion / 100,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.categoryProfile,
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            if (completion < 80) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.push('/profile/edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.categoryProfile.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: colorScheme.onSurface,
                ),
                child: const Text('Complete profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context, ProfileState profileState) {
    final profile = profileState.profile;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Contact & basics',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => context.push('/profile/edit'),
                  icon: const Icon(Iconsax.edit_copy),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile != null && (profile.email?.isNotEmpty ?? false))
              _buildInfoRow(context, Iconsax.sms_copy, profile.email ?? ''),
            if (profile?.phoneNumber?.isNotEmpty == true)
              _buildInfoRow(context, Iconsax.call_copy, profile!.phoneNumber!),
            // Location: Combine city and country if available
            if (profile?.city?.isNotEmpty == true ||
                profile?.country?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Iconsax.building_copy,
                _formatLocation(profile!.city, profile.country),
              ),
            if (profile?.age != null)
              _buildInfoRow(
                context,
                Iconsax.calendar_copy,
                '${profile!.age!} years old',
              ),
            if (profile?.gender?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Iconsax.profile_circle_copy,
                profile!.gender!,
              ),
            if (profile?.language?.isNotEmpty == true)
              _buildInfoRow(context, Iconsax.global_copy, profile!.language!),
            if (profile?.preferredSport?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Iconsax.medal_star_copy,
                profile!.preferredSport!,
              ),
            if (profile?.intention?.isNotEmpty == true)
              _buildInfoRow(context, Iconsax.flag_copy, profile!.intention!),
            if (profile == null ||
                ((profile.email?.isEmpty ?? true) &&
                    profile.phoneNumber == null &&
                    (profile.city == null || profile.city!.isEmpty) &&
                    (profile.country == null || profile.country!.isEmpty) &&
                    profile.age == null &&
                    (profile.gender == null || profile.gender!.isEmpty) &&
                    (profile.language == null || profile.language!.isEmpty) &&
                    (profile.preferredSport == null ||
                        profile.preferredSport!.isEmpty) &&
                    (profile.intention == null || profile.intention!.isEmpty)))
              _buildEmptyState(context, 'Add your basic information'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsProfiles(
    BuildContext context,
    SportsProfileState sportsState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Show error if any
    if (sportsState.errorMessage != null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 0,
        color: colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Iconsax.danger_copy, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error loading sports profiles: ${sportsState.errorMessage}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Sports focus',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final currentProfileState = ref.read(
                      profileControllerProvider,
                    );
                    final profileType =
                        currentProfileState.profile?.profileType ?? 'player';
                    context.push(
                      '/profile/sports-preferences',
                      extra: {'profileType': profileType},
                    );
                  },
                  // icon: Icon(
                  //   Iconsax.setting_4_copy,
                  //   size: 18,
                  //   color: colorScheme.categoryProfile,
                  // ),
                  label: const Text('Manage'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.categoryProfile.withValues(
                      alpha: 0.2,
                    ),
                    foregroundColor: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sportsState.profiles.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: sportsState.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final sport = sportsState.profiles[index];
                    return _buildSportCard(context, sport);
                  },
                ),
              )
            else
              _buildEmptyState(context, 'Add your favorite sports'),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, SportProfile sport) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.4)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and primary badge
          Row(
            children: [
              Icon(
                _getSportIcon(sport.sportName),
                color: colorScheme.categoryProfile,
                size: 28,
              ),
              const Spacer(),
              if (sport.isPrimarySport)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.categoryProfile.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Iconsax.star_copy,
                    size: 12,
                    color: colorScheme.categoryProfile,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Sport name
          Text(
            sport.sportName,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Skill level
          Text(
            _getSkillLevelText(sport.skillLevel),
            style: textTheme.labelSmall?.copyWith(
              color: _getSkillLevelColor(context, sport.skillLevel),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Stats divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outlineVariant.withValues(alpha: 0.0),
                  colorScheme.outlineVariant.withValues(alpha: 0.3),
                  colorScheme.outlineVariant.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sport.gamesPlayed}',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'games',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 24,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        sport.averageRating.toStringAsFixed(1),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Iconsax.star_copy,
                        size: 10,
                        color: colorScheme.categoryProfile,
                      ),
                    ],
                  ),
                  Text(
                    'rating',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary(
    BuildContext context,
    ProfileState profileState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statistics =
        profileState.profile?.statistics ?? const ProfileStatistics();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF585858).withValues(alpha: 0.6)
          : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity snapshot',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Games played',
                    statistics.totalGamesPlayed.toString(),
                    Iconsax.game_copy,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Win rate',
                    statistics.winRateFormatted,
                    Iconsax.cup_copy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Avg. rating',
                    statistics.ratingFormatted,
                    Iconsax.star_copy,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Teammates',
                    statistics.uniqueTeammates.toString(),
                    Iconsax.people_copy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.categoryProfile.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.categoryProfile),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.categoryProfile.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Iconsax.info_circle_copy,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Format sport name from sport key
  String _formatSportName(String sportKey) {
    // Convert sport key to display name (e.g., 'football' -> 'Football')
    if (sportKey.isEmpty) return sportKey;
    final words = sportKey.split('_');
    return words
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  /// Format location string combining city and country
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

  IconData _getSportIcon(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'basketball':
        return Iconsax.game_copy;
      case 'football':
      case 'soccer':
        return Iconsax.medal_star_copy;
      case 'tennis':
        return Iconsax.game_copy;
      case 'volleyball':
        return Iconsax.game_copy;
      case 'baseball':
        return Iconsax.game_copy;
      case 'hockey':
        return Iconsax.game_copy;
      case 'golf':
        return Iconsax.game_copy;
      default:
        return Iconsax.game_copy;
    }
  }

  String _getSkillLevelText(SkillLevel skillLevel) {
    switch (skillLevel) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
      case SkillLevel.expert:
        return 'Expert';
    }
  }

  Color _getSkillLevelColor(BuildContext context, SkillLevel skillLevel) {
    final colorScheme = Theme.of(context).colorScheme;
    final appTheme = Theme.of(context).extension<AppThemeExtension>();

    switch (skillLevel) {
      case SkillLevel.beginner:
        return appTheme?.success ?? colorScheme.primaryContainer;
      case SkillLevel.intermediate:
        return appTheme?.warning ?? colorScheme.primaryContainer;
      case SkillLevel.advanced:
        return appTheme?.infoLink ?? colorScheme.primaryContainer;
      case SkillLevel.expert:
        return colorScheme.primary;
    }
  }

  Widget _buildRewardsSection(BuildContext context) {
    // Get current user ID from profile state
    final profileState = ref.watch(profileControllerProvider);
    final userProfile = profileState.profile;

    if (userProfile == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF585858).withValues(alpha: 0.6)
            : const Color(0xFFFBFBFB).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.categoryProfile.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Check-in widget
          const ProfileCheckInWidget(),
          const SizedBox(height: 16),
          ProfileRewardsWidget(userId: userProfile.id),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.leaderboard),
              icon: const Icon(Iconsax.ranking_copy, size: 18),
              label: const Text('View leaderboard'),
            ),
          ),
        ],
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

class ManageProfilesSheet extends ConsumerWidget {
  const ManageProfilesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);

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

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...profiles.map((profile) {
                        final isActive =
                            profile.profileType?.toLowerCase() ==
                            activeProfileType?.toLowerCase();
                        return _ProfileListTile(
                          profile: profile,
                          isActive: isActive,
                          onTap: () {
                            // Switch to this profile
                            ref
                                .read(profileControllerProvider.notifier)
                                .loadProfile(
                                  profile.userId,
                                  profileType: profile.profileType,
                                );
                            ref.read(activeProfileTypeProvider.notifier).state =
                                profile.profileType;
                            Navigator.pop(context);
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Determine which profile type to create
                            final hasPlayer = profiles.any(
                              (p) => p.profileType?.toLowerCase() == 'player',
                            );
                            final hasOrganiser = profiles.any(
                              (p) =>
                                  p.profileType?.toLowerCase() == 'organiser',
                            );

                            if (!hasPlayer) {
                              context.push(RoutePaths.intentSelection);
                            } else if (!hasOrganiser) {
                              context.push(RoutePaths.createUserInfo);
                            } else {
                              // Show choice dialog if both exist (future)
                              context.push(RoutePaths.intentSelection);
                            }
                          },
                          icon: const Icon(Iconsax.add_copy),
                          label: const Text('Add Profile'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
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
      color: colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? Text(
                        profile.getDisplayName().isNotEmpty
                            ? profile.getDisplayName()[0].toUpperCase()
                            : 'P',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
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
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.profileType?.toUpperCase() ?? 'PLAYER',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
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
