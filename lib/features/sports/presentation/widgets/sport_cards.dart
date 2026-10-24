import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart'
    show JoinActionResult;
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart'
    show gamesSkillTierFor, gamesSkillTierLabel;
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/rsvp_state.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
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

// KAN-591: the sport page's cards and rows, drawn as Sport Overview v2 draws
// them. Every Join and RSVP still runs through [confirmSportProfileForJoin]
// first: a persona with no profile for this sport is asked before anything is
// created or joined. Venues, Spaces and Places are separate things and never
// share a card.

/// The width of a rail game card (`Sport Overview v2`, "Next games").
const double kSportRailGameWidth = 236;

/// The width of a rail venue card and the height of its photo slot.
const double kSportRailVenueWidth = 180;
const double kSportRailVenuePhoto = 96;

/// The height of the photo slot on a full venue card.
const double kSportVenuePhoto = 130;

DabblerTextTone _textTone(DabblerProgressBarTone tone) => switch (tone) {
  DabblerProgressBarTone.brand => DabblerTextTone.brand,
  DabblerProgressBarTone.onBrand => DabblerTextTone.onBrand,
  DabblerProgressBarTone.success => DabblerTextTone.success,
  DabblerProgressBarTone.warning => DabblerTextTone.warning,
  DabblerProgressBarTone.error => DabblerTextTone.error,
  DabblerProgressBarTone.info => DabblerTextTone.info,
};

/// The day-of-week and day-of-month a date tile shows.
({String dow, String day}) _dateParts(DateTime at, String locale) => (
  dow: DateFormat.E(locale).format(at),
  day: DateFormat.d(locale).format(at),
);

// ---------------------------------------------------------------------------
// Join / RSVP behaviour, shared by the rail card and the row.
// ---------------------------------------------------------------------------

enum _GameOutcome { none, waitlisted, requested }

/// What a game's action button shows and does.
class _GameAction {
  const _GameAction({
    required this.label,
    required this.primary,
    this.disabled = false,
    this.loading = false,
    this.onPressed,
  });

  final String label;
  final bool primary;
  final bool disabled;
  final bool loading;
  final VoidCallback? onPressed;
}

mixin _GameJoinState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _joining = false;
  _GameOutcome _outcome = _GameOutcome.none;

  Future<void> _join(
    NearbyGameModel game,
    SportInfo sport,
    VoidCallback? onJoined,
  ) async {
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
      sport: sport,
    );
    if (!go) {
      if (mounted) setState(() => _joining = false);
      return;
    }
    final Result<JoinActionResult, Failure> r = await ref.read(
      sportGameJoinerProvider,
    )(container, game.id, l);
    if (!mounted) return;
    setState(() {
      _joining = false;
      _outcome = switch (r) {
        Ok(value: JoinActionResult.waitlisted) => _GameOutcome.waitlisted,
        Ok(value: JoinActionResult.requestSubmitted) => _GameOutcome.requested,
        _ => _GameOutcome.none,
      };
    });
    if (r is Ok<JoinActionResult, Failure>) onJoined?.call();
  }

  _GameAction _actionFor(
    AppLocalizations l,
    NearbyGameModel game,
    SportInfo sport,
    VoidCallback? onJoined,
  ) {
    if (game.isMine) {
      return _GameAction(
        label: game.isCreated ? l.listing_created : l.listing_joined,
        primary: false,
        disabled: true,
      );
    }
    switch (_outcome) {
      case _GameOutcome.waitlisted:
        return _GameAction(
          label: l.listing_on_waitlist,
          primary: false,
          disabled: true,
        );
      case _GameOutcome.requested:
        return _GameAction(
          label: l.listing_request_sent,
          primary: false,
          disabled: true,
        );
      case _GameOutcome.none:
        break;
    }
    if (game.spotsRemaining == 0) {
      return _GameAction(label: l.listing_full, primary: false, disabled: true);
    }
    return _GameAction(
      label: l.sport_overview_join,
      primary: true,
      loading: _joining,
      onPressed: () => _join(game, sport, onJoined),
    );
  }
}

Widget _smallButton(_GameAction a) => DabblerButton(
  label: a.label,
  tone: a.primary ? DabblerButtonTone.primary : DabblerButtonTone.outlined,
  size: DabblerButtonSize.small,
  disabled: a.disabled,
  loading: a.loading,
  onPressed: a.onPressed,
);

