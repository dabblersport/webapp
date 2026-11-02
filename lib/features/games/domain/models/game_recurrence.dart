/// How a game repeats (KAN-697). [none] is an ordinary single game.
enum GameRepeat {
  none,
  weekly,
  biweekly;

  /// The `p_frequency` value of `rpc_create_game_series`; null for [none].
  String? get rpcFrequency => switch (this) {
    GameRepeat.none => null,
    GameRepeat.weekly => 'weekly',
    GameRepeat.biweekly => 'biweekly',
  };

  int get intervalDays => switch (this) {
    GameRepeat.none => 0,
    GameRepeat.weekly => 7,
    GameRepeat.biweekly => 14,
  };
}

/// Epic KAN-692 v1: a series holds at most this many games.
const int kMaxSeriesOccurrences = 52;

/// A resolved place for a series: both ids are always present.
class SeriesLocation {
  const SeriesLocation({required this.geoLocationId, required this.areaId});

  final String geoLocationId;
  final String areaId;
}

String? _nonEmpty(String? v) => v == null || v.trim().isEmpty ? null : v;

/// The series place, in the CTO's order (KAN-697): the chosen venue's own
/// geo/area first, else the profile's saved location. Null when neither has
/// both ids: nothing is invented and the series is not created.
SeriesLocation? resolveSeriesLocation({
  String? venueGeoLocationId,
  String? venueAreaId,
  String? profileGeoLocationId,
  String? profileAreaId,
}) {
  final vg = _nonEmpty(venueGeoLocationId);
  final va = _nonEmpty(venueAreaId);
  if (vg != null && va != null) {
    return SeriesLocation(geoLocationId: vg, areaId: va);
  }
  final pg = _nonEmpty(profileGeoLocationId);
  final pa = _nonEmpty(profileAreaId);
  if (pg != null && pa != null) {
    return SeriesLocation(geoLocationId: pg, areaId: pa);
  }
  return null;
}

/// How many games the series holds from [first] every [repeat] until [end]
/// (inclusive, date only), capped at [kMaxSeriesOccurrences]. With no [end]
/// the open-ended series is counted as the cap. 0 for [GameRepeat.none].
int seriesOccurrenceCount(GameRepeat repeat, DateTime first, DateTime? end) {
  if (repeat == GameRepeat.none) return 0;
  if (end == null) return kMaxSeriesOccurrences;
  final a = DateTime.utc(first.year, first.month, first.day);
  final b = DateTime.utc(end.year, end.month, end.day);
  if (b.isBefore(a)) return 0;
  final n = b.difference(a).inDays ~/ repeat.intervalDays + 1;
  return n > kMaxSeriesOccurrences ? kMaxSeriesOccurrences : n;
}

/// True when [end] is after the first game's date (a valid end date).
bool seriesEndIsValid(DateTime first, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).isAfter(DateTime.utc(first.year, first.month, first.day));
