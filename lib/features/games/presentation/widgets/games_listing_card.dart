import 'dart:async';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/controllers/join_game_feedback.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// =============================================================================
// GAME CARD
// =============================================================================

/// A game on the design system's game card (`Listings.2026-10-08.dc.html:
/// 207-279`): verified tick, sport / format / skill tags, day and time, the
/// place line (venue · distance · duration), players, price, the "Join game"
/// button ([_JoinAction]) and, beside it, the favourite heart with its count
/// and the share action (no count).
class GamesListingCard extends ConsumerWidget {
  const GamesListingCard({super.key, required this.game, this.sportLabel});

  final NearbyGameModel game;

  /// The sport tag's words, localised; falls back to the model's name.
  final String? sportLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final game = gameWithFavourite(
      ref.watch(gameFavouriteOverridesProvider),
      this.game,
    );
    final format = game.formatName(Localizations.localeOf(context).languageCode);
    final minutes = game.durationMinutes;
    final price = gamesPrice(l);
    final at = game.scheduledAt;
    final skill = gamesSkillTierFor(game.minSkill, game.maxSkill);
    final status = gamesCardStatus(
      spotsRemaining: game.spotsRemaining ?? 0,
      startsAt: at,
      now: DateTime.now(),
    );

    return DabblerCardGame(
      title: game.title,
      verified: game.hostVerified,
      verifiedLabel: l.listing_verified_host,
      // `Listings.dc.html:220`: sport in info, skill in its tone.
      tags: [
        if (game.sportName?.isNotEmpty == true)
          DabblerListingTag(label: sportLabel ?? game.sportName!),
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
          )
        else
          // No skill range: open to every level, so every card keeps the
          // design's skill tag (`Listings.2026-10-08.dc.html:2147`).
          DabblerListingTag(
            label: l.listing_skill_all_levels,
            tone: DabblerListingTagTone.neutral,
          ),
        if (game.isMine)
          DabblerListingTag(
            label: game.isCreated ? l.listing_created : l.listing_joined,
            tone: DabblerListingTagTone.success,
          ),
      ],
      dayLabel: at == null ? null : _dayLabel(l, at, locale),
      timeLabel: at == null ? null : DateFormat.jm(locale).format(at),
      meta: [
        if (game.venueName?.isNotEmpty == true) game.venueName!,
        // Only the location path measures distance; "Any distance" has none.
        if (game.distanceMeters > 0) game.distanceLabel,
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
              note: gamesStatusNote(l, status, game.spotsRemaining!),
              tone: gamesStatusTone(status),
            )
          : null,
      price: DabblerCardEventPrice(
        price: price.label,
        note: price.note,
        free: price.free,
      ),
      action: _JoinAction(game: game),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DabblerSpacing.space3,
        children: [
          DabblerFeedAction(
            icon: 'heart',
            metrics: DabblerFeedMetrics.drawn,
            count: game.favoriteCount,
            weight: game.favouritedByMe
                ? DabblerIconWeight.bold
                : DabblerIconWeight.linear,
            color: game.favouritedByMe
                ? DabblerColors.of(context).error.base
                : null,
            semanticLabel: game.favouritedByMe
                ? l.listing_favourite_remove
                : l.listing_favourite_add,
            onTap: () => toggleGameFavourite(
              ProviderScope.containerOf(context, listen: false),
              game,
            ),
          ),
          DabblerFeedAction(
            icon: 'share',
            metrics: DabblerFeedMetrics.drawn,
            semanticLabel: l.listing_share_game,
            onTap: () => SharePlus.instance.share(
              ShareParams(
                uri: Uri.parse(RoutePaths.gameLink(game.id)),
                title: game.title,
                subject: game.title,
              ),
            ),
          ),
        ],
      ),
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
      semanticLabel: game.title,
    );
  }

  static String _dayLabel(AppLocalizations l, DateTime dt, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);
    final diff = gameDay.difference(today).inDays;
    if (diff == 0) return l.listing_today;
    if (diff == 1) return l.listing_tomorrow;
    return DateFormat.MMMd(locale).format(dt);
  }
}

// =============================================================================
// JOIN ACTION — the card's button, on the detail screen's own join flow
// =============================================================================

enum _JoinOutcome { none, waitlisted, requested }

/// The card's "Join game" button (`Listings.dc.html:258`). It runs the game
/// detail's own [GameViewController.joinGame] — the same RPC, outcomes, errors
/// and toast copy — with no confirmation step. The states the frame does not
/// draw follow the rules the detail uses: already on the game → a disabled
/// "Joined"/"Created", no spots left → a disabled "Full", and after the server
/// answers "waitlisted" / "request submitted" the button settles on the
/// matching disabled label (the detail's "On waitlist" / pending request).
class _JoinAction extends ConsumerStatefulWidget {
  const _JoinAction({required this.game});

  final NearbyGameModel game;

  @override
  ConsumerState<_JoinAction> createState() => _JoinActionState();
}

class _JoinActionState extends ConsumerState<_JoinAction> {
  bool _joining = false;
  _JoinOutcome _outcome = _JoinOutcome.none;

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    // The Action Area reports the join (feedback center); the button keeps
    // its own local loading and outcome.
    final r = await joinGameWithFeedback(
      ProviderScope.containerOf(context, listen: false),
      widget.game.id,
      AppLocalizations.of(context),
    );
    if (!mounted) return;
    setState(() {
      _joining = false;
      _outcome = switch (r) {
        Ok(value: JoinActionResult.waitlisted) => _JoinOutcome.waitlisted,
        Ok(value: JoinActionResult.requestSubmitted) => _JoinOutcome.requested,
        _ => _JoinOutcome.none,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final game = widget.game;
    if (game.isMine) {
      return DabblerCardEventListing.joinButton(
        label: game.isCreated ? l.listing_created : l.listing_joined,
        disabled: true,
      );
    }
    switch (_outcome) {
      case _JoinOutcome.waitlisted:
        return DabblerCardEventListing.joinButton(
          label: l.listing_on_waitlist,
          disabled: true,
        );
      case _JoinOutcome.requested:
        return DabblerCardEventListing.joinButton(
          label: l.listing_request_sent,
          disabled: true,
        );
      case _JoinOutcome.none:
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
}

