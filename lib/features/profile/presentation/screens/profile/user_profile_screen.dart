import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import '../../providers/visited_profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_actions.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_feed.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/visitor/contributor_visitor_sections.dart';
import 'package:dabbler/features/ratings/presentation/widgets/rating_summary.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import '../../models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_message_action.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsProvider;
import 'package:dabbler/l10n/app_localizations.dart';

/// Another user's profile (design frames PF04 / PF05, "seen by another
/// user"): a brand-tinted identity header (avatar, name, handle, place badge,
/// bio, counters, Follow / Message actions), then the persona's body, then
/// the tabbed posts. DS-only; the content column is centred.
///
/// A Contributor gets the `contributorVisitor` body (KAN-688): the
/// practicing-sport selector, the bento it scopes and the public Upcoming
/// list, all from the KAN-686 read model. Other personas keep their existing
/// layout; converting them is out of scope.
///
/// The visited profile lives in [visitedProfileControllerProvider], keyed by
/// route identity, so opening someone else never replaces the signed-in
/// user's own `profileControllerProvider`.
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
    with UserProfileActions {
  final _activitiesKey = GlobalKey();

  // Drives the top bar: tinted with no title until the identity block has
  // scrolled away, then the page ground with the handle.
  final ScrollController _scroll = ScrollController();

  @override
  VisitedProfileKey get visitedKey =>
      (userId: widget.userId, profileId: widget.profileId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!mounted) return;

    if (widget.profileId != null && widget.profileId != myProfileId) {
      // Viewing own inactive profile — do NOT redirect to ProfileScreen.
      return;
    }

    final viewedProfileId = visitedProfileId();
    if (viewedProfileId != null && viewedProfileId == myProfileId) {
      context.go(RoutePaths.profile);
    }
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final profileController = ref.read(
      visitedProfileControllerProvider(visitedKey).notifier,
    );
    final sportsController = ref.read(
      visitedSportsProfileControllerProvider(visitedKey).notifier,
    );
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

  Future<void> _refresh() async {
    final String? profileId = visitedProfileId();
    if (profileId != null) {
      ref.invalidate(visitedFollowersCountProvider(profileId));
      ref.invalidate(visitedFollowingCountProvider(profileId));
      ref.invalidate(visitedPostsCountProvider(profileId));
    }
    await _loadProfileData();
  }

  ProfileCounterState _stateOf(AsyncValue<int>? v) {
    if (v == null || v.isLoading && !v.hasValue) {
      return ProfileCounterState.loading;
    }
    if (v.hasError && !v.isLoading) return ProfileCounterState.failed;
    return ProfileCounterState.data;
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(
      visitedProfileControllerProvider(visitedKey),
    );
    final sportsState = ref.watch(
      visitedSportsProfileControllerProvider(visitedKey),
    );
    final l10n = AppLocalizations.of(context);

    if (profileState.isLoading) {
      return const DabblerPage(body: Center(child: DabblerSpinner()));
    }

    if (profileState.errorMessage != null && profileState.profile == null) {
      // Neutral, not alarming: most of the time this fires because the
      // profile isn't visible to this viewer (a benched persona, per
      // P-028/KAN-100), not because anything actually failed.
      return DabblerPage(
        body: DabblerEmptyState(
          icon: 'profile-circle',
          title: l10n.user_profile_error_not_found_title,
          text:
              profileState.errorMessage ??
              l10n.user_profile_error_unable_to_load,
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
    final profileId = profile?.id;
    final authUserId = profile?.userId;

    final postsAsync = profileId == null
        ? null
        : ref.watch(visitedPostsCountProvider(profileId));
    final followingAsync = profileId == null
        ? null
        : ref.watch(visitedFollowingCountProvider(profileId));
    final followersAsync = profileId == null
        ? null
        : ref.watch(visitedFollowersCountProvider(profileId));

    final isContributor =
        personaTypeOrNull(profile?.personaType ?? profile?.profileType) ==
        PersonaType.contributor;

    final allSports = ref.watch(sportsProvider).valueOrNull ?? [];
    final byId = {for (final s in allSports) s.id: s};
    final mySports = [
      for (final id in profile?.interests ?? const <String>[])
        if (byId.containsKey(id)) byId[id]!,
    ];

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: (username != null && username.isNotEmpty) ? '‎@$username' : null,
        scrollController: _scroll,
        heroTint: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        actions: [
          DabblerNavigationAction(
            icon: 'more',
            label: 'More',
            onPressed: showMoreOptions,
          ),
        ],
      ),
      body: DabblerRefresh(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: DabblerSpacing.space11),
          children: [
            OwnProfileHeader(
              profile: profile,
              posts: postsAsync?.valueOrNull ?? 0,
              following: followingAsync?.valueOrNull ?? 0,
              followers: followersAsync?.valueOrNull ?? 0,
              postsState: _stateOf(postsAsync),
              followingState: _stateOf(followingAsync),
              followersState: _stateOf(followersAsync),
              onRetryCounts: profileId == null
                  ? null
                  : () {
                      ref.invalidate(visitedPostsCountProvider(profileId));
                      ref.invalidate(visitedFollowingCountProvider(profileId));
                      ref.invalidate(visitedFollowersCountProvider(profileId));
                    },
              // The Contributor frame's third counter is Posts; the other
              // personas keep their Sports counter.
              sportsCount: isContributor ? null : mySports.length,
              sportsLabel: l10n.user_profile_stat_sports,
              location: _formatLocation(profile?.city, profile?.country),
              showPersonaBadge: !isContributor,
              onCopyLink: isContributor && profileId != null
                  ? () => copyProfileLink(confirmInPlace: true)
                  : null,
              linkCopied: linkCopied,
              onPosts: _scrollToFeed,
              onFollowing: profileId == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.following,
                      pathParameters: {'profileId': profileId},
                    ),
              onFollowers: profileId == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.followers,
                      pathParameters: {'profileId': profileId},
                    ),
              actions: _buildActionButtons(context),
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            if (isContributor && profileId != null && authUserId != null)
              ContributorVisitorSections(
                userId: authUserId,
                profileId: profileId,
                primarySportId: profile?.primarySport,
                onOpenSport: (sport) => _openSportProfile(profile, sport),
              )
            else ...[
              if (profile != null) _buildStats(profile, sportsState),
              const DabblerGap.v(DabblerSpacing.space8),
              RatingSummary(userId: profile?.userId),
              if (mySports.isNotEmpty) ...[
                OwnProfileSportPicker(
                  title: l10n.profile_section_their_sports,
                  sports: mySports,
                  selectedId: null,
                  primaryId: profile?.primarySport,
                  onSelect: (id) {
                    if (id == null) return;
                    _openSportProfile(
                      profile,
                      mySports.firstWhere((s) => s.id == id),
                    );
                  },
                ),
                const DabblerGap.v(DabblerSpacing.space8),
              ],
            ],
            if (profileId != null)
              KeyedSubtree(
                key: _activitiesKey,
                child: OwnProfileFeed(profileId: profileId),
              ),
          ],
        ),
      ),
    );
  }

  void _scrollToFeed() {
    final ctx = _activitiesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: DabblerMotion.durationOf(context, DabblerMotion.scrollTo),
        curve: DabblerMotion.standardInOut,
      );
    }
  }

  void _openSportProfile(UserProfile? profile, Sport sport) {
    final profileId = profile?.id;
    final userId = profile?.userId;
    final personaType = profile?.personaType ?? profile?.profileType ?? '';
    if (profileId == null ||
        userId == null ||
        (personaType != 'player' &&
            personaType != 'organiser' &&
            personaType != 'contributor')) {
      return;
    }
    final args = SportProfileRouteArgs(
      profileId: profileId,
      userId: userId,
      displayName: profile?.displayName ?? '',
      personaType: personaType,
      sportId: sport.id,
      sportKey: OwnProfileSportPicker.sportKeyOf(sport),
      sportName: sport.nameEn,
      avatarUrl: profile?.avatarUrl,
      sportEmoji: sport.emoji,
    );
    // Query params keep the route alive across web refresh; extra stays as
    // the fast path.
    context.push(
      Uri(
        path: RoutePaths.sportProfile,
        queryParameters: args.toQueryParameters(),
      ).toString(),
      extra: args,
    );
  }

  /// The legacy (non-Contributor) bento: Player and Organiser figures from
  /// the profile's own statistics. Contributors never reach this.
  Widget _buildStats(UserProfile profile, SportsProfileState sportsState) {
    final statistics = profile.statistics;
    final List<SportProfile> sports = sportsState.profiles;
    final List<SportProfile> rated = [
      for (final p in sports)
        if (p.averageRating > 0) p,
    ];
    return OwnProfileStats(
      posts: 0,
      sportsCount: sports.length,
      gamesPlayed: statistics.totalGamesPlayed,
      rating: rated.isEmpty
          ? null
          : rated.fold<double>(0, (a, p) => a + p.averageRating) / rated.length,
      minutesPlayed: (statistics.totalHoursPlayed * 60).round(),
      reliability: statistics.getReliabilityScore().round(),
      primarySports: sports.where((p) => p.isPrimarySport).length,
      heroSub: sports.isEmpty
          ? null
          : [
              for (final p in sports)
                if (p.isPrimarySport) p.sportName,
            ].take(3).join(' · '),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    final myProfileId = ref
        .watch(myProfileIdProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    // The profile on screen: counters, follow state and follow actions all
    // reference this one profiles.id.
    final visited = ref.watch(visitedProfileControllerProvider(visitedKey));
    final targetProfileId = visited.profile?.id;
    final targetAuthUserId = visited.profile?.userId;
    final flags = ref.watch(profileMessageActionFlagsProvider);
    final bool messageOn = flags.messaging && flags.direct;

    return ProfileActionButtons(
      follow: (myProfileId == null || targetProfileId == null)
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
      // KAN-557: the Message action draws nothing unless the messaging and
      // direct-message flags are on, so the gap goes with it.
      message: messageOn
          ? ProfileMessageAction(targetAuthUserId: targetAuthUserId)
          : null,
      invite: const ProfileInviteAction(),
    );
  }

  Widget _buildFollowButton(
    BuildContext context, {
    required String myProfileId,
    required String targetProfileId,
  }) {
    final l10n = AppLocalizations.of(context);
    final ids = (
      currentProfileId: myProfileId,
      targetProfileId: targetProfileId,
    );
    final isBlocked = ref
        .watch(isBlockedProvider(ids))
        .maybeWhen(data: (v) => v, orElse: () => false);

    if (isBlocked) {
      return DabblerButton(
        label: l10n.user_profile_btn_unblock,
        icon: 'slash',
        tone: DabblerButtonTone.destructive,
        fullWidth: true,
        onPressed: unblockUser,
      );
    }

    final isFollowing = ref
        .watch(isFollowingProvider(ids))
        .maybeWhen(data: (v) => v, orElse: () => false);

    if (isFollowing) {
      return DabblerButton(
        label: l10n.user_profile_btn_following,
        icon: 'user-tick',
        tone: DabblerButtonTone.outlined,
        fullWidth: true,
        onPressed: () => toggleFollow(
          myProfileId: myProfileId,
          targetProfileId: targetProfileId,
          currentlyFollowing: true,
        ),
      );
    }

    return DabblerButton(
      label: l10n.user_profile_btn_follow,
      leadingWidget: const DabblerIcon(
        'add',
        weight: DabblerIconWeight.bold,
        size: DabblerSizing.iconSm,
      ),
      tone: DabblerButtonTone.primary,
      fullWidth: true,
      onPressed: () => toggleFollow(
        myProfileId: myProfileId,
        targetProfileId: targetProfileId,
        currentlyFollowing: false,
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
}
