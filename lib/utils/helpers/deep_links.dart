// KAN-597: shared-item links. One place that BUILDS the public share links (post, venue, game, meetup, profile) from
// the originating environment, and one place that PARSES and VALIDATES an incoming link into an in-app location.
//
// Pure Dart (no Flutter, no Supabase) so it can be tested on its own.
//
// Rules, all enforced here:
//  * the destination id must be a UUID; anything else (empty, encoded traversal, a different shape) is "malformed" and
//    the caller falls back to Home;
//  * the sharer (`sp`, the sharing profile id) must also be a UUID or it is dropped. It is ATTRIBUTION ONLY: it is
//    never used to sign anyone in, to pick an account, or to widen access (the destination screens still apply the
//    viewer's own permissions);
//  * no auth token, session or secret ever appears in a link or its query. The one carried value is a game's
//    join-link token (`lt`, KAN-939): a UUID minted by rpc_mint_join_link that only lets a holder join a link-policy
//    game; it signs nobody in, and rpc_join_game checks it again;
//  * the share origin comes from the environment the app is running in, not a fixed production host.

enum SharedItemType { post, venue, game, meetup, profile }

/// A validated shared destination. [sharerProfileId] is attribution, never identity.
class SharedItem {
  const SharedItem(this.type, this.id, {this.sharerProfileId, this.linkToken});

  final SharedItemType type;
  final String id;
  final String? sharerProfileId;

  /// KAN-939: a game's join-link token; only ever set for [SharedItemType.game].
  final String? linkToken;

  @override
  bool operator ==(Object other) =>
      other is SharedItem &&
      other.type == type &&
      other.id == id &&
      other.sharerProfileId == sharerProfileId &&
      other.linkToken == linkToken;

  @override
  int get hashCode => Object.hash(type, id, sharerProfileId, linkToken);

  @override
  String toString() => 'SharedItem($type, $id)';
}

abstract final class DeepLinks {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// The public entry path segment of each type (the part after the origin).
  static const Map<SharedItemType, String> entrySegment = {
    SharedItemType.post: 'post',
    SharedItemType.venue: 'venue',
    SharedItemType.game: 'game',
    SharedItemType.meetup: 'meetups',
    SharedItemType.profile: 'u',
  };

  /// The query parameter that carries the sharing profile id.
  static const String sharerParam = 'sp';

  /// KAN-939: the query parameter that carries a game's join-link token.
  static const String linkTokenParam = 'lt';

  /// Hosts a share origin may use: the production, alpha and canary web apps. Anything else falls back to [fallback].
  static bool isAllowedOrigin(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return host == 'dabbler.pro' || host.endsWith('.dabbler.pro');
  }

  /// The origin share links are built on. [configured] is the build's `WEB_LINK_BASE` define (empty when unset);
  /// [webOrigin] is the browser's own origin when running on web. The environment you are in wins, so an Alpha build or
  /// the Alpha web app never shares a production link; an unknown or insecure origin falls back to [fallback].
  static String resolveOrigin({
    required String configured,
    String? webOrigin,
    required String fallback,
  }) {
    String strip(String s) =>
        s.endsWith('/') ? s.substring(0, s.length - 1) : s;
    final candidates = <String?>[webOrigin, configured];
    for (final c in candidates) {
      if (c != null && c.isNotEmpty && isAllowedOrigin(c)) return strip(c);
    }
    return strip(fallback);
  }

  static bool isValidId(String? id) => id != null && _uuid.hasMatch(id);

  /// The public share link for an item, e.g. `https://app.dabbler.pro/game/<id>?sp=<profile>`. [sharerProfileId] is
  /// added only when it is a valid UUID. An id that is not a UUID is percent-escaped (and is rejected by [parse]).
  static String link({
    required String origin,
    required SharedItemType type,
    required String id,
    String? sharerProfileId,
    String? linkToken,
  }) {
    // The item id is escaped, never trusted: a share button must not crash on an odd id, and the receiving side
    // validates it again (a non-UUID id resolves to the safe fallback there).
    final safeId = isValidId(id) ? id.toLowerCase() : Uri.encodeComponent(id);
    final base = '$origin/${entrySegment[type]}/$safeId';
    final query = [
      if (isValidId(sharerProfileId))
        '$sharerParam=${sharerProfileId!.toLowerCase()}',
      if (type == SharedItemType.game && isValidId(linkToken))
        '$linkTokenParam=${linkToken!.toLowerCase()}',
    ];
    return query.isEmpty ? base : '$base?${query.join('&')}';
  }

  /// Parses an incoming link (https web link or `dabbler://app/...`) into a validated [SharedItem], or null when it is
  /// not a recognised shared-item link or its id is malformed. The path is decoded once; a decoded value that is not a
  /// plain UUID (slashes, dots, spaces, double encoding) is rejected.
  static SharedItem? parse(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 2) return null;
    final head = segments[0].toLowerCase();
    final type = entrySegment.entries
        .where((e) => e.value == head)
        .map((e) => e.key)
        .firstOrNull;
    if (type == null) return null;
    final id = segments[1];
    if (!isValidId(id)) return null;
    final sp = uri.queryParameters[sharerParam];
    final lt = uri.queryParameters[linkTokenParam];
    return SharedItem(
      type,
      id.toLowerCase(),
      sharerProfileId: isValidId(sp) ? sp!.toLowerCase() : null,
      linkToken: type == SharedItemType.game && isValidId(lt)
          ? lt!.toLowerCase()
          : null,
    );
  }

  /// The in-app router location of a shared item. The sharer, when valid, rides along as `sp` (ignored by the screens;
  /// it is attribution only).
  static String location(SharedItem item) {
    final id = item.id;
    final base = switch (item.type) {
      SharedItemType.game => '/sports/games/$id',
      SharedItemType.venue => '/sports/venues/$id',
      SharedItemType.meetup => '/meetups/$id',
      SharedItemType.post => '/social-post-detail/$id',
      SharedItemType.profile => '/user-profile/$id?profileId=$id',
    };
    final query = [
      if (item.sharerProfileId != null) '$sharerParam=${item.sharerProfileId}',
      if (item.linkToken != null) '$linkTokenParam=${item.linkToken}',
    ];
    if (query.isEmpty) return base;
    return '$base${base.contains('?') ? '&' : '?'}${query.join('&')}';
  }

  /// The router location for an incoming link, or null when it is not a shared-item link at all. A recognised link
  /// with a malformed id returns [malformedFallback] so the caller lands somewhere safe instead of on an error page.
  static String? resolve(Uri uri, {required String malformedFallback}) {
    final head = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first.toLowerCase();
    final isEntry = entrySegment.values.contains(head);
    if (!isEntry) return null;
    final item = parse(uri);
    return item == null ? malformedFallback : location(item);
  }
}
