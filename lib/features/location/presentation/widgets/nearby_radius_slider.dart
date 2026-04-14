import 'package:flutter/material.dart';
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

  String _label(int meters) => '${(meters / 1000).round()} km';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search radius',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _label(_currentMeters),
                style: tt.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _currentMeters.toDouble(),
          min: _min.toDouble(),
          max: _max.toDouble(),
          divisions: (_max - _min) ~/ _step,
          activeColor: cs.primary,
          inactiveColor: cs.surfaceContainerHigh,
          onChanged: (raw) {
            final snapped = _snap(raw);
            setState(() => _currentMeters = snapped);
            // Live preview — no DB write
            ref
                .read(activeLocationProvider.notifier)
                .setRadiusOverride(snapped);
          },
          onChangeEnd: (raw) {
            final snapped = _snap(raw);
            // Persist to DB and propagate to ActiveLocation
            ref
                .read(profileLocationNotifierProvider.notifier)
                .updatePrimaryRadius(snapped);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _label(_min),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                _label(_max),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
