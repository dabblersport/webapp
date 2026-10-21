import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart'
    show JoinActionResult;
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart'
    show GamesSkillFilter, gamesSkillTierFor, gamesSkillTierLabel;
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/rsvp_state.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_listing_card.dart'
    show meetupIsPopular;
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/join_gate.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// The sport page's listing cards. They draw the same design-system cards the
// Games and Meetups listings draw, from the record's own fields, but their
// Join runs through [confirmSportProfileForJoin] first: a persona with no
// profile for this sport is asked before anything is created or joined.

/// A game on the sport page. Price, spots and format appear only when the
/// record supplies them.
class SportGameCard extends ConsumerStatefulWidget {
  const SportGameCard({
    super.key,
    required this.game,
    required this.sport,
    this.onJoined,
    this.now,
  });

  final NearbyGameModel game;
  final SportInfo sport;

  /// Called after the server joined, waitlisted or requested, so the list
  /// can reload.
  final VoidCallback? onJoined;
  final DateTime? now;

  @override
  ConsumerState<SportGameCard> createState() => _SportGameCardState();
}

enum _GameOutcome { none, waitlisted, requested }

class _SportGameCardState extends ConsumerState<SportGameCard> {
  bool _joining = false;
  _GameOutcome _outcome = _GameOutcome.none;

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final AppLocalizations l = AppLocalizations.of(context);
    final bool go = await confirmSportProfileForJoin(
      context: context,
      ref: ref,
      sport: widget.sport,
    );
    if (!go) {
      if (mounted) setState(() => _joining = false);
      return;
    }
    final Result<JoinActionResult, Failure> r = await ref.read(
      sportGameJoinerProvider,
    )(container, widget.game.id, l);
    if (!mounted) return;
    setState(() {
      _joining = false;
      _outcome = switch (r) {
        Ok(value: JoinActionResult.waitlisted) => _GameOutcome.waitlisted,
        Ok(value: JoinActionResult.requestSubmitted) => _GameOutcome.requested,
        _ => _GameOutcome.none,
      };
    });
    if (r is Ok<JoinActionResult, Failure>) widget.onJoined?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final NearbyGameModel game = widget.game;
    final String? format = game.formatName(
      Localizations.localeOf(context).languageCode,
    );
    final int? minutes = game.durationMinutes;
    final price = gamesPrice(l, game.priceAed);
    final DateTime? at = game.scheduledAt;
    final GamesSkillFilter? skill = gamesSkillTierFor(
      game.minSkill,
      game.maxSkill,
    );
    final GamesCardStatus status = gamesCardStatus(
      spotsRemaining: game.spotsRemaining ?? 0,
      startsAt: at,
      now: widget.now ?? DateTime.now(),
    );

