import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_reason_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The line for a failed DM request (KAN-562): `dm_cap_reached` gets its own
/// `messaging_reason_dm_cap_reached`; every other typed reason resolves as the
/// game chat does ([gameChatReasonText]); a non-messaging failure is unknown.
String? dmReasonText(AppLocalizations l10n, Failure failure) {
  if (failure is DmCapReachedFailure) {
    return l10n.messaging_reason_dm_cap_reached;
  }
  if (failure is MessagingFailure) {
    return gameChatReasonText(l10n, failure.reason);
  }
  return l10n.messaging_reason_unknown;
}
