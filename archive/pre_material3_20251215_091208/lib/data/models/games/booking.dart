enum BookingStatus { pending, confirmed, cancelled, completed, noShow }

enum PaymentStatus { pending, paid, failed, refunded, partiallyRefunded }

class Booking {
  final String id;
  final String venueId;
  final String gameId;
  final String bookedBy; // User ID who made the booking

  // Booking details
  final DateTime bookingDate;
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final String? courtNumber; // Optional court/field identifier

  // Venue details (cached for performance)
  final String venueName;
  final String venueAddress;

  // Financial details
  final double totalAmount;
  final String currency;
  final double? deposit; // Security deposit if required
  final double? tax; // Tax amount
  final double? serviceFee; // Platform service fee

  // Status tracking
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod; // 'card', 'cash', 'paypal', etc.
  final String? transactionId;

  // Cancellation details
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy; // User ID who cancelled
  final double? refundAmount;
  final DateTime? refundedAt;

  // Additional details
  final String? specialRequests;
  final String? notes;
  final List<String> attachments; // Photos, documents, etc.

  // Confirmation details
  final String? confirmationCode;
  final DateTime? confirmedAt;

  // Check-in details
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String? actualUsageDuration; // Actual time used vs booked time

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const Booking({
    required this.id,
    required this.venueId,
    required this.gameId,
    required this.bookedBy,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.courtNumber,
    required this.venueName,
    required this.venueAddress,
    required this.totalAmount,
    required this.currency,
    this.deposit,
    this.tax,
    this.serviceFee,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.transactionId,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledBy,
    this.refundAmount,
    this.refundedAt,
    this.specialRequests,
    this.notes,
    this.attachments = const [],
    this.confirmationCode,
    this.confirmedAt,
    this.checkedInAt,
    this.checkedOutAt,
    this.actualUsageDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the full booking DateTime (start)
  DateTime get bookingStartDateTime {
    final timeParts = startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      hour,
      minute,
    );
  }

  /// Get the full booking DateTime (end)
  DateTime get bookingEndDateTime {
    final timeParts = endTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      hour,
      minute,
    );
  }

  /// Get booking duration in minutes
  int get durationMinutes {
    return bookingEndDateTime.difference(bookingStartDateTime).inMinutes;
  }

  /// Get booking duration in hours (with decimal)
  double get durationHours {
    return durationMinutes / 60.0;
  }

  /// Check if booking is active (confirmed and not cancelled)
  bool get isActive {
    return status == BookingStatus.confirmed &&
        paymentStatus == PaymentStatus.paid;
  }

  /// Check if booking can be cancelled
  bool canCancel() {
    if (status == BookingStatus.cancelled ||
        status == BookingStatus.completed ||
        status == BookingStatus.noShow) {
      return false;
    }

    // Can't cancel if booking has already started
    return DateTime.now().isBefore(bookingStartDateTime);
  }

  /// Check if booking can be modified
  bool canModify() {
    if (status != BookingStatus.confirmed && status != BookingStatus.pending) {
      return false;
    }

    // Can't modify if booking is within 2 hours
    final twoHoursBefore = bookingStartDateTime.subtract(
      const Duration(hours: 2),
    );
    return DateTime.now().isBefore(twoHoursBefore);
  }

  /// Check if check-in is available
  bool canCheckIn() {
    if (status != BookingStatus.confirmed ||
        paymentStatus != PaymentStatus.paid) {
      return false;
    }

    final now = DateTime.now();
    final checkInWindow = bookingStartDateTime.subtract(
      const Duration(minutes: 15),
    );

    return now.isAfter(checkInWindow) &&
        now.isBefore(bookingEndDateTime) &&
        checkedInAt == null;
  }

  /// Check if check-out is available
  bool canCheckOut() {
    return checkedInAt != null && checkedOutAt == null;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending Confirmation';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  /// Get payment status display text
  String get paymentStatusText {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  /// Get booking time display text
  String get timeText {
    return '$startTime - $endTime';
  }

  /// Get court/field display text
  String get courtText {
    return courtNumber != null && courtNumber!.isNotEmpty
        ? 'Court $courtNumber'
        : 'Court TBD';
  }

  /// Get total amount display text
  String get totalAmountText {
    return '$currency${totalAmount.toStringAsFixed(2)}';
  }

  /// Calculate cancellation fee (if applicable)
  double calculateCancellationFee() {
    final hoursUntilBooking = bookingStartDateTime
        .difference(DateTime.now())
        .inHours;

    // Cancellation fee structure
    if (hoursUntilBooking < 2) {
      return totalAmount; // Full charge
    } else if (hoursUntilBooking < 24) {
      return totalAmount * 0.5; // 50% charge
    } else if (hoursUntilBooking < 48) {
      return totalAmount * 0.25; // 25% charge
    } else {
      return 0.0; // Free cancellation
    }
  }

  /// Calculate refund amount
  double calculateRefundAmount() {
    final cancellationFee = calculateCancellationFee();
    return (totalAmount - cancellationFee).clamp(0.0, totalAmount);
  }

  /// Time until booking starts
  Duration timeUntilBooking() {
    final now = DateTime.now();
    if (now.isAfter(bookingStartDateTime)) {
      return Duration.zero;
    }
    return bookingStartDateTime.difference(now);
  }

  /// Check if booking is happening today
  bool get isToday {
    final now = DateTime.now();
    return bookingDate.year == now.year &&
        bookingDate.month == now.month &&
        bookingDate.day == now.day;
  }

  /// Generate confirmation code
  static String generateConfirmationCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = timestamp.toString().substring(
      timestamp.toString().length - 6,
    );
    return 'BK$code';
  }

  Booking copyWith({
    String? id,
    String? venueId,
    String? gameId,
    String? bookedBy,
    DateTime? bookingDate,
    String? startTime,
    String? endTime,
    String? courtNumber,
    String? venueName,
    String? venueAddress,
    double? totalAmount,
    String? currency,
    double? deposit,
    double? tax,
    double? serviceFee,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    String? transactionId,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
    double? refundAmount,
    DateTime? refundedAt,
    String? specialRequests,
    String? notes,
    List<String>? attachments,
    String? confirmationCode,
    DateTime? confirmedAt,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
    String? actualUsageDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      gameId: gameId ?? this.gameId,
      bookedBy: bookedBy ?? this.bookedBy,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      courtNumber: courtNumber ?? this.courtNumber,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      deposit: deposit ?? this.deposit,
      tax: tax ?? this.tax,
      serviceFee: serviceFee ?? this.serviceFee,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      refundAmount: refundAmount ?? this.refundAmount,
      refundedAt: refundedAt ?? this.refundedAt,
      specialRequests: specialRequests ?? this.specialRequests,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
      actualUsageDuration: actualUsageDuration ?? this.actualUsageDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Booking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Booking{id: $id, venue: $venueName, date: $bookingDate, status: $status}';
  }
}
