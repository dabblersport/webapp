import 'package:flutter/material.dart';

/// A bar widget for bulk actions on friend requests
class BulkActionsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onAcceptAll;
  final VoidCallback? onDeclineAll;
  final VoidCallback? onCancel;
  final bool isLoading;

  const BulkActionsBar({
    super.key,
    required this.selectedCount,
    this.onAcceptAll,
    this.onDeclineAll,
    this.onCancel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Selection count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$selectedCount selected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Action buttons
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onAcceptAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept All'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onDeclineAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline All'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Cancel selection button
          TextButton.icon(
            onPressed: isLoading ? null : onCancel,
            icon: const Icon(Icons.clear),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