// ---------------------------------------------------------------------------
// Rail cards.
// ---------------------------------------------------------------------------

/// A game on the "Next games" rail.
class SportRailGameCard extends ConsumerStatefulWidget {
  const SportRailGameCard({
    super.key,
    required this.game,
    required this.sport,
    this.onJoined,
    this.now,
  });

  final NearbyGameModel game;
  final SportInfo sport;
  final VoidCallback? onJoined;
  final DateTime? now;

  @override
  ConsumerState<SportRailGameCard> createState() => _SportRailGameCardState();
}

class _SportRailGameCardState extends ConsumerState<SportRailGameCard>
    with _GameJoinState<SportRailGameCard> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final NearbyGameModel game = widget.game;
    final DateTime? at = game.scheduledAt;
    final int? spots = game.spotsRemaining;
    final int? players = game.playerCount;
    final bool hasPlayers = spots != null && players != null;
    final int capacity = hasPlayers ? players + spots : 0;
    final GamesCardStatus status = gamesCardStatus(
      spotsRemaining: spots ?? 0,
      startsAt: at,
      now: widget.now ?? DateTime.now(),
    );
    final DabblerProgressBarTone tone = gamesStatusTone(status);
    final _GameAction action = _actionFor(
      l,
      game,
      widget.sport,
      widget.onJoined,
    );
    final ({String dow, String day})? parts = at == null
        ? null
        : _dateParts(at, locale);
    final String when = <String>[
      if (at != null) DateFormat.jm(locale).format(at),
      if (game.venueName?.isNotEmpty == true) game.venueName!,
    ].join(' · ');

    return SizedBox(
      width: kSportRailGameWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(RoutePaths.gameDetail(game.id)),
        child: Semantics(
          button: true,
          label: game.title,
          child: DabblerSurface.card(
            radius: DabblerRadius.xl,
            padding: const EdgeInsets.all(DabblerSpacing.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (parts != null) ...<Widget>[
                      _DateTile(
                        dow: parts.dow,
                        day: parts.day,
                        width: DabblerSizing.tileLg,
                      ),
                      const DabblerGap.h(DabblerSpacing.space4),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          DabblerText(
                            game.title,
                            style: DabblerType.subheadline,
                            weight: DabblerTextWeight.semibold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (when.isNotEmpty) ...<Widget>[
                            const DabblerGap.v(DabblerSpacing.space1),
                            DabblerText(
                              when,
                              style: DabblerType.footnote,
                              tone: DabblerTextTone.secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasPlayers) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Expanded(
                        child: DabblerText(
                          l.listing_players_in(players, capacity),
                          style: DabblerType.caption1,
                          weight: DabblerTextWeight.semibold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const DabblerGap.h(DabblerSpacing.space3),
                      DabblerText(
                        gamesStatusNote(l, status, spots),
                        style: DabblerType.caption1,
                        weight: DabblerTextWeight.semibold,
                        tone: _textTone(tone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const DabblerGap.v(DabblerSpacing.space2),
                  DabblerProgressBar(
                    value: capacity == 0 ? 0 : players / capacity,
                    tone: tone,
                  ),
                ],
                const DabblerGap.v(DabblerSpacing.space4),
                const DabblerDivider(),
                const DabblerGap.v(DabblerSpacing.space3),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DabblerText(
                        gamesPrice(l, game.priceAed).label,
                        style: DabblerType.subheadline,
                        weight: DabblerTextWeight.bold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const DabblerGap.h(DabblerSpacing.space3),
                    _smallButton(action),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A venue on the "Top venues" rail. The data has no venue photo, so the photo
/// slot is the design's faint block (recorded on KAN-591).
class SportRailVenueCard extends StatelessWidget {
  const SportRailVenueCard({super.key, required this.venue});

  final SportVenue venue;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kSportRailVenueWidth,
    child: _VenueCardBody(venue: venue, photoHeight: kSportRailVenuePhoto),
  );
}

/// A venue in the Venues view: the same card, with the tall photo slot.
class SportVenueCard extends StatelessWidget {
  const SportVenueCard({super.key, required this.venue});

  final SportVenue venue;

  @override
  Widget build(BuildContext context) =>
      _VenueCardBody(venue: venue, photoHeight: kSportVenuePhoto);
}

class _VenueCardBody extends StatelessWidget {
  const _VenueCardBody({required this.venue, required this.photoHeight});

  final SportVenue venue;
  final double photoHeight;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final double? rating = venue.rating;
    final int? reviews = venue.ratingCount;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      child: Semantics(
        button: true,
        label: venue.name(lang),
        child: DabblerSurface.card(
          radius: DabblerRadius.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DabblerSurface.sunken(
                height: photoHeight,
                radius: DabblerRadius.xl,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space5,
                  DabblerSpacing.space4,
                  DabblerSpacing.space5,
                  DabblerSpacing.space5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DabblerText(
                      venue.name(lang),
                      style: DabblerType.smallTight,
                      weight: DabblerTextWeight.semibold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (venue.areaName?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: DabblerSpacing.space1),
                      DabblerText(
                        venue.areaName!,
                        style: DabblerType.caption1,
                        tone: DabblerTextTone.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (rating != null) ...<Widget>[
                      const SizedBox(height: DabblerSpacing.space1),
                      Row(
                        children: <Widget>[
                          DabblerIcon(
                            'star',
                            weight: DabblerIconWeight.bold,
                            size: DabblerSizing.iconInline,
                            color: colors.brandPrimary,
                          ),
                          const DabblerGap.h(DabblerSpacing.space2),
                          DabblerText(
                            rating.toStringAsFixed(1),
                            style: DabblerType.footnote,
                            weight: DabblerTextWeight.bold,
                          ),
                          if (reviews != null && reviews > 0) ...<Widget>[
                            const DabblerGap.h(DabblerSpacing.space2),
                            DabblerText(
                              '($reviews)',
                              style: DabblerType.caption1,
                              tone: DabblerTextTone.secondary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows (the sub-views).
// ---------------------------------------------------------------------------

class _DateTile extends StatelessWidget {
  const _DateTile({required this.dow, required this.day, this.width});

  final String dow;
  final String day;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerSurface(
      fill: colors.bgPrimary,
      borderColor: colors.borderDefault,
      borderWidth: 1,
      radius: DabblerRadius.md,
      width: width,
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DabblerText(
            dow,
            style: DabblerType.tagTight,
            textAlign: TextAlign.center,
          ),
          DabblerText(
            day,
            style: DabblerType.title2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The shared row of a sub-view list: a lead tile, a title, a sub line, a
/// coloured note and one small action.
class SportRow extends StatelessWidget {
  const SportRow({
    super.key,
    this.leadTop,
    this.lead,
    required this.title,
    this.sub,
    this.note,
    this.noteTone = DabblerTextTone.secondary,
    this.action,
    this.onTap,
    this.semanticLabel,
  });

  final String? leadTop;
  final String? lead;
  final String title;
  final String? sub;
  final String? note;
  final DabblerTextTone noteTone;
  final Widget? action;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final Widget body = DabblerSurface.card(
      radius: DabblerRadius.lg,
      padding: const EdgeInsets.all(DabblerSpacing.space4),
      child: Row(
        children: <Widget>[
          if (lead != null) ...<Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: DabblerSpacing.space10 + DabblerSpacing.space6,
              ),
              child: DabblerSurface(
                fill: colors.bgPrimary,
                borderColor: colors.borderDefault,
                borderWidth: 1,
                radius: DabblerRadius.md,
                padding: const EdgeInsets.symmetric(
                  horizontal: DabblerSpacing.space2,
                  vertical: DabblerSpacing.space2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (leadTop != null)
                      DabblerText(
                        leadTop!,
                        style: DabblerType.tagTight,
                        textAlign: TextAlign.center,
                      ),
                    DabblerText(
                      lead!,
                      style: DabblerType.title3,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const DabblerGap.h(DabblerSpacing.space4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DabblerText(
                  title,
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null && sub!.isNotEmpty)
                  DabblerText(
                    sub!,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (note != null && note!.isNotEmpty)
                  DabblerText(
                    note!,
                    style: DabblerType.caption1,
                    weight: DabblerTextWeight.semibold,
                    tone: noteTone,
                  ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[
            const DabblerGap.h(DabblerSpacing.space3),
            action!,
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: semanticLabel ?? title,
        child: body,
      ),
    );
  }
}

/// A game row: date, "{time} · {venue} · {format} · {skill}", the players note
/// and price, and Join.
class SportGameRow extends ConsumerStatefulWidget {
  const SportGameRow({
    super.key,
    required this.game,
    required this.sport,
    this.onJoined,
    this.now,
  });

  final NearbyGameModel game;
  final SportInfo sport;
  final VoidCallback? onJoined;
  final DateTime? now;

  @override
  ConsumerState<SportGameRow> createState() => _SportGameRowState();
}

class _SportGameRowState extends ConsumerState<SportGameRow>
    with _GameJoinState<SportGameRow> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final NearbyGameModel game = widget.game;
    final DateTime? at = game.scheduledAt;
    final int? spots = game.spotsRemaining;
    final int? players = game.playerCount;
    final GamesCardStatus status = gamesCardStatus(
      spotsRemaining: spots ?? 0,
      startsAt: at,
      now: widget.now ?? DateTime.now(),
    );
    final String? format = game.formatName(
      Localizations.localeOf(context).languageCode,
    );
    final skill = gamesSkillTierFor(game.minSkill, game.maxSkill);
    final ({String dow, String day})? parts = at == null
        ? null
        : _dateParts(at, locale);
    final String sub = <String>[
      if (at != null) DateFormat.jm(locale).format(at),
      if (game.venueName?.isNotEmpty == true) game.venueName!,
      ?format,
      if (skill != null) gamesSkillTierLabel(l, skill),
    ].join(' · ');
    final String note = <String>[
      if (spots != null && players != null)
        l.listing_players_in(players, players + spots),
      if (spots != null) gamesStatusNote(l, status, spots),
      gamesPrice(l, game.priceAed).label,
    ].join(' · ');
    return SportRow(
      leadTop: parts?.dow,
      lead: parts?.day,
      title: game.title,
      sub: sub,
      note: note,
      noteTone: spots == null
          ? DabblerTextTone.secondary
          : _textTone(gamesStatusTone(status)),
      action: _smallButton(_actionFor(l, game, widget.sport, widget.onJoined)),
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
    );
  }
}

/// A meetup row. Its RSVP goes through the same profile confirmation as a
/// game's Join.
class SportMeetupRow extends ConsumerStatefulWidget {
  const SportMeetupRow({
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
  ConsumerState<SportMeetupRow> createState() => _SportMeetupRowState();
}

class _SportMeetupRowState extends ConsumerState<SportMeetupRow> {
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
    final parts = _dateParts(m.startAt, locale);
    final String sub = <String>[
      DateFormat.jm(locale).format(m.startAt),
      ?place,
    ].join(' · ');
    final String note = <String>[
      l.meetups_going_count(m.goingCount),
      if (m.capacity != null)
        m.isFull ? l.listing_full : l.meetups_max(m.capacity!),
      meetupDayLabel(l, m.startAt, now, locale),
    ].join(' · ');
    return SportRow(
      leadTop: parts.dow,
      lead: parts.day,
      title: m.title,
      sub: sub,
      note: note,
      // The CTA is always as wide as it is given; a row hands it a width.
      action: SizedBox(
        width:
            DabblerSpacing.space11 +
            DabblerSpacing.space11 +
            DabblerSpacing.space4,
        child: DabblerRsvpCta(
          state: state,
          label: rsvpLabel(l, state),
          size: DabblerRsvpCtaSize.card,
          loading: _busy,
          onPressed: action == null
              ? () => context.push(RoutePaths.meetupDetail(m.id))
              : () => _run(action),
        ),
      ),
      onTap: () => context.push(RoutePaths.meetupDetail(m.id)),
    );
  }
}

/// A space row: "AED" over the hourly price, the venue, the setting and the
/// capacity, and Book (which opens the venue the space is in).
class SportSpaceRow extends StatelessWidget {
  const SportSpaceRow({super.key, required this.space});

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
    final String sub = <String>[
      ?venue,
      if (space.indoor != null)
        space.indoor! ? l.listing_indoor : l.listing_outdoor,
      if (space.capacity != null && space.capacity! > 0)
        l.sport_overview_space_capacity(space.capacity!),
    ].join(' · ');
    void open() => context.push(RoutePaths.venueDetail(space.venueId));
    return SportRow(
      leadTop: price == null ? null : l.sport_overview_currency,
      lead: price == null
          ? null
          : (price == price.roundToDouble()
                ? price.toStringAsFixed(0)
                : price.toStringAsFixed(2)),
      title: title,
      sub: sub,
      note: price == null ? null : l.sport_overview_per_hour,
      action: DabblerButton(
        label: l.sport_overview_book,
        tone: DabblerButtonTone.outlined,
        size: DabblerButtonSize.small,
        onPressed: open,
      ),
      onTap: open,
    );
  }
}
