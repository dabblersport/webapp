import 'dart:math' as math;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The place rows of the "Change location" sheet: the saved locations (the
/// frame's "Recent" group) with "Add location", then the areas grouped by
/// district, all as flat [DabblerListRow]s (Listings.dc.html:343-364).
class HomeLocationPlaces extends StatelessWidget {
  const HomeLocationPlaces({
    super.key,
    required this.areas,
    required this.saved,
    required this.query,
    required this.currentState,
    required this.onSaved,
    required this.onArea,
    required this.onAdd,
    this.frame = false,
  });

  /// The Home Feed frame's rows: drawn metrics, 20 glyphs, the selected area's
  /// title in the brand ink and the group label at the regular weight.
  final bool frame;

  final Future<Map<String, List<Area>>> areas;
  final List<ProfileLocation> saved;
  final String query;
  final ActiveLocationState? currentState;
  final void Function(ProfileLocation location) onSaved;
  final void Function(Area area) onArea;
  final VoidCallback onAdd;

  static String _savedIcon(ProfileLocation location) =>
      switch (location.label) {
        ProfileLocationLabel.home => 'home-2',
        ProfileLocationLabel.work => 'briefcase',
        ProfileLocationLabel.school => 'teacher',
        ProfileLocationLabel.current => 'gps',
        ProfileLocationLabel.custom => 'location',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Map<String, List<Area>>>(
      future: areas,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space5),
            child: Center(child: DabblerSpinner()),
          );
        }
        final grouped = snapshot.data!;
        final q = query.toLowerCase();
        bool hit(Area a) =>
            q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            a.city.toLowerCase().contains(q);

        final byId = <String, Area>{
          for (final list in grouped.values)
            for (final a in list) a.id: a,
        };
        final savedRows = <ProfileLocation>[
          for (final loc in saved)
            if (q.isEmpty ||
                loc.effectiveLabel.toLowerCase().contains(q) ||
                (byId[loc.areaId]?.name.toLowerCase().contains(q) ?? false))
              loc,
        ];
        final filtered = <String, List<Area>>{
          for (final e in grouped.entries)
            if (e.value.any(hit)) e.key: e.value.where(hit).toList(),
        };

        if (savedRows.isEmpty && filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerEmptyState(
              icon: 'search-normal',
              text: l10n.home_location_no_match(query),
            ),
          );
        }

        final state = currentState;
        final ready = state is ActiveLocationReady ? state : null;
        final colors = DabblerColors.of(context);

        Widget label(String text) => Padding(
          padding: const EdgeInsetsDirectional.only(
            top: DabblerSpacing.space5,
            bottom: DabblerSpacing.space2,
          ),
          child: DabblerText(
            text,
            style: DabblerType.caption1,
            weight: frame
                ? DabblerTextWeight.regular
                : DabblerTextWeight.semibold,
            tone: DabblerTextTone.secondary,
          ),
        );

        Widget row({
          required String icon,
          required String title,
          String? subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) => DabblerListRow(
          flat: true,
          metrics: frame ? DabblerFeedMetrics.drawn : DabblerFeedMetrics.touch,
          brand: frame && selected,
          leading: DabblerIcon(
            icon,
            size: frame ? DabblerHomeFrame.listRowGlyph : DabblerSizing.iconRow,
            weight: selected
                ? DabblerIconWeight.bold
                : DabblerIconWeight.linear,
            color: selected ? colors.brandPrimary : colors.textTertiary,
          ),
          title: title,
          subtitle: subtitle,
          trailing: selected
              ? DabblerIcon(
                  'tick-circle',
                  size: frame
                      ? DabblerHomeFrame.listRowGlyph
                      : DabblerSizing.iconRow,
                  weight: DabblerIconWeight.bold,
                  color: colors.brandPrimary,
                )
              : null,
          onTap: onTap,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label(l10n.home_location_recent),
            for (final loc in savedRows)
              row(
                icon: _savedIcon(loc),
                title: loc.effectiveLabel,
                subtitle: byId[loc.areaId]?.name,
                selected: ready?.location.savedLocationId == loc.id,
                onTap: () => onSaved(loc),
              ),
            DabblerListRow(
              flat: true,
              leading: DabblerIcon(
                'location-add',
                size: DabblerSizing.iconRow,
                color: colors.textTertiary,
              ),
              title: l10n.home_location_add,
              onTap: onAdd,
            ),
            for (final entry in filtered.entries) ...[
              label(entry.key),
              for (final area in entry.value)
                row(
                  icon: 'location',
                  title: area.name,
                  subtitle: _sub(area, ready),
                  selected: ready?.location.area.id == area.id,
                  onTap: () => onArea(area),
                ),
            ],
          ],
        );
      },
    );
  }

  static String _sub(Area area, ActiveLocationReady? ready) {
    if (ready == null) return area.city;
    final d = _haversineM(
      ready.location.lat,
      ready.location.lng,
      area.centerLat,
      area.centerLng,
    );
    return '${area.city} · ${_fmt(d)}';
  }

  static double _haversineM(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _fmt(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
