import 'package:dabbler/features/location/data/manual_location_catalog.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flag/flag.dart';
import 'package:flutter/widgets.dart';

/// KAN-640: the round flag of a service country, from the `flag` package's
/// asset set. [region] is the canonical English name; a name with no flag
/// (Global) shows the global icon instead.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.region, required this.size});

  final String region;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? iso = kCountryIsoCodes[region];
    if (iso == null) {
      return DabblerIcon(
        'global',
        weight: DabblerIconWeight.bold,
        size: DabblerSizing.iconSm,
        color: DabblerColors.of(context).brandPrimary,
      );
    }
    return ExcludeSemantics(
      child: Flag.fromString(
        iso,
        width: size,
        height: size,
        fit: BoxFit.cover,
        flagSize: FlagSize.size_1x1,
        borderRadius: size / 2,
      ),
    );
  }
}
