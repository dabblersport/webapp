// KAN-988 (W1-F2): the row's inline actions really run. One small interface
// ([NotifActionHandler]) calls the existing RPCs and tables; the row only
// knows outcomes. Actions whose backend does not exist yet return
// [NotifActionStatus.unavailable] and are marked `WAVE-2` for wiring.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/app/app_router.dart' show rootNavigatorKey;
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart'
    show attendanceReviewRepositoryProvider;
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart'
    show messagingRepositoryProvider;
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider, profileIdByUserIdProvider;
import 'package:dabbler/utils/constants/route_constants.dart';

/// How an action ended.
enum NotifActionStatus {
  /// It ran; the row shows its result.
  success,

  /// The server says it was already done (another device, or the state moved
  /// on): the row shows "Already handled on another device".
  alreadyHandled,

  /// It failed; the row offers Retry.
  failed,

  /// No backend yet (WAVE-2); the row says "Not available yet".
  unavailable,
}

/// The outcome of one action; [detail] is the server's code, for logs.
class NotifActionOutcome {
  const NotifActionOutcome(this.status, [this.detail]);

  final NotifActionStatus status;
  final String? detail;

  static const success = NotifActionOutcome(NotifActionStatus.success);
  static const already = NotifActionOutcome(NotifActionStatus.alreadyHandled);
  static const unavailable = NotifActionOutcome(NotifActionStatus.unavailable);
}

/// Whether [action] runs inline (true) or only opens the row (false).
bool notifActionRunsInline(NotificationActionId action) => switch (action) {
  NotificationActionId.respond ||
  NotificationActionId.view ||
  NotificationActionId.seeCircle => false,
  _ => true,
};

/// What the row can ask for.
abstract class NotifActionHandler {
  /// Runs [action] for [n].
  Future<NotifActionOutcome> run(
    NotificationActionId action,
    AppNotification n,
  );

  /// Marks [n] read or unread.
  Future<bool> setRead(AppNotification n, {required bool read});

  /// Mutes (or, for Undo, unmutes) every notification of [kindKey].
  Future<bool> setKindMuted(String kindKey, {required bool muted});

  /// Mutes (or unmutes) the conversation a message notification is about.
  Future<bool> setConversationMuted(
    String conversationId, {
    required bool muted,
  });
}

