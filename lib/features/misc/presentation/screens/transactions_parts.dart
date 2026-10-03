import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'transaction_details_sheet.dart';

/// Signed-in body of the transactions screen: header, summary tiles, search,
/// status and period filters, and the date-grouped list. Mock data, exactly as
/// before (replace with real data from a repository).
class TransactionsHistoryView extends StatefulWidget {
  const TransactionsHistoryView({super.key});

  @override
  State<TransactionsHistoryView> createState() =>
      _TransactionsHistoryViewState();
}

class _TransactionsHistoryViewState extends State<TransactionsHistoryView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  String _selectedPeriod = 'All Time';

  static const List<String> _filters = [
    'All',
    'Completed',
    'Pending',
    'Failed',
    'Refunds',
  ];
  static const List<String> _periods = [
    'All Time',
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mock transaction data - Replace with real data from repository
  List<Map<String, dynamic>> get _transactions => [
    {
      'id': 'TXN001',
      'type': 'game_payment',
      'title': 'Football Game Payment',
      'amount': 150.00,
      'currency': 'AED',
      'status': 'completed',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'paymentMethod': 'Visa •••• 4242',
      'recipient': 'Al Ahly Sports Club',
      'category': 'Sports',
    },
    {
      'id': 'TXN002',
      'type': 'booking_payment',
      'title': 'Court Booking',
      'amount': 200.00,
      'currency': 'AED',
      'status': 'completed',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'paymentMethod': 'Mastercard •••• 8888',
      'recipient': 'Zayed Sports City',
      'category': 'Bookings',
    },
    {
      'id': 'TXN003',
      'type': 'refund',
      'title': 'Booking Cancellation Refund',
      'amount': 100.00,
      'currency': 'AED',
      'status': 'completed',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'paymentMethod': 'Visa •••• 4242',
      'recipient': 'System Refund',
      'category': 'Refunds',
    },
    {
      'id': 'TXN004',
      'type': 'game_payment',
      'title': 'Basketball Tournament Fee',
      'amount': 250.00,
      'currency': 'AED',
      'status': 'pending',
      'date': DateTime.now().subtract(const Duration(hours: 12)),
      'paymentMethod': 'Apple Pay',
      'recipient': 'The Sevens Stadium',
      'category': 'Sports',
    },
    {
      'id': 'TXN005',
      'type': 'game_payment',
      'title': 'Tennis Match Payment',
      'amount': 120.00,
      'currency': 'AED',
      'status': 'failed',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'paymentMethod': 'Visa •••• 4242',
      'recipient': 'Zabeel Sports District',
      'category': 'Sports',
    },
  ];

  double _sumCompleted({Duration? within}) => _transactions
      .where(
        (t) =>
            t['status'] == 'completed' &&
            (within == null ||
                (t['date'] as DateTime).isAfter(
                  DateTime.now().subtract(within),
                )),
      )
      .fold<double>(
        0,
        (sum, t) =>
            sum +
            (t['type'] == 'refund'
                ? -(t['amount'] as double)
                : (t['amount'] as double)),
      );

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            DabblerSpacing.space4,
            DabblerSpacing.space6,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transactions',
                style: DabblerType.title1
                    .resolveForDirection(Directionality.of(context))
                    .copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: DabblerSpacing.space1),
              Text(
                'View your payment history',
                style: DabblerType.subheadline
                    .resolveForDirection(Directionality.of(context))
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: DabblerSpacing.space6),
              DabblerStatGrid(
                children: [
                  DabblerStatTile(
                    value: 'AED ${_sumCompleted().toStringAsFixed(0)}',
                    label: 'Total Spent',
                    span: 3,
                    trailing: const DabblerIcon(
                      'trend-up',
                      size: DabblerSizing.iconMd,
                    ),
                  ),
                  DabblerStatTile(
                    value:
                        'AED ${_sumCompleted(within: const Duration(days: 30)).toStringAsFixed(0)}',
                    label: 'This Month',
                    span: 3,
                    trailing: const DabblerIcon(
                      'calendar',
                      size: DabblerSizing.iconMd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DabblerSpacing.space6),
              DabblerSearchField(
                controller: _searchController,
                placeholder: 'Search transactions...',
                onChanged: (_) => setState(() {}),
                onCleared: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space4),
        _chipRail(_filters, _selectedFilter, (f) {
          setState(() => _selectedFilter = f);
        }),
        const SizedBox(height: DabblerSpacing.space3),
        _chipRail(_periods, _selectedPeriod, (p) {
          setState(() => _selectedPeriod = p);
        }),
        Expanded(child: _buildTransactionsList(context)),
      ],
    );
  }

  Widget _chipRail(
    List<String> items,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return SizedBox(
      height: DabblerSizing.touchTargetMin,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: DabblerSpacing.space3),
        itemBuilder: (context, index) {
          final item = items[index];
          return Center(
            child: DabblerChip(
              label: item,
              selected: selected == item,
              onTap: () => onSelect(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    final filtered = _getFilteredTransactions();

    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(DabblerSpacing.space8),
          child: DabblerEmptyState(
            icon: 'receipt-item',
            size: DabblerEmptyStateSize.page,
            title: 'No transactions found',
            text: 'Your transaction history will appear here',
          ),
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var transaction in filtered) {
      final dateKey = _getDateGroup(transaction['date']);
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(transaction);
    }

    return DabblerRefresh(
      onRefresh: _refreshTransactions,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DabblerSpacing.space6),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final dateKey = grouped.keys.elementAt(index);
          final transactions = grouped[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (index > 0) const SizedBox(height: DabblerSpacing.space7),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: DabblerSpacing.space4,
                ),
                child: Text(
                  dateKey,
                  style: DabblerType.headline
                      .resolveForDirection(Directionality.of(context))
                      .copyWith(color: DabblerColors.of(context).brandPrimary),
                ),
              ),
              ...transactions.map((t) => _TransactionRow(transaction: t)),
            ],
          );
        },
      ),
    );
  }

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) return 'Today';
    if (transactionDate == yesterday) return 'Yesterday';
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    var filtered = _transactions;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (t) =>
                t['title'].toString().toLowerCase().contains(query) ||
                t['recipient'].toString().toLowerCase().contains(query) ||
                t['id'].toString().toLowerCase().contains(query),
          )
          .toList();
    }

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((t) {
        if (_selectedFilter == 'Refunds') {
          return t['type'] == 'refund';
        }
        return t['status'] == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Apply period filter
    if (_selectedPeriod != 'All Time') {
      final now = DateTime.now();
      filtered = filtered.where((t) {
        final date = t['date'] as DateTime;
        switch (_selectedPeriod) {
          case 'Today':
            return date.isAfter(DateTime(now.year, now.month, now.day));
          case 'This Week':
            return date.isAfter(now.subtract(const Duration(days: 7)));
          case 'This Month':
            return date.isAfter(now.subtract(const Duration(days: 30)));
          case 'This Year':
            return date.year == now.year;
          default:
            return true;
        }
      }).toList();
    }

    // Sort by date (most recent first)
    filtered.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    return filtered;
  }

  Future<void> _refreshTransactions() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }
}

