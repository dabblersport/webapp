import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The viewer's own upcoming meetups, counting down: one is a
/// [DabblerCardUpcoming], two or more a rail of [DabblerCardUpcomingRail]
/// (`Listings.dc.html:422-482`).
class MeetupUpcoming extends StatelessWidget {
  const MeetupUpcoming({
    super.key,
    required this.meetups,
    required this.onOpen,
    this.now,
  });

  final List<MeetupListItem> meetups;
  final ValueChanged<MeetupListItem> onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final clock = now ?? DateTime.now();
    final tones = DabblerCardUpcomingTone.values;
    final tiles = <Widget>[];
    for (var i = 0; i < meetups.length; i++) {
      final m = meetups[i];
      final c = meetupCountdown(l, m.startAt, clock);
      final place = m.venueName ?? m.locationName ?? m.areaName;
      final tone = tones[(i + 2) % tones.length];
      if (meetups.length == 1) {
        final end = m.endAt;
        tiles.add(
          DabblerCardUpcoming(
            tone: tone,
            fraction: c.fraction,
            countdownValue: c.value,
            countdownUnit: c.unit,
            title: m.title,
            when:
                '${DateFormat.MMMd(locale).format(m.startAt)} · ${DateFormat.jm(locale).format(m.startAt)}'
                '${end == null ? '' : ' · ${end.difference(m.startAt).inMinutes} ${l.listing_unit_min}'}',
            place: place,
            onTap: () => onOpen(m),
          ),
        );
      } else {
        tiles.add(
          DabblerCardUpcomingRail(
            tone: tone,
            month: DateFormat.MMM(locale).format(m.startAt).toUpperCase(),
            day: '${m.startAt.day}',
            title: m.title,
            time: DateFormat.jm(locale).format(m.startAt),
            place: place,
            fraction: c.fraction,
            countdownValue: c.value,
            countdownUnit: c.unit,
            onTap: () => onOpen(m),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerText(l.listing_upcoming, style: DabblerType.displayLabel),
        const DabblerGap.v(DabblerSpacing.space3),
        if (tiles.length == 1)
          tiles.first
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: DabblerSpacing.space3, children: tiles),
          ),
      ],
    );
  }
}
