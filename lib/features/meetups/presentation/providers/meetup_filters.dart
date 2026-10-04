import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the listing orders meetups. `soonest` is the default (start time);
/// `nearest` needs distances, which exist only when the location is ready.
enum MeetupSort { soonest, nearest }

/// The radius filter in metres; null is "Any distance".
final meetupRadiusProvider = StateProvider<int?>((ref) => null);

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
}) {
  final out = <MeetupListItem>[
    for (final m in all)
      if (radiusMeters == null ||
          distances[m.id] == null ||
          distances[m.id]! <= radiusMeters)
        m,
  ];
  out.sort((a, b) {
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