    return DabblerCardGame(
      title: game.title,
      verified: game.hostVerified,
      verifiedLabel: l.listing_verified_host,
      tags: <Widget>[
        DabblerListingTag(
          label: widget.sport.name(
            Localizations.localeOf(context).languageCode,
          ),
        ),
        if (format != null)
          DabblerListingTag(
            label: format,
            tone: DabblerListingTagTone.brandTint,
          ),
        if (skill != null)
          DabblerListingTag(
            label: gamesSkillTierLabel(l, skill),
            tone: switch (skill) {
              GamesSkillFilter.beginner => DabblerListingTagTone.success,
              GamesSkillFilter.intermediate => DabblerListingTagTone.warning,
              _ => DabblerListingTagTone.error,
            },
          ),
        if (game.isMine)
          DabblerListingTag(
            label: game.isCreated ? l.listing_created : l.listing_joined,
            tone: DabblerListingTagTone.success,
          ),
      ],
      dayLabel: at == null ? null : _dayLabel(l, at, widget.now, locale),
      timeLabel: at == null ? null : DateFormat.jm(locale).format(at),
      meta: <String>[
        if (game.venueName?.isNotEmpty == true) game.venueName!,
        if (minutes != null) l.listing_duration_min(minutes),
      ],
      progress: game.spotsRemaining != null && game.playerCount != null
          ? DabblerCardEventPlayers(
              label: l.listing_players_in(
                game.playerCount!,
                game.playerCount! + game.spotsRemaining!,
              ),
              joined: game.playerCount!,
              capacity: game.playerCount! + game.spotsRemaining!,
              note: gamesCardNote(l, status, game.spotsRemaining!, 0),
              tone: gamesStatusTone(status),
            )
          : null,
      price: game.priceAed == null
          ? null
          : DabblerCardEventPrice(
              price: price.label,
              note: price.note,
              free: price.free,
            ),
      action: _action(l, game, status),
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
      semanticLabel: game.title,
    );
  }

  Widget _action(AppLocalizations l, NearbyGameModel game, GamesCardStatus s) {
    if (game.isMine) {
      return DabblerCardEventListing.joinButton(
        label: game.isCreated ? l.listing_created : l.listing_joined,
        disabled: true,
      );
    }
    switch (_outcome) {
      case _GameOutcome.waitlisted:
        return DabblerCardEventListing.joinButton(
          label: l.listing_on_waitlist,
          disabled: true,
        );
      case _GameOutcome.requested:
        return DabblerCardEventListing.joinButton(
          label: l.listing_request_sent,
          disabled: true,
        );
      case _GameOutcome.none:
        break;
    }
    if (game.spotsRemaining == 0) {
      return DabblerCardEventListing.joinButton(
        label: l.listing_full,
        disabled: true,
      );
    }
    return DabblerCardEventListing.joinButton(
      label: l.listing_join_game,
      loading: _joining,
      onPressed: _join,
    );
  }

  static String _dayLabel(
    AppLocalizations l,
    DateTime at,
    DateTime? clock,
    String locale,
  ) {
    final DateTime now = clock ?? DateTime.now();
    final int diff = DateTime(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return l.listing_today;
    if (diff == 1) return l.listing_tomorrow;
    return DateFormat.MMMd(locale).format(at);
  }
}

/// A meetup on the sport page. Its RSVP goes through the same profile
/// confirmation as a game's Join.
class SportMeetupCard extends ConsumerStatefulWidget {
  const SportMeetupCard({
    super.key,
    required this.meetup,
    required this.sport,
    this.onChanged,
    this.now,
  });

  final MeetupListItem meetup;
  final SportInfo sport;
  final VoidCallback? onChanged;
  final DateTime? now;

  @override
  ConsumerState<SportMeetupCard> createState() => _SportMeetupCardState();
}

class _SportMeetupCardState extends ConsumerState<SportMeetupCard> {
  bool _busy = false;

  Future<void> _run(RsvpAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final AppLocalizations l = AppLocalizations.of(context);
    final bool go = await confirmSportProfileForJoin(
      context: context,
      ref: ref,
      sport: widget.sport,
    );
    if (!go) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final Result<RsvpStatus, Failure> r = await ref.read(
      sportMeetupRsvpProvider,
    )(container, widget.meetup.id, action, l);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is Ok<RsvpStatus, Failure>) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final MeetupListItem m = widget.meetup;
    final DateTime now = widget.now ?? DateTime.now();
    final DabblerRsvpCtaState state = rsvpStateFromListItem(m, now);
    final RsvpAction? action = rsvpActionFor(state);
    final String? place = m.venueName ?? m.locationName ?? m.areaName;
    final GamesSkillFilter? skill = gamesSkillTierFor(m.minSkill, m.maxSkill);
    return DabblerCardGame(
      title: m.title,
      tags: <Widget>[
        DabblerListingTag(
          label: widget.sport.name(
            Localizations.localeOf(context).languageCode,
          ),
        ),
        if (meetupIsPopular(goingCount: m.goingCount, capacity: m.capacity))
          DabblerListingTag(
            label: l.listing_popular,
            tone: DabblerListingTagTone.warning,
          ),
        if (skill != null)
          DabblerListingTag(
            label: gamesSkillTierLabel(l, skill),
            tone: switch (skill) {
              GamesSkillFilter.beginner => DabblerListingTagTone.success,
              GamesSkillFilter.intermediate => DabblerListingTagTone.warning,
              _ => DabblerListingTagTone.error,
            },
          ),
      ],
      dayLabel: meetupDayLabel(l, m.startAt, now, locale),
      timeLabel: DateFormat.jm(locale).format(m.startAt),
      meta: <String>[?place],
      progress: DabblerMeetupAttendees(
        maxAvatars: 3,
        people: <String>[
          for (final a in m.attendeeAvatars) a.displayName ?? a.avatarUrl ?? '',
        ],
        imageUrls: <String?>[for (final a in m.attendeeAvatars) a.avatarUrl],
        goingLabel: l.meetups_going_count(m.goingCount),
        capacityLabel: m.capacity == null
            ? null
            : (m.isFull ? l.listing_full : l.meetups_max(m.capacity!)),
        full: m.isFull,
      ),
      action: DabblerRsvpCta(
        state: state,
        label: rsvpLabel(l, state),
        size: DabblerRsvpCtaSize.card,
        loading: _busy,
        onPressed: action == null
            ? () => context.push(RoutePaths.meetupDetail(m.id))
            : () => _run(action),
      ),
      onTap: () => context.push(RoutePaths.meetupDetail(m.id)),
      semanticLabel: m.title,
    );
  }
}

