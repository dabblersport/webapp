import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_reason_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-557: `under_age` is a recognised reason with its own localized line.
void main() {
  test('fromWire(under_age) is underAge, a forbidden server reason', () {
    expect(MessagingReason.fromWire('under_age'), MessagingReason.underAge);
    expect(MessagingReason.underAge.isServerReason, isTrue);
    final f = MessagingFailure.fromErrorBody(403, {
      'error': {'reason': 'under_age'},
    });
    expect(f.reason, MessagingReason.underAge);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    test('dmReasonText(under_age) is the under_age line [$locale]', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final text = dmReasonText(
        l10n,
        MessagingFailure(reason: MessagingReason.underAge),
      );
      expect(text, l10n.messaging_reason_under_age);
      expect(text, isNot(l10n.messaging_reason_unknown));
    });
  }
}
