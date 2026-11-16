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

export 'active_card_look.dart';

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
      sub = <String>[?event.detail, ?event.city].join(' · ');
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
            const DabblerGap.v(DabblerSpacing.space4),
            _Footer(
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

/// Text in an ink the type tones do not name (a look's tone ink).
class _Inked extends StatelessWidget {
  const _Inked({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: DefaultTextStyle.of(context).style.copyWith(color: color),
    child: child,
  );
}

/// The kicker pill: on the card surface, the family glyph and the kicker in
/// the look's ink, or while live the green dot and the kicker in the success
/// ink (`ActivityCard.dc.html`, 11/13, `padding:4px 10px 4px 8px`).
class ActiveKickerPill extends StatelessWidget {
  const ActiveKickerPill({
    super.key,
    required this.look,
    required this.label,
    required this.ink,
  });

  final ActiveLook look;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DabblerSurface.sunken(
        radius: DabblerRadius.pill,
        fill: colors.surfaceCard,
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerHomeFrame.postBadgePaddingInline,
          DabblerSpacing.space1,
          DabblerSpacing.space3,
          DabblerSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (look.isLive) ...<Widget>[
              DabblerSurface.sunken(
                key: const ValueKey<String>('active-live-dot'),
                width: DabblerSpacing.space2,
                height: DabblerSpacing.space2,
                radius: DabblerRadius.pill,
                fill: colors.success.base,
              ),
              const DabblerGap.h(DabblerSpacing.space2),
            ] else ...<Widget>[
              DabblerIcon(
                look.familyIcon,
                size: DabblerSpacing.space4,
                weight: DabblerIconWeight.bold,
                color: ink,
              ),
              const SizedBox(width: DabblerHomeFrame.postMetaGap),
            ],
            Flexible(
              child: look.isLive
                  ? DabblerText(
                      label,
                      style: DabblerType.caption2,
                      tone: DabblerTextTone.success,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : _Inked(
                      color: ink,
                      child: DabblerText(
                        label,
                        style: DabblerType.caption2,
                        tone: DabblerTextTone.inherit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ],
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
                _Inked(
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

/// The host's 28 avatar (games, meetups), the sport tags and the action pill
/// in the look's ink.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.event,
    required this.sports,
    required this.action,
    required this.ink,
  });

  final ActiveItem event;
  final List<String> sports;
  final String action;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final host = event.entityKind != 'profile' && event.hasActor;
    return Row(
      children: <Widget>[
        if (host) ...<Widget>[
          DabblerAvatar(
            seed: event.actorName,
            imageUrl: event.actorAvatarUrl,
            size: DabblerAvatarSize.xs,
            ringColor: colors.surfaceCard,
          ),
          const DabblerGap.h(DabblerSpacing.space3),
        ],
        Expanded(
          child: Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: <Widget>[
              for (final s in sports)
                DabblerSurface.sunken(
                  radius: DabblerRadius.pill,
                  fill: colors.surfaceCard,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: DabblerSpacing.space3,
                    vertical: DabblerSpacing.space1,
                  ),
                  child: DabblerText(
                    s,
                    style: DabblerType.caption2,
                    tone: DabblerTextTone.secondary,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerSurface.sunken(
          key: const ValueKey<String>('active-card-action'),
          radius: DabblerRadius.pill,
          fill: ink,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space6,
            vertical: DabblerSpacing.space3,
          ),
          child: _Inked(
            color: colors.surfaceCard,
            child: DabblerText(
              action,
              style: DabblerType.small,
              tone: DabblerTextTone.inherit,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