/// A venue that offers the sport: name, area and a rating only when it has one.
class SportVenueCard extends StatelessWidget {
  const SportVenueCard({super.key, required this.venue});

  final SportVenue venue;

  @override
  Widget build(BuildContext context) {
    final String lang = Localizations.localeOf(context).languageCode;
    final DabblerColors colors = DabblerColors.of(context);
    final double? rating = venue.rating;
    return DabblerCard(
      variant: DabblerCardVariant.white,
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      semanticLabel: venue.name(lang),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DabblerText(
                  venue.name(lang),
                  style: DabblerType.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (venue.areaName?.isNotEmpty == true) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space1),
                  DabblerText(
                    venue.areaName!,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (rating != null) ...<Widget>[
            const DabblerGap.h(DabblerSpacing.space3),
            DabblerIcon(
              'star',
              size: DabblerSizing.iconSm,
              color: colors.warning.base,
            ),
            const DabblerGap.h(DabblerSpacing.space1),
            DabblerText(
              rating.toStringAsFixed(1),
              style: DabblerType.subheadline,
            ),
          ],
        ],
      ),
    );
  }
}

/// A space (court, pitch) of the sport: name, its venue, and only the price,
/// capacity and setting the record lists.
class SportSpaceCard extends StatelessWidget {
  const SportSpaceCard({super.key, required this.space});

  final SportSpace space;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String title = space.name(lang) ?? space.venueName(lang) ?? '';
    final String? venue = space.name(lang) == null
        ? null
        : space.venueName(lang);
    final double? price = space.pricePerHour;
    final List<String> facts = <String>[
      if (space.capacity != null && space.capacity! > 0)
        l.sport_overview_space_capacity(space.capacity!),
      if (space.indoor != null)
        space.indoor! ? l.listing_indoor : l.listing_outdoor,
    ];
    return DabblerCard(
      variant: DabblerCardVariant.white,
      onTap: () => context.push(RoutePaths.venueDetail(space.venueId)),
      semanticLabel: title,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DabblerText(
                  title,
                  style: DabblerType.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (venue != null) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space1),
                  DabblerText(
                    venue,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (facts.isNotEmpty) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space1),
                  DabblerText(
                    facts.join(' · '),
                    style: DabblerType.caption1,
                    tone: DabblerTextTone.secondary,
                  ),
                ],
              ],
            ),
          ),
          if (price != null) ...<Widget>[
            const DabblerGap.h(DabblerSpacing.space3),
            DabblerText(
              l.sport_overview_space_price(
                price == price.roundToDouble()
                    ? price.toStringAsFixed(0)
                    : price.toStringAsFixed(2),
              ),
              style: DabblerType.subheadline,
            ),
          ],
        ],
      ),
    );
  }
}
