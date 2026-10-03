import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart'
    show OnboardingSportGlyph;
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import '../../../../../app/app_router.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';

import '../../../../../utils/constants/route_constants.dart';
import '../../models/sport_profile_route_args.dart';

import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show
        sportsProvider,
        userPostsProvider,
        userLikedPostsProvider,
        userCommentedPostsProvider,
        userRepostedPostsProvider;
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/public_activity_card.dart';
import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';

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
        .from(SupabaseConfig.postsTable)
        .select('id')
        .eq('author_user_id', userId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false);

    return (response as List).length;
  } catch (e) {
    return 0;
  }
});

/// Maximum width of the profile column. One layout at every width: the
/// Material scaffold rail / right-panel wrapper is gone, the design
/// draws a single column (same decision as the other migrated screens).
const double _kProfileMaxWidth = 700;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with RouteAware {
  int _selectedTabIndex = 0;

  String? _selectedProfileType; // 'player' or 'organiser'

  @override
  void initState() {
    super.initState();

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
      ref.invalidate(sportProfileHeaderProvider((userId: user.id, profileId: null)));
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

    final previousProfileType = _selectedProfileType;

    setState(() {
      _selectedProfileType = profileType;
    });

    // Update is_active in the database: deactivate old, activate new
    final switched = await ref
        .read(personaServiceProvider.notifier)
        .switchActiveProfile(profileType);

    if (!switched) {
      // Revert optimistic state on failure
      setState(() {
        _selectedProfileType = previousProfileType;
      });
      if (mounted) {
        final errorMsg =
            ref.read(personaServiceProvider).errorMessage ??
            AppLocalizations.of(context).profile_error_switch_profile_failed;
        DabblerToastProvider.of(context).show(DabblerToastSpec(message: errorMsg));
      }
      return;
    }

    // Clear profile cache to force fresh fetch for the new profile type
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await clearProfileCache(ref, user.id);
    }

    await _loadProfileData(profileType: profileType);

    // Persist the active profile type for app restarts
    persistActiveProfileType(profileType);
  }

  Future<void> _loadAverageRating() async {
    // Rating data loading (not displayed in top section)
  }

  Future<void> _onRefresh() async {
    // Clear cache and reload fresh data on pull-to-refresh
    await _refreshProfileWithCacheClear();
  }

  void _showManageProfiles() {
    showDabblerSheet<String>(
      context: context,
      title: AppLocalizations.of(context).profile_manage_profiles_title,
      detent: DabblerSheetDetent.content,
      builder: (context) => const ManageProfilesSheet(),
    ).then((selectedProfileType) {
      if (selectedProfileType != null &&
          selectedProfileType != _selectedProfileType) {
        _switchProfileType(selectedProfileType);
      }
    });
  }

  TextStyle _type(DabblerTypeStyle s, Color c) =>
      s.resolveForDirection(Directionality.of(context)).copyWith(color: c);

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
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
        return DabblerPage(body: _buildTakedownPlaceholder(context));
      }
    }

    // Loading spinner while takedown check is in flight
    if (profileId != null && takedownAsync is AsyncLoading) {
      return const DabblerPage(body: Center(child: DabblerSpinner()));
    }

    return DabblerPage(
      topBar: _buildTopBar(context),
      body: DabblerRefresh(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Hero section ──
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kProfileMaxWidth,
                  ),
                  child: _buildProfileHeader(
                    context,
                    profileState,
                    sportsState,
                  ),
                ),
              ),
            ),

            // ── Posts section ──
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kProfileMaxWidth,
                  ),
                  child: profileId == null
                      ? const Padding(
                          padding: EdgeInsets.all(DabblerSpacing.space11),
                          child: Center(child: DabblerSpinner()),
                        )
                      : _buildTabbedPostsSection(context),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: DabblerSpacing.space9),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username = ref.watch(profileControllerProvider).profile?.username;
    return DabblerNavigationTopBar.titled(
      title: (username != null && username.isNotEmpty)
          ? username
          : l10n.profile_header_fallback,
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      actions: [
        DabblerNavigationAction(
          icon: 'repeat',
          label: l10n.profile_btn_manage_profiles_tooltip,
          onPressed: _showManageProfiles,
        ),
        DabblerNavigationAction(
          icon: 'setting-2',
          label: l10n.settings_header_title,
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    ProfileState profileState,
    SportsProfileState sportsState,
  ) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = profileState.profile;
    final displayName = profile?.getDisplayName() ?? '';

    return DecoratedBox(
      // The design's header: the brand colour at 14% over the card surface.
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.brandPrimary.withValues(alpha: 0.14),
          colors.surfaceCard,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name ──
            Row(
              children: [
                DabblerAvatar(
                  seed: displayName.isNotEmpty ? displayName : 'User',
                  imageUrl: profile?.avatarUrl,
                  size: DabblerAvatarSize.lg,
                ),
                const SizedBox(width: DabblerSpacing.space5),
                Expanded(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName
                        : l10n.profile_complete_your_profile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _type(DabblerType.title2, colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space5),

            // ── Pills: persona type + primary sport + location & age ──
            _buildInfoPills(context, profile),

            // ── Bio ──
            const SizedBox(height: DabblerSpacing.space5),
            Text(
              profile?.bio?.isNotEmpty == true
                  ? profile!.bio!
                  : l10n.profile_bio_placeholder,
              style: _type(DabblerType.subheadline, colors.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DabblerSpacing.space5),

            // ── Posts / Following / Followers counters ──
            _buildPostsAndFriendsCounter(context),
            const SizedBox(height: DabblerSpacing.space5),

            // ── Edit profile + Share profile buttons ──
            _buildEditShareButtons(context),
            const SizedBox(height: DabblerSpacing.space7),

            // ── Sports section ──
            _buildSportsChipsSection(context, sportsState),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPills(BuildContext context, UserProfile? profile) {
    // Resolve preferred & primary sport UUIDs to Sport objects
    final sportsAsync = ref.watch(sportsProvider);
    final allSports = sportsAsync.valueOrNull ?? [];
    final colors = DabblerColors.of(context);

    dynamic findSport(String? id) {
      if (id == null || id.isEmpty) return null;
      return allSports.cast<dynamic>().firstWhere(
        (s) => s.id == id,
        orElse: () => null,
      );
    }

    final preferredSport = findSport(profile?.preferredSport);
    final primarySport = findSport(profile?.primarySport);
    final city = profile?.city;
    final age = profile?.age;

    final pills = <Widget>[
      // Persona type pill
      if (profile?.personaType != null && profile!.personaType!.isNotEmpty)
        DabblerBadge(
          label: personaLabel(context, profile.personaType),
          tone: DabblerBadgeTone.defaultTone,
        ),
      // Primary sport pill
      if (primarySport != null)
        DabblerChip(
          label: primarySport.localizedName(context) as String,
          selected: true,
          leadingIcon: OnboardingSportGlyph(
            sport: primarySport,
            selected: true,
            size: DabblerSizing.iconSm,
            color: colors.onBrand,
          ),
        ),
      // Preferred sport pill (only if different from primary)
      if (preferredSport != null &&
          (primarySport == null ||
              (preferredSport.id as String) != (primarySport.id as String)))
        DabblerChip(
          label: preferredSport.localizedName(context) as String,
          leadingIcon: OnboardingSportGlyph(
            sport: preferredSport,
            selected: false,
            size: DabblerSizing.iconSm,
            color: colors.textPrimary,
          ),
        ),
      // Location & age
      if (city != null && city.isNotEmpty)
        DabblerChip(
          label: city,
          leadingIcon: DabblerIcon(
            'location',
            size: DabblerSizing.iconSm,
            color: colors.textPrimary,
          ),
        ),
      if (age != null)
        DabblerChip(
          label: '$age yo',
          leadingIcon: DabblerIcon(
            'calendar',
            size: DabblerSizing.iconSm,
            color: colors.textPrimary,
          ),
        ),
    ];

    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pills,
    );
  }

  Widget _counter(
    BuildContext context, {
    required int value,
    required String label,
    VoidCallback? onTap,
  }) {
    final colors = DabblerColors.of(context);
    return Semantics(
      button: onTap != null,
      label: '$value $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DabblerSizing.touchTargetMin,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$value',
                style: _type(DabblerType.headline, colors.textPrimary),
              ),
              const SizedBox(width: DabblerSpacing.space1 + 2),
              Text(
                label,
                style: _type(DabblerType.footnote, colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsAndFriendsCounter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    return Wrap(
      spacing: DabblerSpacing.space6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Posts counter
        _counter(
          context,
          value: postsCount,
          label: l10n.profile_post_count(postsCount),
          onTap: () {
            // Scroll to posts tab
          },
        ),
        // Following counter
        _counter(
          context,
          value: followingCount,
          label: l10n.profile_following_label,
          onTap: profileId != null
              ? () => context.pushNamed(
                  RouteNames.following,
                  pathParameters: {'profileId': profileId},
                )
              : null,
        ),
        // Followers counter
        _counter(
          context,
          value: followersCount,
          label: l10n.profile_follower_count(followersCount),
          onTap: profileId != null
              ? () => context.pushNamed(
                  RouteNames.followers,
                  pathParameters: {'profileId': profileId},
                )
              : null,
        ),
      ],
    );
  }

  /// Edit profile + Share profile buttons as shown in the design
  Widget _buildEditShareButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: DabblerButton(
            label: l10n.profile_btn_edit,
            icon: 'edit',
            tone: DabblerButtonTone.outlined,
            fullWidth: true,
            onPressed: () => context.push('/profile/edit'),
          ),
        ),
        const SizedBox(width: DabblerSpacing.space4),
        Expanded(
          child: DabblerButton(
            label: l10n.profile_btn_share,
            icon: 'share',
            tone: DabblerButtonTone.outlined,
            fullWidth: true,
            onPressed: () {
              // TODO: Implement share profile
            },
          ),
        ),
      ],
    );
  }

  void _openSportProfile(UserProfile? profile, dynamic sport) {
    final profileId = profile?.id;
    final userId = profile?.userId;
    final personaType = profile?.personaType ?? profile?.profileType ?? 'player';
    if (profileId == null ||
        userId == null ||
        (personaType != 'player' && personaType != 'organiser')) {
      return;
    }
    final args = SportProfileRouteArgs(
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
    );
    // Query params keep the route alive across web
    // refresh; extra stays as the fast path.
    context.push(
      Uri(
        path: RoutePaths.sportProfile,
        queryParameters: args.toQueryParameters(),
      ).toString(),
      extra: args,
    );
  }

  /// Sports chips section with label, edit button and the sport chips
  Widget _buildSportsChipsSection(
    BuildContext context,
    SportsProfileState sportsState,
  ) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider).profile;

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

    final personaType = profile?.personaType ?? profile?.profileType ?? 'player';
    final canOpen =
        profile?.id != null &&
        profile?.userId != null &&
        (personaType == 'player' || personaType == 'organiser');

    final chips = [
      for (final sport in resolvedSports)
        DabblerChip(
          label: sport.nameEn,
          leadingIcon: OnboardingSportGlyph(
            sport: sport,
            selected: false,
            size: DabblerSizing.iconSm,
            color: colors.textPrimary,
          ),
          onTap: canOpen ? () => _openSportProfile(profile, sport) : null,
        ),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.profile_section_sports,
                style: _type(DabblerType.headline, colors.textPrimary),
              ),
            ),
            DabblerButton.icon(
              icon: 'edit',
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              semanticLabel: l10n.profile_btn_edit,
              onPressed: () {
                ManageSportsSheet.show(context);
              },
            ),
          ],
        ),
        const SizedBox(height: DabblerSpacing.space3),
        if (chips.isEmpty)
          Text(
            l10n.profile_empty_no_sports,
            style: _type(DabblerType.footnote, colors.textSecondary),
          )
        else if (isWide)
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: chips,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: DabblerSpacing.space2,
                    ),
                    child: c,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Tabbed posts ─────────────────────────────────────────────────────────────

  /// Tabbed posts section for the bottom part of the profile
  Widget _buildTabbedPostsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(profileControllerProvider).profile?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DabblerSpacing.space6),
        // Tab bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          child: DabblerTabs(
            scrollable: true,
            value: '$_selectedTabIndex',
            onChanged: (id) => setState(() => _selectedTabIndex = int.parse(id)),
            items: [
              DabblerTabItem(id: '0', label: l10n.profile_tab_posts),
              DabblerTabItem(id: '1', label: l10n.profile_tab_replies),
              DabblerTabItem(id: '2', label: l10n.profile_tab_liked),
              DabblerTabItem(id: '3', label: l10n.profile_tab_reposts),
              DabblerTabItem(id: '4', label: l10n.profile_tab_activity),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space1),
        // Tab content
        _buildTabContent(context, profileId),
      ],
    );
  }

  /// Content for the selected tab
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
        padding: EdgeInsets.all(DabblerSpacing.space11),
        child: Center(child: DabblerSpinner()),
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
              padding: const EdgeInsets.only(bottom: DabblerSpacing.space1 + 1),
              child: resolvePostLayout(post),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space11),
        child: Center(child: DabblerSpinner()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space6),
        child: DabblerEmptyState.error(
          title: AppLocalizations.of(context).profile_error_failed_load_posts,
          size: DabblerEmptyStateSize.inline,
        ),
      ),
    );
  }

  Widget _buildEmptyTabContent(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space8,
      ),
      child: DabblerEmptyState(icon: 'document-text', title: message),
    );
  }

  Widget _buildTakedownPlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: DabblerEmptyState(
        icon: 'close-square',
        title: l10n.profile_takedown_title,
        text: l10n.profile_takedown_body,
        size: DabblerEmptyStateSize.page,
      ),
    );
  }
}

