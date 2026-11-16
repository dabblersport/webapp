import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'active_card_look.dart';
import 'active_card_parts.dart';
import 'active_card_stat.dart';

export 'active_card_look.dart';
export 'active_card_parts.dart';
export 'active_card_stat.dart';

/// The card's 18 padding (`ActivityCard.dc.html`, `padding:18px`, no border).
const double activeCardInset = DabblerSpacing.space6;

/// KAN-957 / KAN-964: one Active card, the design's `ActivityCard`
/// (`project/ActivityCard.dc.html`): a pastel card in its look's tone with a
/// large watermark glyph, a kicker pill (the family glyph, or the green dot
/// while live) and the time, the body (a player's welcome, a game's or
/// meetup's date tile and title, a venue's name), and a footer of the host,
/// the sport tags and the action pill.
class ActiveEventCard extends ConsumerWidget {
  const ActiveEventCard({super.key, required this.event});

  final ActiveItem event;

  /// `just now`, `12m ago`, `3h ago`, `2d ago`, then `Nov 3`.
  static String timeLabel(AppLocalizations l, DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return l.time_just_now;
    if (diff.inMinutes < 60) return l.time_minutes_ago(diff.inMinutes);
    if (diff.inHours < 24) return l.time_hours_ago(diff.inHours);
    if (diff.inDays < 7) return l.time_days_ago(diff.inDays);
    return DateFormat.MMMd(l.localeName).format(at);
  }

  String? _route() => switch (event.entityKind) {
    'game' => RoutePaths.gameDetail(event.entityId),
    'meetup' => RoutePaths.meetupDetail(event.entityId),
    'venue' => RoutePaths.venueDetail(event.entityId),
    // A player: the profile by its profile id, the form the `/u/:profileId`
    // share link resolves to (DeepLinks); UserProfileScreen loads by
    // profileId when the user id slot holds a profile id.
    'profile' => profileRoute(event.actorProfileId ?? event.entityId),
    _ => null,
  };

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
    final colors = DabblerColors.of(context);
    final now = ref.watch(homeNowProvider)();
    final look = ActiveLook.of(event, now);
    final tone = look.tone(colors);
    final route = _route();
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

    final body = switch (event.entityKind) {
      'profile' => _PlayerBody(event: event, headline: headline, sub: sub),
      'venue' => _VenueBody(headline: headline, sub: sub),
      _ => _EventBody(event: event, tone: tone, headline: headline, sub: sub),
    };

    final stat = ActiveCardStat.of(l, event, look, tone.ink);

    final card = DabblerSurface.sunken(
      radius: DabblerRadius.xl,
      fill: tone.surface,
      // The design's 120 watermark glyph (`look.mark`, 14% of the tone ink,
      // overhanging the top end corner) needs a layered surface the package
      // does not have yet; app widgets may not stack (design_system_gate).
      child: Padding(
        padding: const EdgeInsetsDirectional.all(activeCardInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(
                  child: ActiveKickerPill(
                    look: look,
                    label: look.kicker(l),
                    ink: tone.ink,
                  ),
                ),
                const DabblerGap.h(DabblerSpacing.space2),
                DabblerText(
                  timeLabel(l, event.eventAt, now),
                  style: DabblerType.caption1,
                  tone: DabblerTextTone.secondary,
                  maxLines: 1,
                ),
              ],
            ),
            const DabblerGap.v(DabblerSpacing.space4),
            body,
            if (stat != null) ...<Widget>[
              const DabblerGap.v(DabblerSpacing.space4),
              stat,
            ],
            const DabblerGap.v(DabblerSpacing.space4),
            ActiveCardFooter(
              event: event,
              sports: sports,
              action: look.action(l),
              ink: tone.ink,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      link: route != null,
      container: true,
      label: '${look.kicker(l)}: $headline',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: route == null ? null : () => context.push(route),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: DabblerSpacing.space4,
          ),
          child: DabblerPressScale.gesture(enabled: route != null, child: card),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.text, {this.style = DabblerType.title2});

  final String text;
  final DabblerTypeStyle style;

  @override
  Widget build(BuildContext context) => DabblerText(
    text,
    style: style,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

class _Sub extends StatelessWidget {
  const _Sub(this.text, {this.oneLine = false});

  final String text;
  final bool oneLine;

  @override
  Widget build(BuildContext context) => DabblerText(
    text,
    style: DabblerType.footnote,
    tone: DabblerTextTone.secondary,
    maxLines: oneLine ? 1 : 2,
    softWrap: !oneLine,
    overflow: TextOverflow.ellipsis,
  );
}

/// A new player: the 64 avatar ringed in the card surface, "Say welcome to
/// …" and what they play.
class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.event,
    required this.headline,
    required this.sub,
  });

  final ActiveItem event;
  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Row(
      children: <Widget>[
        DabblerAvatar(
          seed: event.actorName ?? event.title,
          imageUrl: event.actorAvatarUrl,
          size: DabblerAvatarSize.lg,
          ringColor: colors.surfaceCard,
        ),
        const DabblerGap.h(DabblerSpacing.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Headline(headline),
              if (sub.isNotEmpty) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space1),
                _Sub(sub),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A game or meetup: the date tile (month in the look's ink, the day in
/// display type) and the title over "place · time · by host".
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
    final colors = DabblerColors.of(context);
    final start = event.startAt;
    return Row(
      children: <Widget>[
        if (start != null) ...<Widget>[
          DabblerSurface.sunken(
            key: const ValueKey<String>('active-date-tile'),
            width: DabblerSizing.tileLg,
            height: DabblerSizing.tileLg,
            center: true,
            radius: DabblerRadius.lg,
            fill: colors.surfaceCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ActiveInked(
                  color: tone.ink,
                  child: DabblerText(
                    DateFormat.MMM(l.localeName).format(start),
                    style: DabblerType.caption2,
                    tone: DabblerTextTone.inherit,
                    maxLines: 1,
                  ),
                ),
                DabblerText(
                  DateFormat.d(l.localeName).format(start),
                  style: DabblerType.title1,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const DabblerGap.h(DabblerSpacing.space4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Headline(headline),
              if (sub.isNotEmpty) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space1),
                _Sub(sub, oneLine: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A new venue: its name in the larger display type, clear of the watermark.
class _VenueBody extends StatelessWidget {
  const _VenueBody({required this.headline, required this.sub});

  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: DabblerSpacing.space11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Headline(headline, style: DabblerType.displaySection),
        if (sub.isNotEmpty) ...<Widget>[
          const DabblerGap.v(DabblerSpacing.space1),
          _Sub(sub),
        ],
      ],
    ),
  );
}
