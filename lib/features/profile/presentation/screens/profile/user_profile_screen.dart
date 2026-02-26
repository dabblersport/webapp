import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import '../../../../../utils/constants/route_constants.dart';
import '../../widgets/profile/player_sport_profile_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show userPostsProvider;
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';

class _UserActivitiesTab extends ConsumerWidget {
  final String userId;
  const _UserActivitiesTab({required this.userId});

  static const String _emptyIllustrationAssetPath =
      'assets/images/undraw/empty_post.svg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(profileControllerProvider).profile?.id;
    final postsAsync = profileId != null
        ? ref.watch(userPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const _ActivitiesEmptyState(
            assetPath: _emptyIllustrationAssetPath,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: posts.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeedPostCard(post: post),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Failed to load posts.')),
      ),
    );
  }
}

class _ActivitiesEmptyState extends StatelessWidget {
  final String assetPath;

  const _ActivitiesEmptyState({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                _ThemeableUndrawSvg(assetPath: assetPath, height: 130),
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
}

class _ThemeableUndrawSvg extends StatelessWidget {
  final String assetPath;
  final double height;

  const _ThemeableUndrawSvg({required this.assetPath, required this.height});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final themedSvg = _themeifyUndrawSvg(snapshot.data!, colorScheme);
          return SvgPicture.string(
            themedSvg,
            height: height,
            fit: BoxFit.contain,
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: height,
            child: Center(
              child: Icon(
                Icons.article_outlined,
                size: 60,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          );
        }

        return SizedBox(height: height);
      },
    );
  }

  String _themeifyUndrawSvg(String svg, ColorScheme colorScheme) {
    final primary = _toHexRgb(colorScheme.primary);
    final secondary = _toHexRgb(colorScheme.tertiary);
    final surfaceStroke = _toHexRgb(colorScheme.outlineVariant);
    final darkInk = _toHexRgb(colorScheme.onSurfaceVariant);
    final lightFill = _toHexRgb(colorScheme.surfaceContainerHighest);
    final accentSoft = _toHexRgb(colorScheme.secondaryContainer);

    return svg
        .replaceAll('#6c63ff', primary)
        .replaceAll('#6C63FF', primary)
        .replaceAll('#ff6584', secondary)
        .replaceAll('#FF6584', secondary)
        .replaceAll('#3f3d56', darkInk)
        .replaceAll('#3F3D56', darkInk)
        .replaceAll('#2f2e41', darkInk)
        .replaceAll('#2F2E41', darkInk)
        .replaceAll('#e6e6e6', lightFill)
        .replaceAll('#E6E6E6', lightFill)
        .replaceAll('#ffb8b8', accentSoft)
        .replaceAll('#FFB8B8', accentSoft)
        .replaceAll('#d0cde1', surfaceStroke)
        .replaceAll('#D0CDE1', surfaceStroke);
  }

