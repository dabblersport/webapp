import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
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
  return showAppSheet<void>(
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

/// KAN-588: what Venues, Games and Meetups show while no city is selected:
/// "Choose city" and a "Select city" button that opens the city picker (no GPS,
/// no area needed).
class ListingChooseCity extends StatelessWidget {
  const ListingChooseCity({super.key, this.icon = 'location'});

  final String icon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ListingEmpty(
      icon: icon,
      title: l.listing_choose_city_title,
      action: DabblerButton(
        label: l.listing_select_city,
        onPressed: () => showCityRequiredSheet(context),
      ),
    );
  }
}

/// The listing empty answer, 60 under the chrome (`Listings.dc.html:192-203`).
/// Scrollable so a pull still refreshes and a large text scale never clips.
/// With [onRefresh] the pull gesture and loader are the feed's own
/// ([DabblerRefresh]); without it the answer just scrolls.
class ListingEmpty extends StatelessWidget {
  const ListingEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.action,
    this.onRefresh,
  });

  final String icon;
  final String title;
  final String? text;
  final Widget? action;

  /// Pull-to-refresh for the empty list (KAN-598); null leaves it unrefreshable.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final Future<void> Function()? refresh = onRefresh;
    final Widget list = ListView(
      // An empty or short list must still overscroll for the pull to arm.
      physics: refresh == null ? null : const AlwaysScrollableScrollPhysics(),
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
    return refresh == null
        ? list
        : DabblerRefresh(onRefresh: refresh, child: list);
  }
}

/// The listing's load-failed answer, centred in the page like before, but
/// scrollable so a pull refreshes it with the feed's loader (KAN-598). The
/// retry button stays as the explicit way out.
class ListingError extends StatelessWidget {
  const ListingError({
    super.key,
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.onRefresh,
  });

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;

  /// Pull-to-refresh for the error answer; null leaves it unrefreshable.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final Future<void> Function()? refresh = onRefresh;
    final Widget answer = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ListingLayout.gutter,
      ),
      child: Center(
        child: DabblerEmptyState.error(
          title: title,
          size: DabblerEmptyStateSize.inline,
          onRetry: onRetry,
          retryLabel: retryLabel,
        ),
      ),
    );
    if (refresh == null) return answer;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => DabblerRefresh(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: box.hasBoundedHeight ? box.maxHeight : null,
              child: answer,
            ),
          ],
        ),
      ),
    );
  }
}
