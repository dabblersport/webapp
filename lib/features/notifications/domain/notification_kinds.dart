/// KAN-978 (W0-5): the one place the app knows a notification kind.
///
/// Per kind: aliases, icon and tone, title (and body) template, CTAs and their
/// action ids, route builder, chip, settings group, needsAction and category.
/// The registry is this file plus its parts in this folder:
/// `notification_kind_table.dart` (client facts), `notification_kind_types.dart`
/// (the types) and the generated `notification_kind_titles.dart` /
/// `notification_kind_bodies.dart` (server facts and ARB templates, from the
/// KAN-974 migration by `tool/notifications/gen_kind_tables.py`). No other file
/// switches on a kind string.
library;

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'notification_kind_bodies.dart';
import 'notification_kind_table.dart';
import 'notification_kind_titles.dart';
import 'notification_kind_types.dart';

export 'notification_kind_types.dart';

/// One kind: the server facts and what the client does with it.
class NotificationKindSpec {
  NotificationKindSpec._(this.client, this._server);

  final NotificationKindClient client;
  final (String, bool, bool, bool) _server;

  String get key => client.key;
  NotificationCategory get category =>
      NotificationCategory.parse(_server.$1) ?? NotificationCategory.system;

  /// The server sends this kind today (`notification_kinds.is_active`).
  bool get active => _server.$2;
  bool get breaksQuiet => _server.$3;
  bool get canMute => _server.$4;

  String get icon => client.visual.$1;
  NotifTone get tone => client.visual.$2;
  NotificationRouteKind get routeKind => client.route;
  NotificationSettingsGroup? get settingsGroup => client.settingsGroup;
  bool get needsAction => client.needsAction;
  List<NotificationCta> get ctas => client.ctas;
  String? get aliasOf => client.aliasOf;

  /// The chip the kind belongs to; an activity row by its entity (a meetup
  /// goes to Meetups, anything else to Games).
  NotificationChip chipFor(Map<String, dynamic>? payload) => switch (category) {
    NotificationCategory.social => NotificationChip.social,
    NotificationCategory.messages => NotificationChip.messages,
    NotificationCategory.games => NotificationChip.games,
    NotificationCategory.meetups => NotificationChip.meetups,
    NotificationCategory.activities =>
      NotificationKinds._entityType(payload) == 'meetup'
          ? NotificationChip.meetups
          : NotificationChip.games,
    NotificationCategory.system ||
    NotificationCategory.security ||
    NotificationCategory.booking => NotificationChip.system,
  };
}

/// The registry.
abstract final class NotificationKinds {
  static final Map<String, NotificationKindSpec> _specs = {
    for (final c in notificationKindTable)
      c.key: NotificationKindSpec._(c, notificationServerKinds[c.key]!),
  };

  /// Every kind, in settings order.
  static Iterable<NotificationKindSpec> get all => _specs.values;

  /// Every kind key the client knows.
  static Iterable<String> get keys => _specs.keys;

  /// The kind, or null when the client does not know it.
  static NotificationKindSpec? of(String kindKey) => _specs[kindKey];

  /// The canonical kind a key stands for (itself when it is not an alias).
  static String canonical(String kindKey) =>
      _specs[kindKey]?.aliasOf ?? kindKey;

  /// The keys that stand for [kindKey] (itself and its legacy aliases).
  static List<String> aliasesOf(String kindKey) => <String>[
    kindKey,
    for (final s in _specs.values)
      if (s.aliasOf == kindKey) s.key,
  ];

  // ── Visual ─────────────────────────────────────────────────────────────