/// One transaction line; tap opens [TransactionDetailsSheet].
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final isRefund = transaction['type'] == 'refund';
    final status = transaction['status'] as String;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showTransactionDetails(context, transaction),
        child: DabblerSurface.card(
          padding: const EdgeInsets.all(DabblerSpacing.space6),
          child: Row(
            children: [
              transactionTypeTile(context, transaction['type'] as String),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction['title'],
                            style: DabblerType.subheadline
                                .resolveForDirection(Directionality.of(context))
                                .copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: DabblerType.semibold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DabblerSpacing.space3),
                        transactionStatusBadge(context, status),
                      ],
                    ),
                    const SizedBox(height: DabblerSpacing.space1),
                    Row(
                      children: [
                        DabblerIcon(
                          'building',
                          size: 12,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: DabblerSpacing.space1),
                        Expanded(
                          child: Text(
                            transaction['recipient'],
                            style: DabblerType.footnote
                                .resolveForDirection(Directionality.of(context))
                                .copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      transaction['paymentMethod'],
                      style: DabblerType.caption2
                          .resolveForDirection(Directionality.of(context))
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DabblerSpacing.space4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isRefund ? '+' : '-'}${transaction['currency']} ${transaction['amount'].toStringAsFixed(0)}',
                    style: DabblerType.headline
                        .resolveForDirection(Directionality.of(context))
                        .copyWith(
                          color: isRefund
                              ? colors.success.base
                              : colors.textPrimary,
                        ),
                  ),
                  Text(
                    _formatTime(transaction['date']),
                    style: DabblerType.caption2
                        .resolveForDirection(Directionality.of(context))
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('h:mm a').format(date);
  }
}
