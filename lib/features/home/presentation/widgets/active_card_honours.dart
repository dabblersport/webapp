import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'active_card_look.dart';
import 'active_card_parts.dart';

/// KAN-967: the Active card types the design added (`ActivityCard.dc.html`,
/// `Home Feed.dc.html` `actCardNew`): the trending strip and its pair box,
/// the player award, the featured venue (week, month, day) and the new venue
/// rating. Copy and figures come from the row; the parts are the package's.
abstract final class ActiveHonours {
  /// The ISO 8601 week number of [d] (`Week 47`).
  static int isoWeek(DateTime d) {
    final day = DateTime.utc(d.year, d.month, d.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    return (thursday.difference(firstDay).inDays ~/ DateTime.daysPerWeek) + 1;
  }

  /// The honour's period (`a.badge`): `Week 47` or `October`.
  static String? period(AppLocalizations l, ActiveItem e, ActiveLook look) {
    final start = e.periodStart;
    if (!look.isPeriod || start == null) return null;
    return look.isMonth
        ? DateFormat.MMMM(l.localeName).format(start)
        : l.act_week(isoWeek(start));
  }

  /// The card's `e.time` for a KAN-967 look, or null to use the default
  /// rule: trending `Now`, venue of the day `Today`, an honour its period.
  static String? time(AppLocalizations l, ActiveItem e, ActiveLook look) =>
      switch (look) {
        ActiveLook.trendingSport ||
        ActiveLook.trendingHashtag => l.act_time_now,
        ActiveLook.venueDay => l.act_group_today,
        _ => period(l, e, look),
      };

  /// One decimal, as the design's `toFixed(1)`.
  static String oneDecimal(num v) => v.toStringAsFixed(1);

  static String _km(num km) => km.toStringAsFixed(km < 10 ? 1 : 0);

  /// The strip's and box's figure (`a.slimMetric`).
  static String metric(AppLocalizations l, ActiveItem e) {
    final v = e.metricValue;
    if (v == null) return '';
    final n = v.round();
    return switch (e.metricKind) {
      'games_growth_pct' => l.act_metric_games_growth(n),
      'players_growth_pct' => l.act_metric_players_growth(n),
      'posts_today' => l.act_metric_posts_today(n),
      'posts_yesterday' => l.act_metric_posts_yesterday(n),
      _ => '',
    };
  }

  /// The strip's value (`a.slimValue`): the sport's name, or the hashtag.
  static String value(AppLocalizations l, ActiveItem e) {
    if (e.eventType == 'trending_sport') {
      final tags = e.sportTagsFor(l.localeName);
      if (tags.isNotEmpty) return tags.first.label;
    }
    return e.title ?? '';
  }

  static String _statLabel(AppLocalizations l, String key) => switch (key) {
    'games' => l.act_stat_label_games,
    'hosted' => l.act_stat_label_hosted,
    'bookings' => l.act_stat_label_bookings,
    'rating' => l.act_stat_label_rating,
    _ => key,
  };

  static String _statValue(ActiveStat s) =>
      s.key == 'rating' ? oneDecimal(s.value) : s.value.round().toString();

  /// The featured venue's and the rated venue's sub line (`a.detail`).
  static String venueSub(AppLocalizations l, ActiveItem e, ActiveLook look) {
    final spaces = e.spaceCount;
    final km = e.distanceKm;
    final avg = e.venueRatingAvg;
    final count = e.ratingCount;
    return <String>[
      ?e.detail,
      if (look == ActiveLook.venueDay && km != null)
        l.act_km_from_you(_km(km))
      // The venue's average; the rater's own stars sit by the rater's name.
      else if (look == ActiveLook.venueRating && avg != null && count != null)
        l.act_rating_from(oneDecimal(avg), count)
      else if (look != ActiveLook.venueRating && spaces != null)
        l.act_venue_spaces(spaces),
    ].join(' · ');
  }

  static String? _reason(AppLocalizations l, ActiveReason r) {
    final v = r.value;
    return switch (r.kind) {
      'free_from' when r.text != null => l.act_reason_free_from(
        DateFormat.jm(l.localeName).format(DateFormat.Hm().parse(r.text!)),
      ),
      'distance_km' when v != null => l.act_reason_km(_km(v)),
      'price_aed' when v != null => l.act_reason_price(v.round().toString()),
      _ => null,
    };
  }

  static String _reasonIcon(String kind) => switch (kind) {
    'free_from' => 'clock',
    'distance_km' => 'location',
    _ => 'ticket-2',
  };

  /// The rows of a full KAN-967 card (award, feature, review), in the
  /// design's order: the kicker row, the body, the figures or reasons, and
  /// the footer of sport chips and the action (no host).
  static List<Widget> fullRows({
    required AppLocalizations l,
    required ActiveItem event,
    required ActiveLook look,
    required DabblerToneColor tone,
    required String time,
  }) {
    final badge = period(l, event, look);
    final name = event.actorName?.trim() ?? '';
    final rating = event.rating;
    return <Widget>[
      Row(
        children: <Widget>[
          Flexible(
            child: DabblerActivityKicker(
              label: look.kicker(l),
              ink: tone.ink,
              icon: look.familyIcon,
            ),
          ),
          if (badge != null) ...<Widget>[
            const DabblerGap.h(DabblerSpacing.space2),
            DabblerActivityBadge(label: badge, ink: tone.ink),
          ],
          const DabblerGap.h(DabblerSpacing.space2),
          DabblerText(
            time,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
      if (look.isAward)
        DabblerActivityAward(
          seed: name.isEmpty ? event.entityId : name,
          imageUrl: event.actorAvatarUrl,
          mark: look.mark,
          ink: tone.ink,
          headline: name,
          sub: <String>[
            ...event.sportsFor(l.localeName),
            ?event.city,
          ].join(' · '),
        ),
      if (look.isFeature) ...<Widget>[
        DabblerActivityPhoto(
          url: event.photoUrl,
          ratingText: rating == null
              ? ''
              : l.act_rating_reviews(
                  oneDecimal(rating),
                  event.ratingCount ?? 0,
                ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DabblerText(event.title ?? '', style: DabblerType.displayFeature),
            const DabblerGap.v(DabblerSpacing.space1),
            DabblerText(
              venueSub(l, event, look),
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ],
      if (look == ActiveLook.venueRating) ...<Widget>[
        DabblerActivityReview(
          seed: name.isEmpty ? event.entityId : name,
          name: name,
          imageUrl: event.actorAvatarUrl,
          line: event.ratedGameAt == null
              ? ''
              : l.act_played_here(
                  DateFormat.EEEE(l.localeName).format(event.ratedGameAt!),
                ),
          rating: rating ?? 0,
          ratingLabel: l.act_rating_label(rating == null ? '0' : _trim(rating)),
          quote: event.quote ?? '',
        ),
        DabblerActivityVenueRow(
          title: event.title ?? '',
          detail: venueSub(l, event, look),
          ink: tone.ink,
        ),
      ],
      if (event.stats.isNotEmpty)
        DabblerActivityStats(
          items: <(String, String)>[
            for (final s in event.stats) (_statValue(s), _statLabel(l, s.key)),
          ],
        ),
      if (look == ActiveLook.venueDay && event.reasons.isNotEmpty)
        Wrap(
          spacing: DabblerSpacing.space2,
          runSpacing: DabblerSpacing.space2,
          children: <Widget>[
            for (final r in event.reasons)
              if (_reason(l, r) case final String text)
                DabblerActivityReason(
                  icon: _reasonIcon(r.kind),
                  text: text,
                  ink: tone.ink,
                ),
          ],
        ),
      ActiveCardFooter(
        event: event,
        sports: event.sportTagsFor(l.localeName),
        action: look.action(l),
        ink: tone.ink,
        showHost: false,
      ),
    ];
  }

  /// `Rated 5 out of 5`: the design prints the number as given (`5`, `4.5`).
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// KAN-967: one trending item as the full-width strip, or (paired) as a box.
class ActiveTrendCard extends StatelessWidget {
  const ActiveTrendCard({super.key, required this.event, this.box = false});

  final ActiveItem event;

  /// Draw the pair's box instead of the strip.
  final bool box;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = ActiveLook.of(event, DateTime.now());
    final tone = look.tone(DabblerColors.of(context));
    final kicker = look.kicker(l);
    final value = ActiveHonours.value(l, event);
    final metric = ActiveHonours.metric(l, event);
    return box
        ? DabblerActivityTrendBox(
            tone: tone,
            icon: look.slimIcon,
            kicker: kicker,
            value: value,
            metric: metric,
          )
        : DabblerActivitySlim(
            tone: tone,
            icon: look.slimIcon,
            kicker: kicker,
            value: value,
            metric: metric,
          );
  }
}
