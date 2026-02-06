import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/profile_statistics.dart';
import 'package:dabbler/themes/app_theme.dart';
import '../../../../../utils/constants/route_constants.dart';
import '../../widgets/profile/player_sport_profile_header.dart';
import 'package:dabbler/data/repositories/friends_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/design_system/layouts/two_section_layout.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // Check if viewing own profile and load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOwnProfile();
      _loadProfileData();
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
    if (currentUser != null && currentUser.id == widget.userId) {
      // Redirect to own profile screen
      if (mounted) {
        context.go(RoutePaths.profile);
      }
    }
  }

  Future<void> _loadProfileData() async {
    final profileController = ref.read(profileControllerProvider.notifier);
    final sportsController = ref.read(sportsProfileControllerProvider.notifier);

    await Future.wait<void>([
      profileController.loadProfile(widget.userId),
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
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
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
                  icon: const Icon(Icons.arrow_back),
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
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildProfileHeroCard(context, profileState, sportsState),
          const SizedBox(height: 16),
          _buildSportProfileHeaderSection(context, sportProfileHeaderAsync),
        ],
      ),
      bottomSection: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionButtons(context),
              const SizedBox(height: 24),
              _buildBasicInfo(context, profileState),
              _buildSportsProfiles(context, sportsState),
              _buildStatisticsSummary(context, profileState),
            ],
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
          icon: const Icon(Icons.arrow_back_rounded),
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
          onPressed: () => _showMoreOptions(context),
          icon: const Icon(Icons.more_vert),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.6),
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
          const SizedBox(height: 24),
          _buildHeroStats(context, profileState, sportsState),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserProfile? profile) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.3)
              : Colors.black.withOpacity(0.2),
          width: 3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
          ? Image.network(profile.avatarUrl!, fit: BoxFit.cover)
          : Container(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              child: Icon(
                Icons.person_outline,
                size: 42,
                color: isDarkMode ? Colors.white : Colors.black87,
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
        : 'No bio available.';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.getDisplayName().isNotEmpty == true
              ? profile!.getDisplayName()
              : 'User',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        if (profile?.username != null && profile!.username!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '@${profile.username}',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: isDarkMode
                ? Colors.white.withOpacity(0.85)
                : Colors.black.withOpacity(0.7),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeroStats(
    BuildContext context,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    final profile = profileState.profile;
    final statistics = profile?.statistics ?? const ProfileStatistics();
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final statTiles = [
      _HeroStat(
        label: 'Games',
        value: statistics.totalGamesPlayed.toString(),
        icon: Icons.sports_soccer,
      ),
      _HeroStat(
        label: 'Win rate',
        value: statistics.winRateFormatted,
        icon: Icons.emoji_events_outlined,
      ),
      _HeroStat(
        label: 'Sports',
        value: sportsState.profiles.length.toString(),
        icon: Icons.sports_handball,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: statTiles.map((stat) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                stat.icon,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 6),
              Text(
                stat.value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                stat.label,
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => _sendMessage(context),
          icon: const Icon(Icons.message_outlined),
          label: const Text('Message'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addFriend(context),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Friend'),
          style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildBasicInfo(BuildContext context, ProfileState profileState) {
    final profile = profileState.profile;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact & basics',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (profile?.email?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Icons.email_outlined,
                profile!.email ?? '',
              ),
            if (profile?.phoneNumber?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Icons.phone_outlined,
                profile!.phoneNumber!,
              ),
            if (profile?.city?.isNotEmpty == true ||
                profile?.country?.isNotEmpty == true)
              _buildInfoRow(
                context,
                Icons.location_city_outlined,
                _formatLocation(profile!.city, profile.country),
              ),
            if (profile?.age != null)
              _buildInfoRow(
                context,
                Icons.cake_outlined,
                '${profile!.age!} years old',
              ),
            if (profile == null ||
                ((profile.email?.isEmpty ?? true) &&
                    profile.phoneNumber == null &&
                    (profile.city == null || profile.city!.isEmpty) &&
                    (profile.country == null || profile.country!.isEmpty) &&
                    profile.age == null))
              _buildEmptyState(context, 'No information available'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sports focus',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
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
              _buildEmptyState(context, 'No sports added'),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, SportProfile sport) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(sport.sportName),
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (sport.isPrimarySport)
                Icon(Icons.star_rounded, size: 20, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            sport.sportName,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            _getSkillLevelText(sport.skillLevel),
            style: textTheme.bodySmall?.copyWith(
              color: _getSkillLevelColor(context, sport.skillLevel),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '${sport.yearsPlaying} ${sport.yearsPlaying == 1 ? 'year' : 'years'}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    Icons.sports_esports_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Win rate',
                    statistics.winRateFormatted,
                    Icons.emoji_events_outlined,
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
                    Icons.star_rate_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Teammates',
                    statistics.uniqueTeammates.toString(),
                    Icons.groups_2_outlined,
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
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
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
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sports_soccer, color: colorScheme.primary),
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
                  'When this player shares their sport profile, you will see it here.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  IconData _getSportIcon(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'football':
      case 'soccer':
        return Icons.sports_soccer;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'baseball':
        return Icons.sports_baseball;
      case 'hockey':
        return Icons.sports_hockey;
      case 'golf':
        return Icons.sports_golf;
      default:
        return Icons.sports;
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

  void _sendMessage(BuildContext context) {
    final userId = widget.userId;
    context.push('${RoutePaths.socialChat}/$userId');
  }

  void _addFriend(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final errorMapper = SupabaseErrorMapper();
      final supabaseService = SupabaseService(client, errorMapper);
      final friendsRepo = FriendsRepositoryImpl(supabaseService);

      final result = await friendsRepo.sendFriendRequest(widget.userId);

      if (mounted) {
        switch (result) {
          case Ok():
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Friend request sent')),
            );
          case Err(:final error):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed: ${error.message}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final errorMapper = SupabaseErrorMapper();
      final supabaseService = SupabaseService(client, errorMapper);
      final friendsRepo = FriendsRepositoryImpl(supabaseService);

      final result = await friendsRepo.blockUser(widget.userId);

      if (mounted) {
        switch (result) {
          case Ok():
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('User blocked')));
          case Err(:final error):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed: ${error.message}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _reportUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this user?'),
            const SizedBox(height: 16),
            ...[
              'Harassment',
              'Spam',
              'Inappropriate content',
              'Hate speech',
              'Other',
            ].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  _submitUserReport(context, reason);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUserReport(BuildContext context, String reason) async {
    try {
      final client = Supabase.instance.client;

      await client.from('reports').insert({
        'reporter_id': client.auth.currentUser?.id,
        'reported_user_id': widget.userId,
        'reason': reason,
        'target_type': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report submitted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
      }
    }
  }

  void _showMoreOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Block user'),
              onTap: () async {
                Navigator.pop(context);
                await _blockUser(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report user'),
              onTap: () {
                Navigator.pop(context);
                _reportUser(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}
