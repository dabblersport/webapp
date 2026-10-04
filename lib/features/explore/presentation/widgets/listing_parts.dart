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
    detents: const <double>[0.8],
    title: AppLocalizations.of(context).listing_filters,
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
