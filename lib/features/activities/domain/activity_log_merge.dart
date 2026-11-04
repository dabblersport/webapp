import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';

/// KAN-852: the Activity log behind the Home bell combines two existing,
/// authenticated sources:
///
/// * `rpc_get_activity_feed` — the personal log ([ActivityFeedEvent]);
/// * `public_activities` filtered to the owner's profile — what the owner's
///   Profile → Activity tab used to show ([PublicActivity]).
///
/// The same real-world event can exist in both. The database shares ids
/// between them (baseline schema `fn_games_activity_sync` writes a
/// `game_create` row whose id IS the game id; `fn_game_roster_activity_sync`
/// writes a `game_join` row whose `parent_activity_id` IS the game id), and the
/// RPC emits `game/created` and `game/joined` with `subject_id` = game id.
/// [activityLogIdentity] turns both into one key so the merge keeps one row.

/// Marks a converted [PublicActivity] in [ActivityFeedEvent.payload].
const String kActivityLogSourceKey = 'source';
const String kActivityLogSourcePublic = 'public_activities';

/// The stable identity of a personal-log event.
String activityLogIdentity(ActivityFeedEvent e) {
  if (e.payload?[kActivityLogSourceKey] == kActivityLogSourcePublic) {
    final String raw = (e.payload?['activity_type'] as String?) ?? '';
    final String? parent = e.payload?['parent_activity_id'] as String?;
    switch (raw) {
      case 'game_create':
        return 'game:created:${e.id}';
      case 'game_join':
        if (parent != null) return 'game:joined:$parent';
    }
    return 'public:${e.id}';
  }
  return '${e.subjectType}:${e.verb}:${e.subjectId}';
}

/// `public_activities.activity_type` → the log's subject/verb vocabulary.
({String subject, String verb}) _publicShape(String raw) => switch (raw) {
  'post' => (subject: 'post', verb: 'posted'),
  'repost' => (subject: 'post', verb: 'reposted'),
  'comment' => (subject: 'post', verb: 'commented'),
  'like' || 'reaction' => (subject: 'social', verb: 'liked'),
  'follow' => (subject: 'social', verb: 'followed'),
  'game_create' => (subject: 'game', verb: 'created'),
  'game_join' => (subject: 'game', verb: 'joined'),
  'meetup_create' => (subject: 'social', verb: 'created_meetup'),
  'meetup_join' => (subject: 'social', verb: 'joined_meetup'),
  'badge' || 'level_up' => (subject: 'reward', verb: 'earned'),
  _ => (subject: 'social', verb: 'active'),
};

/// Adapts a [PublicActivity] of the owner into the log's row model, so the
/// existing [ActivityFeedEvent] rows, statistics and grouping draw it.
ActivityFeedEvent activityFromPublic(PublicActivity a, {String? language}) {
  final shape = _publicShape(a.rawType);
  final String subjectId = a.rawType == 'game_join'
      ? (a.parentActivityId ?? a.id)
      : a.id;
  final String title = a.localizedTargetTitle(language ?? 'en');
  return ActivityFeedEvent(
    id: a.id,
    subjectType: shape.subject,
    subjectId: subjectId,
    verb: shape.verb,
    timeBucket: 'past',
    happenedAt: a.createdAt,
    priority: 0,
    payload: <String, dynamic>{
      kActivityLogSourceKey: kActivityLogSourcePublic,
      'activity_type': a.rawType,
      'parent_activity_id': a.parentActivityId,
      if (title.isNotEmpty) 'description': title,
    },
  );
}

/// Merges [incoming] into [existing]: one row per [activityLogIdentity]
/// (the RPC row wins over its `public_activities` twin, since it carries the
/// time bucket and schedule), newest first.
List<ActivityFeedEvent> mergeActivityLog(
  Iterable<ActivityFeedEvent> existing,
  Iterable<ActivityFeedEvent> incoming,
) {
  final Map<String, ActivityFeedEvent> byKey = <String, ActivityFeedEvent>{};
  for (final ActivityFeedEvent e in <ActivityFeedEvent>[
    ...existing,
    ...incoming,
  ]) {
    final String key = activityLogIdentity(e);
    final ActivityFeedEvent? prior = byKey[key];
    if (prior == null || (_isPublic(prior) && !_isPublic(e))) {
      byKey[key] = e;
    }
  }
  final List<ActivityFeedEvent> out = byKey.values.toList()
    ..sort((a, b) {
      final int c = b.happenedAt.compareTo(a.happenedAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return out;
}

bool _isPublic(ActivityFeedEvent e) =>
    e.payload?[kActivityLogSourceKey] == kActivityLogSourcePublic;

/// The Activity log chip an event belongs to (`all` matches every event).
String activityLogCategoryOf(ActivityFeedEvent e) => switch (e.subjectType) {
  'post' => 'me',
  'payment' => 'booking',
  final String s => s,
};

/// Events shown under the chip [category]; `all` (or null) is the full list.
List<ActivityFeedEvent> filterActivityLog(
  List<ActivityFeedEvent> events,
  String? category,
) {
  if (category == null || category == 'all') return events;
  return events.where((e) => activityLogCategoryOf(e) == category).toList();
}

/// KAN-874: the text an Activity log row shows, as searchable strings.
///
/// Mirrors `ActivityRow` (`notifications/presentation/widgets/activity_row.dart`):
/// the title is `payload.title`, else "<Verb> <subject>"; the detail is the
/// first non-blank of description / game_name / venue_name / user_name, plus
/// `location`. The localized participant count is not searchable text.
List<String> _activityLogSearchText(ActivityFeedEvent e) {
  final Map<String, dynamic> p = e.payload ?? const <String, dynamic>{};
  final Object? title = p['title'];
  final String verb = e.verb.replaceAll('_', ' ');
  final List<String> out = <String>[
    if (title is String)
      title
    else if (verb.isNotEmpty)
      '${verb[0].toUpperCase()}${verb.substring(1)} ${e.subjectType}',
  ];
  for (final String key in const <String>[
    'description',
    'game_name',
    'venue_name',
    'user_name',
  ]) {
    final Object? v = p[key];
    if (v is String && v.trim().isNotEmpty) {
      out.add(v.trim());
      break;
    }
  }
  final Object? location = p['location'];
  if (location is String) out.add(location);
  return out;
}

/// Events whose visible title or detail contains [query], case-insensitively.
/// A blank query returns [events] itself; order is always preserved.
List<ActivityFeedEvent> searchActivityLog(
  List<ActivityFeedEvent> events,
  String query,
) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return events;
  return events
      .where(
        (e) =>
            _activityLogSearchText(e).any((s) => s.toLowerCase().contains(q)),
      )
      .toList();
}
