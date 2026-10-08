import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart'
    show ListingEmpty, ListingLayout;
import 'package:dabbler/features/favourites/data/favourite_item.dart';
import 'package:dabbler/features/favourites/presentation/providers/favourites_providers.dart';
import 'package:dabbler/features/games/data/repositories/favorites_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart'
    show formatDistanceMeters;
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart'
    show haversineMeters;
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_favourites.dart';
import 'package:dabbler/features/venues/providers.dart'
    show
        favoriteVenueIdsForCurrentUserProvider,
        favoriteVenuesForCurrentUserProvider;
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

/// The Favourites screen (`Favourites.dc.html`): a back button and the display
/// title, Venues / Games / Meetups tabs, and one compact row per favourite -
/// name, a meta line and a red heart that removes it; the row opens the detail.
/// Games and meetups list what is upcoming or running first, then an "Ended"
/// section; each tab has its own empty state.
class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key, this.initialKind = FavouriteKind.venue});

  /// The tab it opens on (Venues by default).
  final FavouriteKind initialKind;

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  late FavouriteKind _kind = widget.initialKind;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _open(FavouriteItem item) => context.push(switch (item.kind) {
    FavouriteKind.venue => RoutePaths.venueDetail(item.id),
    FavouriteKind.game => RoutePaths.gameDetail(item.id),
    FavouriteKind.meetup => RoutePaths.meetupDetail(item.id),
  });

  /// Takes the favourite off at once, then settles with the server's answer
  /// and says so; on failure the row comes back and the toast says why.
  Future<void> _remove(FavouriteItem item) async {
    final removals = ref.read(favouriteRemovalsProvider.notifier);
    removals.state = {...removals.state, item.id};
    final target = switch (item.kind) {
      FavouriteKind.venue => FavoriteTarget.venue,
      FavouriteKind.game => FavoriteTarget.game,
      FavouriteKind.meetup => FavoriteTarget.meetup,
    };
    final result = await ref
        .read(favoritesRepositoryProvider)
        .toggle(target, item.id);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value) when !value.favourited:
        // Gone for good: the listings' hearts follow.
        switch (item.kind) {
          case FavouriteKind.game:
            final o = ref.read(gameFavouriteOverridesProvider.notifier);
            o.state = {...o.state, item.id: value};
          case FavouriteKind.meetup:
            ref.invalidate(meetupFavouritesProvider);
          case FavouriteKind.venue:
            ref.invalidate(favoriteVenuesForCurrentUserProvider);
            ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        }
        showFavouriteToast(context, item.kind, added: false);
      case Ok(:final value):
        // The toggle added it back (it had already been removed elsewhere).
        removals.state = {...removals.state}..remove(item.id);
        showFavouriteToast(context, item.kind, added: value.favourited);
      case Err():
        removals.state = {...removals.state}..remove(item.id);
        showFavouriteToast(context, item.kind, added: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DabblerPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // `:9-15`: back circle and the display title.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ListingLayout.gutter,
                DabblerSpacing.space2,
                ListingLayout.gutter,
                DabblerSpacing.space5,
              ),
              child: Row(
                spacing: DabblerSpacing.space4,
                children: <Widget>[
                  DabblerPageHeaderButton(
                    icon: rtl ? 'arrow-circle-right' : 'arrow-circle-left',
                    semanticLabel: l.fav_back,
                    onPressed: _back,
                  ),
                  Expanded(
                    child: DabblerText(l.fav_title, style: DabblerType.title1),
                  ),
                ],
              ),
            ),
          ),
          // `:17-20`: the tabs.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ListingLayout.gutter,
              end: ListingLayout.gutter,
              bottom: DabblerSpacing.space5,
            ),
            child: DabblerTabs(
              scrollable: true,
              items: <DabblerTabItem>[
                DabblerTabItem(
                  id: FavouriteKind.venue.name,
                  label: l.nav_venues,
                ),
                DabblerTabItem(id: FavouriteKind.game.name, label: l.nav_games),
                DabblerTabItem(
                  id: FavouriteKind.meetup.name,
                  label: l.nav_meetups,
                ),
              ],
              value: _kind.name,
              onChanged: (id) => setState(
                () => _kind = FavouriteKind.values.firstWhere(
                  (k) => k.name == id,
                ),
              ),
            ),
          ),
          Expanded(
            child: _FavouritesList(kind: _kind, open: _open, remove: _remove),
          ),
        ],
      ),
    );
  }
}

class _FavouritesList extends ConsumerWidget {
  const _FavouritesList({
    required this.kind,
    required this.open,
    required this.remove,
  });