/// The switch-profile sheet body. Shown by [ProfileScreen] inside a
/// [showDabblerSheet] (the sheet owns the title, the handle and the close
/// affordance); pops with the chosen persona type.
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

  TextStyle _type(DabblerTypeStyle s, Color c) =>
      s.resolveForDirection(Directionality.of(context)).copyWith(color: c);

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final personaState = ref.watch(personaServiceProvider);

    return availableProfilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: Center(
              child: Text(
                l10n.profile_no_profiles_found,
                style: _type(DabblerType.subheadline, colors.textSecondary),
              ),
            ),
          );
        }

        // Get available persona options (only if not at limit)
        final availablePersonas = personaState.canAddNewProfile
            ? personaState.availablePersonas.where((p) => p.canProceed).toList()
            : <PersonaAvailability>[];

        // Check if at profile limit
        final isAtLimit = personaState.isAtProfileLimit;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Existing profiles section
            ...profiles.map((profile) {
              final effectiveType = profile.personaType ?? profile.profileType;
              final isActive =
                  effectiveType?.toLowerCase() ==
                  activeProfileType?.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: DabblerSpacing.space2),
                child: _ProfileRow(
                  profile: profile,
                  isActive: isActive,
                  onTap: () {
                    // Pop the sheet and return the persona type
                    // The parent ProfileScreen will handle the full switch
                    Navigator.pop(context, effectiveType);
                  },
                ),
              );
            }),

            // Add persona options section (only if not at limit)
            if (availablePersonas.isNotEmpty && !isAtLimit) ...[
              const SizedBox(height: DabblerSpacing.space4),
              DabblerSection(
                title: l10n.profile_add_profile,
                children: [
                  for (final availability in availablePersonas)
                    _PersonaOptionTile(
                      availability: availability,
                      onTap: () => _startPersonaFlow(availability),
                    ),
                ],
              ),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space8),
        child: Center(child: DabblerSpinner()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space8),
        child: Center(
          child: Text(
            l10n.profile_error_loading_profiles,
            style: _type(DabblerType.subheadline, colors.error.strong),
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
      DabblerToastProvider.of(context).show(
        const DabblerToastSpec(
          message: PersonaRules.profileLimitMessage,
          tone: DabblerToastTone.error,
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
    final l10n = AppLocalizations.of(context);

    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: l10n.profile_convert_to(
          personaLabel(context, availability.targetPersona.name),
        ),
        description: l10n.profile_convert_confirm_body(
          personaLabel(context, availability.convertFrom?.name),
          personaLabel(context, availability.targetPersona.name),
        ),
        onClose: () => Navigator.of(dialogContext).pop(),
        secondaryAction: DabblerDialogAction(
          label: l10n.profile_btn_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        primaryAction: DabblerDialogAction(
          label: l10n.profile_btn_continue,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            // Navigate to first screen of add flow
            context.push(RoutePaths.addPersonaInterests);
          },
        ),
      ),
    );
  }
}

