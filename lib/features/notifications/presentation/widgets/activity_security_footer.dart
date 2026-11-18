// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
//
// KAN-990: the Activity log security card. It shows real sign-in data only
// (F-16, G.9, H.2): the fixed "All activity looks normal" banner is gone,
// because it claimed "no unusual activity" with no data behind it.
//
// KAN-1003: "Last sign-in · time · device" from the KAN-985 ledger and a
// "Review sign-ins" link to the sign-in list. No data, loading or an error
// renders nothing. Security notices are always on: no switch here.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/security/presentation/security_format.dart'
    show securityWhen;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/activities/domain/activity_last_sign_in.dart';

class ActivitySecurityFooter extends ConsumerWidget {
  const ActivitySecurityFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityLastSignIn? lastSignIn = ref
        .watch(activityLastSignInProvider)
        .valueOrNull;
    if (lastSignIn == null || !FeatureFlags.securityScreens) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final device = lastSignIn.device == null
        ? l.sec6_device_unknown
        : context.isolate(lastSignIn.device);
    final city = lastSignIn.city;
    final line = l.sec6_last_sign_in(
      securityWhen(context, lastSignIn.at),
      city == null ? device : '$device · ${context.isolate(city)}',
    );
    return Padding(
      padding: DabblerInsets.screen,
      child: DabblerNotificationCard(
        key: const ValueKey<String>('activity-security-card'),
        leading: const DabblerNotificationIconTile(
          icon: 'security',
          tone: DabblerNotificationTone.brand,
        ),
        actor: l.activity_subject_security,
        sub: line,
        actions: <DabblerNotificationCardAction>[
          DabblerNotificationCardAction(
            l.sec6_review_sign_ins,
            onPressed: () => context.push(RoutePaths.securitySignIns),
          ),
        ],
      ),
    );
  }
}
