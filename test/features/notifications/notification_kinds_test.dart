// KAN-978 (W0-5): the kind registry knows every server kind, routes each
// family, maps each kind to its chip and settings group, and titles rows in
// EN and AR (including the mentions fix).
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kind_titles.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// The 102 kinds of `public.notification_kinds`: 87 after KAN-974 (35 live,
/// 52 new), KAN-1013 and KAN-1015's two live kinds, and KAN-1010's 13
/// inactive booking and payment kinds (which also made
/// `arena.payment_required` inactive: 36 live). A kind added on the server must be added here and to the registry.
const List<String> serverKinds = <String>[
  // live (35)
  'arena.payment_required', 'auth.welcome', 'friend.accepted',
  'friend.requested', 'game.invited', 'game.join_accepted',
  'game.join_request', 'game.player_joined', 'game.reminder', 'game.removed',
  'game.updated', 'game.waitlist_promoted', 'meetup.cancelled',
  'meetup.invited', 'meetup.player_joined', 'meetup.request_approved',
  'meetup.request_declined', 'meetup.request_received',
  'meetup.rsvp_received', 'message.received', 'moderation.report_submitted',
  'moderation.user_blocked', 'reward.badge_awarded', 'social.circle_joined',
  'social.comment_liked', 'social.followed', 'social.friend_accepted',
  'social.friend_request', 'social.mentioned_in_comment',
  'social.mentioned_in_post', 'social.post_commented', 'social.post_liked',
  'social.post_reacted', 'squad.invited', 'system.announcement',
  // new (52)
  'game.join_declined', 'game.invite_accepted', 'game.invite_declined',
  'game.invite_withdrawn', 'game.invite_expired', 'game.player_left',
  'game.full', 'game.waitlist_joined', 'game.waitlist_position_changed',
  'meetup.removed', 'meetup.player_left', 'meetup.rsvp_interested',
  'game.cancelled', 'game.time_changed', 'game.venue_changed',
  'game.details_changed', 'game.occurrence_cancelled', 'game.series_changed',
  'meetup.time_changed', 'meetup.venue_changed', 'meetup.details_changed',
  'meetup.occurrence_cancelled', 'meetup.series_changed', 'meetup.reminder',
  'meetup.confirm_attendance', 'activity.checkin_open',
  'activity.checkin_closing', 'activity.checked_in',
  'activity.attendance_corrected', 'activity.no_show_pending',
  'activity.review_requested', 'activity.review_accepted',
  'activity.review_kept', 'activity.no_show_confirmed',
  'activity.showup_rate_updated', 'activity.confirm_end',
  'activity.confirm_end_reminder', 'activity.auto_closed', 'activity.ended',
  'activity.post_activity', 'activity.result_ready',
  'activity.result_enter_final', 'activity.result_confirmed',
  'activity.result_corrected', 'activity.result_closed',
  'activity.rating_reminder', 'activity.summary', 'security.new_signin',
  'security.password_changed', 'security.email_changed',
  'social.comment_replied', 'social.post_reposted',
  // KAN-1013 / KAN-1015 (live)
  'meetup.wants_to_join_full', 'game.series_cancelled',
  // KAN-1010 (inactive, F-12)
  'booking.pending', 'booking.confirmed', 'booking.rejected',
  'booking.hold_expiring', 'booking.changed', 'booking.cancelled',
  'venue.feedback_request', 'payment.pending', 'payment.succeeded',
  'payment.failed', 'refund.processing', 'refund.completed', 'refund.failed',
];