/// Row for displaying an available persona option
class _PersonaOptionTile extends StatelessWidget {
  final PersonaAvailability availability;
  final VoidCallback onTap;

  const _PersonaOptionTile({required this.availability, required this.onTap});

  String get _personaIcon {
    switch (availability.targetPersona) {
      case PersonaType.player:
        return 'user';
      case PersonaType.organiser:
        return 'calendar';
      case PersonaType.host:
        return 'building';
      case PersonaType.socialiser:
        return 'people';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConversion = availability.actionType == PersonaActionType.convert;

    return DabblerInputRow(
      onTap: onTap,
      leading: DabblerIconTile.named(
        _personaIcon,
        tone: isConversion
            ? DabblerIconTileTone.accent
            : DabblerIconTileTone.brand,
      ),
      title: personaLabel(context, availability.targetPersona.name),
      subtitle: availability.targetPersona.description,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConversion) ...[
            DabblerBadge(
              label: AppLocalizations.of(context).profile_persona_convert_badge,
            ),
            const SizedBox(width: DabblerSpacing.space2),
          ],
          const DabblerChevron(),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final name = profile.getDisplayName().isNotEmpty
        ? profile.getDisplayName()
        : 'Profile';

    return DabblerInputRow(
      onTap: onTap,
      leading: DabblerAvatar(
        seed: name,
        imageUrl: profile.avatarUrl,
        size: DabblerAvatarSize.sm,
      ),
      title: name,
      subtitle: (profile.personaType ?? profile.profileType)?.toUpperCase() ??
          'PLAYER',
      trailing: DabblerIcon(
        isActive ? 'tick-circle' : 'record',
        weight: isActive ? DabblerIconWeight.bold : DabblerIconWeight.linear,
        size: DabblerSizing.iconMd,
        color: isActive ? colors.brandPrimary : colors.borderStrong,
      ),
    );
  }
}
