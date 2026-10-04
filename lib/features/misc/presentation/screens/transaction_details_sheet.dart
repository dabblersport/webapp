import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Opens the details sheet for [transaction].
void showTransactionDetails(
  BuildContext context,
  Map<String, dynamic> transaction,
) {
  showDabblerSheet<void>(
    context: context,
    detent: DabblerSheetDetent.content,
    builder: (context) => TransactionDetailsSheet(transaction: transaction),
  );
}

/// Type glyph in a DS icon tile (game / booking / refund / other).
Widget transactionTypeTile(BuildContext context, String type) {
  switch (type) {
    case 'game_payment':
      return const DabblerIconTile.named('game');
    case 'booking_payment':
      return const DabblerIconTile.named(
        'calendar',
        tone: DabblerIconTileTone.info,
      );
    case 'refund':
      return DabblerIconTile.tinted(
        const DabblerIcon('arrow-circle-left'),
        color: DabblerColors.of(context).success.base,
      );
    default:
      return const DabblerIconTile.named(
        'card',
        tone: DabblerIconTileTone.amber,
      );
  }
}

/// Status as a DS badge with the matching status role.
Widget transactionStatusBadge(BuildContext context, String status) {
  final colors = DabblerColors.of(context);
  final DabblerStatusColor? role = switch (status) {
    'completed' => colors.success,
    'pending' => colors.warning,
    'failed' => colors.error,
    _ => null,
  };
  return DabblerBadge(
    label: status.toUpperCase(),
    status: role,
    tone: DabblerBadgeTone.warning,
  );
}

/// Transaction Details Bottom Sheet
class TransactionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsSheet({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isRefund = transaction['type'] == 'refund';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          leading: transactionTypeTile(context, transaction['type'] as String),
          title: transaction['title'] as String,
          subtitle: 'Transaction ID: ${transaction['id']}',
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSurface(
          variant: DabblerSurfaceVariant.sunken,
          padding: DabblerInsets.card,
          child: Column(
            children: [
              DabblerText(
                'Amount',
                style: DabblerType.subheadline,
                tone: DabblerTextTone.secondary,
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerText(
                '${isRefund ? '+' : '-'}${transaction['currency']} ${transaction['amount'].toStringAsFixed(2)}',
                style: DabblerType.largeTitle,
                tone: isRefund
                    ? DabblerTextTone.success
                    : DabblerTextTone.brand,
              ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerInputRow(
          flat: true,
          showDivider: false,
          title: 'Status',
          trailing: transactionStatusBadge(
            context,
            transaction['status'] as String,
          ),
        ),
        _detailRow(
          'Date',
          DateFormat('MMM d, yyyy • h:mm a').format(transaction['date']),
        ),
        _detailRow('Payment Method', transaction['paymentMethod'] as String),
        _detailRow('Recipient', transaction['recipient'] as String),
        _detailRow('Category', transaction['category'] as String),
        const DabblerGap.v(DabblerSpacing.space6),
        Row(
          children: [
            Expanded(
              child: DabblerButton(
                label: 'Download Receipt',
                icon: 'document-download',
                tone: DabblerButtonTone.outlined,
                fullWidth: true,
                onPressed: () {},
              ),
            ),
            const DabblerGap.h(DabblerSpacing.space4),
            Expanded(
              child: DabblerButton(
                label: 'Get Help',
                icon: 'message-question',
                fullWidth: true,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => DabblerInputRow(
    flat: true,
    showDivider: false,
    title: label,
    value: value,
  );
}
