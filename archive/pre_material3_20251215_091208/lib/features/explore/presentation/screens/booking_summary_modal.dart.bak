import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/core/design_system/ds.dart';

class BookingSummaryModal extends StatelessWidget {
  final Map<String, dynamic> venue;
  final DateTime selectedDate;
  final String selectedTime;
  final String selectedSport;
  final String? selectedFormat;
  final int price;

  const BookingSummaryModal({
    super.key,
    required this.venue,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedSport,
    this.selectedFormat,
    required this.price,
  });

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
                Icon(LucideIcons.checkCircle, color: DS.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Booking Summary',
                  style: DS.headline.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Venue Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: DS.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.mapPin,
                      color: DS.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue['name'] as String,
                          style: DS.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          venue['location'] as String,
                          style: DS.caption.copyWith(
                            color: DS.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Booking Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildDetailRow('Date', _formatDate(selectedDate)),
                _buildDetailRow('Time', selectedTime),
                _buildDetailRow('Sport', selectedSport),
                if (selectedFormat != null)
                  _buildDetailRow('Format', selectedFormat!),
                const Divider(height: 32),
                _buildDetailRow('Price', 'AED $price', isPrice: true),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cancellation Policy
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DS.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DS.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, color: DS.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Free cancellation up to 24 hours before booking',
                      style: DS.caption.copyWith(
                        color: DS.primary,
                        fontWeight: FontWeight.w500,
                      ),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: DS.primaryButton.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(48),
                      ),
                    ),
                    child: Text(
                      'Continue to Pay',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DS.body.copyWith(color: DS.onSurfaceVariant)),
          Text(
            value,
            style: DS.body.copyWith(
              fontWeight: isPrice ? FontWeight.w700 : FontWeight.w600,
              color: isPrice ? DS.primary : DS.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}
