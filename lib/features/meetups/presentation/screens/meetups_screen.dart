import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_setting.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_listing_card.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_upcoming.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_scaffold.dart';
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
    final radius = ref.watch(meetupRadiusProvider);
    final sort = ref.watch(meetupSortProvider);
    final date = ref.watch(meetupDateProvider);
    final indoor = ref.watch(meetupIndoorProvider);
    void reset() {
      ref.read(meetupRadiusProvider.notifier).state = null;
      ref.read(meetupSortProvider.notifier).state = MeetupSort.soonest;
      ref.read(meetupDateProvider.notifier).state = null;
      ref.read(meetupIndoorProvider.notifier).state = null;
    }

    final active = <DabblerFilterRailItem>[
      if (radius != null)
        DabblerFilterRailItem(
          label: l.listing_within_km((radius / 1000).round()),
          onRemove: () => ref.read(meetupRadiusProvider.notifier).state = null,
        ),
      if (date != null)
        DabblerFilterRailItem(
          label: _dateLabel(l, date),
          onRemove: () => ref.read(meetupDateProvider.notifier).state = null,
        ),
      if (indoor != null)
        DabblerFilterRailItem(
          label: indoor ? l.listing_indoor : l.listing_outdoor,
          onRemove: () => ref.read(meetupIndoorProvider.notifier).state = null,
        ),
      if (sort != MeetupSort.soonest)
        DabblerFilterRailItem(
          label: _sortLabel(l, sort),
          onRemove: () =>
              ref.read(meetupSortProvider.notifier).state = MeetupSort.soonest,
        ),
    ];
    return DabblerPage(
      body: ListingScaffold(
        head: DabblerListingHead.accent,
        header: DabblerPageHeader(
          safeArea: false,
          contentPadding: DabblerPageHeader.listingPadding,
          title: l.nav_meetups,
          locationLabel: loc is ActiveLocationReady
              ? loc.location.area.name
              : l.listing_set_location,
          onLocationPressed:
              onPickLocation ?? () => HomeLocationPickerSheet.show(context),
          actions: <DabblerPageHeaderAction>[
            // The Favourites entry (`Listings.2026-10-08b.dc.html:403-405`).
            DabblerPageHeaderAction(
              icon: 'heart',
              semanticLabel: l.fav_title,
              onPressed: () => context.push(
                '${RoutePaths.favourites}?tab=${FavouriteKind.meetup.name}',
              ),
            ),
            DabblerPageHeaderAction(
              icon: 'search-normal',
              semanticLabel: l.listing_search,
              onPressed: () => context.push(RoutePaths.socialSearch),
            ),
            DabblerPageHeaderAction(
              icon: 'filter',
              semanticLabel: l.listing_filters,
              count: active.length,
              onPressed: () => showListingFilterSheet(
                context,
                onReset: reset,
                builder: (_) => const _MeetupFilterBody(),
                footerBuilder: (_) => const _ShowMeetupsButton(),
              ),
            ),
          ],
        ),
        tabs: <DabblerTabItem>[
          DabblerTabItem(id: 'all', label: l.meetups_tab_all),
          for (final s in sports)
            DabblerTabItem(id: s.id, label: meetupSportName(context, s)),
        ],
        filters: active,
        clearAllLabel: l.listing_clear_all,
        onClearAll: reset,
        pages: <Widget>[
          for (final id in <String?>[null, for (final s in sports) s.id])
            _MeetupsBody(sportId: id, onOpen: onOpen),
        ],
      ),
    );
  }
}

String _dateLabel(AppLocalizations l, MeetupDateFilter f) => switch (f) {
  MeetupDateFilter.today => l.listing_today,
  MeetupDateFilter.tomorrow => l.listing_tomorrow,
  MeetupDateFilter.thisWeek => l.listing_this_week,
  MeetupDateFilter.thisWeekend => l.listing_this_weekend,
};

String _sortLabel(AppLocalizations l, MeetupSort s) => switch (s) {
  MeetupSort.nearest => l.listing_sort_nearest,
  MeetupSort.soonest => l.listing_sort_soonest,
  MeetupSort.popular => l.listing_sort_popular,
};

class _MeetupsBody extends ConsumerWidget {
  const _MeetupsBody({required this.sportId, this.onOpen});

  final String? sportId;
  final ValueChanged<String>? onOpen;

  void _open(BuildContext context, String id) =>
      (onOpen ?? (v) => context.push(RoutePaths.meetupDetail(v)))(id);

