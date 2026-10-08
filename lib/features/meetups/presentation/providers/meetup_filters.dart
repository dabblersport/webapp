import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the listing orders meetups. `soonest` is the default (start time);
/// `nearest` needs distances, which exist only when the location is ready.
enum MeetupSort { soonest, nearest, popular }

/// The Date group of the filter sheet (`Listings.dc.html:1833`).
enum MeetupDateFilter { today, tomorrow, thisWeek, thisWeekend }

/// Whether [start] falls in [filter], relative to [now] (local time). "This
/// week" is the next seven days; "This weekend" is the coming Saturday and
/// Sunday (the UAE weekend).
bool meetupInDateFilter(DateTime start, MeetupDateFilter filter, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final diff = day.difference(today).inDays;
  return switch (filter) {
    MeetupDateFilter.today => diff == 0,
    MeetupDateFilter.tomorrow => diff == 1,
    MeetupDateFilter.thisWeek => diff >= 0 && diff < 7,
    MeetupDateFilter.thisWeekend =>
      diff >= 0 &&
          diff < 7 &&
          (start.weekday == DateTime.saturday ||
              start.weekday == DateTime.sunday),
  };
}

/// The radius filter in metres; null is "Any distance".
final meetupRadiusProvider = StateProvider<int?>((ref) => null);

/// The date filter; null is any date.
final meetupDateProvider = StateProvider<MeetupDateFilter?>((ref) => null);

/// The setting filter: true Indoor, false Outdoor, null both. A meetup whose
/// venue (and so setting) is unknown matches neither Indoor nor Outdoor.
final meetupIndoorProvider = StateProvider<bool?>((ref) => null);

final meetupSortProvider = StateProvider<MeetupSort>(
  (ref) => MeetupSort.soonest,
);

/// The radius presets of the Distance group, in metres.
const List<int> kMeetupRadiusPresets = <int>[5000, 10000];

/// Narrows and orders [all] client-side (no backend): a meetup farther than
/// [radiusMeters] is dropped when its distance is known; unknown distances are
/// kept so a missing location never empties the list.
List<MeetupListItem> applyMeetupFilters(
  List<MeetupListItem> all, {
  required Map<String, double> distances,
  int? radiusMeters,
  MeetupSort sort = MeetupSort.soonest,
  MeetupDateFilter? date,
  bool? indoor,
  Map<String, bool?> settings = const <String, bool?>{},
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final out = <MeetupListItem>[
    for (final m in all)
      if ((radiusMeters == null ||
              distances[m.id] == null ||
              distances[m.id]! <= radiusMeters) &&
          (date == null || meetupInDateFilter(m.startAt, date, clock)) &&
          (indoor == null || settings[m.id] == indoor))
        m,
  ];
  out.sort((a, b) {
    if (sort == MeetupSort.popular && a.goingCount != b.goingCount) {
      return b.goingCount.compareTo(a.goingCount);
    }
    if (sort == MeetupSort.nearest) {
      final da = distances[a.id];
      final db = distances[b.id];
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da != null && db == null) return -1;
      if (da == null && db != null) return 1;
    }
    return a.startAt.compareTo(b.startAt);
  });
  return out;
}

/// Distance in metres per meetup id, from `nearbyMeetups`, when the location is
/// ready; empty otherwise.
final meetupDistancesProvider = Provider<Map<String, double>>((ref) {
  final loc = ref.watch(activeLocationProvider).valueOrNull;
  if (loc is! ActiveLocationReady) return const <String, double>{};
  final radius = ref.watch(meetupRadiusProvider) ?? kMeetupRadiusPresets.last;
  final nearby = ref
      .watch(
        nearbyMeetupsProvider(
          NearbyMeetupsQuery(
            loc.location.lat,
            loc.location.lng,
            radius.toDouble(),
          ),
        ),
      )
      .valueOrNull;
  return <String, double>{
    for (final n in nearby ?? const <NearbyMeetup>[])
      if (n.distanceM != null) n.id: n.distanceM!,
  };
});