  /// The kind's icon and tone; an unknown kind by its family, as before.
  static (String, NotifTone) visualOf(String kindKey) {
    final spec = _specs[kindKey];
    if (spec != null) return spec.client.visual;
    bool p(String s) => kindKey.startsWith(s);
    if (p('social.post_liked') || p('social.comment_liked')) {
      return ('heart', NotifTone.accent);
    }
    if (p('social.post_commented') || p('social.mentioned')) {
      return ('message', NotifTone.info);
    }
    if (p('social.followed')) return ('user-add', NotifTone.brand);
    if (p('social.circle_joined')) return ('people', NotifTone.brand);
    if (p('booking') || p('arena')) return ('ticket', NotifTone.info);
    if (p('game')) return ('game', NotifTone.amber);
    if (p('achievement') || p('reward')) return ('cup', NotifTone.amber);
    if (p('loyalty')) return ('coin', NotifTone.amber);
    if (p('system')) return ('warning-2', NotifTone.accent);
    if (p('friend')) return ('user-add', NotifTone.brand);
    return ('notification', NotifTone.brand);
  }

  /// The row's CTA (the first of the kind's CTAs), or null.
  static NotificationCta? ctaOf(String kindKey) =>
      _specs[kindKey]?.ctas.firstOrNull;

  // ── Chips ──────────────────────────────────────────────────────────────

  /// Whether [n] shows under [chip].
  static bool inChip(NotificationChip chip, AppNotification n) =>
      switch (chip) {
        NotificationChip.all => true,
        NotificationChip.unread => !n.isRead,
        NotificationChip.needsAction => _specs[n.kindKey]?.needsAction ?? false,
        _ => chipOf(n) == chip,
      };

  /// The kind chip of [n]; an unknown kind falls under System.
  static NotificationChip chipOf(AppNotification n) =>
      _specs[n.kindKey]?.chipFor(n.payload) ?? NotificationChip.system;

  /// The chip of today's Center (`games`, `bookings`, `social`, `achieve`),
  /// by kind family as before KAN-978; W1-F3 moves the screen to
  /// [NotificationChip]. Null is "All" only.
  static String? currentChipOf(String kindKey) {
    bool p(String s) => kindKey.startsWith(s);
    if (p('game')) return 'games';
    if (p('booking') || p('arena')) return 'bookings';
    if (p('social') || p('friend')) return 'social';
    if (p('achievement') || p('reward') || p('loyalty')) return 'achieve';
    return null;
  }

  // ── Settings ───────────────────────────────────────────────────────────

  /// The live kinds toggled by [groups], in settings order.
  static List<String> kindsIn(Set<NotificationSettingsGroup> groups) => [
    for (final s in _specs.values)
      if (s.active && groups.contains(s.settingsGroup)) s.key,
  ];

  // ── Titles ─────────────────────────────────────────────────────────────

  /// The title in the app's language. The live kinds keep their localized
  /// lines (or the server's title); a new kind uses its template when every
  /// argument is known ([args], else the row's payload), otherwise the
  /// server's title.
  static String title(
    AppLocalizations l,
    AppNotification n, {
    Map<String, dynamic>? args,
  }) {
    final actor = actorName(n.payload);
    final legacy = _legacyTitle(l, n.kindKey, actor, args ?? n.payload);
    if (legacy != null) return legacy;
    final spec = _specs[n.kindKey];
    if (spec == null) {
      return n.kindKey.startsWith('achievement')
          ? l.notif_kind_achievement_earned
          : n.title;
    }
    if (spec.active) return n.title;
    final a = _resolver(l, args ?? n.payload, actor);
    final names = notificationTitleArgs[n.kindKey] ?? const <String>[];
    if (names.any((name) => a(name).isEmpty)) return n.title;
    return notificationTitleTemplate(l, n.kindKey, a) ?? n.title;
  }

  /// The body template in the app's language, or null when an argument is
  /// missing (the caller keeps the server's body).
  static String? body(
    AppLocalizations l,
    String kindKey,
    Map<String, dynamic>? args,
  ) {
    var missing = false;
    final resolve = _resolver(l, args, actorName(args));
    String a(String name) {
      final v = resolve(name);
      if (v.isEmpty) missing = true;
      return v;
    }

    final text = notificationBodyTemplate(l, kindKey, a);
    return missing ? null : text;
  }