AppNotification _n(
  String kind, {
  Map<String, dynamic>? payload,
  Map<String, dynamic> args = const <String, dynamic>{},
  String title = 'Server title',
  bool read = false,
}) => AppNotification(
  id: 'n-$kind',
  toUserId: 'u1',
  kindKey: kind,
  title: title,
  payload: payload,
  args: args,
  schemaVersion: args.isEmpty ? 1 : 2,
  isRead: read,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

void main() {
  group('coverage', () {
    test('every server kind is in the registry, and nothing else', () {
      expect(serverKinds, hasLength(102));
      expect(serverKinds.toSet(), hasLength(102));
      expect(NotificationKinds.keys.toSet(), serverKinds.toSet());
      expect(notificationServerKinds.keys.toSet(), serverKinds.toSet());
      expect(NotificationKinds.all.where((s) => s.active), hasLength(36));
    });

    test('every kind has an EN and AR title and body', () {
      for (final k in serverKinds) {
        final names = notificationTitleArgs[k]!;
        final args = {for (final n in names) n: 'X'};
        final spec = NotificationKinds.of(k)!;
        expect(spec.icon, isNotEmpty, reason: k);
        for (final l in [en, ar]) {
          expect(
            NotificationKinds.body(l, k, {
              ...args,
              'old': 'a',
              'new': 'b',
              'field': 'f',
              'position': '2',
              'organiser': 'o',
              'reason': 'r',
              'close_time': 't',
              'status': 's',
              'rate': '9',
              'count': '3',
              'score': '1-0',
              'when': 'w',
              'time': 't',
              'slot': 's',
              'title': 'T',
              'actor': 'A',
            }),
            isNotEmpty,
            reason: '$k ${l.localeName}',
          );
        }
      }
    });

    test('aliases: friend.* stand for the social kinds, game.updated for a '
        'cancellation', () {
      expect(
        NotificationKinds.canonical('friend.requested'),
        'social.friend_request',
      );
      expect(
        NotificationKinds.canonical('friend.accepted'),
        'social.friend_accepted',
      );
      expect(NotificationKinds.canonical('game.updated'), 'game.cancelled');
      expect(NotificationKinds.aliasesOf('game.cancelled'), <String>[
        'game.cancelled',
        'game.updated',
      ]);
      expect(NotificationKinds.canonical('social.followed'), 'social.followed');
    });

    test('security notices cannot be muted and break quiet hours', () {
      for (final k in [
        'security.new_signin',
        'security.password_changed',
        'security.email_changed',
      ]) {
        final s = NotificationKinds.of(k)!;
        expect(s.canMute, isFalse);
        expect(s.breaksQuiet, isTrue);
        expect(s.category, NotificationCategory.security);
      }
    });
  });

  group('routes', () {
    String? r(String k, Map<String, dynamic> ctx, {bool meetups = true}) =>
        NotificationKinds.route(k, ctx, meetupsEnabled: meetups);

    test('social', () {
      expect(
        r('social.post_liked', {'entity_id': 'p1'}),
        '${RoutePaths.socialPostDetail}/p1',
      );
      expect(
        r('social.mentioned_in_post', {'post_id': 'p2'}),
        '${RoutePaths.socialPostDetail}/p2',
      );
      expect(
        r('social.comment_liked', {'post_id': 'p3', 'entity_id': 'c'}),
        '${RoutePaths.socialPostDetail}/p3',
      );
      expect(
        r('social.mentioned_in_comment', {'entity_id': 'p4'}),
        '${RoutePaths.socialPostDetail}/p4',
      );
      expect(
        r('social.comment_replied', {'post_id': 'p5'}),
        '${RoutePaths.socialPostDetail}/p5',
      );
      expect(
        r('social.post_reposted', {'entity_id': 'p6'}),
        '${RoutePaths.socialPostDetail}/p6',
      );
      expect(
        r('social.followed', {
          'follower_user_ids': ['u9'],
        }),
        '${RoutePaths.userProfile}/u9',
      );
      expect(
        r('social.circle_joined', {'actor_user_id': 'u8'}),
        '${RoutePaths.userProfile}/u8',
      );
      expect(r('friend.requested', {}), RoutePaths.socialFriends);
      expect(r('friend.accepted', {}), RoutePaths.socialFriends);
      expect(
        r('friend.accepted', {'actor_user_id': 'u7'}),
        '${RoutePaths.userProfile}/u7',
      );
      expect(r('social.post_reacted', {'entity_id': 'p'}), isNull);
    });

    test('games, including the game.updated cancellation alias', () {
      for (final k in [
        'game.invited',
        'game.reminder',
        'game.removed',
        'game.updated',
        'game.cancelled',
        'game.time_changed',
        'game.full',
      ]) {
        expect(
          r(k, {'entity_id': 'g1'}),
          RoutePaths.gameDetail('g1'),
          reason: k,
        );
        expect(r(k, {}), RoutePaths.gamesTab, reason: k);
      }
      expect(
        r('game.updated', {'game_id': 'g2'}),
        r('game.cancelled', {'game_id': 'g2'}),
      );
      expect(
        r('game.join_request', {'entity_id': 'g1'}),
        '${RoutePaths.gameDetail('g1')}?focus=requests',
      );
      expect(
        r('arena.payment_required', {'entity_id': 'g3'}),
        RoutePaths.gameDetail('g3'),
      );
      expect(r('arena.payment_required', {}), isNull);
      expect(r('reward.badge_awarded', {}), RoutePaths.profile);
    });

    test('meetups: host kinds open Manage, guest kinds the details', () {
      const host = [
        'meetup.rsvp_received',
        'meetup.request_received',
        'meetup.player_left',
        'meetup.rsvp_interested',
      ];
      const guest = [
        'meetup.invited',
        'meetup.player_joined',
        'meetup.request_approved',
        'meetup.request_declined',
        'meetup.cancelled',
        'meetup.removed',
        'meetup.time_changed',
        'meetup.reminder',
        'meetup.confirm_attendance',
      ];
      for (final k in host) {
        expect(r(k, {'entity_id': 'm1'}), RoutePaths.meetupManage('m1'));
      }
      for (final k in guest) {
        expect(r(k, {'meetup_id': 'm1'}), RoutePaths.meetupDetail('m1'));
        expect(r(k, {'meetup_id': 'm1'}, meetups: false), isNull);
      }
      expect(r('meetup.invited', {}), isNull);
    });

    test(
      'activities follow their entity; security and system open nothing',
      () {
        expect(
          r('activity.checkin_open', {
            'entity_type': 'game',
            'entity_id': 'g1',
          }),
          RoutePaths.checkIn('g1'),
        );
        expect(
          r('activity.summary', {
            'entity_type': 'meetup',
            'entity_id': 'm1',
          }),
          RoutePaths.meetupDetail('m1'),
        );
        // KAN-1000: result notices open G-03, post-activity ones G-02.
        expect(
          r('activity.result_ready', {'event_id': 'e1', 'entity_id': 'm1'}),
          RoutePaths.resultApproval('e1'),
        );
        expect(
          r('activity.rating_reminder', {'event_id': 'e1'}),
          RoutePaths.postActivity('e1'),
        );
        // KAN-998: both check-in notices open the check-in screen; the
        // event id falls back to entity_id.
        expect(
          r('activity.checkin_closing', {'event_id': 'e1', 'entity_id': 'g1'}),
          RoutePaths.checkIn('e1'),
        );
        expect(
          r('activity.checkin_closing', {'entity_id': 'g1'}),
          RoutePaths.checkIn('g1'),
        );
        expect(r('activity.checkin_closing', {}), isNull);
        // KAN-999: a review request opens the organiser's list; the no-show
        // and review outcomes open the player's no-show screen.
        expect(
          r('activity.review_requested', {'event_id': 'e1', 'title': 'Padel'}),
          RoutePaths.attendance('e1', title: 'Padel'),
        );
        for (final k in <String>[
          'activity.no_show_pending',
          'activity.review_accepted',
          'activity.review_kept',
          'activity.no_show_confirmed',
        ]) {
          expect(r(k, {'event_id': 'e1'}), RoutePaths.noShow('e1'));
          expect(r(k, {'entity_id': 'g1'}), RoutePaths.noShow('g1'));
        }
        expect(r('activity.review_requested', {}), isNull);
        expect(r('activity.summary', {}), isNull);
        expect(r('security.new_signin', {'entity_id': 'x'}), isNull);
        expect(r('message.received', {'entity_id': 'x'}), isNull);
        expect(r('unknown.kind', {'entity_id': 'x'}), isNull);
      },
    );
  });

  group('chips', () {
    test('each kind maps to its category chip', () {
      final cases = <String, NotificationChip>{
        'social.post_liked': NotificationChip.social,
        'friend.requested': NotificationChip.social,
        'message.received': NotificationChip.messages,
        'game.invited': NotificationChip.games,
        'meetup.invited': NotificationChip.meetups,
        'system.announcement': NotificationChip.system,
        'security.new_signin': NotificationChip.system,
        'arena.payment_required': NotificationChip.system,
        'activity.checkin_open': NotificationChip.games,
      };
      for (final c in cases.entries) {
        expect(NotificationKinds.chipOf(_n(c.key)), c.value, reason: c.key);
      }
      expect(
        NotificationKinds.chipOf(
          _n('activity.checkin_open', payload: {'entity_type': 'meetup'}),
        ),
        NotificationChip.meetups,
      );
    });

    test('All, Unread and Needs action cut across kinds', () {
      final unreadInvite = _n('game.invited');
      final readLike = _n('social.post_liked', read: true);
      expect(NotificationKinds.inChip(NotificationChip.all, readLike), isTrue);
      expect(
        NotificationKinds.inChip(NotificationChip.unread, readLike),
        isFalse,
      );
      expect(
        NotificationKinds.inChip(NotificationChip.unread, unreadInvite),
        isTrue,
      );
      expect(
        NotificationKinds.inChip(NotificationChip.needsAction, unreadInvite),
        isTrue,
      );
      expect(
        NotificationKinds.inChip(NotificationChip.needsAction, readLike),
        isFalse,
      );
      expect(
        NotificationKinds.inChip(NotificationChip.games, unreadInvite),
        isTrue,
      );
    });

    test("today's Center chips are unchanged", () {
      expect(NotificationKinds.currentChipOf('game.invited'), 'games');
      expect(
        NotificationKinds.currentChipOf('arena.payment_required'),
        'bookings',
      );
      expect(NotificationKinds.currentChipOf('friend.accepted'), 'social');
      expect(
        NotificationKinds.currentChipOf('reward.badge_awarded'),
        'achieve',
      );
      expect(NotificationKinds.currentChipOf('meetup.invited'), isNull);
    });
  });

  test('settings toggles keep their kinds', () {
    List<String> k(Set<NotificationSettingsGroup> g) =>
        NotificationKinds.kindsIn(g);
    expect(k({NotificationSettingsGroup.gameInvites}), [
      'game.invited',
      'game.join_request',
      'game.join_accepted',
    ]);
    expect(
      k({
        NotificationSettingsGroup.gameUpdates,
        NotificationSettingsGroup.waitlist,
      }),
      [
        'game.updated',
        'game.waitlist_promoted',
        'game.player_joined',
        // KAN-1015: live, so the Game updates switch covers it.
        'game.series_cancelled',
      ],
    );
    expect(
      k({
        NotificationSettingsGroup.likes,
        NotificationSettingsGroup.comments,
        NotificationSettingsGroup.mentions,
        NotificationSettingsGroup.followers,
      }),
      [
        'social.post_liked',
        'social.post_reacted',
        'social.comment_liked',
        'social.post_commented',
        'social.mentioned_in_post',
        'social.mentioned_in_comment',
        'social.followed',
      ],
    );
    expect(k({NotificationSettingsGroup.friends}), [
      'friend.requested',
      'friend.accepted',
    ]);
    expect(k({NotificationSettingsGroup.meetups}), [
      'meetup.invited',
      'meetup.player_joined',
    ]);
  });

  group('titles', () {
    const actor = {'actor_display_name': 'Sara'};
    test('mentions are localized (the server kinds, not social.mentioned)', () {
      for (final k in [
        'social.mentioned_in_post',
        'social.mentioned_in_comment',
      ]) {
        expect(
          NotificationKinds.title(en, _n(k, payload: actor)),
          'Sara mentioned you',
        );
        expect(
          NotificationKinds.title(ar, _n(k, payload: actor)),
          ar.notif_kind_social_mentioned('Sara'),
        );
        expect(NotificationKinds.title(en, _n(k)), 'You were mentioned');
      }
    });

    test('an old game.updated row reads as game.cancelled, EN and AR', () {
      final named = _n(
        'game.updated',
        payload: {'title': 'Friday 5-a-side', 'title_ar': 'خماسي الجمعة'},
      );
      expect(
        NotificationKinds.title(en, named),
        'Friday 5-a-side was cancelled',
      );
      expect(NotificationKinds.title(ar, named), 'تم إلغاء خماسي الجمعة');
      expect(
        NotificationKinds.title(
          en,
          _n('game.updated', payload: {'game_title': 'Padel'}),
        ),
        en.notif_t_game_cancelled('Padel'),
      );
      // No game named: the cancellation line, never "Game details updated".
      expect(
        NotificationKinds.title(en, _n('game.updated')),
        'The organiser cancelled this game.',
      );
      expect(
        NotificationKinds.title(ar, _n('game.updated')),
        ar.notif_b_game_cancelled,
      );
      expect(
        NotificationKinds.title(ar, _n('game.updated')),
        'ألغى المنظّم هذه المباراة.',
      );
    });

    test('live kinds keep their lines or the server title', () {
      expect(
        NotificationKinds.title(en, _n('social.post_liked', payload: actor)),
        'Sara liked your post',
      );
      expect(
        NotificationKinds.title(ar, _n('game.reminder')),
        ar.notif_kind_game_reminder,
      );
      expect(
        NotificationKinds.title(en, _n('game.player_joined')),
        'Server title',
      );
      expect(
        NotificationKinds.title(en, _n('achievement.first_win')),
        en.notif_kind_achievement_earned,
      );
      expect(NotificationKinds.title(en, _n('no.such_kind')), 'Server title');
    });

    test('a new kind uses its template from the row args; a missing argument '
        'keeps the server title; a _ar argument wins in Arabic', () {
      final row = _n(
        'game.full',
        args: {'title': 'Friday 5-a-side', 'title_ar': 'خماسي الجمعة'},
      );
      expect(NotificationKinds.title(en, row), 'Friday 5-a-side is full');
      expect(NotificationKinds.title(ar, row), 'اكتمل العدد في خماسي الجمعة');
      expect(NotificationKinds.title(en, _n('game.full')), 'Server title');
      // KAN-987: the template reads the row's args, not the context payload.
      expect(
        NotificationKinds.title(en, _n('game.full', payload: {'title': 'X'})),
        'Server title',
      );
      // A v2 row of a live kind renders its template too.
      expect(
        NotificationKinds.title(
          ar,
          _n('social.post_liked', args: {'actor': 'Sara'}),
        ),
        ar.notif_t_social_post_liked('Sara'),
      );
      expect(
        NotificationKinds.title(
          en,
          _n(
            'game.invite_accepted',
            payload: {'actor_name': 'Omar'},
            args: {'title': 'Padel'},
          ),
        ),
        'Omar accepted your invite to Padel',
      );
      expect(
        NotificationKinds.body(en, 'game.time_changed', {
          'old': '6 PM',
          'new': '7 PM',
        }),
        'Was 6 PM, now 7 PM.',
      );
      expect(
        NotificationKinds.body(ar, 'game.time_changed', {
          'old': '6 PM',
          'new': '7 PM',
        }),
        'كان 6 PM، والآن 7 PM.',
      );
      expect(NotificationKinds.body(en, 'game.time_changed', {}), isNull);
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode}: a mention row shows the localized '
        'title, its icon and no CTA; an invite shows View and Decline', (
      tester,
    ) async {
      final l = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withFonts(
              DabblerDesignSystemTheme.withTokens(renderThemeBase()),
              locale: locale,
            ),
            home: DabblerPage(
              body: Column(
                children: [
                  NotificationRow(
                    notification: _n('social.mentioned_in_comment'),
                    onTap: () {},
                  ),
                  NotificationRow(
                    notification: _n('game.invited'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(l.notif_kind_social_mentioned_anon), findsOneWidget);
      expect(find.text(l.notif_kind_game_invited_anon), findsOneWidget);
      // KAN-988: the row is the card library's DabblerNotificationCard; an
      // invite shows its filled View and the inline Decline.
      final rows = tester
          .widgetList<DabblerNotificationCard>(
            find.byType(DabblerNotificationCard),
          )
          .toList();
      expect(rows[0].actions, isEmpty);
      expect(rows[1].actions.map((a) => a.label), [
        l.notif_action_view,
        l.notif_action_decline,
      ]);
      expect(rows[1].actions.first.primary, isTrue);
    });
  }
}