  String _toHexRgb(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}

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
    final brightness = Theme.of(context).brightness;
    final theme = brightness == Brightness.dark
        ? TokenBasedTheme.build(AppThemeMode.socialDark)
        : TokenBasedTheme.build(AppThemeMode.socialLight);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
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
          if (profileState.errorMessage != null &&
              profileState.profile == null) {
            return Scaffold(
              backgroundColor: colorScheme.surface,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.danger_copy,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Profile not found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profileState.errorMessage ?? 'Unable to load profile',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Iconsax.arrow_left_copy),
                        label: const Text('Go back'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return TwoSectionLayout(
            category: 'social',
            onRefresh: _onRefresh,
            topPadding: const EdgeInsets.only(
              top: 48,
              left: 24,
              right: 24,
              bottom: 18,
            ),
            bottomPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            topSection: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 18),
                _buildProfileHeroCard(context, profileState, sportsState),
                const SizedBox(height: 12),
                _buildActionButtons(context),
                const SizedBox(height: 12),
                _buildSportProfileHeaderSection(
                  context,
                  sportProfileHeaderAsync,
                ),
              ],
            ),
            bottomSection: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: _activitiesKey,
                  'Posts & Activities',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _UserActivitiesTab(userId: widget.userId),
              ],
            ),
            bottomBackgroundColor: Theme.of(
              context,
            ).colorScheme.secondaryContainer,
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Iconsax.arrow_left_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categorySocial.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   'Username',
              //   style: textTheme.headlineSmall?.copyWith(
              //     fontWeight: FontWeight.w700,
              //     color: colorScheme.onSurface,
              //   ),
              // ),
              if (profile?.username != null &&
                  profile!.username!.isNotEmpty) ...[
                Text(
                  '${profile.username}',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () => _showMoreOptions(context),
          icon: const Icon(Iconsax.more_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categorySocial.withValues(alpha: 0.0),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colorScheme.onPrimaryContainer),
        child: IconTheme.merge(
          data: IconThemeData(color: colorScheme.onPrimaryContainer),
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
              const SizedBox(height: AppSpacing.xl),
              // Pills row for persona type and primary sport
              _buildInfoPills(context, profile, colorScheme, textTheme),
              // Bio text below the avatar row
              if (profile?.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  profile!.bio!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _buildUnifiedStats(context, profileState, sportsState),
            ],
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
      context: AvatarContext.social,
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
                    : 'User',
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
        // Posts, Following, and Followers counter row
        _buildPostsAndFollowingCounter(
          context,
          colorScheme,
          textTheme,
          baseOnTop,
        ),
        const SizedBox(height: 6),
        // @username, location, age row
        _buildUserMetaRow(
          context,
          profileState.profile,
          textTheme,
          colorScheme,
        ),
      ],
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
                const SizedBox(width: 4),
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
                const SizedBox(width: 4),
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

  Widget _buildUserMetaRow(
    BuildContext context,
    UserProfile? profile,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final baseOnTop = colorScheme.onPrimaryContainer;

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
                '${profile!.age!} Yo',
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
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color baseOnTop,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.categorySocial.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.categorySocial.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.categorySocial),
          const SizedBox(width: 4),
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

  String _formatSportName(String sportKey) {
    if (sportKey.isEmpty) return sportKey;
    final words = sportKey.split('_');
    return words
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
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
        label: 'Games',
        value: statistics.totalGamesPlayed.toString(),
        icon: Iconsax.medal_star_copy,
      ),
      _StatItem(
        label: 'Win rate',
        value: statistics.winRateFormatted,
        icon: Iconsax.cup_copy,
      ),
      _StatItem(
        label: 'Sports',
        value: sportsState.profiles.length.toString(),
        icon: Iconsax.game_copy,
      ),
      _StatItem(
        label: 'Reliability',
        value: '${statistics.getReliabilityScore().round()}%',
        icon: Iconsax.verify_copy,
      ),
      _StatItem(
        label: 'Activity',
        value: statistics.getActivityLevel(),
        icon: Iconsax.flash_copy,
      ),
      _StatItem(
        label: 'Last play',
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
    final baseOnTop = colorScheme.onPrimaryContainer;

    return Card(
      elevation: 0,
      color: colorScheme.categorySocial.withValues(alpha: 0.08),
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
              foregroundColor: colorScheme.categorySocial,
              side: BorderSide(
                color: colorScheme.categorySocial.withValues(alpha: 0.5),
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
          child: SizedBox(
            height: 40,
            child: (myProfileId == null || targetProfileId == null)
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('Loading'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      textStyle: buttonTextStyle,
                      foregroundColor: colorScheme.categorySocial,
                      side: BorderSide(
                        color: colorScheme.categorySocial.withValues(
                          alpha: 0.5,
                        ),
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
    final buttonTextStyle = Theme.of(context).textTheme.labelMedium;

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
        label: const Text('Unblock'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
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
        label: const Text('Following'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          textStyle: buttonTextStyle,
          foregroundColor: colorScheme.categorySocial,
          side: BorderSide(
            color: colorScheme.categorySocial.withValues(alpha: 0.5),
          ),
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
      label: const Text('Follow'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        textStyle: buttonTextStyle,
        foregroundColor: colorScheme.categorySocial,
        side: BorderSide(
          color: colorScheme.categorySocial.withValues(alpha: 0.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          const SnackBar(content: Text('Cannot message a blocked user')),
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
        await supabase
            .from('profile_follows')
            .delete()
            .eq('follower_profile_id', myProfileId)
            .eq('following_profile_id', targetProfileId);
      } else {
        await supabase.from('profile_follows').insert({
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
        title: const Text('Block User'),
        content: const Text(
          'This will block the user across the entire app. '
          'They won\'t be able to see your profile, posts, or interact with you. '
          'You can unblock them later from their profile or Privacy Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Block'),
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
          ).showSnackBar(const SnackBar(content: Text('User blocked')));
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
          ).showSnackBar(const SnackBar(content: Text('User unblocked')));
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

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocked)
              ListTile(
                leading: const Icon(Iconsax.close_circle_copy),
                title: const Text('Unblock user'),
                onTap: () async {
                  Navigator.pop(context);
                  await _unblockUser(this.context);
                },
              )
            else
              ListTile(
                leading: const Icon(Iconsax.close_circle_copy),
                title: const Text('Block user'),
                onTap: () async {
                  Navigator.pop(context);
                  await _blockUser(this.context);
                },
              ),
            ListTile(
              leading: const Icon(Iconsax.warning_2_copy),
              title: const Text('Report user'),
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
