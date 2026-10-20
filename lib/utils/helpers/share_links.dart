import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/helpers/deep_links.dart';

/// Share links built for the environment the app is running in (KAN-597). On web the browser's own origin is used when
/// it is a Dabbler origin (so the Alpha web app never shares a production link); on mobile the build's `WEB_LINK_BASE`
/// is used; otherwise the production origin. Every id is validated as a UUID and the sharer (the sharing profile id)
/// is attribution only.
abstract final class ShareLinks {
  static String origin() => DeepLinks.resolveOrigin(
    configured: Environment.webLinkBase,
    webOrigin: kIsWeb ? Uri.base.origin : null,
    fallback: RoutePaths.webLinkBase,
  );

  static String _link(SharedItemType type, String id, String? sharer) =>
      DeepLinks.link(
        origin: origin(),
        type: type,
        id: id,
        sharerProfileId: sharer,
      );

  static String game(String id, {String? sharerProfileId}) =>
      _link(SharedItemType.game, id, sharerProfileId);
  static String meetup(String id, {String? sharerProfileId}) =>
      _link(SharedItemType.meetup, id, sharerProfileId);
  static String venue(String id, {String? sharerProfileId}) =>
      _link(SharedItemType.venue, id, sharerProfileId);
  static String post(String id, {String? sharerProfileId}) =>
      _link(SharedItemType.post, id, sharerProfileId);
  static String profile(String id, {String? sharerProfileId}) =>
      _link(SharedItemType.profile, id, sharerProfileId);
}
