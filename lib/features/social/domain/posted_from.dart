import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// KAN-592: where a post's author posted FROM. It is not the place the post is
/// about: that is the post's `location_name` tag (a venue, street or address),
/// which may be in another city entirely.
const String kLegacyPostedFromCity = 'Dubai';

/// The composer's error message when no posting city is known yet. The screen
/// reads it to open the city prompt; it is never shown as text.
const String kPostedFromRequired = 'posted_from_required';

/// The author's posting origin: always a [city], plus an [area] only when one
/// is known.
class PostedFrom {
  const PostedFrom({required this.city, this.area});

  final String city;
  final String? area;

  @override
  bool operator ==(Object other) =>
      other is PostedFrom && other.city == city && other.area == area;

  @override
  int get hashCode => Object.hash(city, area);
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The posting origin the device location gives, or null when there is none
/// (denied, still loading, errored). A city-only state has no area; an area is
/// never made up.
PostedFrom? postedFromOfActive(ActiveLocationState? state) {
  if (state is ActiveLocationReady) {
    final city = _clean(state.location.area.city);
    if (city == null) return null;
    return PostedFrom(city: city, area: _clean(state.location.area.name));
  }
  if (state is ActiveLocationCityOnly) {
    final city = _clean(state.city);
    return city == null ? null : PostedFrom(city: city);
  }
  return null;
}

/// True for a post written before posting cities were recorded (or by an older
/// client): its `posted_from_city` was never set. Such rows are not rewritten.
bool isLegacyPost(Post post) => _clean(post.postedFromCity) == null;

/// The header location: the posting area and city, or just the city when no
/// area is known. A legacy post reads [legacyCity] (Dubai). The tagged place
/// is never used here.
String postedFromHeaderLabel(
  Post post, {
  String legacyCity = kLegacyPostedFromCity,
}) {
  final city = _clean(post.postedFromCity);
  if (city == null) return legacyCity;
  final area = _clean(post.postedFromArea);
  if (area == null || area == city) return city;
  return '$area, $city';
}

/// The in-post place pill text: the tagged venue, street, area or address, or
/// null when the post has no tag. Never falls back to the posting city.
String? postPlaceTagLabel(Post post) => _clean(post.locationName);
