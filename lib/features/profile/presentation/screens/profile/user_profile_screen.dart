import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/sports_profile_controller.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_feed.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import '../../models/sport_profile_route_args.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show userPostsProvider, sportsProvider;
import 'package:dabbler/l10n/app_localizations.dart';

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
  final _activitiesKey = GlobalKey();

  // Drives the top bar: tinted with no title until the identity block has
  // scrolled away, then the page ground with the handle.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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

    final posts = profileId == null
        ? 0
        : ref
              .watch(userPostsProvider((profileId: profileId, page: 0)))
              .maybeWhen(data: (v) => v.length, orElse: () => 0);
    final following = profileId == null
        ? 0
        : ref
              .watch(followingCountProvider(profileId))
              .maybeWhen(data: (v) => v, orElse: () => 0);
    final followers = profileId == null
        ? 0
        : ref
              .watch(followersCountProvider(profileId))
              .maybeWhen(data: (v) => v, orElse: () => 0);

    final allSports = ref.watch(sportsProvider).valueOrNull ?? [];
    final byId = {for (final s in allSports) s.id: s};
    final mySports = [
      for (final id in profile?.interests ?? const <String>[])
        if (byId.containsKey(id)) byId[id]!,
    ];

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: (username != null && username.isNotEmpty)
            ? '\u200E@$username'
            : null,
        scrollController: _scroll,
        heroTint: true,
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
        onRefresh: _loadProfileData,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: DabblerSpacing.space11),
          children: [
            OwnProfileHeader(
              profile: profile,
              posts: posts,
              following: following,
              followers: followers,
              sportsCount: mySports.length,
              sportsLabel: l10n.user_profile_stat_sports,
              location: _formatLocation(profile?.city, profile?.country),
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
            if (profile != null) _buildStats(context, profile, sportsState),
            const DabblerGap.v(DabblerSpacing.space8),
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

  void _openSportProfile(UserProfile? profile, dynamic sport) {
    final profileId = profile?.id;
    final userId = profile?.userId;
    final personaType = profile?.personaType ?? profile?.profileType ?? '';
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
          sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_'),
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

  Widget _buildStats(
    BuildContext context,
    UserProfile profile,
    SportsProfileState sportsState,
  ) {
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
          const DabblerGap.h(DabblerSpacing.space3),
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
      leadingWidget: const DabblerIcon(
        'add',
        weight: DabblerIconWeight.bold,
        size: DabblerSizing.iconSm,
      ),
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
        _toast(
          AppLocalizations.of(context).user_profile_cannot_message_blocked,
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
              const DabblerGap.v(DabblerSpacing.space3),
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
