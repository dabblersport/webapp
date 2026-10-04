import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/manage_profiles_sheet.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_feed.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_followed_sports.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import '../../../../../app/app_router.dart';
import '../../providers/profile_providers.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';

import '../../../../../utils/constants/route_constants.dart';
import '../../models/sport_profile_route_args.dart';

import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsProvider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with RouteAware {
  String? _selectedSportId;

  String? _selectedProfileType; // 'player' or 'organiser'

  // Drives the top bar: the tinted bar shows no title until the identity block
  // has scrolled away, then drops to the page ground with the handle.
  final ScrollController _scroll = ScrollController();

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
    _scroll.dispose();
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
      ref.invalidate(
        sportProfileHeaderProvider((userId: user.id, profileId: null)),
      );
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
        DabblerToastProvider.of(
          context,
        ).show(DabblerToastSpec(message: errorMsg));
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

  void _openSportProfile(UserProfile? profile, dynamic sport) {
    final profileId = profile?.id;
    final userId = profile?.userId;
    final personaType =
        profile?.personaType ?? profile?.profileType ?? 'player';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileState = ref.watch(profileControllerProvider);
    final sportsState = ref.watch(sportsProfileControllerProvider);
    final profile = profileState.profile;
    final profileId = profile?.id;

    final takedownAsync = profileId != null
        ? ref.watch(profileTakedownProvider(profileId))
        : const AsyncData<bool>(false);

    if (profileId != null &&
        takedownAsync.maybeWhen(data: (v) => v, orElse: () => false)) {
      return DabblerPage(
        body: Center(
          child: DabblerEmptyState(
            icon: 'close-square',
            title: l10n.profile_takedown_title,
            text: l10n.profile_takedown_body,
            size: DabblerEmptyStateSize.page,
          ),
        ),
      );
    }
    if (profileId != null && takedownAsync is AsyncLoading) {
      return const DabblerPage(body: Center(child: DabblerSpinner()));
    }

    final posts = ref
        .watch(myPostsCountProvider)
        .maybeWhen(data: (v) => v, orElse: () => 0);
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
    final selected =
        _selectedSportId != null &&
            mySports.any((s) => s.id == _selectedSportId)
        ? mySports.firstWhere((s) => s.id == _selectedSportId)
        : null;
    final sportProfiles = sportsState.profiles;
    final shown = selected == null
        ? sportProfiles
        : sportProfiles.where((p) => p.sportId == selected.id).toList();
    final personaType =
        profile?.personaType ?? profile?.profileType ?? 'player';
    final List<String> primaryNames = [
      for (final p in sportProfiles)
        if (p.isPrimarySport) p.sportName,
    ];
    final String allSub =
        (primaryNames.isNotEmpty
                ? primaryNames
                : [for (final s in mySports) s.nameEn])
            .take(3)
            .join(' · ');
    final canOpen =
        profile?.userId != null &&
        (personaType == 'player' || personaType == 'organiser');

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: (profile?.username ?? '').isNotEmpty
            ? '\u200E@${profile!.username!}'
            : l10n.profile_header_fallback,
        scrollController: _scroll,
        heroTint: true,
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
      ),
      body: DabblerRefresh(
        onRefresh: _refreshProfileWithCacheClear,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: DabblerSpacing.space9),
          children: [
            OwnProfileHeader(
              profile: profile,
              posts: posts,
              following: following,
              followers: followers,
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
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            OwnProfileStats(
              posts: posts,
              sportsCount: mySports.length,
              gamesPlayed: sportProfiles.isEmpty
                  ? null
                  : shown.fold<int>(0, (a, p) => a + p.gamesPlayed),
              rating: shown.isEmpty
                  ? null
                  : shown.fold<double>(0, (a, p) => a + p.averageRating) /
                        shown.length,
              winRate: personaType == 'player'
                  ? profile?.statistics.winRateFormatted
                  : null,
              reliability: personaType == 'player'
                  ? profile?.statistics.getReliabilityScore().round()
                  : null,
              primarySports: sportProfiles
                  .where((p) => p.isPrimarySport)
                  .length,
              sportsLabel: personaType == 'socialiser'
                  ? l10n.profile_stat_sports_followed
                  : null,
              sportsTone: personaType == 'socialiser'
                  ? DabblerStatTileTone.ink
                  : DabblerStatTileTone.card,
              scoped: selected != null,
              heroLabel: selected == null
                  ? null
                  : l10n.profile_stat_sport_matches(selected.nameEn),
              heroSub: selected == null
                  ? (allSub.isEmpty ? null : allSub)
                  : (shown.isEmpty ? null : shown.first.getSkillLevelName()),
              accent: switch (personaType) {
                'socialiser' => DabblerSportAccent.socialRamp,
                'organiser' => DabblerSportAccent.mainRamp,
                _ => DabblerSportAccent.of(
                  selected == null
                      ? null
                      : OwnProfileSportPicker.sportKeyOf(selected),
                ),
              },
              heroTone: personaType == 'host'
                  ? DabblerStatTileTone.amber
                  : DabblerStatTileTone.brand,
              // The sport artwork belongs to a player's hero only.
              sportKey: personaType != 'player'
                  ? null
                  : (selected ?? (mySports.isEmpty ? null : mySports.first))
                        ?.sportKey,
              onOpenSport: selected != null && canOpen
                  ? () => _openSportProfile(profile, selected)
                  : null,
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            if (personaType == 'socialiser')
              OwnProfileFollowedSports(sports: mySports)
            else
              OwnProfileSportPicker(
                sports: mySports,
                selectedId: selected?.id,
                primaryId: profile?.primarySport,
                onSelect: (id) => setState(() => _selectedSportId = id),
                onManage: () => ManageSportsSheet.show(context),
              ),
            const DabblerGap.v(DabblerSpacing.space8),
            if (profileId == null)
              const Padding(
                padding: EdgeInsets.all(DabblerSpacing.space11),
                child: Center(child: DabblerSpinner()),
              )
            else
              OwnProfileFeed(profileId: profileId),
          ],
        ),
      ),
    );
  }
}