String? _s(Map<String, dynamic>? p, String k) {
  final v = p?[k];
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// The id of the entity the row is about (`entity_id`, then the kind's own).
String? notifEntityId(AppNotification n, [String? alt]) =>
    _s(n.payload, 'entity_id') ??
    (alt == null ? null : _s(n.payload, alt)) ??
    _s(n.args, 'entity_id');

/// The actor's user id (`actor_user_id`, else the first follower / actor).
String? notifActorUserId(AppNotification n) {
  final p = n.payload;
  final direct = _s(p, 'actor_user_id');
  if (direct != null) return direct;
  for (final key in const ['follower_user_ids', 'actor_user_ids']) {
    final list = p?[key];
    if (list is List && list.isNotEmpty && list.first != null) {
      return '${list.first}';
    }
  }
  return null;
}

/// The live handler: existing RPCs and tables (`SupabaseConfig`).
class SupabaseNotifActionHandler implements NotifActionHandler {
  SupabaseNotifActionHandler(this._ref, this._db, {required this.open});

  final Ref _ref;
  final SupabaseClient _db;

  /// Pushes a route (the app's router; tests record it).
  final void Function(String location) open;

  /// Server codes that mean "already done": the RPCs' own words.
  static const Set<String> alreadyCodes = <String>{
    'already_decided',
    'already',
    'joined',
    'not_attending',
    'request_not_found',
  };

  static bool isAlreadyHandledError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') return true; // unique: the follow exists
      return alreadyCodes.contains(e.message.trim());
    }
    return false;
  }

  Future<NotifActionOutcome> _guard(
    Future<NotifActionOutcome> Function() f,
  ) async {
    try {
      return await f();
    } catch (e) {
      if (isAlreadyHandledError(e)) return NotifActionOutcome.already;
      return NotifActionOutcome(NotifActionStatus.failed, '$e');
    }
  }

  @override
  Future<NotifActionOutcome> run(
    NotificationActionId action,
    AppNotification n,
  ) {
    final kind = NotificationKinds.canonical(n.kindKey);
    return switch (action) {
      NotificationActionId.followBack => _guard(() => _followBack(n)),
      NotificationActionId.approve ||
      NotificationActionId.decline ||
      NotificationActionId.reject => _guard(
        () => _decide(n, kind, approve: action == NotificationActionId.approve),
      ),
      NotificationActionId.going => _guard(() => _rsvp(n, 'going')),
      NotificationActionId.notGoing => _guard(() => _rsvp(n, 'cancel')),
      // KAN-999 (G-06): the note sheet lives on the no-show screen.
      NotificationActionId.requestReview => Future<NotifActionOutcome>.value(
        _openNoShow(n),
      ),
      NotificationActionId.accept || NotificationActionId.keepDecision
          when kind == 'activity.review_requested' =>
        _guard(
          () => _decideReview(n, accept: action == NotificationActionId.accept),
        ),
      // WAVE-2: no backend yet — declining a game invite, giving up a
      // waitlist place (W1-B6 sheet), attendance, results, ratings, reviews
      // and the security answers.
      _ => Future<NotifActionOutcome>.value(NotifActionOutcome.unavailable),
    };
  }

  Future<NotifActionOutcome> _followBack(AppNotification n) async {
    final actor = notifActorUserId(n);
    final me = await _ref.read(myProfileIdProvider.future);
    final target = actor == null
        ? null
        : await _ref.read(profileIdByUserIdProvider(actor).future);
    if (me == null || target == null) {
      return const NotifActionOutcome(NotifActionStatus.failed, 'no_profile');
    }
    await _db.from(SupabaseConfig.profileFollowsTable).insert({
      'follower_profile_id': me,
      'following_profile_id': target,
    });
    return NotifActionOutcome.success;
  }

  /// A join request: the host approves or declines. A game request is looked
  /// up by game and requester (the payload has no request id); a meet-up
  /// request is decided by meet-up and requester.
  Future<NotifActionOutcome> _decide(
    AppNotification n,
    String kind, {
    required bool approve,
  }) async {
    final requester = notifActorUserId(n);
    if (kind.startsWith('meetup.')) {
      final meetup = notifEntityId(n, 'meetup_id');
      if (meetup == null || requester == null) {
        return const NotifActionOutcome(NotifActionStatus.failed, 'no_target');
      }
      await _db.rpc(
        SupabaseConfig.rpcMeetupDecideRequestFn,
        params: {
          'p_meetup_id': meetup,
          'p_user_id': requester,
          'p_decision': approve ? 'approve' : 'decline',
        },
      );
      return NotifActionOutcome.success;
    }
    final game = notifEntityId(n, 'game_id');
    if (game == null || requester == null) {
      return const NotifActionOutcome(NotifActionStatus.failed, 'no_target');
    }
    final rows = await _db
        .from(SupabaseConfig.gameJoinRequestsTable)
        .select('id')
        .eq('game_id', game)
        .eq('from_user_id', requester)
        .eq('status', 'pending')
        .limit(1);
    if ((rows as List).isEmpty) return NotifActionOutcome.already;
    final res = await _db.rpc(
      SupabaseConfig.rpcDecideJoinRequestFn,
      params: {'p_request_id': rows.first['id'], 'p_approve': approve},
    );
    return '$res' == 'already_decided'
        ? NotifActionOutcome.already
        : NotifActionOutcome.success;
  }

  NotifActionOutcome _openNoShow(AppNotification n) {
    final event = _s(n.payload, 'event_id');
    if (event == null) {
      return const NotifActionOutcome(NotifActionStatus.failed, 'no_target');
    }
    open(RoutePaths.noShow(event, title: _s(n.payload, 'title')));
    return NotifActionOutcome.success;
  }

  /// The organiser accepts the correction (attended) or keeps the no-show.
  /// The server names the player in `player_user_id`.
  Future<NotifActionOutcome> _decideReview(
    AppNotification n, {
    required bool accept,
  }) async {
    final event = _s(n.payload, 'event_id');
    final player = _s(n.payload, 'player_user_id');
    if (event == null || player == null) {
      return const NotifActionOutcome(NotifActionStatus.failed, 'no_target');
    }
    final r = await _ref
        .read(attendanceReviewRepositoryProvider)
        .decide(event, player, accept: accept);
    return r.fold(
      (f) => f.code == 'no_open_review'
          ? NotifActionOutcome.already
          : NotifActionOutcome(NotifActionStatus.failed, f.code ?? f.message),
      (_) => NotifActionOutcome.success,
    );
  }

  Future<NotifActionOutcome> _rsvp(AppNotification n, String action) async {
    final meetup = notifEntityId(n, 'meetup_id');
    if (meetup == null) {
      return const NotifActionOutcome(NotifActionStatus.failed, 'no_target');
    }
    await _db.rpc(
      SupabaseConfig.rpcMeetupRsvpFn,
      params: {'p_meetup_id': meetup, 'p_action': action},
    );
    return NotifActionOutcome.success;
  }

  @override
  Future<bool> setRead(AppNotification n, {required bool read}) async {
    if (read) {
      final r = await _ref
          .read(notificationsRepositoryProvider)
          .markAsRead(n.id);
      return r.isSuccess;
    }
    try {
      await _db
          .from(SupabaseConfig.notificationsTable)
          .update({'is_read': false, 'read_at': null})
          .eq('id', n.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setKindMuted(String kindKey, {required bool muted}) async {
    final repo = _ref.read(notificationSettingsRepositoryProvider);
    final loaded = await repo.load();
    if (loaded is! Ok<NotificationSettings, Failure>) return false;
    final settings = loaded.value;
    final saved = await repo.save(
      settings.withKindsMuted(NotificationKinds.aliasesOf(kindKey), muted),
    );
    return saved.isSuccess;
  }

  @override
  Future<bool> setConversationMuted(
    String conversationId, {
    required bool muted,
  }) async {
    final r = await _ref
        .read(messagingRepositoryProvider)
        .setMuted(conversationId, muted);
    return r.isSuccess;
  }
}

/// The handler the rows use (tests override it with a fake).
final notifActionHandlerProvider = Provider<NotifActionHandler>(
  (ref) => SupabaseNotifActionHandler(
    ref,
    Supabase.instance.client,
    open: (location) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) GoRouter.of(ctx).push(location);
    },
  ),
);
