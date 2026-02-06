import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/widgets/app_button.dart';
import 'package:dabbler/widgets/custom_app_bar.dart';
import 'package:dabbler/data/models/payments/payment_method.dart' as pm;
import 'package:dabbler/features/payments/presentation/providers/payment_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/config/feature_flags.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!FeatureFlags.enablePayments) return;
      _loadPaymentMethods();
    });
  }

  Future<void> _loadPaymentMethods() async {
    if (!FeatureFlags.enablePayments) return;
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;

    ref
        .read(paymentMethodsControllerProvider(userId).notifier)
        .loadPaymentMethods();
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.enablePayments) {
      return Scaffold(
        appBar: CustomAppBar(actionIcon: Iconsax.card_copy),
        body: _buildPaymentsDisabledState(context),
      );
    }

    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      return Scaffold(
        appBar: CustomAppBar(actionIcon: Iconsax.card_copy),
        body: const Center(
          child: Text('Please sign in to view payment methods'),
        ),
      );
    }

    final state = ref.watch(paymentMethodsControllerProvider(userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(actionIcon: Iconsax.card_copy),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? _buildErrorState(state.error!)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 116, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransactionHistoryCard(context),
                  const SizedBox(height: 16),
                  _buildAddPaymentButton(context),
                  const SizedBox(height: 24),
                  _buildPaymentMethodsList(context, state.paymentMethods),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentsDisabledState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Payments are coming soon',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re polishing the payments experience for the next release.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPaymentMethods,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryCard(BuildContext context) {
    return GestureDetector(
      onTap: FeatureFlags.enablePayments
          ? () {
              Navigator.of(context).pushNamed('/transactions');
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF813FD6), Color(0xFF9D5CE8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF813FD6).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View all your payments',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPaymentButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: 'Add Payment Method',
        onPressed: () {
          _showAddPaymentDialog(context);
        },
        variant: ButtonVariant.primary,
        size: ButtonSize.large,
        leadingIcon: Icons.add,
      ),
    );
  }

  Widget _buildPaymentMethodsList(
    BuildContext context,
    List<pm.PaymentMethod> methods,
  ) {
    if (methods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.credit_card, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No payment methods yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first payment method to get started',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Payment Methods',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: methods.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final method = methods[index];
            return _buildPaymentMethodCard(context, method);
          },
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context,
    pm.PaymentMethod method,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getMethodColor(method.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPaymentIcon(method.type),
                color: _getMethodColor(method.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getMethodTitle(method),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (method.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMethodSubtitle(method),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'default':
                    _setAsDefault(method);
                    break;
                  case 'edit':
                    _editPaymentMethod(method);
                    break;
                  case 'delete':
                    _deletePaymentMethod(method);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!method.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 16),
                        SizedBox(width: 8),
                        Text('Set as Default'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(pm.PaymentType type) {
    switch (type) {
      case pm.PaymentType.card:
        return Icons.credit_card;
      case pm.PaymentType.paypal:
        return Icons.account_balance_wallet;
      case pm.PaymentType.applePay:
        return Icons.apple;
      case pm.PaymentType.googlePay:
        return Icons.smartphone;
      case pm.PaymentType.bankTransfer:
        return Icons.business;
    }
  }

  Color _getMethodColor(pm.PaymentType type) {
    switch (type) {
      case pm.PaymentType.card:
        return Colors.blue;
      case pm.PaymentType.paypal:
        return Colors.orange;
      case pm.PaymentType.applePay:
        return Colors.black;
      case pm.PaymentType.googlePay:
        return Colors.green;
      case pm.PaymentType.bankTransfer:
        return Colors.teal;
    }
  }

  String _getMethodTitle(pm.PaymentMethod method) {
    switch (method.type) {
      case pm.PaymentType.card:
        return '${method.brand} •••• ${method.lastFour}';
      case pm.PaymentType.paypal:
        return 'PayPal';
      case pm.PaymentType.applePay:
        return 'Apple Pay';
      case pm.PaymentType.googlePay:
        return 'Google Pay';
      case pm.PaymentType.bankTransfer:
        return 'Bank Transfer';
    }
  }

  String _getMethodSubtitle(pm.PaymentMethod method) {
    switch (method.type) {
      case pm.PaymentType.card:
        return 'Expires ${method.expiryDate}';
      case pm.PaymentType.paypal:
        return method.email ?? '';
      case pm.PaymentType.applePay:
        return 'Apple Wallet';
      case pm.PaymentType.googlePay:
        return 'Google Wallet';
      case pm.PaymentType.bankTransfer:
        return 'Bank account ending in ${method.lastFour}';
    }
  }

  void _showAddPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: const Text('Choose a payment method to add:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credit Card setup coming soon!')),
              );
            },
            child: const Text('Credit Card'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PayPal setup coming soon!')),
              );
            },
            child: const Text('PayPal'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsDefault(pm.PaymentMethod method) async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;

    final success = await ref
        .read(paymentMethodsControllerProvider(userId).notifier)
        .setDefaultPaymentMethod(method.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_getMethodTitle(method)} set as default')),
      );
    }
  }

  void _editPaymentMethod(pm.PaymentMethod method) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit payment method coming soon!')),
    );
  }

  Future<void> _deletePaymentMethod(pm.PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: const Text(
          'Are you sure you want to delete this payment method?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final userId = _authService.getCurrentUserId();
    if (userId == null) return;

    final success = await ref
        .read(paymentMethodsControllerProvider(userId).notifier)
        .deletePaymentMethod(method.id);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment method deleted')));
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete payment method'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
