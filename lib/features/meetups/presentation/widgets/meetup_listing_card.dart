import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart'
    show GamesSkillFilter, gamesSkillTierFor, gamesSkillTierLabel;
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/rsvp_state.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_feedback.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A meetup on the design system's game card, drawn from the Listings meetup
/// card (`Listings.dc.html:519-570`). The card has no price (meetups are free
/// in v1), no faces (the list row carries counts, not attendees) and no
/// like/share counts (no feature behind them).
class MeetupListingCard extends ConsumerStatefulWidget {
  const MeetupListingCard({
    super.key,
    required this.meetup,
    this.distanceMeters,
    this.onOpen,
    this.now,
  });

  final MeetupListItem meetup;
  final double? distanceMeters;
  final VoidCallback? onOpen;

  /// The clock; tests pin it.
  final DateTime? now;

  @override
  ConsumerState<MeetupListingCard> createState() => _MeetupListingCardState();
}

class _MeetupListingCardState extends ConsumerState<MeetupListingCard> {
  bool _busy = false;

  Future<void> _run(RsvpAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    // The Action Area reports a failure with Retry (feedback center); the
    // button keeps its own local busy state. Success stays silent, as before.
    await rsvpWithFeedback(
      ProviderScope.containerOf(context, listen: false),
      widget.meetup.id,
      action,
      AppLocalizations.of(context),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final m = widget.meetup;
    final now = widget.now ?? DateTime.now();
    final state = rsvpStateFromListItem(m, now);
    final action = rsvpActionFor(state);
    final place = m.venueName ?? m.locationName ?? m.areaName;
    final distance = widget.distanceMeters;
    final skill = gamesSkillTierFor(m.minSkill, m.maxSkill);
    return DabblerCardGame(
      title: m.title,
      // `Listings.dc.html:526`: activity in info, then the skill in its tone
      // (the meetup has no setting or requirement fields to tag).
      tags: <Widget>[
        if (m.sportNameEn != null)
          DabblerListingTag(
            label:
                Localizations.localeOf(context).languageCode == 'ar' &&
                    (m.sportNameAr?.trim().isNotEmpty ?? false)
                ? m.sportNameAr!
                : m.sportNameEn!,
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
      meta: <String>[
        ?place,
        if (distance != null)
          l.meetups_distance_km((distance / 1000).toStringAsFixed(1)),
      ],
      progress: DabblerMeetupAttendees(
        // The frame's card draws four faces (`Listings.dc.html:545`).
        maxAvatars: 4,
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
      price: DabblerCardEventPrice(
        price: l.listing_free,
        note: l.meetups_free_note,
        free: true,
      ),
      action: DabblerRsvpCta(
        state: state,
        label: rsvpLabel(l, state),
        size: DabblerRsvpCtaSize.card,
        loading: _busy,
        onPressed: action == null ? widget.onOpen : () => _run(action),
      ),
      onTap: widget.onOpen,
      semanticLabel: m.title,
    );
  }
}
