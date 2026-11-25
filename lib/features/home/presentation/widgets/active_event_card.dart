import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'active_card_honours.dart';
import 'active_card_look.dart';
import 'active_card_parts.dart';
import 'active_card_stat.dart';

export 'active_card_honours.dart';
export 'active_card_look.dart';
export 'active_card_parts.dart';
export 'active_card_stat.dart';

/// KAN-957 / KAN-964 / KAN-965: one Active card, the design's
/// `ActivityCard` (`project/ActivityCard.dc.html`) drawn with the package's
/// [DabblerActivityCard]: the look's tone with its large mark glyph, a
/// kicker pill (the family glyph, or the pulsing live dot) and the time, the
/// body (a player's welcome, a game's or meetup's date tile and title, a
/// venue's name), the stat block, and the footer of the host, the sport chips
/// and the action pill.
class ActiveEventCard extends ConsumerWidget {
  const ActiveEventCard({super.key, required this.event});

  final ActiveItem event;

  /// The design's `e.time` (`ACT_EVENTS`): under an hour `3 min ago`,
  /// otherwise the clock time (`8:30 AM`); the day is the group header's.
  /// Under a minute: `just now`.
  static String timeLabel(AppLocalizations l, DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return l.time_just_now;
    if (diff.inMinutes < 60) return l.act_time_minutes(diff.inMinutes);
    return DateFormat.jm(l.localeName).format(at);
  }

  /// The date tile's month (`a.month`): `OCT`, the short English month in
  /// capitals, in the Arabic frame too (its translation table skips `month`).
  static String monthLabel(DateTime at) =>
      DateFormat.MMM('en').format(at).toUpperCase();

  String? _route() => routeFor(event);

  /// Where a card opens: the game, meetup, venue or profile; KAN-967 the
  /// sport's overview (trending sport) or the hashtag's feed (`detail` is
  /// the hashtag's slug).
  static String? routeFor(ActiveItem event) => switch (event.entityKind) {
    'sport' => RoutePaths.sportOverviewFor(event.entityId),
    'hashtag' => '${RoutePaths.hashtagFeed}/${event.detail ?? event.entityId}',
    'game' => RoutePaths.gameDetail(event.entityId),
    'meetup' => RoutePaths.meetupDetail(event.entityId),
    'venue' => RoutePaths.venueDetail(event.entityId),
    // A player: the profile by its profile id, the form the `/u/:profileId`
    // share link resolves to (DeepLinks); UserProfileScreen loads by
    // profileId when the user id slot holds a profile id.
    'profile' => profileRoute(event.actorProfileId ?? event.entityId),
    _ => null,
  };

  /// The press-scaled, tappable card with its 12 bottom gap.
  static Widget tappable(
    BuildContext context, {
    required String? route,
    required String label,
    required Widget child,
    bool gap = true,
  }) => Semantics(
    link: route != null,
    container: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route == null ? null : () => context.push(route),
      child: Padding(
        padding: gap
            ? const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4)
            : EdgeInsetsDirectional.zero,
        child: DabblerPressScale.gesture(enabled: route != null, child: child),
      ),
    ),
  );

  /// The visited-profile route for a profile id.
  static String profileRoute(String profileId) =>
      '${RoutePaths.userProfile}/$profileId?profileId=$profileId';

  static String _first(String name) => name.trim().split(' ').first;

  /// "Football", "Football and Padel", "Cricket, Football and Padel".
  static String _list(AppLocalizations l, List<String> items) {
    if (items.length < 2) return items.join();
    return items.sublist(0, items.length - 1).join(l.act_list_comma) +
        l.act_list_and +
        items.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(homeNowProvider)();
    final look = ActiveLook.of(event, now);
    final tone = look.tone(DabblerColors.of(context));
    final route = _route();

    // KAN-967: the trending strip, and the award, feature and review cards.
    if (look.isSlim) {
      return tappable(
        context,
        route: route,
        label: '${look.kicker(l)}: ${ActiveHonours.value(l, event)}',
        child: ActiveTrendCard(event: event),
      );
    }
    if (look.isAward || look.isFeature || look == ActiveLook.venueRating) {
      final headline = look.isAward
          ? (event.actorName ?? '')
          : (event.title ?? '');
      return tappable(
        context,
        route: route,
        label: '${look.kicker(l)}: $headline',
        child: DabblerActivityCard(
          tone: tone,
          mark: look.mark,
          children: ActiveHonours.fullRows(
            l: l,
            event: event,
            look: look,
            tone: tone,
            time:
                ActiveHonours.time(l, event, look) ??
                timeLabel(l, event.eventAt, now),
          ),
        ),
      );
    }
    final sports = event.sportsFor(l.localeName);
    final name = event.actorName?.trim() ?? '';

    final String headline;
    final String sub;
    if (event.entityKind == 'profile') {
      headline = l.act_welcome(_first(name.isEmpty ? event.title ?? '' : name));
      sub = <String>[
        if (sports.isNotEmpty) l.act_plays(_list(l, sports)),
        ?event.city,
      ].join(' · ');
    } else if (event.isVenue) {
      headline = event.title ?? '';
      final spaces = event.spaceCount;
      sub = <String>[
        ?event.detail,
        if (spaces != null) l.act_venue_spaces(spaces),
        ?event.city,
      ].join(' · ');
    } else {
      headline = event.title ?? '';
      final start = event.startAt;
      sub = <String>[
        ?event.detail,
        if (start != null) DateFormat.jm(l.localeName).format(start),
        if (name.isNotEmpty) l.act_by(_first(name)),
      ].join(' · ');
    }

    final stat = ActiveCardStat.of(l, event, look, tone);

    final card = DabblerActivityCard(
      tone: tone,
      mark: look.mark,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: DabblerActivityKicker(
                label: look.kicker(l),
                ink: tone.ink,
                icon: look.familyIcon,
                live: look.isLive,
              ),
            ),
            const DabblerGap.h(DabblerSpacing.space2),
            DabblerText(
              timeLabel(l, event.eventAt, now),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
        switch (event.entityKind) {
          'profile' => _PlayerBody(event: event, headline: headline, sub: sub),
          'venue' => _VenueBody(headline: headline, sub: sub),
          _ => _EventBody(
            event: event,
            tone: tone,
            headline: headline,
            sub: sub,
          ),
        },
        ?stat,
        ActiveCardFooter(
          event: event,
          sports: event.sportTagsFor(l.localeName),
          action: look.action(l),
          ink: tone.ink,
        ),
      ],
    );

    return tappable(
      context,
      route: route,
      label: '${look.kicker(l)}: $headline',
      child: card,
    );
  }
}

