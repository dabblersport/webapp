import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// The card's 12 padding inside its 1px outline (CSS border-box): the
/// surface's padding is measured from its outer edge.
const double activeCardInset =
    DabblerSpacing.space4 + DabblerSizing.borderDefault;
const double _cardInset = activeCardInset;

/// KAN-957: one Active activity card (`Home Feed.dc.html:370-432`): a type
/// row with the Live badge and the time, an actor row, a listing row with a
/// date or venue tile, and the sport tags with the city.
class ActiveEventCard extends ConsumerWidget {
  const ActiveEventCard({super.key, required this.event});

  final ActiveItem event;

  /// The card's type label for [eventType].
  static String typeLabel(AppLocalizations l, String eventType) =>
      switch (eventType) {
        'game_created' => l.act_type_game_created,
        'game_started' => l.act_type_game_started,
        'game_ended' => l.act_type_game_ended,
        'meetup_created' => l.act_type_meetup_created,
        'meetup_started' => l.act_type_meetup_started,
        'meetup_completed' => l.act_type_meetup_completed,
        'venue_added' => l.act_type_venue_added,
        _ => l.act_type_player_joined,
      };

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final now = ref.watch(homeNowProvider)();
    final route = _route();
    final sports = event.sportsFor(l.localeName);
    final type = ActiveType.ofEvent(event.eventType) ?? ActiveType.players;

    final card = DabblerSurface.card(
      radius: DabblerRadius.xl,
      fill: colors.surfaceCard,
      borderColor: colors.borderDefault,
      borderWidth: DabblerSizing.borderDefault,
      padding: const EdgeInsetsDirectional.all(_cardInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              DabblerIcon(
                type.icon,
                size: DabblerHomeFrame.searchFieldGlyph,
                weight: DabblerIconWeight.bold,
                color: colors.brandPrimary,
              ),
              const DabblerGap.h(DabblerSpacing.space2),
              // The label gives way before the badge and the time.
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: DabblerText(
                        typeLabel(l, event.eventType),
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.secondary,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.isLive) ...<Widget>[
                      const DabblerGap.h(DabblerSpacing.space2),
                      ActiveLiveBadge(label: l.act_live),
                    ],
                  ],
                ),
              ),
              const DabblerGap.h(DabblerSpacing.space2),
              DabblerText(
                timeLabel(l, event.eventAt, now),
                style: DabblerType.caption1,
                tone: DabblerTextTone.tertiary,
                maxLines: 1,
              ),
            ],
          ),
          if (event.hasActor) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space3),
            _ActorRow(event: event),
          ],
          if (event.hasListing) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space3),
            _ListingRow(event: event),
          ],
          if (sports.isNotEmpty || event.city != null) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space3),
            _Footer(sports: sports, city: event.city),
          ],
        ],
      ),
    );

    return Semantics(
      link: route != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: route == null ? null : () => context.push(route),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: DabblerSpacing.space3,
          ),
          child: DabblerPressScale.gesture(enabled: route != null, child: card),
        ),
      ),
    );
  }
}

/// The green "Live" pill (`Home Feed.dc.html:383-385`).
class ActiveLiveBadge extends StatelessWidget {
  const ActiveLiveBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerSurface.sunken(
      radius: DabblerRadius.pill,
      fill: colors.success.surface,
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space2,
        DabblerHomeFrame.postBadgePaddingBlock,
        DabblerHomeFrame.postBadgePaddingInline,
        DabblerHomeFrame.postBadgePaddingBlock,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerSurface.sunken(
            width: DabblerSpacing.space2,
            height: DabblerSpacing.space2,
            radius: DabblerRadius.pill,
            fill: colors.success.base,
          ),
          const SizedBox(width: DabblerHomeFrame.activityGap),
          DabblerText(
            label,
            style: DabblerType.caption2,
            tone: DabblerTextTone.success,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _ActorRow extends StatelessWidget {
  const _ActorRow({required this.event});

  final ActiveItem event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = event.actorName!;
    return Row(
      children: <Widget>[
        DabblerAvatar(
          seed: name,
          imageUrl: event.actorAvatarUrl,
          size: DabblerAvatarSize.sm,
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DabblerText(
                name,
                style: DabblerType.subheadline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              DabblerText(
                event.entityKind == 'profile'
                    ? l.act_actor_joined
                    : l.act_actor_host,
                style: DabblerType.caption1,
                tone: DabblerTextTone.tertiary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.event});

  final ActiveItem event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final start = event.startAt;
    final Widget? tile = event.isVenue
        ? _Tile(
            child: DabblerIcon(
              'building-4',
              size: DabblerHomeFrame.listRowGlyph,
              color: colors.brandPrimary,
            ),
          )
        : start != null
        ? _Tile(
            key: const ValueKey<String>('active-date-tile'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DabblerText(
                  DateFormat.MMM(l.localeName).format(start),
                  style: DabblerType.caption2,
                  tone: DabblerTextTone.secondary,
                  maxLines: 1,
                ),
                DabblerText(
                  DateFormat.d(l.localeName).format(start),
                  style: DabblerType.subheadline,
                  maxLines: 1,
                ),
              ],
            ),
          )
        : null;
    return DabblerSurface.sunken(
      radius: DabblerRadius.lg,
      fill: colors.surfaceSunken,
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space3),
      child: Row(
        children: <Widget>[
          if (tile != null) ...<Widget>[
            tile,
            const DabblerGap.h(DabblerSpacing.space4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DabblerText(
                  event.title!,
                  style: DabblerType.subheadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.detail != null)
                  DabblerText(
                    event.detail!,
                    style: DabblerType.caption1,
                    tone: DabblerTextTone.tertiary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 45 square date or venue tile.
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerSurface.card(
      width: DabblerSizing.tileMd,
      height: DabblerSizing.tileMd,
      center: true,
      radius: DabblerRadius.md,
      fill: colors.surfaceCard,
      borderColor: colors.borderDefault,
      borderWidth: DabblerSizing.borderDefault,
      child: child,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.sports, required this.city});

  final List<String> sports;
  final String? city;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: <Widget>[
              for (final s in sports) DabblerListingTag.outlined(label: s),
            ],
          ),
        ),
        if (city != null) ...<Widget>[
          DabblerIcon(
            'location',
            size: DabblerHomeFrame.locationGlyph,
            color: colors.textTertiary,
          ),
          const SizedBox(width: DabblerHomeFrame.locationGap),
          DabblerText(
            city!,
            style: DabblerType.caption1,
            tone: DabblerTextTone.tertiary,
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}
