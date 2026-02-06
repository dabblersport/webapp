import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/custom_app_bar.dart';
import 'package:dabbler/core/services/auth_service.dart';

/// Professional Transactions History Screen
///
/// Features:
/// - Transaction history with filters
/// - Search functionality
/// - Export capabilities
/// - Transaction details view
/// - Status indicators
/// - Amount summaries
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  String _selectedPeriod = 'All Time';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        actionIcon: Icons.download,
        onActionPressed: _exportTransactions,
      ),
      body: user == null
          ? _buildSignInPrompt(context)
          : Column(
              children: [
                const SizedBox(height: 100),
                _buildHeader(context),
                _buildSearchBar(context),
                _buildFilters(context),
                Expanded(child: _buildTransactionsList(context)),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF813FD6),
            const Color(0xFF813FD6).withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transactions',
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View your payment history',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSummaryCards(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final total = _transactions
        .where((t) => t['status'] == 'completed')
        .fold<double>(
          0,
          (sum, t) =>
              sum +
              (t['type'] == 'refund'
                  ? -(t['amount'] as double)
                  : (t['amount'] as double)),
        );

    final thisMonth = _transactions
        .where(
          (t) =>
              t['status'] == 'completed' &&
              (t['date'] as DateTime).isAfter(
                DateTime.now().subtract(const Duration(days: 30)),
              ),
        )
        .fold<double>(
          0,
          (sum, t) =>
              sum +
              (t['type'] == 'refund'
                  ? -(t['amount'] as double)
                  : (t['amount'] as double)),
        );

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              context,
              'Total Spent',
              'AED ${total.toStringAsFixed(0)}',
              Icons.trending_up,
              Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              context,
              'This Month',
              'AED ${thisMonth.toStringAsFixed(0)}',
              Icons.calendar_today,
              Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.trending_up, color: Colors.white, size: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: context.colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: context.colors.outline.withValues(alpha: 0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: context.colors.outline.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final filters = ['All', 'Completed', 'Pending', 'Failed', 'Refunds'];
    final periods = [
      'All Time',
      'Today',
      'This Week',
      'This Month',
      'This Year',
    ];

    return Column(
      children: [
        // Status filters
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = _selectedFilter == filter;

              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isSelected) ...[
                        Icon(Icons.check, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        filter,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Period filters
        Container(
          height: 45,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final period = periods[index];
              final isSelected = _selectedPeriod == period;

              return GestureDetector(
                onTap: () => setState(() => _selectedPeriod = period),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    period,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    final filtered = _getFilteredTransactions();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var transaction in filtered) {
      final dateKey = _getDateGroup(transaction['date']);
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(transaction);
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final dateKey = grouped.keys.elementAt(index);
          final transactions = grouped[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  dateKey,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                ),
              ),
              ...transactions.map((t) => _buildTransactionCard(context, t)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    final isRefund = transaction['type'] == 'refund';
    final status = transaction['status'] as String;

    return GestureDetector(
      onTap: () => _showTransactionDetails(context, transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.violetCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(status).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTypeColor(
                  transaction['type'],
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(transaction['type']),
                color: _getTypeColor(transaction['type']),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction['title'],
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(context, status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          transaction['recipient'],
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction['paymentMethod'],
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isRefund ? '+' : '-'}${transaction['currency']} ${transaction['amount'].toStringAsFixed(0)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isRefund ? Colors.green : context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(transaction['date']),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: context.textTheme.bodySmall?.copyWith(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'game_payment':
        return Icons.sports_esports;
      case 'booking_payment':
        return Icons.calendar_today;
      case 'refund':
        return Icons.arrow_circle_left;
      default:
        return Icons.credit_card;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'game_payment':
        return const Color(0xFF813FD6);
      case 'booking_payment':
        return Colors.blue;
      case 'refund':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('h:mm a').format(date);
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt,
              size: 64,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view transactions',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your payments and transaction history',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/phone-input'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  Future<void> _refreshTransactions() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  void _exportTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📊 Exporting transactions...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Transaction Details Bottom Sheet
class TransactionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsSheet({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isRefund = transaction['type'] == 'refund';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getTypeColor(
                          transaction['type'],
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTypeIcon(transaction['type']),
                        color: _getTypeColor(transaction['type']),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['title'],
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Transaction ID: ${transaction['id']}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Amount
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Amount',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${isRefund ? '+' : '-'}${transaction['currency']} ${transaction['amount'].toStringAsFixed(2)}',
                        style: context.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isRefund
                              ? Colors.green
                              : context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Details
                _buildDetailRow(
                  context,
                  'Status',
                  _buildStatusChip(context, transaction['status']),
                ),
                _buildDetailRow(
                  context,
                  'Date',
                  DateFormat(
                    'MMM d, yyyy • h:mm a',
                  ).format(transaction['date']),
                ),
                _buildDetailRow(
                  context,
                  'Payment Method',
                  transaction['paymentMethod'],
                ),
                _buildDetailRow(context, 'Recipient', transaction['recipient']),
                _buildDetailRow(context, 'Category', transaction['category']),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download Receipt'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Get Help'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          value is Widget
              ? value
              : Text(
                  value.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: context.textTheme.bodySmall?.copyWith(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'game_payment':
        return Icons.sports_esports;
      case 'booking_payment':
        return Icons.calendar_today;
      case 'refund':
        return Icons.arrow_circle_left;
      default:
        return Icons.credit_card;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'game_payment':
        return const Color(0xFF813FD6);
      case 'booking_payment':
        return Colors.blue;
      case 'refund':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
