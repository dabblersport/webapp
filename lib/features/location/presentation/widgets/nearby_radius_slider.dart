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

  /// Persist to DB and propagate to ActiveLocation. DabblerSlider has no
  /// `onChangeEnd`, so the end of a drag is read from the pointer lifting
  /// (non-visual [Listener]); the persisted value is the last snapped one.
  void _persist() {
    ref
        .read(profileLocationNotifierProvider.notifier)
        .updatePrimaryRadius(_currentMeters);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final caption = DabblerType.caption1
        .resolveForDirection(direction)
        .copyWith(color: colors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerUp: (_) => _persist(),
          onPointerCancel: (_) => _persist(),
          child: DabblerSlider(
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
          ),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label(_min), style: caption),
            Text(_label(_max), style: caption),
          ],
        ),
      ],
    );
  }
}
