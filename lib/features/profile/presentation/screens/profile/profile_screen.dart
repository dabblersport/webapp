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
import '../../controllers/organiser_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/organiser_profile.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_rewards_widget.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_check_in_widget.dart';
import '../../widgets/profile/player_sport_profile_header.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/data/models/sport_tags.dart';
import 'package:dabbler/features/social/presentation/widgets/feed/post_card.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/features/social/services/social_service.dart';
// Extracted widgets for hero and basics live alongside this screen for now.
// If you re-enable them, ensure the import paths match actual file locations.

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

/// Provider to fetch current user's posts
final myPostsProvider = FutureProvider.autoDispose<List<PostModel>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    // Query posts by author_user_id
    final postsResponse = await supabase
        .from('posts')
        .select(
          '*, vibe:vibes!primary_vibe_id(emoji, label_en, key, color_hex)',
        )
        .eq('author_user_id', userId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .limit(50);

    // Fetch author profile
    final profileResponse = await supabase
        .from('profiles')
        .select('user_id, display_name, avatar_url, verified')
        .eq('user_id', userId)
        .eq('profile_type', 'personal')
        .maybeSingle();

    // Fetch current user's liked post IDs
    final Set<String> likedPostIds = {};
    if (postsResponse.isNotEmpty) {
      final postIds = postsResponse
          .map((post) => post['id'].toString())
          .toList();
      final likedPosts = await supabase
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      likedPostIds.addAll(likedPosts.map((like) => like['post_id'].toString()));
    }

    // Transform database posts to PostModel
    final posts = postsResponse.map((post) {
      final postId = post['id'].toString();

      // Extract media URL
      List<String> mediaUrls = [];
      final mediaData = post['media'];
      if (mediaData is Map<String, dynamic>) {
        final bucket = mediaData['bucket'] as String?;
        final path = mediaData['path'] as String?;
        if (bucket != null && path != null) {
          final publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
          if (publicUrl.isNotEmpty) {
            mediaUrls.add(publicUrl);
          }
        }
      }

      return {
        ...post,
        'profiles': profileResponse ?? {},
        'is_liked': likedPostIds.contains(postId),
        'media_urls': mediaUrls,
      };
    }).toList();

    return posts.map((post) => PostModel.fromJson(post)).toList();
  } catch (e) {
    return [];
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
        persistActiveProfileType(effectiveType);

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
    final organiserState = ref.watch(organiserProfileControllerProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userId = profileState.profile?.userId ?? currentUser?.id ?? '';
    final profileType =
        profileState.profile?.personaType ??
        profileState.profile?.profileType ??
        'player';
    final sportProfileHeaderAsync = userId.isEmpty
        ? const AsyncData<SportProfileHeaderData?>(null)
        : ref.watch(sportProfileHeaderProvider(userId));

    final colorScheme = context.getCategoryTheme('profile');
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
                    const SizedBox(height: 9),
                    _buildProfileHeroCard(context, profileState, sportsState),
                    // const SizedBox(height: 16),
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
                        _buildPostsActivitiesSection(context),
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
            topSection: Container(
              color: colorScheme.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.10
                    : 0.08,
              ),
              child: Padding(
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
                      if (profileType == 'organiser')
                        _buildVenueSubmissionsCard(context),
                      _buildBasicInfo(context, profileState),
                      if (FeatureFlags.enableRewards)
                        _buildRewardsSection(context),
                      if (profileType == 'player')
                        _buildSportsProfiles(context, sportsState),
                      if (profileType == 'organiser')
                        _buildOrganiserProfilesList(context, organiserState),
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
    final colorScheme = context.getCategoryTheme('profile');

    return availableProfilesAsync.when(
      data: (profiles) {
        final hasPlayer = profiles.any(
          (p) => (p.personaType ?? p.profileType)?.toLowerCase() == 'player',
        );
        final hasOrganiser = profiles.any(
          (p) => (p.personaType ?? p.profileType)?.toLowerCase() == 'organiser',
        );

        final currentType =
            activeProfileType ?? _selectedProfileType ?? 'player';

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.12
                  : 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              isAvailable ? label : '$label (+)',
              style: textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onSurface
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
    final colorScheme = context.getCategoryTheme('profile');
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
              foregroundColor: colorScheme.onPrimaryContainer,
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
                        color: colorScheme.onPrimaryContainer,
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
              foregroundColor: colorScheme.onPrimaryContainer,
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
              foregroundColor: colorScheme.onPrimaryContainer,
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;
    final profile = profileState.profile;

    final onTop = colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          // color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: onTop),
          child: IconTheme.merge(
            data: IconThemeData(color: onTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(context, profile),
                    const SizedBox(width: 18),
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
                const SizedBox(height: 10),
                // Pills row for persona type and primary sport
                _buildInfoPills(context, profile, colorScheme, textTheme),
                const SizedBox(height: 12),
                // Bio text below the avatar row
                Text(
                  profile?.bio?.isNotEmpty == true
                      ? profile!.bio!
                      : 'Add a short bio so teammates know what to expect.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                _buildUnifiedStats(context, profileState, sportsState),
              ],
            ),
          ),
        ),
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

  Widget _buildHeroDetails(
    BuildContext context,
    ProfileState profileState,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final profile = profileState.profile;

    final baseOnTop = colorScheme.onPrimaryContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                profile?.getDisplayName().isNotEmpty == true
                    ? profile!.getDisplayName()
                    : 'Complete your profile',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: baseOnTop,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Profile type pill next to name
            if (profile?.profileType != null &&
                profile!.profileType!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: baseOnTop.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.profileType![0].toUpperCase() +
                      profile.profileType!.substring(1),
                  style: textTheme.labelSmall?.copyWith(
                    color: baseOnTop,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Posts and Friends counter row
        _buildPostsAndFriendsCounter(
          context,
          colorScheme,
          textTheme,
          baseOnTop,
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    final baseOnTop = colorScheme.onPrimaryContainer;
    final primarySport = profile?.preferredSport;
    final primarySportProfile = profile?.sportsProfiles
        .where((sp) => sp.isPrimarySport)
        .firstOrNull;
    final skillLevel = primarySportProfile?.skillLevel;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Persona type pill
        if (profile?.personaType != null && profile!.personaType!.isNotEmpty)
          _buildInfoPill(
            context,
            icon: profile.personaType == 'organiser'
                ? Iconsax.calendar_copy
                : profile.personaType == 'hoster'
                ? Iconsax.building_copy
                : profile.personaType == 'socialiser'
                ? Iconsax.people_copy
                : Iconsax.profile_circle_copy,
            label:
                profile.personaType![0].toUpperCase() +
                profile.personaType!.substring(1),
            colorScheme: colorScheme,
            textTheme: textTheme,
            baseOnTop: baseOnTop,
          ),
        // Primary sport pill
        if (primarySport != null && primarySport.isNotEmpty)
          _buildInfoPill(
            context,
            icon: Iconsax.medal_star_copy,
            label: skillLevel != null
                ? '${_formatSportName(primarySport)} · ${_getSkillLevelText(skillLevel)}'
                : _formatSportName(primarySport),
            colorScheme: colorScheme,
            textTheme: textTheme,
            baseOnTop: baseOnTop,
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
            // TODO: Navigate to user's posts
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
                const SizedBox(width: AppSpacing.sm),
                Text(
                  postsCount == 1 ? 'Post' : 'Posts',
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
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Following',
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
                const SizedBox(width: AppSpacing.sm),
                Text(
                  followersCount == 1 ? 'Follower' : 'Followers',
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
    final colorScheme = context.getCategoryTheme('profile');
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
        Row(
          children: allStats
              .sublist(0, 3)
              .map(
                (stat) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: _buildStatCard(stat, colorScheme, textTheme),
                  ),
                ),
              )
              .toList(),
        ),
        Row(
          children: allStats
              .sublist(3)
              .map(
                (stat) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: _buildStatCard(stat, colorScheme, textTheme),
                  ),
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
    final baseOnTop = colorScheme.onPrimaryContainer;

    return Card(
      elevation: 0,
      color: colorScheme.primary.withValues(alpha: 0.08),
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseOnTop =
        DefaultTextStyle.of(context).style.color ??
        colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(
            alpha: isDarkMode ? 0.08 : 0.06,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
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
                      color: baseOnTop.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a sport profile to track your level, positions, and achievements.',
                    style: textTheme.bodySmall?.copyWith(
                      color: baseOnTop.withValues(alpha: 0.78),
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
      ),
    );
  }

  Widget _buildOrganiserProfilesList(
    BuildContext context,
    OrganiserProfileState organiserState,
  ) {
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
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
    final colorScheme = context.getCategoryTheme('profile');
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDarkMode ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
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
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.calendar_copy,
                    color: colorScheme.primary,
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
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
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
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSubmissionsCard(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
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
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.building_4_copy,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue submissions',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submit new venues for approval',
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
              onPressed: () => context.push(RoutePaths.myVenueSubmissions),
              icon: const Icon(Iconsax.document_text_copy),
              label: const Text('View submissions'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.createVenueSubmission),
              icon: const Icon(Iconsax.add_copy),
              label: const Text('Create submission'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.3),
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

    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.chart_copy, color: colorScheme.primary),
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
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completion / 100,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            if (completion < 80) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.push('/profile/edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
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
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          initiallyExpanded: false,
          iconColor: colorScheme.onSurfaceVariant,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          title: Text(
            'Contact & basics',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Iconsax.edit_copy),
              ),
            ],
          ),
          children: [
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
    final colorScheme = context.getCategoryTheme('profile');
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
    final colorScheme = context.getCategoryTheme('profile');
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
      color: colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
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
                        currentProfileState.profile?.personaType ??
                        currentProfileState.profile?.profileType ??
                        'player';
                    context.push(
                      '/profile/sports-preferences',
                      extra: {'profileType': profileType},
                    );
                  },
                  // icon: Icon(
                  //   Iconsax.setting_4_copy,
                  //   size: 18,
                  //   color: colorScheme.primary,
                  // ),
                  label: const Text('Manage'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
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
    final colorScheme = context.getCategoryTheme('profile');
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
          Row(
            children: [
              Icon(
                _getSportIcon(sport.sportName),
                color: colorScheme.primary,
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
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Iconsax.star_copy,
                    size: 12,
                    color: colorScheme.primary,
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
                        color: colorScheme.primary,
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

  Widget _buildEmptyState(BuildContext context, String message) {
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
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
    final colorScheme = context.getCategoryTheme('profile');
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

  Widget _buildPostsActivitiesSection(BuildContext context) {
    final postsAsync = ref.watch(myPostsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posts & Activities',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          postsAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return _buildActivitiesEmptyState(context);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(posts.length, (index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    onLike: () => _handleLikePost(context, post.id),
                    onComment: () => _handleCommentPost(context, post.id),
                    onDelete: () {
                      ref.invalidate(myPostsProvider);
                      ref.invalidate(myPostsCountProvider);
                    },
                    onPostTap: () => context.pushNamed(
                      RouteNames.socialPostDetail,
                      pathParameters: {'postId': post.id},
                    ),
                    onProfileTap: () {
                      // Already on own profile, no need to navigate
                    },
                  );
                }),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Failed to load activities.'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesEmptyState(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 60,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'No activities yet',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Posts you create will appear here.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLikePost(BuildContext context, String postId) async {
    try {
      final socialService = SocialService();
      await socialService.toggleLike(postId);

      await Future.delayed(const Duration(milliseconds: 400));

      if (context.mounted) {
        ref.invalidate(myPostsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like post: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleCommentPost(BuildContext context, String postId) {
    context.pushNamed(
      RouteNames.socialPostDetail,
      pathParameters: {'postId': postId},
    );
  }

  Widget _buildRewardsSection(BuildContext context) {
    if (!FeatureFlags.enableRewards) {
      return const SizedBox.shrink();
    }

    // Get current user ID from profile state
    final profileState = ref.watch(profileControllerProvider);
    final userProfile = profileState.profile;

    if (userProfile == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = context.getCategoryTheme('profile');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    final colorScheme = context.getCategoryTheme('profile');
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
    final colorScheme = context.getCategoryTheme('profile');

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
    final colorScheme = context.getCategoryTheme('profile');
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
    final colorScheme = context.getCategoryTheme('profile');
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
