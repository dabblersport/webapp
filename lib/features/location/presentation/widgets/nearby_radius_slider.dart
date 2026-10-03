import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

class NearbyRadiusSlider extends ConsumerStatefulWidget {
  const NearbyRadiusSlider({super.key});

  @override
  ConsumerState<NearbyRadiusSlider> createState() => _NearbyRadiusSliderState();
}

class _NearbyRadiusSliderState extends ConsumerState<NearbyRadiusSlider> {
  static const int _min = 1000;
  static const int _max = 50000;
  static const int _step = 1000;

  late int _currentMeters;

  @override
  void initState() {
    super.initState();
    _currentMeters = ref.read(nearbyRadiusProvider);
  }

  int _snap(double raw) {
    final snapped = ((raw / _step).round() * _step).clamp(_min, _max);
    return snapped;
  }

  String _label(num meters) => '${(meters / 1000).round()} km';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerSlider(
          value: _currentMeters.toDouble(),
          min: _min.toDouble(),
          max: _max.toDouble(),
          step: _step.toDouble(),
          label: 'Search radius',
          formatValue: _label,
          onChanged: (raw) {
            final snapped = _snap(raw);
            if (snapped == _currentMeters) return;
            setState(() => _currentMeters = snapped);
            // Live preview — no DB write
            ref
                .read(activeLocationProvider.notifier)
                .setRadiusOverride(snapped);
          },
          // End of a drag or a keyboard step: persist to DB and propagate
          // to ActiveLocation.
          onChangeEnd: (raw) {
            final snapped = _snap(raw);
            ref
                .read(profileLocationNotifierProvider.notifier)
                .updatePrimaryRadius(snapped);
          },
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DabblerText(
              _label(_min),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
            DabblerText(
              _label(_max),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ],
    );
  }
}
