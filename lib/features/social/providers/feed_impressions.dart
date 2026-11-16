import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/constants/timing/home_feed_timing.dart';

/// One impression: `{entity_type, entity_id, feed_at}`, as
/// `rpc_mark_feed_impressions` takes it (`feed_at` optional server-side).
typedef FeedImpression = Map<String, String>;

/// KAN-966: records the For you Active cards that came on screen, so the
/// server ranks a card in once and then lets it sink with the posts.
///
/// Each card is sent once per tracker (a session). Marks are debounced by
/// [delay] and sent in batches of at most
/// [SupabaseConfig.markFeedImpressionsMaxItems]; a batch that fails is
/// forgotten, so the card is marked again the next time it is on screen.
class FeedImpressionTracker {
  FeedImpressionTracker(
    this._send, {
    this.delay = HomeFeedTiming.impressionDebounce,
  });

  final Future<void> Function(List<FeedImpression> items) _send;
  final Duration delay;

  final Set<String> _sent = <String>{};
  final Map<String, FeedImpression> _pending = <String, FeedImpression>{};
  Timer? _timer;

  static String _key(String type, String id) => '$type:$id';

  /// The card [entityType] / [entityId] is on screen; [feedAt] is that card
  /// row's `feed_at` as rendered (KAN-966 PEER: sent with the item).
  void markSeen(String entityType, String entityId, {DateTime? feedAt}) {
    if (entityType.isEmpty || entityId.isEmpty) return;
    final key = _key(entityType, entityId);
    if (_sent.contains(key) || _pending.containsKey(key)) return;
    _pending[key] = <String, String>{
      'entity_type': entityType,
      'entity_id': entityId,
      if (feedAt != null) 'feed_at': feedAt.toUtc().toIso8601String(),
    };
    _timer?.cancel();
    if (_pending.length >= SupabaseConfig.markFeedImpressionsMaxItems) {
      unawaited(flush());
    } else {
      _timer = Timer(delay, () => unawaited(flush()));
    }
  }

  /// Sends what is pending now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = Map<String, FeedImpression>.of(_pending);
    _pending.clear();
    _sent.addAll(batch.keys);
    final keys = batch.keys.toList();
    const max = SupabaseConfig.markFeedImpressionsMaxItems;
    for (var i = 0; i < keys.length; i += max) {
      final chunk = keys.sublist(
        i,
        i + max > keys.length ? keys.length : i + max,
      );
      try {
        await _send(<FeedImpression>[for (final k in chunk) batch[k]!]);
      } catch (e) {
        debugPrint('[FeedImpressions] send failed: $e');
        _sent.removeAll(chunk);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isNotEmpty) unawaited(flush());
  }
}

/// The session's tracker, sending to `rpc_mark_feed_impressions`.
final feedImpressionTrackerProvider = Provider<FeedImpressionTracker>((ref) {
  final db = Supabase.instance.client;
  final tracker = FeedImpressionTracker(
    (items) => db.rpc(
      SupabaseConfig.markFeedImpressionsFn,
      params: <String, dynamic>{'p_items': items},
    ),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});
