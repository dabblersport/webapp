import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The existing `messaging_reason_*` line (KAN-514) for a typed reason, or null
/// for the reasons that have their own screen or notice and keep it:
/// not_in_pilot and removed (KAN-518), game_ended and game_cancelled (KAN-517)
/// and offline. Every other reason resolves to one of the eight lines; a
/// reason this build cannot name falls to the unknown line.
///
/// The key identifiers live in [MessagingL10nKeys]; this resolves them to text.
String? gameChatReasonText(AppLocalizations l10n, MessagingReason reason) =>
    switch (reason) {
      MessagingReason.notAMember => l10n.messaging_reason_not_a_member,
      MessagingReason.leftReadOnly => l10n.messaging_reason_left_read_only,
      MessagingReason.blocked => l10n.messaging_reason_blocked,
      MessagingReason.suspended => l10n.messaging_reason_suspended,
      MessagingReason.underAge => l10n.messaging_reason_under_age,
      MessagingReason.rateLimited => l10n.messaging_reason_rate_limited,
      MessagingReason.notFound => l10n.messaging_reason_not_found,
      MessagingReason.invalidRequest => l10n.messaging_reason_invalid_request,
      MessagingReason.payloadTooLarge => l10n.messaging_image_too_large,
      MessagingReason.unsupportedMediaType => l10n.messaging_image_unsupported,
      MessagingReason.unknown => l10n.messaging_reason_unknown,
      MessagingReason.notInPilot ||
      MessagingReason.removed ||
      MessagingReason.gameEnded ||
      MessagingReason.gameCancelled ||
      MessagingReason.offline => null,
    };
