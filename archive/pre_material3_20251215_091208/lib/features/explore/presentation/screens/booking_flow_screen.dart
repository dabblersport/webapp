import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/design_system/ds.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/domain/repositories/venues_repository.dart';
import 'booking_summary_modal.dart';
import 'payment_sheet.dart';
import 'booking_success_screen.dart';

class BookingFlowScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> venue;

  const BookingFlowScreen({super.key, required this.venue});

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  DateTime? selectedDate;
  String? selectedTime;
  String? selectedSport;
  String? selectedFormat;
  bool isLoading = false;
  bool isSlotLocked = false;
  String? lockError;

  List<TimeSlot> _availableSlots = [];
  bool _isLoadingSlots = false;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    // Set default sport from venue
    final sports =
        (widget.venue['sports'] as List<dynamic>?)?.cast<String>() ?? [];
    if (sports.isNotEmpty) {
      selectedSport = sports.first;
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (selectedDate == null) return;

    final venueId = widget.venue['id'] as String?;
    if (venueId == null) return;

    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
    });

    final venuesRepository = ref.read(venuesRepositoryProvider);
    final result = await venuesRepository.checkAvailability(
      venueId,
      selectedDate!,
      sport: selectedSport,
    );

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _slotsError = 'Failed to load available slots';
          });
        }
      },
      (slots) {
        if (mounted) {
          setState(() {
            _availableSlots = slots;
            _isLoadingSlots = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Slot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Venue Info Header
                    _buildVenueHeader(),
                    const SizedBox(height: 24),

                    // Sport & Format Selection
                    _buildSportFormatSelection(),
                    const SizedBox(height: 24),

                    // Date Picker
                    _buildDatePicker(),
                    const SizedBox(height: 24),

                    // Time Slot Grid
                    if (selectedDate != null) _buildTimeSlotGrid(),

                    const SizedBox(height: 100), // Space for sticky CTA
                  ],
                ),
              ),
            ),

            // Sticky Confirm & Pay Button
            if (selectedDate != null && selectedTime != null) _buildStickyCTA(),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueHeader() {
    final venue = widget.venue;
    final name = venue['name'] as String;
    final location = venue['location'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: DS.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.location_city, color: DS.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: DS.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: DS.caption.copyWith(color: DS.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportFormatSelection() {
    final sports =
        (widget.venue['sports'] as List<dynamic>?)?.cast<String>() ?? [];
    final formats =
        (widget.venue['formats'] as List<dynamic>?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sport & Format',
          style: DS.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // Sport Selection
        if (sports.length > 1) ...[
          Text(
            'Sport',
            style: DS.caption.copyWith(
              color: DS.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: sports.map((sport) {
              final isSelected = selectedSport == sport;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSport = sport;
                  });
                  if (selectedDate != null) {
                    _loadAvailableSlots(); // Reload slots for new sport
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DS.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? DS.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    sport,
                    style: DS.caption.copyWith(
                      color: isSelected ? Colors.white : DS.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Format Selection
        if (formats.isNotEmpty) ...[
          Text(
            'Format',
            style: DS.caption.copyWith(
              color: DS.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: formats.map((format) {
              final isSelected = selectedFormat == format;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedFormat = format;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DS.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? DS.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    format,
                    style: DS.caption.copyWith(
                      color: isSelected ? Colors.white : DS.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    final today = DateTime.now();
    final dates = List.generate(
      14,
      (index) => today.add(Duration(days: index)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: DS.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = selectedDate?.day == date.day;
              final isToday = date.day == today.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = date;
                    selectedTime = null; // Reset time when date changes
                  });
                  _loadAvailableSlots(); // Load slots for new date
                },
                child: Container(
                  width: 60,
                  margin: EdgeInsets.only(
                    right: index < dates.length - 1 ? 12 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DS.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? DS.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getDayName(date.weekday),
                        style: DS.caption.copyWith(
                          color: isSelected
                              ? Colors.white
                              : DS.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: DS.body.copyWith(
                          fontSize: 16,
                          color: isSelected ? Colors.white : DS.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : DS.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time',
          style: DS.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // Loading state
        if (_isLoadingSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        // Error state
        else if (_slotsError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: DS.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _slotsError!,
                    style: DS.body.copyWith(color: DS.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadAvailableSlots,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        // Empty state
        else if (_availableSlots.isEmpty && selectedDate != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No available slots for this date',
                style: DS.body.copyWith(color: DS.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          )
        // Slots grid
        else if (_availableSlots.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _availableSlots.length,
            itemBuilder: (context, index) {
              final slot = _availableSlots[index];
              final time = slot.startTime;
              final price = slot.price ?? 150;
              final available = slot.isAvailable;
              final isSelected = selectedTime == time;

              return GestureDetector(
                onTap: available
                    ? () {
                        setState(() {
                          selectedTime = time;
                        });
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DS.primary
                        : available
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? DS.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        style: DS.caption.copyWith(
                          color: isSelected
                              ? Colors.white
                              : available
                              ? DS.onSurface
                              : DS.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AED ${price.toStringAsFixed(0)}',
                        style: DS.caption.copyWith(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : available
                              ? DS.onSurfaceVariant
                              : DS.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        // Initial state - no date selected
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Please select a date first',
                style: DS.body.copyWith(color: DS.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStickyCTA() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lockError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
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
                        lockError!,
                        style: DS.caption.copyWith(color: DS.error),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleConfirmAndPay,
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
                        'Confirm & Pay',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Future<void> _handleConfirmAndPay() async {
    if (selectedDate == null || selectedTime == null || selectedSport == null) {
      return;
    }

    setState(() {
      isLoading = true;
      lockError = null;
    });

    try {
      // Step 1: Lock the slot
      final lockResult = await _lockSlot();

      if (!lockResult) {
        setState(() {
          lockError = 'Slot just taken. Please select another time.';
          isLoading = false;
        });
        return;
      }

      setState(() {
        isSlotLocked = true;
        isLoading = false;
      });

      // Step 2: Show booking summary
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BookingSummaryModal(
          venue: widget.venue,
          selectedDate: selectedDate!,
          selectedTime: selectedTime!,
          selectedSport: selectedSport!,
          selectedFormat: selectedFormat,
          price: _getSelectedSlotPrice(),
        ),
      );

      if (confirmed != true) {
        await _releaseSlot();
        return;
      }

      // Step 3: Show payment sheet
      if (!mounted) return;
      final paymentResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentSheet(
          amount: _getSelectedSlotPrice(),
          venueName: widget.venue['name'] as String,
        ),
      );

      if (paymentResult == null) {
        await _releaseSlot();
        return;
      }

      // Step 4: Confirm booking
      final bookingResult = await _confirmBooking(paymentResult);

      if (bookingResult) {
        // Navigate to success screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BookingSuccessScreen(
                venue: widget.venue,
                selectedDate: selectedDate!,
                selectedTime: selectedTime!,
                selectedSport: selectedSport!,
                bookingId: 'BK${DateTime.now().millisecondsSinceEpoch}',
              ),
            ),
          );
        }
      } else {
        await _releaseSlot();
        setState(() {
          lockError = 'Payment failed. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      await _releaseSlot();
      setState(() {
        lockError = 'Something went wrong. Please try again.';
        isLoading = false;
      });
    }
  }

  int _getSelectedSlotPrice() {
    final slot = _availableSlots.firstWhere(
      (slot) => slot.startTime == selectedTime,
      orElse: () => const TimeSlot(
        startTime: '',
        endTime: '',
        isAvailable: false,
        price: 150,
      ),
    );
    return (slot.price ?? 150).toInt();
  }

  Future<bool> _lockSlot() async {
    // Simulate API call to lock slot
    await Future.delayed(const Duration(seconds: 1));
    // Simulate 90% success rate
    return DateTime.now().millisecondsSinceEpoch % 10 != 0;
  }

  Future<void> _releaseSlot() async {
    if (isSlotLocked) {
      // Simulate API call to release slot
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        isSlotLocked = false;
      });
    }
  }

  Future<bool> _confirmBooking(Map<String, dynamic> paymentResult) async {
    // Simulate API call to confirm booking
    await Future.delayed(const Duration(seconds: 1));
    // Simulate 95% success rate
    return DateTime.now().millisecondsSinceEpoch % 20 != 0;
  }

  @override
  void dispose() {
    // Release slot if user leaves without completing booking
    if (isSlotLocked) {
      _releaseSlot();
    }
    super.dispose();
  }
}
