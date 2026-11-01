import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

/// The visitor's Upcoming list (`Profiles.dc.html` `contributorVisitor`,
/// lines 725-727): one card per game or meetup the Contributor plays in or
/// organises, date block first, then title, time and the role tag.
///
/// The rows are exactly what the read model let this viewer read: games from
/// the public game card view and the target's active roster, and meetups the
/// target hosts through the meetup list view's visibility gate. Venue and
/// capacity are not in the read model, so the meta line carries the time only.
class ContributorVisitorUpcoming extends StatelessWidget {
  const ContributorVisitorUpcoming({
    super.key,
    required this.rows,
    required this.onOpen,
  });

  final List<ContributorEntity> rows;
  final ValueChanged<ContributorEntity> onOpen;

  static ValueKey<String> rowKey(ContributorEntity e) =>
      ValueKey<String>('visitor-upcoming-${e.key}');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerSection(
        title: l10n.listing_upcoming,
        subtitle: l10n.profile_visitor_upcoming_note,
        style: DabblerSectionStyle.label,
        children: <Widget>[
          for (final ContributorEntity e in rows)
            _UpcomingRow(key: rowKey(e), entity: e, onTap: () => onOpen(e)),
        ],
      ),
    );
  }
}

/// The failed state of the Upcoming list: a games or meetups read failed, so
/// the list would be partial. It says so and offers a retry instead.
class ContributorVisitorUpcomingFailed extends StatelessWidget {
  const ContributorVisitorUpcomingFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  static const ValueKey<String> retryKey = ValueKey<String>(
    'visitor-upcoming-retry',
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerSection(
        title: l10n.listing_upcoming,
        style: DabblerSectionStyle.label,
        children: <Widget>[
          DabblerEmptyState(
            icon: 'calendar',
            text: l10n.listing_load_games_failed,
            action: DabblerButton(
              key: retryKey,
              label: l10n.feed_retry,
              tone: DabblerButtonTone.outlined,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({super.key, required this.entity, required this.onTap});

  final ContributorEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final DateTime at = entity.startAt.toLocal();
    final String tag = entity.isOrganiser && entity.takesPart
        ? l10n.profile_tag_organising_playing
        : entity.isOrganiser
        ? l10n.profile_tag_organising
        : l10n.profile_tag_playing;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DabblerSurface.card(
          radius: DabblerRadius.lg,
          padding: const EdgeInsets.all(DabblerSpacing.space4),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: DabblerSpacing.space11,
                child: Column(
                  children: <Widget>[
                    DabblerText(
                      DateFormat.E(locale).format(at),
                      style: DabblerType.tagTight,
                      tone: DabblerTextTone.tertiary,
                      weight: DabblerTextWeight.semibold,
                    ),
                    DabblerText(
                      DateFormat.d(locale).format(at),
                      style: DabblerType.figureLarge,
                    ),
                  ],
                ),
              ),
              const DabblerGap.h(DabblerSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DabblerText(
                      entity.title ?? '',
                      style: DabblerType.copy,
                      weight: DabblerTextWeight.semibold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    DabblerText(
                      DateFormat.jm(locale).format(at),
                      style: DabblerType.footnote,
                      tone: DabblerTextTone.secondary,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const DabblerGap.h(DabblerSpacing.space3),
              DabblerBadge(label: tag, comfortable: true),
            ],
          ),
        ),
      ),
    );
  }
}
