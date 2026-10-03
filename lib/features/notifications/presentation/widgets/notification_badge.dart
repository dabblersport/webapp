import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notifications_providers.dart';

/// Compact badge showing the unread notification count.
///
/// Returns [SizedBox.shrink] when count is zero so it can be
/// safely placed inside a [Stack] without affecting layout.
///
/// Capped at "99+" to avoid overflow. Public constructor unchanged (KAN-420:
/// body is a DS error-status badge; still imported by `lib/widgets/app_top_bar.dart`).
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);

    if (count == 0) return const SizedBox.shrink();

    final label = count > 99 ? '99+' : DabblerType.toWesternDigits('$count');

    return DabblerBadge(
      label: label,
      status: DabblerColors.of(context).error,
      paddingInline: DabblerSpacing.space1,
      minWidth: 16,
    );
  }
}
