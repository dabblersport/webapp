import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
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
import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart'
    show listingSportFor;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';

/// Another user's profile (design frames PF04 / PF05, "seen by another
/// user"): a brand-tinted identity header (avatar, name, handle, persona and
/// place badges, bio, counters, Follow / Message actions), a bento of stat
/// tiles, the user's sports, then the tabbed posts. DS-only; the wide-layout
/// legacy wide-layout wrapper (side rail + right panel) is dropped as in the
/// earlier waves, the content column is centred instead.
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

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  int _selectedTabIndex = 0;
  final _activitiesKey = GlobalKey();

  static const List<String> _tabIds = <String>[
    'posts',
    'replies',
    'liked',
    'reposts',
    'activity',
  ];

  @override
  void initState() {
    super.initState();

    // Check if viewing own profile and load data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfileData();
      _checkOwnProfile();
    });
  }

  Future<void> _checkOwnProfile() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    // NOTE: widget.userId is not always a genuine auth uid — some callers
    // (e.g. a game creator card) only have a profile id and pass it in this
    // slot. Never compare it against currentUser.id; determine "own profile"
    // purely from profile ids below, which are always genuine.

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
      sportsController.loadSportsProfiles(
        widget.userId,
        profileId: widget.profileId,
      ),
    ]);
  }

  Future<void> _onRefresh() async {
    await _loadProfileData();
  }

  TextStyle _t(
    BuildContext context,
    DabblerTypeStyle step,
    Color color, {
    FontWeight? weight,
  }) => step
      .resolveForDirection(Directionality.of(context))
      .copyWith(color: color, fontWeight: weight);

  void _toast(
    String message, {
    DabblerToastTone tone = DabblerToastTone.neutral,
  }) {
    if (!mounted) return;
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final sportProfileHeaderAsync = ref.watch(
      sportProfileHeaderProvider((
        userId: widget.userId,
        profileId: widget.profileId,
      )),
    );

    // Show loading state
    if (profileState.isLoading) {
      return const DabblerPage(body: Center(child: DabblerSpinner()));
    }

    // Show error state
    if (profileState.errorMessage != null && profileState.profile == null) {
      // Neutral, not alarming: most of the time this fires because the
      // profile isn't visible to this viewer (a benched persona, per
      // P-028/KAN-100), not because anything actually failed — no
      // "deleted"/"banned" wording, no danger styling, no avatar.
      return DabblerPage(
        body: DabblerEmptyState(
          icon: 'profile-circle',
          title: l10n.user_profile_error_not_found_title,
          text:
              profileState.errorMessage ?? l10n.user_profile_error_unable_to_load,
          size: DabblerEmptyStateSize.page,
          action: DabblerButton(
            label: l10n.user_profile_btn_go_back,
            icon: 'arrow-left',
            mirrorIconInRtl: true,
            tone: DabblerButtonTone.outlined,
            onPressed: () => context.pop(),
          ),
        ),
      );
    }

    final profile = profileState.profile;
    final username = profile?.username;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: (username != null && username.isNotEmpty) ? username : null,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        actions: [
          DabblerNavigationAction(
            icon: 'more',
            label: 'More',
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: DabblerRefresh(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: DabblerSpacing.space11),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(context, profileState, colors),
                    const SizedBox(height: DabblerSpacing.space8),
                    Padding(
                      padding: _gutter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildUnifiedStats(context, profileState, sportsState),
                          _buildSportsChipsSection(context, profile, colors),
                          _buildSportProfileHeaderSection(
                            context,
                            sportProfileHeaderAsync,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DabblerSpacing.space8),
                    _buildTabbedPostsSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const EdgeInsetsGeometry _gutter = EdgeInsets.symmetric(
    horizontal: DabblerSpacing.space6,
  );

  // ── Header ───────────────────────────────────────────────────────────

  Widget _buildProfileHeader(
    BuildContext context,
    ProfileState profileState,
    DabblerColors colors,
  ) {
    final profile = profileState.profile;
    final displayName = profile?.getDisplayName();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName
        : 'User';

    return DabblerSurface.brandTint(
      radius: 0,
      borderWidth: 0,
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name / handle ──
          Row(
            children: [
              DabblerAvatar(
                seed: name,
                imageUrl: profile?.avatarUrl,
                size: DabblerAvatarSize.lg,
              ),
              const SizedBox(width: DabblerSpacing.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(context, DabblerType.title2, colors.textPrimary),
                    ),
                    if (profile?.username != null &&
                        profile!.username!.isNotEmpty)
                      Text(
                        // LRM keeps the @ on the handle's side in RTL.
                        '\u200E@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                          context,
                          DabblerType.subheadline,
                          colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space5),

          // ── Badges: persona, primary sport, place, age ──
          _buildInfoPills(context, profile, colors),
          const SizedBox(height: DabblerSpacing.space3),

          // ── Online / last seen ──
          if (profile != null) _buildOnlineIndicator(context, profile, colors),

          // ── Bio ──
          if (profile?.bio?.isNotEmpty == true) ...[
            const SizedBox(height: DabblerSpacing.space4),
            Text(
              profile!.bio!,
              style: _t(context, DabblerType.callout, colors.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: DabblerSpacing.space5),

          // ── Posts / Following / Followers counters ──
          _buildPostsAndFollowingCounter(context, colors),
          const SizedBox(height: DabblerSpacing.space5),

          // ── Follow / Message ──
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildCounter(
    BuildContext context,
    DabblerColors colors, {
    required int value,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: _t(
                context,
                DabblerType.headline,
                colors.textPrimary,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: DabblerSpacing.space1),
            Text(
              label,
              style: _t(context, DabblerType.footnote, colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsAndFollowingCounter(
    BuildContext context,
    DabblerColors colors,
  ) {
    final l10n = AppLocalizations.of(context);
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

    return Wrap(
      spacing: DabblerSpacing.space6,
      children: [
        // Posts counter
        _buildCounter(
          context,
          colors,
          value: postsCount,
          label: l10n.profile_post_count(postsCount),
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
        ),
        // Following counter
        _buildCounter(
          context,
          colors,
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
        _buildCounter(
          context,
          colors,
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

  Widget _buildOnlineIndicator(
    BuildContext context,
    UserProfile profile,
    DabblerColors colors,
  ) {
    final isOnline = profile.isOnline;
    final lastSeenText = profile.getLastSeenText();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing dot for online, static neutral dot for offline
        _OnlineStatusDot(isOnline: isOnline),
        const SizedBox(width: DabblerSpacing.space2),
        Text(
          lastSeenText,
          style: _t(
            context,
            DabblerType.caption1,
            isOnline ? colors.success.strong : colors.textTertiary,
            weight: isOnline ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPills(
    BuildContext context,
    UserProfile? profile,
    DabblerColors colors,
  ) {
    final primarySportId = profile?.preferredSport;

    // Resolve UUID → Sport object to get its name
    final sportsAsync = ref.watch(sportsProvider);
    final allSports = sportsAsync.valueOrNull ?? [];
    final matchedSport = (primarySportId != null && primarySportId.isNotEmpty)
        ? allSports.cast<dynamic>().firstWhere(
            (s) => s.id == primarySportId,
            orElse: () => null,
          )
        : null;
    final sportName = matchedSport != null
        ? matchedSport.localizedName(context) as String
        : null;
    final sport = listingSportFor(matchedSport?.nameEn as String?);

    final location = _formatLocation(profile?.city, profile?.country);

    return Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space2,
      children: [
        // Persona type pill
        if (profile?.personaType != null && profile!.personaType!.isNotEmpty)
          DabblerBadge(
            label: personaLabel(context, profile.personaType),
            tone: DabblerBadgeTone.defaultTone,
          ),
        // Primary sport pill — resolved from public.sports
        if (sportName != null && sportName.isNotEmpty)
          DabblerBadge(
            label: sportName,
            tone: DabblerBadgeTone.withIcon,
            icon: sport == null ? null : DabblerSportIcon(sport, size: 14),
          ),
        if (location.isNotEmpty)
          DabblerBadge(
            label: location,
            tone: DabblerBadgeTone.withIcon,
            icon: const DabblerIcon('location', size: 14),
          ),
        if (profile?.age != null)
          DabblerBadge(
            label:
                '${profile!.age!} ${AppLocalizations.of(context).user_profile_age_suffix}',
            tone: DabblerBadgeTone.withIcon,
            icon: const DabblerIcon('cake', size: 14),
          ),
      ],
    );
  }

  // ── Stats bento ──────────────────────────────────────────────────────

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
    final l10n = AppLocalizations.of(context);

    DabblerStatTile tile(
      String value,
      String label,
      DabblerStatTileTone tone,
    ) => DabblerStatTile(
      value: value,
      label: label,
      tone: tone,
      span: 2,
      rows: 1,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space8),
      child: DabblerStatGrid(
        children: [
          tile(
            statistics.totalGamesPlayed.toString(),
            l10n.user_profile_stat_games,
            DabblerStatTileTone.brand,
          ),
          tile(
            statistics.winRateFormatted,
            l10n.user_profile_stat_win_rate,
            DabblerStatTileTone.ink,
          ),
          tile(
            sportsState.profiles.length.toString(),
            l10n.user_profile_stat_sports,
            DabblerStatTileTone.card,
          ),
          tile(
            '${statistics.getReliabilityScore().round()}%',
            l10n.user_profile_stat_reliability,
            DabblerStatTileTone.amber,
          ),
          // Activity and last play carry words, not numbers: one wider tile
          // with the last play as its sub-line.
          DabblerStatTile(
            value: statistics.getActivityLevel(),
            label: l10n.user_profile_stat_activity,
            sub:
                '${l10n.user_profile_stat_last_play}: ${statistics.lastActiveFormatted}',
            tone: DabblerStatTileTone.sunken,
            span: 4,
            rows: 1,
          ),
        ],
      ),
    );
  }

  // ── Sports ───────────────────────────────────────────────────────────

  Widget _buildSportsChipsSection(
    BuildContext context,
    UserProfile? profile,
    DabblerColors colors,
  ) {
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
      final dsSport = listingSportFor(sport.nameEn as String?);

      return DabblerChip(
        label: sport.nameEn,
        leadingIcon: dsSport == null ? null : DabblerSportIcon(dsSport),
        onTap:
            profileId == null ||
                userId == null ||
                (personaType != 'player' && personaType != 'organiser')
            ? null
            : () {
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
                // Query params keep the route alive across web refresh;
                // extra stays as the fast path.
                context.push(
                  Uri(
                    path: RoutePaths.sportProfile,
                    queryParameters: args.toQueryParameters(),
                  ).toString(),
                  extra: args,
                );
              },
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).profile_section_sports,
            style: _t(context, DabblerType.headline, colors.textPrimary),
          ),
          const SizedBox(height: DabblerSpacing.space3),
          if (isWide)
            Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              children: chips,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: DabblerSpacing.space2,
                        ),
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

  // ── Actions ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    final myProfileIdAsync = ref.watch(myProfileIdProvider);

    final myProfileId = myProfileIdAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );
    // Use the same profile ID displayed on screen (from profileControllerProvider)
    // to ensure counters, follow state, and follow actions all reference the same profile.
    final targetProfileId = ref.watch(profileControllerProvider).profile?.id;

    return Row(
      children: [
        Expanded(
          child: (myProfileId == null || targetProfileId == null)
              ? DabblerButton(
                  label: AppLocalizations.of(context).user_profile_btn_loading,
                  tone: DabblerButtonTone.outlined,
                  loading: true,
                  fullWidth: true,
                )
              : _buildFollowButton(
                  context,
                  myProfileId: myProfileId,
                  targetProfileId: targetProfileId,
                ),
        ),
        // KAN-45: chat isn't wired up (this route only reaches a
        // "Coming Soon" placeholder) — hide the button until it ships.
        if (FeatureFlags.messaging) ...[
          const SizedBox(width: DabblerSpacing.space3),
          DabblerButton.icon(
            icon: 'sms',
            semanticLabel: 'Message',
            tone: DabblerButtonTone.outlined,
            onPressed: () => _sendMessage(context),
          ),
        ],
      ],
    );
  }

  Widget _buildFollowButton(
    BuildContext context, {
    required String myProfileId,
    required String targetProfileId,
  }) {
    final l10n = AppLocalizations.of(context);

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
      return DabblerButton(
        label: l10n.user_profile_btn_unblock,
        icon: 'slash',
        tone: DabblerButtonTone.destructive,
        fullWidth: true,
        onPressed: () => _unblockUser(context),
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
      return DabblerButton(
        label: l10n.user_profile_btn_following,
        icon: 'user-tick',
        tone: DabblerButtonTone.outlined,
        fullWidth: true,
        onPressed: () => _toggleFollow(
          context,
          myProfileId: myProfileId,
          targetProfileId: targetProfileId,
          currentlyFollowing: true,
        ),
      );
    }

    return DabblerButton(
      label: l10n.user_profile_btn_follow,
      icon: 'user-add',
      tone: DabblerButtonTone.primary,
      fullWidth: true,
      onPressed: () => _toggleFollow(
        context,
        myProfileId: myProfileId,
        targetProfileId: targetProfileId,
        currentlyFollowing: false,
      ),
    );
  }

  // ── Tabbed posts ─────────────────────────────────────────────────────

  /// Tabbed posts section
  Widget _buildTabbedPostsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(profileControllerProvider).profile?.id;

    return Column(
      key: _activitiesKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _gutter,
          child: DabblerTabs(
            scrollable: true,
            value: _tabIds[_selectedTabIndex],
            onChanged: (id) =>
                setState(() => _selectedTabIndex = _tabIds.indexOf(id)),
            items: [
              DabblerTabItem(id: _tabIds[0], label: l10n.profile_tab_posts),
              DabblerTabItem(id: _tabIds[1], label: l10n.profile_tab_replies),
              DabblerTabItem(id: _tabIds[2], label: l10n.profile_tab_liked),
              DabblerTabItem(id: _tabIds[3], label: l10n.profile_tab_reposts),
              DabblerTabItem(id: _tabIds[4], label: l10n.profile_tab_activity),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space1),
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

  Widget _tabLoading() => const Padding(
    padding: EdgeInsets.all(DabblerSpacing.space11),
    child: Center(child: DabblerSpinner()),
  );

  Widget _buildActivityTabContent(BuildContext context, String? profileId) {
    if (profileId == null) return const SizedBox.shrink();
    final state = ref.watch(userActivitiesProvider(profileId));

    if (state.isLoading && state.activities.isEmpty) {
      return _tabLoading();
    }

    if (state.activities.isEmpty) {
      return _buildEmptyTabContent(
        context,
        AppLocalizations.of(context).profile_empty_no_activity,
      );
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

    return _buildPostsList(
      postsAsync,
      AppLocalizations.of(context).profile_empty_no_posts,
    );
  }

  Widget _buildRepliesTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userCommentedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(
      postsAsync,
      AppLocalizations.of(context).profile_empty_no_replies,
    );
  }

  Widget _buildLikedTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userLikedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(
      postsAsync,
      AppLocalizations.of(context).profile_empty_no_liked,
    );
  }

  Widget _buildRepostsTabContent(BuildContext context, String? profileId) {
    final postsAsync = profileId != null
        ? ref.watch(userRepostedPostsProvider((profileId: profileId, page: 0)))
        : const AsyncData<List<Post>>([]);

    return _buildPostsList(
      postsAsync,
      AppLocalizations.of(context).profile_empty_no_reposts,
    );
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
              padding: const EdgeInsets.only(bottom: DabblerSpacing.space1),
              child: resolvePostLayout(post),
            );
          }).toList(),
        );
      },
      loading: _tabLoading,
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space11),
        child: DabblerEmptyState(
          icon: 'danger',
          title: AppLocalizations.of(context).profile_error_failed_load_posts,
        ),
      ),
    );
  }

  Widget _buildEmptyTabContent(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space11),
      child: DabblerEmptyState(icon: 'document-text', title: message),
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
        child: Center(child: DabblerSpinner()),
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

  /// The genuine `auth.users` id of the profile currently loaded on this
  /// screen. `widget.userId` is NOT reliably this — some entry points (e.g. a
  /// game creator card) only know a profile id and pass it in that slot. Any
  /// action that writes to a user-level (not profile-level) table — block,
  /// report, message — must resolve the real auth uid from the loaded
  /// profile instead, and no-op if it isn't loaded yet rather than fall back
  /// to widget.userId.
  String? _targetAuthUserId() =>
      ref.read(profileControllerProvider).profile?.userId;

  void _sendMessage(BuildContext context) {
    final userId = _targetAuthUserId();
    if (userId == null) return;
    // Gate chat entry on block status
    final isBlocked = ref.read(isUserBlockedProvider(userId));
    isBlocked.whenData((blocked) {
      if (blocked) {
        _toast(AppLocalizations.of(context).user_profile_cannot_message_blocked);
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
    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: AppLocalizations.of(ctx).user_profile_block_dialog_title,
        description: AppLocalizations.of(ctx).user_profile_block_dialog_body,
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: AppLocalizations.of(ctx).profile_btn_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: AppLocalizations.of(ctx).user_profile_block_btn_block,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );

    if (confirmed != true) return;

    final targetUserId = _targetAuthUserId();
    if (targetUserId == null) return;
    final repo = ref.read(blockRepositoryProvider);
    final result = await repo.blockUser(targetUserId);

    result.fold(
      (err) {
        _toast('Error: ${err.message}', tone: DabblerToastTone.error);
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
          _toast(AppLocalizations.of(context).user_profile_blocked_snack);
        }
      },
    );
  }

  Future<void> _unblockUser(BuildContext context) async {
    final targetUserId = _targetAuthUserId();
    if (targetUserId == null) return;
    final repo = ref.read(blockRepositoryProvider);
    final result = await repo.unblockUser(targetUserId);

    result.fold(
      (err) {
        _toast('Error: ${err.message}', tone: DabblerToastTone.error);
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
          _toast(AppLocalizations.of(context).user_profile_unblocked_snack);
        }
      },
    );
  }

  void _reportUser(BuildContext context) {
    final targetUserId = _targetAuthUserId();
    if (targetUserId == null) return;
    showReportDialog(
      context,
      targetType: ReportTargetType.user,
      targetId: targetUserId,
      targetUserId: targetUserId,
    );
  }

  void _showMoreOptions(BuildContext context) {
    final targetUserId = _targetAuthUserId();
    final blocked = targetUserId == null
        ? false
        : ref.read(isUserBlockedProvider(targetUserId)).valueOrNull ?? false;

    showDabblerSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            DabblerSpacing.space2,
            DabblerSpacing.space6,
            DabblerSpacing.space8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocked)
                DabblerButton(
                  label: l10n.user_profile_menu_unblock_user,
                  icon: 'close-circle',
                  tone: DabblerButtonTone.neutral,
                  fullWidth: true,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _unblockUser(this.context);
                  },
                )
              else
                DabblerButton(
                  label: l10n.user_profile_menu_block_user,
                  icon: 'close-circle',
                  tone: DabblerButtonTone.neutral,
                  fullWidth: true,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _blockUser(this.context);
                  },
                ),
              const SizedBox(height: DabblerSpacing.space3),
              DabblerButton(
                label: l10n.user_profile_menu_report_user,
                icon: 'warning-2',
                tone: DabblerButtonTone.neutral,
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _reportUser(this.context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dot for online status: a pulsing success dot while online, a static
/// neutral dot otherwise.
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
    if (!widget.isOnline) {
      return const DabblerBadge.dot(tone: DabblerBadgeTone.withIcon);
    }

    return FadeTransition(
      opacity: _animation,
      child: DabblerBadge.dot(status: DabblerColors.of(context).success),
    );
  }
}
