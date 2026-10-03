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

    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              transactionTypeTile(context, transaction['type'] as String),
              const SizedBox(width: DabblerSpacing.space6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DabblerText(
                      transaction['title'],
                      style: DabblerType.title3,
                    ),
                    DabblerText(
                      'Transaction ID: ${transaction['id']}',
                      style: DabblerType.footnote,
                      tone: DabblerTextTone.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space7),
          DabblerSurface(
            variant: DabblerSurfaceVariant.sunken,
            padding: const EdgeInsets.all(DabblerSpacing.space7),
            child: Column(
              children: [
                DabblerText(
                  'Amount',
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                ),
                const SizedBox(height: DabblerSpacing.space3),
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
          const SizedBox(height: DabblerSpacing.space7),
          _detailRow(
            context,
            'Status',
            transactionStatusBadge(context, transaction['status'] as String),
          ),
          _detailRow(
            context,
            'Date',
            DateFormat('MMM d, yyyy • h:mm a').format(transaction['date']),
          ),
          _detailRow(context, 'Payment Method', transaction['paymentMethod']),
          _detailRow(context, 'Recipient', transaction['recipient']),
          _detailRow(context, 'Category', transaction['category']),
          const SizedBox(height: DabblerSpacing.space7),
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
              const SizedBox(width: DabblerSpacing.space4),
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
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DabblerText(
            label,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          value is Widget
              ? value
              : DabblerText(
                  value.toString(),
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                ),
        ],
      ),
    );
  }
}