  /// The live kinds' localized lines (before KAN-978), with the mentions fix:
  /// the server's kinds are `social.mentioned_in_post` and `_in_comment`.
  static String? _legacyTitle(
    AppLocalizations l,
    String kind,
    String? actor,
    Map<String, dynamic>? args,
  ) {
    final has = actor != null && actor.isNotEmpty;
    final x = actor ?? '';
    return switch (kind) {
      'friend.requested' =>
        has
            ? l.notif_kind_friend_requested(x)
            : l.notif_kind_friend_requested_anon,
      'friend.accepted' =>
        has
            ? l.notif_kind_friend_accepted(x)
            : l.notif_kind_friend_accepted_anon,
      'social.followed' =>
        has
            ? l.notif_kind_social_followed(x)
            : l.notif_kind_social_followed_anon,
      'social.circle_joined' =>
        has
            ? l.notif_kind_social_circle_joined(x)
            : l.notif_kind_social_circle_joined_anon,
      'social.post_liked' =>
        has
            ? l.notif_kind_social_post_liked(x)
            : l.notif_kind_social_post_liked_anon,
      'social.post_commented' =>
        has
            ? l.notif_kind_social_post_commented(x)
            : l.notif_kind_social_post_commented_anon,
      'social.comment_liked' =>
        has
            ? l.notif_kind_social_comment_liked(x)
            : l.notif_kind_social_comment_liked_anon,
      'social.mentioned_in_post' ||
      'social.mentioned_in_comment' ||
      'social.mentioned' =>
        has
            ? l.notif_kind_social_mentioned(x)
            : l.notif_kind_social_mentioned_anon,
      'game.invited' =>
        has ? l.notif_kind_game_invited(x) : l.notif_kind_game_invited_anon,
      // KAN-973: the live trigger only fired game.updated on a cancel, so an
      // old row reads as game.cancelled ("{title} was cancelled", or the
      // cancellation line when the row names no game).
      'game.updated' => _cancelledTitle(l, args),
      'game.join_request' =>
        has
            ? l.notif_kind_game_join_request(x)
            : l.notif_kind_game_join_request_anon,
      'game.waitlist_promoted' => l.notif_kind_game_waitlist_promoted,
      'game.reminder' => l.notif_kind_game_reminder,
      'arena.payment_required' => l.notif_kind_arena_payment_required,
      'reward.badge_awarded' => l.notif_kind_reward_badge_awarded,
      _ => null,
    };
  }

  /// An old `game.updated` row as a cancellation: game.cancelled's title when
  /// the row names the game (`title`, else `game_title`), otherwise its body
  /// line, which names none.
  static String _cancelledTitle(
    AppLocalizations l,
    Map<String, dynamic>? args,
  ) {
    final a = _resolver(l, args, null);
    final title = a('title').isNotEmpty ? a('title') : a('game_title');
    return title.isEmpty
        ? l.notif_b_game_cancelled
        : l.notif_t_game_cancelled(title);
  }

  /// A template argument: `{name}_<lang>` wins over `{name}`; the actor also
  /// reads the payload's actor names.
  static NotifArg _resolver(
    AppLocalizations l,
    Map<String, dynamic>? args,
    String? actor,
  ) => (String name) {
    final lang = l.localeName.split('_').first;
    final v = args?['${name}_$lang'] ?? args?[name];
    if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    if (name == 'actor' && actor != null) return actor;
    return '';
  };

