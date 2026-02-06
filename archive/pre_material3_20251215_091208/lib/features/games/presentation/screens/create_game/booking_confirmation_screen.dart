import 'package:flutter/material.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onBookingConfirmed;
  final Map<String, dynamic> gameData;
  final GameCreationViewModel? viewModel;

  const BookingConfirmationScreen({
    super.key,
    this.onBookingConfirmed,
    required this.gameData,
    this.viewModel,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  String _paymentMethod = 'credit_card';
  bool _agreedToTerms = false;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'credit_card',
      'name': 'Credit Card',
      'icon': Icons.credit_card,
      'subtitle': 'Visa, MasterCard, Amex',
    },
    {
      'id': 'paypal',
      'name': 'PayPal',
      'icon': Icons.account_balance_wallet,
      'subtitle': 'Pay with your PayPal account',
    },
    {
      'id': 'apple_pay',
      'name': 'Apple Pay',
      'icon': Icons.phone_iphone,
      'subtitle': 'Touch ID or Face ID',
    },
    {
      'id': 'google_pay',
      'name': 'Google Pay',
      'icon': Icons.account_balance_wallet_outlined,
      'subtitle': 'Pay with Google',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final venue = widget.gameData['venue'];
    final hasVenue = venue != null;
    final needsPayment = _getTotalCost() > 0;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review & Confirm',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review your game details before creating',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  _buildGameSummary(),
                  const SizedBox(height: 16),

                  if (hasVenue) ...[
                    _buildVenueBooking(),
                    const SizedBox(height: 16),
                  ],

                  _buildCostBreakdown(),
                  const SizedBox(height: 16),

                  if (needsPayment) ...[
                    _buildPaymentMethod(),
                    const SizedBox(height: 16),
                  ],

                  _buildTermsAndConditions(),
                  const SizedBox(height: 16),

                  _buildGamePolicies(),
                ],
              ),
            ),
          ),

          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildGameSummary() {
    final sport = widget.gameData['sport'] ?? 'Game';
    final title = widget.gameData['title'] ?? '$sport Game';
    final date = widget.gameData['date'] as DateTime?;
    final time = widget.gameData['time'];
    final duration = widget.gameData['duration'] ?? 60;
    final minPlayers = widget.gameData['minPlayers'] ?? 2;
    final maxPlayers = widget.gameData['maxPlayers'] ?? 10;
    final skillLevel = widget.gameData['skillLevel'] ?? 'Mixed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_soccer, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Game Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildInfoRow(Icons.calendar_today, _formatDate(date)),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.access_time,
                        '$time • ${duration}min',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.people,
                        '$minPlayers-$maxPlayers players',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.star, skillLevel),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sport,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (widget.gameData['description']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                widget.gameData['description'],
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVenueBooking() {
    final venue = widget.gameData['venue'];
    if (venue == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Venue Booking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Available',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    venue['imageUrl'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue['name'] ?? 'Venue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue['address'] ?? 'Address not available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking confirmation will be sent to venue. You may receive a confirmation call.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown() {
    final pricePerPlayer = widget.gameData['pricePerPlayer'] ?? 0.0;
    final maxPlayers = widget.gameData['maxPlayers'] ?? 10;
    final venue = widget.gameData['venue'];
    final venuePrice = venue?['pricePerHour'] ?? 0.0;
    final duration = widget.gameData['duration'] ?? 60;

    final playerTotal = pricePerPlayer * maxPlayers;
    final venueTotal = (venuePrice * duration / 60).round().toDouble();
    final subtotal = playerTotal + venueTotal;
    final fee = subtotal * 0.05; // 5% service fee
    final total = subtotal + fee;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Cost Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            if (pricePerPlayer > 0) ...[
              _buildCostRow(
                'Player fees ($maxPlayers × \$${pricePerPlayer.toStringAsFixed(2)})',
                playerTotal,
              ),
              const SizedBox(height: 8),
            ],

            if (venueTotal > 0) ...[
              _buildCostRow('Venue booking (${duration}min)', venueTotal),
              const SizedBox(height: 8),
            ],

            if (fee > 0) ...[
              _buildCostRow('Service fee', fee),
              const SizedBox(height: 8),
            ],

            if (total == 0) ...[
              Row(
                children: [
                  Icon(Icons.celebration, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Free Game!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey[700])),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    if (_getTotalCost() == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ..._paymentMethods.map(
              (method) => RadioListTile<String>(
                value: method['id'],
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
                title: Row(
                  children: [
                    Icon(method['icon'], size: 20),
                    const SizedBox(width: 8),
                    Text(method['name']),
                  ],
                ),
                subtitle: Text(method['subtitle']),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Terms & Conditions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              },
              title: const Text('I agree to the Terms & Conditions'),
              subtitle: const Text('View terms and privacy policy'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 12),

            Text(
              'By creating this game, you agree to:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            const Text('• Show up on time and be respectful to other players'),
            const SizedBox(height: 4),
            const Text('• Follow cancellation policy (24hr notice)'),
            const SizedBox(height: 4),
            const Text('• Comply with venue rules and regulations'),
            const SizedBox(height: 4),
            const Text('• Take responsibility as game organizer'),
          ],
        ),
      ),
    );
  }

  Widget _buildGamePolicies() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.policy, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text(
                  'Game Policies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text(
              '📋 Cancellation: Free cancellation 24 hours before game time',
            ),
            const SizedBox(height: 6),
            const Text(
              '🌧️ Weather: Games may be cancelled due to severe weather',
            ),
            const SizedBox(height: 6),
            const Text(
              '💰 Refunds: Full refund for cancellations within policy',
            ),
            const SizedBox(height: 6),
            const Text(
              '👥 No-shows: Players who don\'t show up won\'t be refunded',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final canConfirm = _agreedToTerms;
    final total = _getTotalCost();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (total > 0) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],

          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing || !canConfirm ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Creating Game...'),
                      ],
                    )
                  : Text(
                      total > 0 ? 'Pay & Create Game' : 'Create Game',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date not set';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final gameDate = DateTime(date.year, date.month, date.day);

    if (gameDate == today) {
      return 'Today, ${_formatDateString(date)}';
    } else if (gameDate == tomorrow) {
      return 'Tomorrow, ${_formatDateString(date)}';
    } else {
      return _formatDateString(date);
    }
  }

  String _formatDateString(DateTime date) {
    const months = [
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  double _getTotalCost() {
    final pricePerPlayer = widget.gameData['pricePerPlayer'] ?? 0.0;
    final maxPlayers = widget.gameData['maxPlayers'] ?? 10;
    final venue = widget.gameData['venue'];
    final venuePrice = venue?['pricePerHour'] ?? 0.0;
    final duration = widget.gameData['duration'] ?? 60;

    final playerTotal = pricePerPlayer * maxPlayers;
    final venueTotal = (venuePrice * duration / 60).round().toDouble();
    final subtotal = playerTotal + venueTotal;
    final fee = subtotal * 0.05; // 5% service fee

    return subtotal + fee;
  }

  Future<void> _confirmBooking() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Use viewmodel if provided, otherwise fallback to callback
      if (widget.viewModel != null) {
        final success = await widget.viewModel!.createGame();

        if (mounted) {
          if (success) {
            // Call callback if provided
            if (widget.onBookingConfirmed != null) {
              widget.onBookingConfirmed!({
                'paymentMethod': _paymentMethod,
                'totalCost': _getTotalCost(),
                'agreedToTerms': _agreedToTerms,
                'success': true,
              });
            } else {
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Game created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate back or to success screen
              Navigator.of(context).pop(true);
            }
          } else {
            // Show error from viewmodel
            final error = widget.viewModel!.state.error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? 'Failed to create game'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (widget.onBookingConfirmed != null) {
        // Fallback to callback if no viewmodel
        widget.onBookingConfirmed!({
          'paymentMethod': _paymentMethod,
          'totalCost': _getTotalCost(),
          'agreedToTerms': _agreedToTerms,
          'bookingId': 'BK${DateTime.now().millisecondsSinceEpoch}',
        });
      } else {
        throw Exception('No viewmodel or callback provided');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
