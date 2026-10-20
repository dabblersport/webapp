import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_chips.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// KAN-586: without a point (a city without an area) the Nearest sort and the
/// radius presets cannot be chosen.
class _CityOnly extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationCityOnly('Dubai');
}

final _enabled = StateProvider<bool>((ref) => false);
final _sort = StateProvider<NearbySortOrder>(
  (ref) => NearbySortOrder.defaultOrder,
);

void main() {
  setUpAll(loadRenderFonts);

  testWidgets('Nearest and distance chips are inert in a city-only state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeLocationProvider.overrideWith(_CityOnly.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: const Locale('en'),
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Wrap(
                children: [
                  ...nearbySortChips(context, ref, _sort),
                  ...nearbyDistanceChips(context, ref, _enabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final l = lookupAppLocalizations(const Locale('en'));
    DabblerChip chip(String label) => tester.widget<DabblerChip>(
      find.byWidgetPredicate((w) => w is DabblerChip && w.label == label),
    );
    expect(chip(l.listing_sort_nearest).onTap, isNull);
    expect(chip(l.listing_within_km(5)).onTap, isNull);
    expect(chip(l.listing_within_km(10)).onTap, isNull);
    // Starting soonest and Any distance stay usable: city content works.
    expect(chip(l.listing_sort_soonest).onTap, isNotNull);
    expect(chip(l.listing_any_distance).onTap, isNotNull);
  });
}
