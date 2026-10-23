import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_repository.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_cards.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_header.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_section_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page's tabs. Places has no source and News has no repository that reads
/// a sport's news, so neither is a tab (recorded on KAN-622).
enum SportTab { overview, games, meetups, venues, posts }

String sportTabLabel(AppLocalizations l, SportTab tab) => switch (tab) {
  SportTab.overview => l.sport_overview_tab_overview,
  SportTab.games => l.sport_overview_tab_games,
  SportTab.meetups => l.sport_overview_tab_meetups,
  SportTab.venues => l.sport_overview_tab_venues,
  SportTab.posts => l.sport_overview_tab_posts,
};

/// Whether the Venues tab shows venues or spaces: never mixed in one list.
enum SportVenuesMode { venues, spaces }

Widget _gap(double h) => DabblerGap.v(h);

Widget _padded(Widget child) => Padding(padding: kSportGutter, child: child);

// Overview -------------------------------------------------------------------

class SportOverviewTab extends ConsumerWidget {
  const SportOverviewTab({
    super.key,
    required this.sport,
    required this.scope,
    required this.onOpenTab,
  });

  final SportInfo sport;
  final SportScope scope;

  /// Opens a tab (a counter tile or a See all). The Spaces tile also asks for
  /// the Spaces side of the Venues tab.
  final void Function(SportTab tab, {SportVenuesMode? venuesMode}) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<SportOverviewCounts> counts = ref.watch(
      sportOverviewCountsProvider(scope),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _padded(
          sportAsyncSection<SportOverviewCounts>(
            value: counts,
            skeletonRows: 1,
            isEmpty: (_) => false,
            empty: const SizedBox.shrink(),
            onRetry: () => ref.invalidate(sportOverviewCountsProvider(scope)),
            data: (SportOverviewCounts c) => DabblerStatGrid(
              children: <DabblerStatTile>[
                DabblerStatTile(
                  value: '${c.gamesNext7}',
                  label: l.sport_overview_stat_games,
                  span: 3,
                  onTap: () => onOpenTab(SportTab.games),
                ),
                DabblerStatTile(
                  value: '${c.meetupsNext7}',
                  label: l.sport_overview_stat_meetups,
                  span: 3,
                  onTap: () => onOpenTab(SportTab.meetups),
                ),
                DabblerStatTile(
                  value: '${c.venues}',
                  label: l.sport_overview_stat_venues,
                  span: 2,
                  onTap: () => onOpenTab(
                    SportTab.venues,
                    venuesMode: SportVenuesMode.venues,
                  ),
                ),
                DabblerStatTile(
                  value: '${c.spaces}',
                  label: l.sport_overview_stat_spaces,
                  span: 2,
                  onTap: () => onOpenTab(
                    SportTab.venues,
                    venuesMode: SportVenuesMode.spaces,
                  ),
                ),
                DabblerStatTile(
                  value: '${c.posts}',
                  label: l.sport_overview_stat_posts,
                  span: 2,
                  onTap: () => onOpenTab(SportTab.posts),
                ),
              ],
            ),
          ),
        ),
        _gap(DabblerSpacing.space8),
        _PreviewHeader(
          title: l.sport_overview_section_games,
          onSeeAll: () => onOpenTab(SportTab.games),
        ),
        _gap(DabblerSpacing.space3),
        _GamesBody(
          sport: sport,
          scope: scope,
          limit: kSportOverviewPreviewCount,
        ),
        _gap(DabblerSpacing.space8),
        _PreviewHeader(
          title: l.sport_overview_section_venues,
          onSeeAll: () =>
              onOpenTab(SportTab.venues, venuesMode: SportVenuesMode.venues),
        ),
        _gap(DabblerSpacing.space3),
        _VenuesBody(scope: scope, limit: kSportOverviewPreviewCount),
        _gap(DabblerSpacing.space8),
        _PreviewHeader(
          title: l.sport_overview_section_posts,
          onSeeAll: () => onOpenTab(SportTab.posts),
        ),
        _gap(DabblerSpacing.space3),
        _PostsBody(sportId: sport.id, limit: kSportOverviewPreviewCount),
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _padded(
      Row(
        children: <Widget>[
          Expanded(child: DabblerText(title, style: DabblerType.title3)),
          DabblerButton(
            label: AppLocalizations.of(context).sport_overview_see_all,
            tone: DabblerButtonTone.text,
            size: DabblerButtonSize.small,
            onPressed: onSeeAll,
          ),
        ],
      ),
    );
  }
}

// Games / Meetups ------------------------------------------------------------

class SportGamesTab extends ConsumerWidget {
  const SportGamesTab({super.key, required this.sport, required this.scope});

  final SportInfo sport;
  final SportScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _GamesBody(sport: sport, scope: scope);
}

class _GamesBody extends ConsumerWidget {
  const _GamesBody({required this.sport, required this.scope, this.limit});

  final SportInfo sport;
  final SportScope scope;
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _padded(
      sportAsyncSection<List<NearbyGameModel>>(
        value: ref.watch(sportGamesProvider(scope)),
        isEmpty: (List<NearbyGameModel> g) => g.isEmpty,
        empty: SportSectionEmpty(
          icon: 'calendar',
          title: l.sport_overview_empty_games_title,
          text: l.sport_overview_empty_games_text,
        ),
        onRetry: () => ref.invalidate(sportGamesProvider(scope)),
        data: (List<NearbyGameModel> games) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final NearbyGameModel g
                in limit == null ? games : games.take(limit!)) ...<Widget>[
              SportGameCard(
                key: ValueKey<String>('game-${g.id}'),
                game: g,
                sport: sport,
                onJoined: () => ref.invalidate(sportGamesProvider(scope)),
              ),
              const DabblerGap.v(DabblerSpacing.space4),
            ],
          ],
        ),
      ),
    );
  }
}

