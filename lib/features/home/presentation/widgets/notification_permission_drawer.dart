import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Shows a Material 3 drawer asking for notification permission with three options:
/// 1. Enable Notifications - Request device native notification permission
/// 2. Remind me later - Close and ask again next time
/// 3. No thanks - Close and never ask again
class NotificationPermissionDrawer extends StatelessWidget {
  const NotificationPermissionDrawer({
    super.key,
    required this.onEnableNotifications,
    required this.onRemindLater,
    required this.onNoThanks,
  });

  final VoidCallback onEnableNotifications;
  final VoidCallback onRemindLater;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Content-only widget: let `showModalBottomSheet` / BottomSheetTheme
    // provide the native Material 3 surface, shape, and drag handle.
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Iconsax.notification_copy,
                      size: 28,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Stay Updated',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'Get notified about game invites, squad updates, and messages. Never miss out on the action!',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Enable Notifications Button
                  FilledButton.icon(
                    onPressed: onEnableNotifications,
                    icon: const Icon(Iconsax.notification_bing_copy),
                    label: const Text('Enable Notifications'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
      },
    );
  }
}
