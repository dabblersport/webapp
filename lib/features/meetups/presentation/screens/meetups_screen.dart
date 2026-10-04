import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_listing_card.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_upcoming.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Meetups listing tab, drawn from `Listings.dc.html` "Meetups listing":
/// the header with the location chip, one tab per activity (sports that allow
/// solo play, from the data layer), the viewer's upcoming meetups, then the
/// meetup cards.
class MeetupsScreen extends ConsumerWidget {
  const MeetupsScreen({super.key, this.onOpen, this.onPickLocation});

  /// Opens a meetup; defaults to the detail route.
  final ValueChanged<String>? onOpen;

  /// Opens the location picker; defaults to the app's sheet.
  final VoidCallback? onPickLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sports = ref.watch(meetupSportsProvider);
    return sports.when(
      loading: () => const DabblerPage(body: Center(child: DabblerSpinner())),
      error: (_, __) => DabblerPage(
        body: Center(
          child: DabblerEmptyState.error(
            title: l.meetups_load_failed,
            retryLabel: l.feed_retry,
            onRetry: () => ref.invalidate(meetupSportsProvider),
          ),
        ),
      ),
      data: (list) => _MeetupsTabs(
        sports: list,
        onOpen: onOpen,
        onPickLocation: onPickLocation,
      ),
    );
  }
}

class _MeetupsTabs extends ConsumerWidget {
  const _MeetupsTabs({required this.sports, this.onOpen, this.onPickLocation});

  final List<MeetupSport> sports;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onPickLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final loc = ref.watch(activeLocationProvider).valueOrNull;
    return DabblerPage(
      topBar: DabblerPageHeader(
        title: l.nav_meetups,
        locationLabel: loc is ActiveLocationReady
            ? loc.location.area.name
            : l.listing_set_location,
        onLocationPressed:
            onPickLocation ?? () => HomeLocationPickerSheet.show(context),
        actions: <DabblerPageHeaderAction>[
          DabblerPageHeaderAction(
            icon: 'search-normal',
            semanticLabel: l.listing_search,
            onPressed: () => context.push(RoutePaths.socialSearch),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
        ),
        child: DabblerTabPager(
          scrollable: true,
          items: <DabblerTabItem>[
            DabblerTabItem(id: 'all', label: l.meetups_tab_all),
            for (final s in sports)
              DabblerTabItem(id: s.id, label: meetupSportName(context, s)),
          ],
          pages: <Widget>[
            _MeetupsBody(sportId: null, onOpen: onOpen),
            for (final s in sports) _MeetupsBody(sportId: s.id, onOpen: onOpen),
          ],
        ),
      ),
    );
  }
}

class _MeetupsBody extends ConsumerWidget {
  const _MeetupsBody({required this.sportId, this.onOpen});

  final String? sportId;
  final ValueChanged<String>? onOpen;

  void _open(BuildContext context, String id) =>
      (onOpen ?? (v) => context.push(RoutePaths.meetupDetail(v)))(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(meetupListProvider(sportId));
    final loc = ref.watch(activeLocationProvider).valueOrNull;
    final nearby = loc is ActiveLocationReady
        ? ref
              .watch(
                nearbyMeetupsProvider(
                  NearbyMeetupsQuery(loc.location.lat, loc.location.lng),
                ),
              )
              .valueOrNull
        : null;
    final distances = <String, double>{
      for (final n in nearby ?? const <NearbyMeetup>[])
        if (n.distanceM != null) n.id: n.distanceM!,
    };
    return list.when(
      loading: () => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space4),
        children: const <Widget>[
          DabblerSkeleton.card(),
          DabblerGap.v(DabblerSpacing.space4),
          DabblerSkeleton.card(),
          DabblerGap.v(DabblerSpacing.space4),
          DabblerSkeleton.card(),
        ],
      ),
      error: (_, __) => Center(
        child: DabblerEmptyState.error(
          title: l.meetups_load_failed,
          size: DabblerEmptyStateSize.inline,
          retryLabel: l.feed_retry,
          onRetry: () => ref.invalidate(meetupListProvider),
        ),
      ),
      data: (all) {
        final now = DateTime.now();
        // A meetup the viewer answered going or interested, still ahead,
        // counts down in the Upcoming row (the list row carries my_rsvp_status).
        final mine = <MeetupListItem>[
          for (final m in all)
            if (!m.isCancelled &&
                m.startAt.isAfter(now) &&
                (m.myRsvpStatus == 'going' || m.myRsvpStatus == 'interested'))
              m,
        ];
        final mineIds = <String>{for (final m in mine) m.id};
        final others = <MeetupListItem>[
          for (final m in all)
            if (!mineIds.contains(m.id) && !m.isCancelled) m,
        ];
        if (mine.isEmpty && others.isEmpty) {
          return Center(
            child: DabblerEmptyState(
              icon: 'people',
              title: l.meetups_none_title,
              action: DabblerButton(
                label: l.meetups_explore_another,
                onPressed: () => ref.invalidate(meetupListProvider),
              ),
            ),
          );
        }
        return DabblerRefresh(
          onRefresh: () async => ref.invalidate(meetupListProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space4,
              bottom: DabblerSpacing.space8,
            ),
            children: <Widget>[
              if (mine.isNotEmpty) ...<Widget>[
                MeetupUpcoming(
                  meetups: mine,
                  onOpen: (m) => _open(context, m.id),
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              for (final m in others) ...<Widget>[
                MeetupListingCard(
                  meetup: m,
                  distanceMeters: distances[m.id],
                  onOpen: () => _open(context, m.id),
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
            ],
          ),
        );
      },
    );
  }
}