class SportMeetupsTab extends ConsumerWidget {
  const SportMeetupsTab({super.key, required this.sport, required this.scope});

  final SportInfo sport;
  final SportScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _padded(
      sportAsyncSection<List<MeetupListItem>>(
        value: ref.watch(sportMeetupsProvider(scope)),
        isEmpty: (List<MeetupListItem> m) => m.isEmpty,
        empty: SportSectionEmpty(
          icon: 'people',
          title: l.sport_overview_empty_meetups_title,
          text: l.sport_overview_empty_meetups_text,
        ),
        onRetry: () => ref.invalidate(sportMeetupsProvider(scope)),
        data: (List<MeetupListItem> meetups) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final MeetupListItem m in meetups) ...<Widget>[
              SportMeetupCard(
                key: ValueKey<String>('meetup-${m.id}'),
                meetup: m,
                sport: sport,
                onChanged: () => ref.invalidate(sportMeetupsProvider(scope)),
              ),
              const DabblerGap.v(DabblerSpacing.space4),
            ],
          ],
        ),
      ),
    );
  }
}

// Venues / Spaces ------------------------------------------------------------

class SportVenuesTab extends ConsumerWidget {
  const SportVenuesTab({
    super.key,
    required this.scope,
    required this.mode,
    required this.onModeChanged,
  });

  final SportScope scope;
  final SportVenuesMode mode;
  final ValueChanged<SportVenuesMode> onModeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _padded(
          DabblerTabs(
            variant: DabblerTabsVariant.segmented,
            fullWidth: true,
            value: mode.name,
            onChanged: (String id) => onModeChanged(
              SportVenuesMode.values.firstWhere((m) => m.name == id),
            ),
            items: <DabblerTabItem>[
              DabblerTabItem(
                id: SportVenuesMode.venues.name,
                label: l.sport_overview_switch_venues,
              ),
              DabblerTabItem(
                id: SportVenuesMode.spaces.name,
                label: l.sport_overview_switch_spaces,
              ),
            ],
          ),
        ),
        _gap(DabblerSpacing.space4),
        if (mode == SportVenuesMode.venues)
          _VenuesBody(scope: scope)
        else
          _SpacesBody(scope: scope),
      ],
    );
  }
}

class _VenuesBody extends ConsumerWidget {
  const _VenuesBody({required this.scope, this.limit});

  final SportScope scope;
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _padded(
      sportAsyncSection<List<SportVenue>>(
        value: ref.watch(sportVenuesProvider(scope)),
        isEmpty: (List<SportVenue> v) => v.isEmpty,
        empty: SportSectionEmpty(
          icon: 'building',
          title: l.sport_overview_empty_venues_title,
          text: l.sport_overview_empty_venues_text,
        ),
        onRetry: () => ref.invalidate(sportVenuesProvider(scope)),
        data: (List<SportVenue> venues) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final SportVenue v
                in limit == null ? venues : venues.take(limit!)) ...<Widget>[
              SportVenueCard(key: ValueKey<String>('venue-${v.id}'), venue: v),
              const DabblerGap.v(DabblerSpacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpacesBody extends ConsumerWidget {
  const _SpacesBody({required this.scope});

  final SportScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _padded(
      sportAsyncSection<List<SportSpace>>(
        value: ref.watch(sportSpacesProvider(scope)),
        isEmpty: (List<SportSpace> s) => s.isEmpty,
        empty: SportSectionEmpty(
          icon: 'building',
          title: l.sport_overview_empty_spaces_title,
          text: l.sport_overview_empty_spaces_text,
        ),
        onRetry: () => ref.invalidate(sportSpacesProvider(scope)),
        data: (List<SportSpace> spaces) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final SportSpace s in spaces) ...<Widget>[
              SportSpaceCard(key: ValueKey<String>('space-${s.id}'), space: s),
              const DabblerGap.v(DabblerSpacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}

// Posts ----------------------------------------------------------------------

class SportPostsTab extends ConsumerWidget {
  const SportPostsTab({super.key, required this.sportId});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _PostsBody(sportId: sportId, paged: true);
}

/// The sport-tagged posts, newest first. Rows are the Home feed's post row, so
/// the existing post actions work; the Following filter is not applied.
class _PostsBody extends ConsumerWidget {
  const _PostsBody({required this.sportId, this.limit, this.paged = false});

  final String sportId;
  final int? limit;
  final bool paged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SportPostsState state = ref.watch(sportPostsProvider(sportId));
    final SportPostsNotifier notifier = ref.read(
      sportPostsProvider(sportId).notifier,
    );
    if (state.loading) {
      return _padded(const SportSectionSkeleton());
    }
    if (state.error != null) {
      return _padded(SportSectionError(onRetry: notifier.load));
    }
    if (state.posts.isEmpty) {
      return _padded(
        SportSectionEmpty(
          icon: 'message-text',
          title: l.sport_overview_empty_posts_title,
          text: l.sport_overview_empty_posts_text,
        ),
      );
    }
    final List<Post> posts = limit == null
        ? state.posts
        : state.posts.take(limit!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Post p in posts) ...<Widget>[
          HomePostRow.resolve(
            p,
            metrics: DabblerFeedMetrics.drawn,
            currentSportId: sportId,
          ),
          const DabblerDivider(),
        ],
        if (paged && state.loadMoreFailed)
          _padded(SportSectionError(onRetry: notifier.loadMore)),
        if (paged && state.hasMore && !state.loadMoreFailed)
          _padded(
            DabblerButton(
              label: l.sport_overview_load_more,
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              loading: state.loadingMore,
              onPressed: notifier.loadMore,
            ),
          ),
      ],
    );
  }
}
