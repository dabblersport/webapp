// KAN-1003: shared formatting for the security screens. Times follow the
// device 12/24h setting (I-7); device names and places are bidi-isolated.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/activities/domain/activity_log_time.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// "18 Nov 2026 · 9:12 AM" in the viewer's locale and clock setting.
String securityWhen(BuildContext context, DateTime t) {
  final l = AppLocalizations.of(context);
  return l.sec6_at(
    DateFormat.yMMMd(l.localeName).format(t.toLocal()),
    formatActivityClock(
      t,
      use24h: MediaQuery.alwaysUse24HourFormatOf(context),
      locale: l.localeName,
    ),
  );
}

/// The device, isolated; "Unknown device" when the ledger has no label.
String securityDevice(BuildContext context, SecuritySignIn s) {
  final l = AppLocalizations.of(context);
  return s.deviceLabel.isEmpty
      ? l.sec6_device_unknown
      : context.isolate(s.deviceLabel);
}

/// Device, time and approximate city of [s] as card meta lines.
List<DabblerNotificationMeta> securityMeta(
  BuildContext context,
  SecuritySignIn s,
) {
  final place = s.place;
  return <DabblerNotificationMeta>[
    DabblerNotificationMeta('mobile', securityDevice(context, s), strong: true),
    DabblerNotificationMeta('clock', securityWhen(context, s.signedInAt)),
    if (place != null)
      DabblerNotificationMeta('location', context.isolate(place)),
  ];
}

/// A toast; [err] for a refusal.
void securityToast(BuildContext context, String message, {bool err = false}) {
  DabblerToastProvider.maybeOf(context)?.show(
    DabblerToastSpec(
      message: message,
      tone: err ? DabblerToastTone.error : DabblerToastTone.success,
    ),
  );
}