/// The headline (`--font-display`, `--ink`, no clamp) over the 13/18
/// `--ink-soft` sub, `gap:3px`. The event's sub is one line with an ellipsis.
///
/// The headline is [DabblerType.title3] (20/25) for games, meetups and new
/// players by the CEO's order of 2026-11-16 (KAN-965; the design draws
/// 22/28). A venue keeps [DabblerType.displaySection] (26/32).
class _Titles extends StatelessWidget {
  const _Titles({
    required this.headline,
    required this.sub,
    this.style = DabblerType.title3,
    this.oneLineSub = false,
  });

  final String headline;
  final String sub;
  final DabblerTypeStyle style;
  final bool oneLineSub;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      DabblerText(headline, style: style),
      if (sub.isNotEmpty) ...<Widget>[
        const DabblerGap.v(DabblerSpacing.space1),
        DabblerText(
          sub,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
          maxLines: oneLineSub ? 1 : null,
          softWrap: !oneLineSub,
          overflow: oneLineSub ? TextOverflow.ellipsis : null,
        ),
      ],
    ],
  );
}

/// A new player (`gap:12px`): the 64 avatar ringed 3 in the card surface,
/// "Say welcome to …" and what they play.
class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.event,
    required this.headline,
    required this.sub,
  });

  final ActiveItem event;
  final String headline;
  final String sub;

  /// `outline:3px solid var(--surface-card)`.
  static const double ring = DabblerSpacing.space1;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Row(
      children: <Widget>[
        DabblerAvatar(
          seed: event.actorName ?? event.title,
          imageUrl: avatarImageUrl(event.actorAvatarUrl),
          size: DabblerAvatarSize.lg,
          ringColor: colors.surfaceCard,
          ringWidth: ring,
        ),
        const DabblerGap.h(DabblerSpacing.space4),
        Expanded(
          child: _Titles(headline: headline, sub: sub),
        ),
      ],
    );
  }
}

/// A game or meetup (`gap:12px`): the 56x62 date tile and the title over
/// "place · time · by host".
class _EventBody extends StatelessWidget {
  const _EventBody({
    required this.event,
    required this.tone,
    required this.headline,
    required this.sub,
  });

  final ActiveItem event;
  final DabblerToneColor tone;
  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final start = event.startAt;
    return Row(
      children: <Widget>[
        if (start != null) ...<Widget>[
          DabblerActivityDateTile(
            key: const ValueKey<String>('active-date-tile'),
            month: ActiveEventCard.monthLabel(start),
            day: DateFormat.d(l.localeName).format(start),
            ink: tone.ink,
          ),
          const DabblerGap.h(DabblerSpacing.space4),
        ],
        Expanded(
          child: _Titles(headline: headline, sub: sub, oneLineSub: true),
        ),
      ],
    );
  }
}

/// A new venue: its name at 26/32 display, `padding-inline-end:48px` clear
/// of the mark.
class _VenueBody extends StatelessWidget {
  const _VenueBody({required this.headline, required this.sub});

  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: DabblerSpacing.space11),
    child: _Titles(
      headline: headline,
      sub: sub,
      style: DabblerType.displaySection,
    ),
  );
}