  final FavouriteKind kind;
  final ValueChanged<FavouriteItem> open;
  final ValueChanged<FavouriteItem> remove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(favouritesProvider(kind));
    final removed = ref.watch(favouriteRemovalsProvider);
    final loc = ref.watch(activeLocationProvider).valueOrNull;
    final here = loc is ActiveLocationReady ? loc.location : null;
    String? distance(FavouriteItem i) =>
        here == null || i.latitude == null || i.longitude == null
        ? null
        : formatDistanceMeters(
            haversineMeters(here.lat, here.lng, i.latitude!, i.longitude!),
          );
    return async.when(
      loading: () => const Center(child: DabblerSpinner()),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: ListingLayout.gutter),
        child: DabblerEmptyState.error(
          title: l.fav_load_failed,
          retryLabel: l.fav_retry,
          onRetry: () => ref.invalidate(favouritesProvider(kind)),
        ),
      ),
      data: (all) {
        final items = [
          for (final i in all)
            if (!removed.contains(i.id)) i,
        ];
        if (items.isEmpty) {
          return ListingEmpty(
            icon: 'heart',
            title: switch (kind) {
              FavouriteKind.venue => l.fav_empty_venues_title,
              FavouriteKind.game => l.fav_empty_games_title,
              FavouriteKind.meetup => l.fav_empty_meetups_title,
            },
            text: switch (kind) {
              FavouriteKind.venue => l.fav_empty_venues_body,
              FavouriteKind.game => l.fav_empty_games_body,
              FavouriteKind.meetup => l.fav_empty_meetups_body,
            },
          );
        }
        final now = DateTime.now();
        final upcoming = [
          for (final i in items)
            if (!i.endedAt(now)) i,
        ];
        final ended = [
          for (final i in items)
            if (i.endedAt(now)) i,
        ];
        return ListView(
          padding: const EdgeInsetsDirectional.only(
            start: ListingLayout.gutter,
            end: ListingLayout.gutter,
            bottom: ListingLayout.listBottom,
          ),
          children: <Widget>[
            Column(
              spacing: ListingLayout.upcomingGap,
              children: <Widget>[
                for (final i in upcoming)
                  FavouriteRow(
                    item: i,
                    now: now,
                    distance: distance(i),
                    onOpen: () => open(i),
                    onRemove: () => remove(i),
                  ),
              ],
            ),
            if (ended.isNotEmpty) ...<Widget>[
              // `:38-41`: a hairline, "Ended", then the same rows softer.
              const Padding(
                padding: EdgeInsetsDirectional.only(
                  top: DabblerSpacing.space5,
                  bottom: DabblerSpacing.space2,
                ),
                child: DabblerDivider(),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: ListingLayout.upcomingGap,
                ),
                child: DabblerText(
                  l.fav_ended,
                  style: DabblerType.footnote,
                  weight: DabblerTextWeight.semibold,
                  tone: DabblerTextTone.tertiary,
                ),
              ),
              Column(
                spacing: ListingLayout.upcomingGap,
                children: <Widget>[
                  for (final i in ended)
                    FavouriteRow(
                      item: i,
                      now: now,
                      ended: true,
                      onOpen: () => open(i),
                      onRemove: () => remove(i),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One favourite (`Favourites.dc.html:25-35`): name, meta, and the red heart.
class FavouriteRow extends StatelessWidget {
  const FavouriteRow({
    super.key,
    required this.item,
    required this.now,
    required this.onOpen,
    required this.onRemove,
    this.ended = false,
    this.distance,
  });

  final FavouriteItem item;
  final DateTime now;
  final bool ended;

  /// Venue rows: how far it is, already formatted (`4 km`).
  final String? distance;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  /// The meta line, as the design writes it per type.
  static String meta(
    AppLocalizations l,
    FavouriteItem i,
    String locale, {
    required bool ended,
    String? distance,
  }) {
    final at = i.startAt;
    final when = at == null
        ? null
        : ended
        ? DateFormat('EEE d MMM', locale).format(at)
        : DateFormat('EEE h:mm a', locale).format(at);
    final parts = switch (i.kind) {
      FavouriteKind.venue => <String?>[i.area, distance],
      FavouriteKind.game => <String?>[
        i.place,
        when,
        if (i.playersIn != null && i.capacity != null)
          l.fav_meta_players(i.playersIn!, i.capacity!),
      ],
      FavouriteKind.meetup => <String?>[
        i.place,
        when,
        if (i.going != null)
          ended ? l.fav_meta_went(i.going!) : l.fav_meta_going(i.going!),
      ],
    };
    return <String>[
      for (final p in parts)
        if (p != null && p.trim().isNotEmpty) p,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final name = item.name(locale.languageCode);
    return DabblerCard(
      variant: DabblerCardVariant.white,
      radius: DabblerRadius.lg,
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space3),
      onTap: onOpen,
      semanticLabel: name,
      child: Row(
        spacing: DabblerSpacing.space4,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DabblerSpacing.space1,
              children: <Widget>[
                DabblerText(
                  name,
                  style: DabblerType.body,
                  weight: DabblerTextWeight.semibold,
                  tone: ended
                      ? DabblerTextTone.secondary
                      : DabblerTextTone.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  spacing: DabblerSpacing.space1,
                  children: <Widget>[
                    Flexible(
                      child: DabblerText(
                        meta(
                          l,
                          item,
                          locale.toString(),
                          ended: ended,
                          distance: distance,
                        ),
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.tertiary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // A venue's rating ends the line (`4.8 ★`); the star is the
                    // DS glyph, as the display faces cannot draw it as text.
                    if (item.kind == FavouriteKind.venue &&
                        item.rating != null) ...<Widget>[
                      const DabblerText(
                        '·',
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.tertiary,
                      ),
                      DabblerText(
                        item.rating!.toStringAsFixed(1),
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.tertiary,
                      ),
                      DabblerIcon(
                        'star',
                        size: DabblerSizing.iconXs,
                        weight: DabblerIconWeight.bold,
                        color: DabblerColors.of(context).textTertiary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          DabblerFeedAction(
            icon: 'heart',
            iconSize: 18,
            weight: DabblerIconWeight.bold,
            color: DabblerColors.of(context).error.base,
            semanticLabel: l.fav_remove,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}