  /// "{activity} has no meetups right now. {a} and {b} have sessions coming
  /// up." (`Listings.dc.html:568`), from the unfiltered list; null on the All
  /// tab or when no other activity has an upcoming session.
  String? _emptyText(BuildContext context, WidgetRef ref) {
    final id = sportId;
    if (id == null) return null;
    final everything = ref.watch(meetupListProvider(null)).valueOrNull;
    if (everything == null) return null;
    final l = AppLocalizations.of(context);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String? name(MeetupListItem m) =>
        ar && (m.sportNameAr?.trim().isNotEmpty ?? false)
        ? m.sportNameAr
        : m.sportNameEn;
    final now = DateTime.now();
    String? mine;
    final others = <String>[];
    for (final m in everything) {
      final n = name(m);
      if (n == null) continue;
      if (m.sportId == id) {
        mine ??= n;
      } else if (!m.isCancelled &&
          m.startAt.isAfter(now) &&
          !others.contains(n)) {
        others.add(n);
      }
    }
    String? self = mine;
    if (self == null) {
      for (final sp
          in ref.watch(meetupSportsProvider).valueOrNull ??
              const <MeetupSport>[]) {
        if (sp.id == id) self = meetupSportName(context, sp);
      }
    }
    if (self == null || others.isEmpty) return null;
    return l.meetups_empty_text(self, others.take(2).join(ar ? ' و' : ' and '));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(meetupListProvider(sportId));
    final radius = ref.watch(meetupRadiusProvider);
    final sort = ref.watch(meetupSortProvider);
    final distances = ref.watch(meetupDistancesProvider);
    final date = ref.watch(meetupDateProvider);
    final indoor = ref.watch(meetupIndoorProvider);
    final settings =
        ref.watch(meetupSettingsProvider).valueOrNull ??
        const <String, bool?>{};
    return list.when(
      loading: () =>
          const ListingSkeletons(kind: DabblerListingSkeletonKind.meetup),
      error: (_, __) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ListingLayout.gutter,
        ),
        child: Center(
          child: DabblerEmptyState.error(
            title: l.meetups_load_failed,
            size: DabblerEmptyStateSize.inline,
            retryLabel: l.feed_retry,
            onRetry: () => ref.invalidate(meetupListProvider),
          ),
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
        final others = applyMeetupFilters(
          <MeetupListItem>[
            for (final m in all)
              if (!mineIds.contains(m.id) && !m.isCancelled) m,
          ],
          distances: distances,
          radiusMeters: radius,
          sort: sort,
          date: date,
          indoor: indoor,
          settings: settings,
        );
        if (mine.isEmpty && others.isEmpty) {
          // The frame's copy under the title names other activities' sessions,
          // read from the unfiltered list.
          return ListingEmpty(
            icon: 'people',
            title: l.meetups_none_title,
            text: _emptyText(context, ref),
            action: DabblerButton(
              label: l.meetups_explore_another,
              onPressed: () => ref.invalidate(meetupListProvider),
            ),
          );
        }
        return DabblerRefresh(
          onRefresh: () async => ref.invalidate(meetupListProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // The Upcoming rail bleeds to the screen edge, so the gutter is
            // per row (`Listings.dc.html:453`).
            padding: const EdgeInsetsDirectional.only(
              top: ListingLayout.listTop,
              bottom: ListingLayout.listBottom,
            ),
            children: <Widget>[
              if (mine.isNotEmpty) ...<Widget>[
                MeetupUpcoming(
                  meetups: mine,
                  onOpen: (m) => _open(context, m.id),
                ),
                const DabblerGap.v(ListingLayout.cardGap),
              ],
              for (var i = 0; i < others.length; i++) ...<Widget>[
                if (i > 0) const DabblerGap.v(ListingLayout.cardGap),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ListingLayout.gutter,
                  ),
                  child: MeetupListingCard(
                    meetup: others[i],
                    distanceMeters: distances[others[i].id],
                    isIndoor: settings[others[i].id],
                    onOpen: () => _open(context, others[i].id),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The Distance and Sort-by groups of the Meetups filter sheet
/// (`Listings.dc.html:283-304`), bound to the listing's own providers.
class _MeetupFilterBody extends ConsumerWidget {
  const _MeetupFilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final radius = ref.watch(meetupRadiusProvider);
    final sort = ref.watch(meetupSortProvider);
    final date = ref.watch(meetupDateProvider);
    final indoor = ref.watch(meetupIndoorProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space6,
      children: <Widget>[
        DabblerFilterGroup(
          label: l.listing_group_distance,
          children: <Widget>[
            for (final m in kMeetupRadiusPresets)
              DabblerChip(
                label: l.listing_within_km((m / 1000).round()),
                selected: radius == m,
                onTap: () => ref.read(meetupRadiusProvider.notifier).state = m,
              ),
            DabblerChip(
              label: l.listing_any_distance,
              selected: radius == null,
              onTap: () => ref.read(meetupRadiusProvider.notifier).state = null,
            ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_date,
          children: <Widget>[
            for (final f in MeetupDateFilter.values)
              DabblerChip(
                label: _dateLabel(l, f),
                selected: date == f,
                onTap: () => ref.read(meetupDateProvider.notifier).state =
                    date == f ? null : f,
              ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_setting,
          children: <Widget>[
            for (final value in const <bool>[true, false])
              DabblerChip(
                label: value ? l.listing_indoor : l.listing_outdoor,
                selected: indoor == value,
                onTap: () => ref.read(meetupIndoorProvider.notifier).state =
                    indoor == value ? null : value,
              ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_sort,
          children: <Widget>[
            for (final value in <MeetupSort>[
              MeetupSort.nearest,
              MeetupSort.soonest,
              MeetupSort.popular,
            ])
              DabblerChip(
                label: _sortLabel(l, value),
                selected: sort == value,
                onTap: () =>
                    ref.read(meetupSortProvider.notifier).state = value,
              ),
          ],
        ),
      ],
    );
  }
}

/// The sheet's closing action: "Show N meetups".
class _ShowMeetupsButton extends ConsumerWidget {
  const _ShowMeetupsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final all = ref.watch(meetupListProvider(null)).valueOrNull;
    final count = all == null
        ? null
        : applyMeetupFilters(
            <MeetupListItem>[
              for (final m in all)
                if (!m.isCancelled) m,
            ],
            distances: ref.watch(meetupDistancesProvider),
            radiusMeters: ref.watch(meetupRadiusProvider),
            sort: ref.watch(meetupSortProvider),
            date: ref.watch(meetupDateProvider),
            indoor: ref.watch(meetupIndoorProvider),
            settings:
                ref.watch(meetupSettingsProvider).valueOrNull ??
                const <String, bool?>{},
          ).length;
    return DabblerButton(
      label: count == null ? l.meetups_tab_all : l.meetups_show_count(count),
      fullWidth: true,
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}
