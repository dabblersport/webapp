// KAN-988 (W1-F2): the one notification row. Every card family of the
// design's card library (NotificationRow.dc.html) is one
// DabblerNotificationCard: the leading (avatar, avatar pair, icon tile or
// sport tile), actor and verb, time, unread dot, urgent pill, sub, excerpt,
// old -> new change, meta, "See all N people", the actions, and the ⋯ menu.
//
// Inline actions really run through [NotifActionHandler] and show pending,
// the result, failed-with-Retry and "handled on another device". An event
// that has started shows no CTA; a deleted target or withdrawn access shows
// the row without an action.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show isFollowingProvider, profileIdByUserIdProvider, myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';

import '../../data/models/notification_model.dart';
import 'notif_actions.dart';
import 'notif_list_states.dart' show NotifCenterScope;
import 'notif_visual.dart';

/// Whether the recipient already follows the follow notification's sender
/// (KAN-101): the row then shows "You follow each other", not Follow back.
final _alreadyFollowingProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, actorUserId) async {
      final myProfileId = await ref.watch(myProfileIdProvider.future);
      if (myProfileId == null) return false;
      final target = await ref.watch(
        profileIdByUserIdProvider(actorUserId).future,
      );
      if (target == null) return false;
      return ref.watch(
        isFollowingProvider((
          currentProfileId: myProfileId,
          targetProfileId: target,
        )).future,
      );
    });

enum _Phase { idle, pending, done, failed }

class NotificationRow extends ConsumerStatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  ConsumerState<NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends ConsumerState<NotificationRow> {
  bool _menu = false;
  bool _people = false;
  bool? _read;
  _Phase _phase = _Phase.idle;
  NotificationActionId? _action;
  NotifActionOutcome? _outcome;
  bool _kindMuted = false;
  bool _conversationMuted = false;

  AppNotification get n => widget.notification;
  NotifActionHandler get _handler => ref.read(notifActionHandlerProvider);

