import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Returns the locale-appropriate title for a notification.
///
/// KAN-978: the kind registry ([NotificationKinds.title]) builds it; this
/// stays as the call site's entry point.
String localizedNotificationTitle(
  BuildContext context,
  AppNotification notification,
) => NotificationKinds.title(AppLocalizations.of(context), notification);
