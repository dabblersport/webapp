// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
//
// KAN-990: the Activity log security card. It shows real sign-in data only
// (F-16, G.9, H.2): the fixed "All activity looks normal" banner is gone,
// because it claimed "no unusual activity" with no data behind it.
//
// Until the sign-in ledger exists (KAN-985) [activityLastSignInProvider]
// answers null and this card renders nothing, in every state (loading, error,
// no data).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/activities/domain/activity_last_sign_in.dart';

class ActivitySecurityFooter extends ConsumerWidget {
  const ActivitySecurityFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityLastSignIn? lastSignIn = ref
        .watch(activityLastSignInProvider)
        .valueOrNull;
    if (lastSignIn == null) return const SizedBox.shrink();
    // KAN-985 / KAN-1003 hook: draw "Last sign-in · time · device · city"
    // from [lastSignIn] (time via formatActivityClock, device 12/24h) and a
    // "Review sign-ins" link to the sign-in list. Until then, nothing is
    // shown even if a test overrides the provider.
    return const SizedBox.shrink();
  }
}