  Future<void> _run(NotificationActionId action) async {
    if (!notifActionRunsInline(action)) {
      widget.onTap();
      return;
    }
    setState(() {
      _phase = _Phase.pending;
      _action = action;
      _menu = false;
    });
    final outcome = await _handler.run(action, n);
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _phase = outcome.status == NotifActionStatus.failed
          ? _Phase.failed
          : _Phase.done;
      _read = true;
    });
  }

  Future<void> _toggleRead(bool unread) async {
    setState(() {
      _read = unread;
      _menu = false;
    });
    final ok = await _handler.setRead(n, read: unread);
    if (!ok && mounted) setState(() => _read = !unread);
  }

  Future<void> _muteKind(bool muted) async {
    setState(() {
      _kindMuted = muted;
      _menu = false;
    });
    final ok = await _handler.setKindMuted(n.kindKey, muted: muted);
    if (!ok && mounted) setState(() => _kindMuted = !muted);
  }

  Future<void> _muteConversation(String id, bool muted) async {
    setState(() {
      _conversationMuted = muted;
      _menu = false;
    });
    final ok = await _handler.setConversationMuted(id, muted: muted);
    if (!ok && mounted) setState(() => _conversationMuted = !muted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = NotifCardView.of(l, n);
    final unread = !(_read ?? n.isRead);
    final head = view.head();
    final ctas = NotificationKinds.of(n.kindKey)?.ctas ?? const [];

    // Static results: the target is gone, or the viewer already follows back.
    DabblerNotificationResult? fixed;
    if (view.targetGone) {
      fixed = DabblerNotificationResult(
        icon: 'info-circle',
        text: l.notif_res_gone,
      );
    } else if (ctas.any((c) => c.action == NotificationActionId.followBack)) {
      final actor = notifActorUserId(n);
      if (actor != null && _phase == _Phase.idle) {
        final following = ref.watch(_alreadyFollowingProvider(actor));
        if (following.valueOrNull == true) {
          fixed = DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_mutual,
          );
        }
      }
    }

    final result = _kindMuted
        ? DabblerNotificationResult(
            icon: 'notification-bing',
            text: l.notif_res_muted,
            linkLabel: l.notif_res_undo,
            onLink: () => _muteKind(false),
          )
        : _conversationMuted
        ? DabblerNotificationResult(
            icon: 'volume-slash',
            text: l.notif_res_conversation_muted,
            linkLabel: l.notif_res_undo,
            onLink: () => _muteConversation(view.conversationId!, false),
          )
        : _phase == _Phase.done || _phase == _Phase.failed
        ? _resultOf(l, view)
        : fixed;

    // An event that has started takes no answer (expired CTA).
    final expired =
        view.started &&
        ctas.any(
          (c) =>
              c.action == NotificationActionId.going ||
              c.action == NotificationActionId.notGoing ||
              c.action == NotificationActionId.cancelPlace,
        );
    // KAN-989: offline, the Center turns row actions off ("Actions are
    // unavailable").
    final showActions =
        result == null &&
        _phase == _Phase.idle &&
        !expired &&
        fixed == null &&
        NotifCenterScope.actionsEnabledOf(context);

    final spec = NotificationKinds.of(n.kindKey);
    final menu = !_menu
        ? null
        : <DabblerNotificationMenuItem>[
            DabblerNotificationMenuItem(
              icon: unread ? 'tick-circle' : 'notification',
              label: unread ? l.notif_menu_mark_read : l.notif_menu_mark_unread,
              onPressed: () => _toggleRead(unread),
            ),
            if (spec != null && spec.canMute)
              DabblerNotificationMenuItem(
                icon: 'notification-bing',
                label: l.notif_menu_mute_kind,
                onPressed: () => _muteKind(true),
              ),
            if (spec?.category == NotificationCategory.messages &&
                view.conversationId != null)
              DabblerNotificationMenuItem(
                icon: 'volume-slash',
                label: l.notif_menu_mute_conversation,
                onPressed: () => _muteConversation(view.conversationId!, true),
              ),
          ];

    final people = view.people;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space1,
      ),
      child: DabblerNotificationCard(
        semanticLabel: '${head.actor} ${head.verb}'.trim(),
        leading: _leading(view),
        actor: head.actor,
        verb: head.verb,
        time: _formatTime(l, n.createdAt),
        unread: unread,
        onOpen: () {
          setState(() => _read = true);
          widget.onTap();
        },
        onMenu: () => setState(() => _menu = !_menu),
        menuLabel: l.notif_menu_more,
        urgent: result == null && !expired ? view.urgent : null,
        sub: view.sub,
        excerpt: view.excerpt,
        change: view.change,
        meta: view.meta(context),
        people: view.grouped && people.length > 1
            ? DabblerNotificationPeople(
                toggleLabel: _people
                    ? l.notif_people_hide
                    : l.notif_people_see_all(people.length),
                open: _people,
                onToggle: () => setState(() => _people = !_people),
                people: <DabblerNotificationPerson>[
                  for (final p in people)
                    DabblerNotificationPerson(
                      name: p.name,
                      imageUrl: p.avatarUrl,
                      time: p.at == null ? null : _formatTime(l, p.at!),
                    ),
                ],
              )
            : null,
        actions: showActions
            ? <DabblerNotificationCardAction>[
                for (final c in ctas)
                  DabblerNotificationCardAction(
                    c.label(l),
                    primary: c.filled,
                    onPressed: () => _run(c.action),
                  ),
              ]
            : const <DabblerNotificationCardAction>[],
        pending: _phase == _Phase.pending
            ? (_action == NotificationActionId.decline ||
                      _action == NotificationActionId.reject ||
                      _action == NotificationActionId.notGoing
                  ? l.notif_pending_declining
                  : l.notif_pending_sending)
            : null,
        result: result,
        menu: menu,
      ),
    );
  }

  Widget _leading(NotifCardView view) {
    final people = view.people;
    final name = view.actorName;
    if (view.grouped && people.length > 1) {
      return DabblerNotificationAvatarPair(
        seed: people[0].name,
        seed2: people[1].name,
        imageUrl: people[0].avatarUrl,
        imageUrl2: people[1].avatarUrl,
      );
    }
    if (name != null) {
      return DabblerAvatar(
        seed: name,
        imageUrl: view.actorAvatar,
        size: DabblerAvatarSize.sm,
      );
    }
    final sport = view.sportKey;
    if (sport != null) return DabblerNotificationSportTile(sportKey: sport);
    final v = view.visual;
    return DabblerNotificationIconTile(icon: v.icon, tone: v.cardTone);
  }

  DabblerNotificationResult _resultOf(AppLocalizations l, NotifCardView view) {
    final o = _outcome!;
    final name = view.actorName ?? '';
    switch (o.status) {
      case NotifActionStatus.failed:
        return DabblerNotificationResult(
          icon: 'danger',
          text: l.notif_res_failed,
          tone: DabblerNotificationTone.err,
          linkLabel: l.notif_res_retry,
          onLink: () => _run(_action!),
        );
      case NotifActionStatus.alreadyHandled:
        return DabblerNotificationResult(
          icon: 'mobile',
          text: l.notif_res_elsewhere,
          tone: DabblerNotificationTone.info,
        );
      case NotifActionStatus.unavailable:
        return DabblerNotificationResult(
          icon: 'info-circle',
          text: l.notif_res_unavailable,
        );
      case NotifActionStatus.success:
        return switch (_action!) {
          NotificationActionId.followBack => DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_following(name),
            tone: DabblerNotificationTone.ok,
          ),
          NotificationActionId.approve => DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_approved(name),
            tone: DabblerNotificationTone.ok,
          ),
          NotificationActionId.decline ||
          NotificationActionId.reject => DabblerNotificationResult(
            icon: 'close-circle',
            text: view.kind == 'game.invited'
                ? l.notif_res_invite_declined
                : l.notif_res_request_declined,
          ),
          NotificationActionId.going => DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_going,
            tone: DabblerNotificationTone.ok,
          ),
          NotificationActionId.notGoing => DabblerNotificationResult(
            icon: 'close-circle',
            text: l.notif_res_not_going,
          ),
          NotificationActionId.cancelPlace => DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_place_given_up,
          ),
          _ => DabblerNotificationResult(
            icon: 'tick-circle',
            text: l.notif_res_unavailable,
          ),
        };
    }
  }
}

/// The row's short time: `just now`, `12m`, `3h`, `2d`, then the date.
String _formatTime(AppLocalizations l10n, DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return l10n.time_just_now;
  if (diff.inHours < 1) return l10n.time_minutes_ago(diff.inMinutes);
  if (diff.inDays < 1) return l10n.time_hours_ago(diff.inHours);
  if (diff.inDays < 7) return l10n.time_days_ago(diff.inDays);
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
