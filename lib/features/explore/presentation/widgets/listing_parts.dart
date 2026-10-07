import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Non-visual helpers shared by the Games and Venues listings. Every visual
/// part of the listings is a design-system component now.

/// Maps a sport's display name (as the games and venues rows carry it) to the
/// DS sport, or null when the system has no artwork for it.
DabblerSport? listingSportFor(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final String key = name.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_]+'),
    '-',
  );
  const Map<String, DabblerSport> aliases = <String, DabblerSport>{
    'soccer': DabblerSport.football,
    'futsal': DabblerSport.football,
    'ping-pong': DabblerSport.tableTennis,
    'tabletennis': DabblerSport.tableTennis,
    'fitness': DabblerSport.gym,
    'field-hockey': DabblerSport.hockey,
    'ice-hockey': DabblerSport.hockey,
  };
  return DabblerSport.fromKey(key) ?? aliases[key];
}

/// Opens a listing's filter sheet (`Listings.dc.html:283-304`): the title
/// "Filters" with Reset in the header, [builder] holding the
/// [DabblerFilterGroup]s, and [footerBuilder] the closing action.
Future<void> showListingFilterSheet(
  BuildContext context, {
  required WidgetBuilder builder,
  required WidgetBuilder footerBuilder,
  required VoidCallback onReset,
}) {
  return showDabblerSheet<void>(
    context: context,
    // `max-height: 80%` around its content, on the page colour.
    detent: DabblerSheetDetent.content,
    pageBackground: true,
    title: AppLocalizations.of(context).listing_filters,
    // The frame's header is the title and Reset only.
    showCloseButton: false,
    headerDivider: true,
    headerActionBuilder: (BuildContext ctx) => DabblerButton(
      label: AppLocalizations.of(ctx).listing_reset,
      tone: DabblerButtonTone.neutral,
      size: DabblerButtonSize.small,
      onPressed: onReset,
    ),
    builder: builder,
    footerBuilder: footerBuilder,
  );
}

/// The geometry the three listing screens share (`Listings.dc.html`, measured
/// in `Dabbler-Alpha-Plan/listings/diff-table.md`). Every value is a DS token.
abstract final class ListingLayout {
  /// The screen gutter — `padding: 0 18px`.
  static const double gutter = DabblerSpacing.space6;

  /// Tabs (or the applied-filters rail) to the first card: the list's
  /// `padding-top: 12` (`Listings.dc.html` 2026-10-08).
  static const double listTop = DabblerSpacing.space4;

  /// Card to card on the games and meetups lists — `gap: 12`.
  static const double cardGap = DabblerSpacing.space4;

  /// Card to card on the venues list — `gap: 15`.
  static const double venueCardGap = DabblerSpacing.space5;

  /// "Upcoming" to its tiles — `gap: 9`.
  static const double upcomingGap = DabblerSpacing.space3;

  /// The listing empty state sits 60 under the chrome — `margin-top: 60px`
  /// plus the list's 3 above it.
  static const double emptyTop =
      DabblerSpacing.space11 + DabblerSpacing.space4 + DabblerSpacing.space1;

  /// The list's bottom inset above the floating bar.
  static const double listBottom = DabblerSpacing.space8;

  /// A listing's scroll padding: the gutter, [listTop] and [listBottom].
  static const EdgeInsetsDirectional listPadding =
      EdgeInsetsDirectional.fromSTEB(gutter, listTop, gutter, listBottom);
}

/// Three listing skeletons of [kind], as the frame's loading state draws them.
class ListingSkeletons extends StatelessWidget {
  const ListingSkeletons({super.key, required this.kind});

  final DabblerListingSkeletonKind kind;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: ListingLayout.listPadding,
    children: <Widget>[
      for (int i = 0; i < 3; i++) ...<Widget>[
        if (i > 0)
          DabblerGap.v(
            kind == DabblerListingSkeletonKind.venue
                ? ListingLayout.venueCardGap
                : ListingLayout.cardGap,
          ),
        DabblerListingSkeleton(kind: kind),
      ],
    ],
  );
}

/// The listing empty answer, 60 under the chrome (`Listings.dc.html:192-203`).
/// Scrollable so a pull still refreshes and a large text scale never clips.
class ListingEmpty extends StatelessWidget {
  const ListingEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.action,
  });

  final String icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      ListingLayout.gutter,
      ListingLayout.emptyTop,
      ListingLayout.gutter,
      ListingLayout.listBottom,
    ),
    children: <Widget>[
      DabblerEmptyState(
        icon: icon,
        title: title,
        text: text,
        size: DabblerEmptyStateSize.listing,
        action: action,
      ),
    ],
  );
}