  /// The actor's display name from the payload (common keys, in order).
  static String? actorName(Map<String, dynamic>? p) {
    if (p == null) return null;
    for (final k in const [
      'actor_display_name',
      'actor_name',
      'actor_username',
      'actor_user_name',
    ]) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  // ── Routes ─────────────────────────────────────────────────────────────

  /// Where tapping a row of [kindKey] goes, from its payload [ctx]; null when
  /// the kind opens nothing. [meetupsEnabled] follows FeatureFlags.
  static String? route(
    String kindKey,
    Map<String, dynamic>? ctx, {
    bool meetupsEnabled = FeatureFlags.enableMeetups,
  }) {
    final kind = _specs[kindKey]?.routeKind ?? NotificationRouteKind.none;
    String? s(String k) => _ctxString(ctx, k);
    String? actorId() =>
        s('actor_user_id') ??
        _ctxFirst(ctx, 'follower_user_ids') ??
        _ctxFirst(ctx, 'actor_user_ids');
    switch (kind) {
      case NotificationRouteKind.none:
        return null;
      case NotificationRouteKind.post:
        final id = s('entity_id') ?? s('post_id');
        return id == null ? null : '${RoutePaths.socialPostDetail}/$id';
      case NotificationRouteKind.comment:
        final id = s('post_id') ?? s('entity_id');
        return id == null ? null : '${RoutePaths.socialPostDetail}/$id';
      case NotificationRouteKind.actorProfile:
        final id = actorId();
        return id == null ? null : '${RoutePaths.userProfile}/$id';
      case NotificationRouteKind.friendRequests:
        return RoutePaths.socialFriends;
      case NotificationRouteKind.friendAccepted:
        final id = s('actor_user_id');
        return id == null
            ? RoutePaths.socialFriends
            : '${RoutePaths.userProfile}/$id';
      case NotificationRouteKind.game:
      case NotificationRouteKind.gameJoinRequest:
        // Game detail lives at /sports/games/:id; join requests land on the
        // requests card.
        final id = s('entity_id') ?? s('game_id');
        if (id == null) return RoutePaths.gamesTab;
        final base = RoutePaths.gameDetail(id);
        return kind == NotificationRouteKind.gameJoinRequest
            ? '$base?focus=requests'
            : base;
      case NotificationRouteKind.arena:
        final id = s('entity_id');
        return id == null ? null : RoutePaths.gameDetail(id);
      case NotificationRouteKind.rewards:
        return RoutePaths.profile;
      case NotificationRouteKind.meetupGuest:
      case NotificationRouteKind.meetupHost:
        return meetupRoute(
          kindKey,
          s('entity_id') ?? s('meetup_id'),
          enabled: meetupsEnabled,
        );
      case NotificationRouteKind.activity:
        final id = s('entity_id');
        if (id == null) return null;
        if (_entityType(ctx) == 'meetup') {
          return meetupsEnabled ? RoutePaths.meetupDetail(id) : null;
        }
        return RoutePaths.gameDetail(id);
    }
  }

  /// Whether [kindKey] is a meetup kind (it opens a meetup).
  static bool isMeetupKind(String kindKey) =>
      switch (_specs[kindKey]?.routeKind) {
        NotificationRouteKind.meetupGuest ||
        NotificationRouteKind.meetupHost => true,
        _ => false,
      };

  /// A meetup kind's route: host kinds open Manage, guest kinds the details.
  /// Null when meetups are off, the kind is not a meetup kind or the id is
  /// missing.
  static String? meetupRoute(
    String kindKey,
    String? meetupId, {
    required bool enabled,
  }) {
    if (!enabled || !isMeetupKind(kindKey)) return null;
    if (meetupId == null || meetupId.isEmpty) return null;
    return _specs[kindKey]!.routeKind == NotificationRouteKind.meetupHost
        ? RoutePaths.meetupManage(meetupId)
        : RoutePaths.meetupDetail(meetupId);
  }

  static String? _entityType(Map<String, dynamic>? ctx) =>
      _ctxString(ctx, 'entity_type') ?? _ctxString(ctx, 'entity_kind');

  static String? _ctxString(Map<String, dynamic>? ctx, String key) {
    final v = ctx?[key];
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    return s.trim().isNotEmpty ? s : null;
  }

  static String? _ctxFirst(Map<String, dynamic>? ctx, String key) {
    final v = ctx?[key];
    if (v is List && v.isNotEmpty && v.first != null) {
      final s = v.first is String ? v.first as String : v.first.toString();
      return s.trim().isNotEmpty ? s : null;
    }
    return null;
  }
}
