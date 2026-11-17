// KAN-420: the visual is a DS icon name plus a DS icon-tile tone. No colour is
// carried, so every tint resolves through the active design-system theme.
//
// KAN-988 (W1-F2): [NotifCardView] reads one notification into the parts of
// the card library's row (NotificationRow.dc.html): the leading, actor and
// verb, sub, excerpt, old -> new change, meta, people and urgent pill. The
// kind's icon, tone and CTAs come from the registry; the rest is the row's
// payload (`context`) and template args. User and venue names are shown as
// entered, never translated.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class NotifVisual {
  /// Kebab-case DS icon name rendered through [DabblerIcon].
  final String icon;
  final DabblerIconTileTone tone;
  const NotifVisual(this.icon, this.tone);

  /// The card library's tone for the registry's tile tone.
  DabblerNotificationTone get cardTone => switch (tone) {
    DabblerIconTileTone.brand => DabblerNotificationTone.brand,
    DabblerIconTileTone.amber => DabblerNotificationTone.amber,
    DabblerIconTileTone.info => DabblerNotificationTone.info,
    DabblerIconTileTone.accent => DabblerNotificationTone.err,
    DabblerIconTileTone.sunken => DabblerNotificationTone.neutral,
  };
}

/// The kinds whose row is a change of time, venue or waitlist position.
enum NotifChangeKind { time, venue, details, position }

/// One person of an aggregated row.
typedef NotifPerson = ({String name, String? avatarUrl, DateTime? at});

/// A notification read into the row's parts.
class NotifCardView {
  NotifCardView._(this.n, this.l);

  final AppNotification n;
  final AppLocalizations l;

  factory NotifCardView.of(AppLocalizations l, AppNotification n) =>
      NotifCardView._(n, l);

  String get kind => NotificationKinds.canonical(n.kindKey);
  NotificationKindSpec? get spec => NotificationKinds.of(n.kindKey);

  /// Payload first, then the v2 template args.
  Object? _raw(String k) => n.payload?[k] ?? n.args[k];

