import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/material3_extensions.dart';

/// Shows a Material 3 drawer asking for location permission with three options:
/// 1. Allow location - Request device native location permission
/// 2. Remind me later - Close and ask again next time
/// 3. No thanks - Close and never ask again
class LocationPermissionDrawer extends StatelessWidget {
  const LocationPermissionDrawer({
    super.key,
    required this.onAllowLocation,
    required this.onRemindLater,
    required this.onNoThanks,
  });

  final VoidCallback onAllowLocation;
  final VoidCallback onRemindLater;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.categorySports.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Iconsax.location_copy,
                  size: 28,
                  color: colorScheme.categorySports,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Enable Location',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Find sports venues and games near you. We\'ll show you activities happening in your area.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Allow Location Button
              FilledButton.icon(
                onPressed: onAllowLocation,
                icon: const Icon(Iconsax.gps_copy),
                label: const Text('Allow Location'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.categorySports,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Remind Me Later Button
              FilledButton.tonalIcon(
                onPressed: onRemindLater,
                icon: const Icon(Iconsax.clock_copy),
                label: const Text('Remind Me Later'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // No Thanks Button
              TextButton(
                onPressed: onNoThanks,
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('No Thanks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
