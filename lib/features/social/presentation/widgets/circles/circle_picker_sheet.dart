import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/user_circle.dart';
import 'package:dabbler/features/social/providers/user_circles_providers.dart';
import 'circle_management_sheet.dart';

export 'circle_management_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a bottom-sheet for selecting a named circle before posting.
///
/// Returns the selected [UserCircle], or null if the user dismissed without
/// selecting.  Opens [CircleManagementSheet] for create / edit.
Future<UserCircle?> showCirclePickerSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<UserCircle>(
    context: context,
    backgroundColor: cs.surfaceContainerHigh,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const CirclePickerSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CirclePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class CirclePickerSheet extends ConsumerWidget {
  const CirclePickerSheet({super.key});

  String _formatError(Object error) {
    final msg = error.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('permission denied for function is_circle_member') ||
        lower.contains('permission denied for function can_view_circle')) {
      return 'Could not load circles due to missing permissions.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final circlesAsync = ref.watch(userCirclesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          _DragHandle(cs: cs),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  'Circle',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: circlesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: _formatError(e),
                onRetry: () =>
                    ref.read(userCirclesProvider.notifier).loadCircles(),
              ),
              data: (circles) => circles.isEmpty
                  ? _EmptyState(
                      cs: cs,
                      tt: tt,
                      onCreateTap: () => _openManagement(context, ref, null),
                    )
                  : _CircleList(
                      circles: circles,
                      scrollController: scrollController,
                      onSelect: (c) => Navigator.of(context).pop(c),
                      onManage: (c) => _openManagement(context, ref, c),
                    ),
            ),
          ),

          // ── Bottom CTA (when circles exist) ──────────────────────────────
          circlesAsync.maybeWhen(
            data: (circles) => circles.isNotEmpty
                ? _CreateButton(
                    cs: cs,
                    onTap: () => _openManagement(context, ref, null),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Future<void> _openManagement(
    BuildContext context,
    WidgetRef ref,
    UserCircle? circle,
  ) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CircleManagementSheet(circle: circle),
    );
    // Refresh circles list after management sheet closes.
    if (context.mounted) {
      ref.read(userCirclesProvider.notifier).loadCircles();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.cs,
    required this.tt,
    required this.onCreateTap,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No circles yet',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Circles let you share posts with specific groups of followers.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create your first circle'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(220, 48),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleList extends StatelessWidget {
  const _CircleList({
    required this.circles,
    required this.scrollController,
    required this.onSelect,
    required this.onManage,
  });

  final List<UserCircle> circles;
  final ScrollController scrollController;
  final ValueChanged<UserCircle> onSelect;
  final ValueChanged<UserCircle> onManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: circles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final circle = circles[i];
        return _CircleListTile(
          circle: circle,
          cs: cs,
          tt: tt,
          onSelect: () => onSelect(circle),
          onManage: () => onManage(circle),
        );
      },
    );
  }
}

class _CircleListTile extends StatelessWidget {
  const _CircleListTile({
    required this.circle,
    required this.cs,
    required this.tt,
    required this.onSelect,
    required this.onManage,
  });

  final UserCircle circle;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.group_outlined, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),

              // Name + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      '${circle.memberCount} '
                      '${circle.memberCount == 1 ? 'person' : 'people'}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // Three-dot menu — manages/edits the circle
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: onManage,
                tooltip: 'Manage circle',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.cs, required this.onTap});
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create circle'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 40),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
