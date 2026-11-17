// KAN-989 (W1-F3): the Center's rules without the screen — highlights, chip
// filtering (registry), day groups and target states.
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_center_feed.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'u-989';

AppNotification _n(
  String id,
  String kind, {
  bool read = false,
  Duration ago = const Duration(minutes: 5),
  Map<String, dynamic>? payload,
  Map<String, dynamic> args = const {},
}) => AppNotification(
  id: id,
  toUserId: _userId,
  kindKey: kind,
  title: 'Title $id',
  isRead: read,
  payload: payload,
  args: args,
  createdAt: DateTime.now().subtract(ago),
);

ActivityFeedEvent _a(
  String id,
  String subject,
  String verb, {
  Duration ago = const Duration(minutes: 20),
}) => ActivityFeedEvent(
  id: id,
  subjectType: subject,
  subjectId: 's-$id',
  verb: verb,
  timeBucket: 'past',
  happenedAt: DateTime.now().subtract(ago),
  priority: 1,
  payload: {'title': 'Activity $id'},
);

/// One of every chip's kinds, plus an open decision and a read row.
List<AppNotification> _mixed() => [
  _n('soc', 'social.post_liked', ago: const Duration(minutes: 1)),
  _n('msg', 'message.received', ago: const Duration(minutes: 2)),
  _n('gam', 'game.invited', ago: const Duration(minutes: 3)),
  _n('mee', 'meetup.invited', read: true, ago: const Duration(minutes: 4)),
  _n('sys', 'system.announcement', read: true, ago: const Duration(minutes: 5)),
  _n(
    'act',
    'activity.checkin_open',
    payload: {'entity_type': 'meetup'},
    ago: const Duration(minutes: 6),
  ),
];

void main() {
  group('rules', () {
    test('highlights: attendance, results and badges; not posted or joined, '
        'and no booking', () {
      expect(isActivityHighlight(_a('1', 'reward', 'earned')), isTrue);
      expect(isActivityHighlight(_a('2', 'game', 'attended')), isTrue);
      expect(isActivityHighlight(_a('3', 'game', 'result_confirmed')), isTrue);
      expect(isActivityHighlight(_a('4', 'post', 'posted')), isFalse);
      expect(isActivityHighlight(_a('5', 'game', 'joined')), isFalse);
      expect(isActivityHighlight(_a('6', 'booking', 'confirmed')), isFalse);
      expect(
        isActivityHighlight(_a('7', 'payment', 'payment_succeeded')),
        isFalse,
      );
    });

    test('each chip filters the mixed list; highlights only under All, with '
        'stable keys', () {
      final acts = [_a('h1', 'reward', 'earned'), _a('p', 'post', 'posted')];
      List<String> keys(NotificationChip c) => [
        for (final r in buildCenterRows(
          notifications: _mixed(),
          activities: acts,
          chip: c,
        ))
          r.key,
      ];
      expect(keys(NotificationChip.all), hasLength(7));
      expect(keys(NotificationChip.all), contains('activity:h1'));
      expect(keys(NotificationChip.unread), [
        'notification:soc',
        'notification:msg',
        'notification:gam',
        'notification:act',
      ]);
      expect(keys(NotificationChip.needsAction), [
        'notification:gam',
        'notification:mee',
        'notification:act',
      ]);
      expect(keys(NotificationChip.social), ['notification:soc']);
      expect(keys(NotificationChip.messages), ['notification:msg']);
      expect(keys(NotificationChip.games), ['notification:gam']);
      expect(keys(NotificationChip.meetups), [
        'notification:mee',
        'notification:act',
      ]);
      expect(keys(NotificationChip.system), ['notification:sys']);
    });

    test('a highlight about an object already notified is dropped', () {
      final rows = buildCenterRows(
        notifications: [
          _n('b', 'reward.badge_awarded', payload: {'entity_id': 's-h1'}),
        ],
        activities: [_a('h1', 'reward', 'earned')],
        chip: NotificationChip.all,
      );
      expect(rows.map((r) => r.key), ['notification:b']);
    });

    test('groups: Today, Yesterday, Earlier this week, then by date', () {
      final now = DateTime.now();
      DateTime at(int days) => DateTime(
        now.year,
        now.month,
        now.day,
        12,
      ).subtract(Duration(days: days));
      final rows = [
        for (final d in [0, 1, 3, 9, 30])
          NotificationCenterRow(
            AppNotification(
              id: '$d',
              toUserId: 'u',
              kindKey: 'game.invited',
              title: 't',
              createdAt: at(d),
            ),
          ),
      ];
      final g = groupCenterRows(rows, now);
      expect(g.map((x) => x.key).take(3), ['today', 'yesterday', 'week']);
      expect(g, hasLength(5));
    });

    test('target states from the row; open decisions exclude handled ones', () {
      final now = DateTime.now();
      NotifTargetState s(AppNotification n) => notifTargetStateOf(n, now);
      expect(s(_n('1', 'game.invited')), NotifTargetState.available);
      expect(s(_n('2', 'game.updated')), NotifTargetState.cancelled);
      expect(s(_n('3', 'game.cancelled')), NotifTargetState.cancelled);
      expect(
        s(_n('4', 'game.invited', args: {'target_state': 'deleted'})),
        NotifTargetState.deleted,
      );
      expect(
        s(_n('5', 'game.invited', payload: {'target_state': 'no_access'})),
        NotifTargetState.noAccess,
      );
      final past = now.subtract(const Duration(hours: 1)).toIso8601String();
      expect(
        s(_n('6', 'game.invited', args: {'expires_at': past})),
        NotifTargetState.expired,
      );
      expect(
        s(_n('7', 'game.invited', args: {'resolved_at': past})),
        NotifTargetState.resolved,
      );
      expect(isOpenDecision(_n('8', 'game.invited'), now), isTrue);
      expect(
        isOpenDecision(
          _n('9', 'game.invited', args: {'resolved_at': past}),
          now,
        ),
        isFalse,
      );
      expect(isOpenDecision(_n('10', 'social.post_liked'), now), isFalse);
    });
  });
}
