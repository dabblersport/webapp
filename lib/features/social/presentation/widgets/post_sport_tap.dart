import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// KAN-622: what tapping the sport tag on [post] does. It opens that sport's
/// page. Null (the tag is not a button) when the Sport Overview flag is off,
/// when the post's sport has no id, or when [currentSportId] is the sport page
/// already open, so a tag never links to the page it is on. The id is the
/// post's own `sport_id`, else the existing name mapping; no new query.
VoidCallback? postSportTap(
  BuildContext context,
  Post post, {
  String? currentSportId,
  bool enabled = FeatureFlags.sportOverview,
}) {
  if (!enabled) return null;
  final String? stored = post.sportId?.trim();
  final String? sportId = (stored != null && stored.isNotEmpty)
      ? stored
      : SportIdMapping.getSportId((post.sport ?? '').trim());
  if (sportId == null || sportId == currentSportId) return null;
  return () => context.pushNamed(
    RouteNames.sportOverview,
    pathParameters: <String, String>{'sportId': sportId},
  );
}
