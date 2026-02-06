import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/ds.dart';

class PaymentSheet extends StatefulWidget {
  final int amount;
  final String venueName;

  const PaymentSheet({
    super.key,
    required this.amount,
    required this.venueName,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  String? selectedPaymentMethod;
  bool isLoading = false;
  String? errorMessage;

  // Mock payment methods
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'card_1',
      'type': 'card',
      'name': 'Visa ending in 4242',
      'icon': Icons.credit_card,
      'color': Colors.blue,
    },
    {
      'id': 'card_2',
      'type': 'card',
      'name': 'Mastercard ending in 8888',
      'icon': Icons.credit_card,
      'color': Colors.orange,
    },
    {
      'id': 'apple_pay',
      'type': 'wallet',
      'name': 'Apple Pay',
      'icon': Icons.apple,
      'color': Colors.black,
    },
    {
      'id': 'google_pay',
      'type': 'wallet',
      'name': 'Google Pay',
      'icon': Icons.credit_card,
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Select first payment method by default
    if (_paymentMethods.isNotEmpty) {
      selectedPaymentMethod = _paymentMethods.first['id'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.credit_card, color: DS.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Payment',
                  style: DS.headline.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Amount Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DS.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DS.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: DS.caption.copyWith(color: DS.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AED ${widget.amount}',
                        style: DS.headline.copyWith(
                          color: DS.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.shield, color: DS.primary, size: 24),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Payment Methods
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: DS.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._paymentMethods.map((method) => _buildPaymentMethod(method)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Error Message
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DS.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: DS.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: DS.caption.copyWith(color: DS.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedPaymentMethod != null && !isLoading
                        ? _handlePayment
                        : null,
                    style: DS.primaryButton.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(48),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Pay AED ${widget.amount}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(Map<String, dynamic> method) {
    final isSelected = selectedPaymentMethod == method['id'];
    final icon = method['icon'] as IconData;
    final color = method['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPaymentMethod = method['id'];
          errorMessage = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? DS.primary.withValues(alpha: 0.05)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? DS.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method['name'] as String,
                style: DS.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: DS.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (selectedPaymentMethod == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Simulate payment success/failure (90% success rate)
      final success = DateTime.now().millisecondsSinceEpoch % 10 != 0;

      if (success) {
        // Payment successful
        if (mounted) {
          Navigator.of(context).pop({
            'success': true,
            'paymentMethod': selectedPaymentMethod,
            'amount': widget.amount,
            'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
          });
        }
      } else {
        // Payment failed
        setState(() {
          errorMessage = 'Payment declined. Please try another method.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Payment failed. Please check your connection and try again.';
        isLoading = false;
      });
    }
  }
}