  String? str(String k) {
    final lang = l.localeName.split('_').first;
    final v = _raw('${k}_$lang') ?? _raw(k);
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  int? _int(String k) {
    final v = _raw(k);
    if (v is num) return v.toInt();
    return v == null ? null : int.tryParse('$v');
  }

  DateTime? _date(String k) {
    final v = _raw(k);
    return v is String ? DateTime.tryParse(v)?.toLocal() : null;
  }

  /// The registry's icon and tone.
  NotifVisual get visual {
    final (icon, tone) = NotificationKinds.visualOf(n.kindKey);
    return NotifVisual(icon, tone);
  }

  // ── Who ───────────────────────────────────────────────────────────────

  String? get actorName =>
      NotificationKinds.actorName(n.payload) ??
      NotificationKinds.actorName(n.args);
  String? get actorAvatar => str('actor_avatar_url');

  /// The people of a grouped row, newest first: `people` ({name,
  /// avatar_url, at}) or the plain `actor_names` / `actor_display_names`.
  List<NotifPerson> get people {
    final raw = _raw('people');
    if (raw is List) {
      return <NotifPerson>[
        for (final p in raw)
          if (p is Map && '${p['name'] ?? ''}'.trim().isNotEmpty)
            (
              name: '${p['name']}'.trim(),
              avatarUrl: p['avatar_url'] as String?,
              at: p['at'] is String
                  ? DateTime.tryParse(p['at'] as String)?.toLocal()
                  : null,
            ),
      ];
    }
    for (final k in const ['actor_display_names', 'actor_names']) {
      final names = _raw(k);
      if (names is List) {
        return <NotifPerson>[
          for (final s in names)
            if ('$s'.trim().isNotEmpty)
              (name: '$s'.trim(), avatarUrl: null, at: null),
        ];
      }
    }
    return const <NotifPerson>[];
  }

  /// How many people a grouped row stands for (`total_count`).
  int get total {
    final t = _int('total_count') ?? 0;
    return t > people.length ? t : people.length;
  }

  bool get grouped => total > 1;

  // ── Head ──────────────────────────────────────────────────────────────

  /// The title, split into the actor (bold) and the verb when it starts with
  /// the actor's name (EN and AR templates both lead with `{actor}`). A
  /// grouped row reads "Ahmed and 4 others" + the verb.
  ({String actor, String verb}) head() {
    final title = NotificationKinds.title(l, n, args: _args());
    final name = actorName;
    if (name == null) return (actor: title, verb: '');
    final who = grouped ? l.notif_actor_and_others(name, total - 1) : name;
    if (title.startsWith(name)) {
      return (actor: who, verb: title.substring(name.length).trim());
    }
    // A template that does not lead with the actor (Arabic verb-first
    // sentences): the whole line is the head, the group phrase in place.
    return (actor: title.replaceFirst(name, who), verb: '');
  }

  Map<String, dynamic> _args() => <String, dynamic>{...n.args, ...?n.payload};

  /// The 2-line sub: the kind's body (template, else the row's), unless the
  /// row shows a change (the body would repeat it).
  String? get sub {
    if (change != null) return null;
    final t = NotificationKinds.body(l, n.kindKey, _args());
    final b = t ?? n.body;
    return (b == null || b.trim().isEmpty) ? null : b.trim();
  }

  // ── Parts ─────────────────────────────────────────────────────────────

  NotifChangeKind? get changeKind {
    if (kind.endsWith('.time_changed')) return NotifChangeKind.time;
    if (kind.endsWith('.venue_changed')) return NotifChangeKind.venue;
    if (kind.endsWith('.details_changed')) return NotifChangeKind.details;
    if (kind == 'game.waitlist_position_changed') {
      return NotifChangeKind.position;
    }
    return null;
  }

  /// The old -> new diff (`old`, `new`; `field` labels a details change).
  DabblerNotificationChange? get change {
    final k = changeKind;
    if (k == null) return null;
    final from = k == NotifChangeKind.position
        ? str('old_position')
        : str('old');
    final to = k == NotifChangeKind.position ? str('position') : str('new');
    if (from == null || to == null) return null;
    final label = switch (k) {
      NotifChangeKind.time => l.notif_change_time,
      NotifChangeKind.venue => l.notif_change_venue,
      NotifChangeKind.position => l.notif_change_position,
      NotifChangeKind.details => str('field') ?? l.notif_change_time,
    };
    return DabblerNotificationChange(label: label, from: from, to: to);
  }

  /// The quoted content: a post or comment excerpt with its thumbnail.
  DabblerNotificationExcerpt? get excerpt {
    final text =
        str('excerpt') ?? str('post_excerpt') ?? str('comment_excerpt');
    if (text == null) return null;
    final ofComment =
        kind == 'social.comment_liked' ||
        kind.startsWith('social.mentioned_in_comment');
    return DabblerNotificationExcerpt(
      label: ofComment ? l.notif_ex_your_comment : l.notif_ex_your_post,
      text: text,
      thumbnailUrl: str('thumbnail_url'),
    );
  }

  /// The meta line: when, where, the roster and mutual followers.
  List<DabblerNotificationMeta> meta(BuildContext context) {
    final at = _date('start_at') ?? _date('starts_at');
    final venue = str('venue_name') ?? str('venue');
    final count = _int('players_count');
    final cap = _int('capacity');
    final mutual = _int('mutual_count');
    return <DabblerNotificationMeta>[
      if (at != null) DabblerNotificationMeta('calendar', clock(context, at)),
      if (venue != null) DabblerNotificationMeta('location', venue),
      if (count != null && cap != null)
        DabblerNotificationMeta('people', l.notif_meta_players(count, cap)),
      if (mutual != null && mutual > 0)
        DabblerNotificationMeta('profile-2user', l.notif_meta_mutual(mutual)),
    ];
  }

  /// A clock time in the device's 12/24-hour setting, with the weekday.
  String clock(BuildContext context, DateTime at) {
    final h24 = MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;
    return (h24
            ? DateFormat('EEE HH:mm', l.localeName)
            : DateFormat('EEE jm', l.localeName))
        .format(at);
  }

  /// The event the row is about has started (a reminder, a confirm-attendance
  /// or a waitlist card): its CTAs are gone.
  bool get started {
    final at = _date('start_at') ?? _date('starts_at');
    return at != null && !DateTime.now().isBefore(at);
  }

  /// The target was deleted or the viewer's access withdrawn
  /// (`target_state`: `deleted`, `no_access`, `cancelled`).
  bool get targetGone {
    final s = str('target_state');
    return s == 'deleted' || s == 'no_access' || s == 'cancelled';
  }

  /// The urgent pill: a kind that needs an answer and breaks quiet hours.
  String? get urgent {
    final s = spec;
    if (s == null || !s.needsAction || !s.breaksQuiet) return null;
    return l.notif_urgent_action;
  }

  /// A reminder row draws the sport's tile when the row names the sport.
  String? get sportKey {
    if (!kind.endsWith('.reminder')) return null;
    return str('sport_key');
  }

  /// The message conversation a message row is about.
  String? get conversationId => str('conversation_id');
}
