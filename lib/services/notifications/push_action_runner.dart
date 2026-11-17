// KAN-992 (W1-F6): runs a notification action — Reply, Mark as read, Going /
// Not going (KAN-983) and Cancel my place (KAN-982, after the in-app
// confirmation, G-14). Each step is a seam so the routing is unit-tested.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'push_contract.dart';
import 'push_presence.dart';

/// What happened to an action.
enum PushActionOutcome {
  done,

  /// Missing the ids it needs (or text for Reply).
  skipped,

  /// The user did not confirm (Cancel my place).
  cancelled,
  failed,

  /// The app was opened on the target instead (the RPC is not live, or the
  /// action needs the app).
  opened,
}

class PushActionRunner {
  PushActionRunner({
    required this.markRead,
    required this.reply,
    required this.rpc,
    required this.confirmCancelPlace,
    required this.openRoute,
  });

  /// Marks the inbox row read (writes is_read and read_at only, KAN-974b).
  final Future<void> Function(String notificationId) markRead;

  /// Sends [text] to the conversation.
  final Future<void> Function(String conversationId, String text) reply;

  /// Calls an RPC.
  final Future<Object?> Function(String fn, Map<String, dynamic> params) rpc;

  /// "Give up your place? No penalty." (G-14); true to go on.
  final Future<bool> Function(Map<String, dynamic> data) confirmCancelPlace;

  /// Opens the app on a route.
  final void Function(String route) openRoute;

  /// The live runner: Supabase for the rows and RPCs; [reply], the
  /// confirmation and navigation come from the app.
  factory PushActionRunner.supabase({
    required Future<void> Function(String conversationId, String text) reply,
    required Future<bool> Function(Map<String, dynamic> data)
    confirmCancelPlace,
    required void Function(String route) openRoute,
    SupabaseClient? client,
  }) {
    SupabaseClient db() => client ?? Supabase.instance.client;
    return PushActionRunner(
      markRead: (id) => db()
          .from(SupabaseConfig.notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id),
      reply: reply,
      rpc: (fn, params) => db().rpc(fn, params: params),
      confirmCancelPlace: confirmCancelPlace,
      openRoute: openRoute,
    );
  }

  static String? _s(Map<String, dynamic> d, String k) {
    final v = d[k];
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _entity(Map<String, dynamic> d, String type, String key) =>
      _s(d, key) ?? (d['entity_type'] == type ? _s(d, 'entity_id') : null);

  /// Runs [event].
  Future<PushActionOutcome> run(PushActionEvent event) async {
    final d = event.data;
    try {
      switch (event.action) {
        case PushActionId.markRead:
          final id = _s(d, 'notification_id');
          if (id == null) return PushActionOutcome.skipped;
          await markRead(id);
          return PushActionOutcome.done;
        case PushActionId.reply:
          final conv = _entity(d, 'conversation', 'conversation_id');
          final text = event.text?.trim();
          if (conv == null || text == null || text.isEmpty) {
            return PushActionOutcome.skipped;
          }
          await reply(conv, text);
          final id = _s(d, 'notification_id');
          if (id != null) await markRead(id);
          return PushActionOutcome.done;
        case PushActionId.going:
        case PushActionId.notGoing:
          final meetup = _entity(d, 'meetup', 'meetup_id');
          if (meetup == null) return PushActionOutcome.skipped;
          await rpc(SupabaseConfig.rpcAnswerMeetupAttendance, {
            'p_meetup_id': meetup,
            'p_answer': event.action == PushActionId.going
                ? 'going'
                : 'not_going',
          });
          return PushActionOutcome.done;
        case PushActionId.cancelPlace:
          final game = _entity(d, 'game', 'game_id');
          if (game == null) return PushActionOutcome.skipped;
          if (!await confirmCancelPlace(d)) return PushActionOutcome.cancelled;
          try {
            await rpc(SupabaseConfig.rpcCancelWaitlistPlace, {
              'p_game_id': game,
            });
            return PushActionOutcome.done;
          } catch (e) {
            // Not live yet (or refused): the game opens, where the place can
            // be given up by hand.
            debugPrint('Cancel my place via RPC failed: $e');
            openRoute(RoutePaths.gameDetail(game));
            return PushActionOutcome.opened;
          }
      }
    } catch (e) {
      debugPrint('Push action ${event.action.wire} failed: $e');
      return PushActionOutcome.failed;
    }
  }
}
