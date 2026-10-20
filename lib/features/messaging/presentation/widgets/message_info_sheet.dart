import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/providers/receipts_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the Message info drawer (KAN-580) for one of the caller's own group
/// messages: who it has reached and who has seen it, from the Worker's
/// sender-only recipients route. The drawer itself is the design system's
/// [DabblerReceiptsSheet]; this only gathers its props. When the Worker cannot
/// say (old Worker, offline, not the sender) nothing opens.
Future<void> showMessageInfo({
  required BuildContext context,
  required WidgetRef ref,
  required String conversationId,
  required int seq,
  required String preview,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  final recipients = await ref.read(
    receiptRecipientsProvider((
      conversationId: conversationId,
      seq: seq,
    )).future,
  );
  if (recipients == null || !context.mounted) return;
  final nameOf = ref.read(receiptPersonNameProvider);
  final names = await Future.wait(recipients.map((r) => nameOf(r.userId)));
  if (!context.mounted) return;

  String time(RecipientReceipt r) => r.updatedAt == null
      ? ''
      : DateFormat.jm(locale.toLanguageTag()).format(r.updatedAt!.toLocal());

  DabblerReceiptGroup group(
    DabblerDeliveryState state,
    ReceiptLevel level,
    String label,
    String shortLabel,
  ) {
    final people = <DabblerReceiptPerson>[];
    for (var i = 0; i < recipients.length; i++) {
      final r = recipients[i];
      if (r.level != level) continue;
      final name = names[i].isEmpty
          ? l10n.messaging_receipts_unknown_person
          : names[i];
      people.add(
        DabblerReceiptPerson(
          name: name,
          avatarSeed: r.userId,
          time: level == ReceiptLevel.sent || time(r).isEmpty ? null : time(r),
        ),
      );
    }
    return DabblerReceiptGroup(
      state: state,
      people: people,
      label: label,
      shortLabel: shortLabel,
    );
  }

  await DabblerReceiptsSheet.show(
    context,
    title: l10n.messaging_receipts_title,
    preview: preview,
    lang: locale.languageCode == 'ar' ? 'ar' : 'en',
    groups: [
      group(
        DabblerDeliveryState.seen,
        ReceiptLevel.seen,
        l10n.messaging_receipts_seen_by,
        l10n.messaging_receipt_seen,
      ),
      group(
        DabblerDeliveryState.delivered,
        ReceiptLevel.delivered,
        l10n.messaging_receipts_delivered_to,
        l10n.messaging_receipt_delivered,
      ),
      group(
        DabblerDeliveryState.sent,
        ReceiptLevel.sent,
        l10n.messaging_receipts_not_yet,
        l10n.messaging_receipts_not_yet_short,
      ),
    ],
  );
}
