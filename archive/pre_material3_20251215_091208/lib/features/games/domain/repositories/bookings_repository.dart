import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/booking.dart';

/// Booking filter options
class BookingFilters {
  final BookingStatus? status;
  final PaymentStatus? paymentStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? venueId;
  final String? sportType;
  final double? minAmount;
  final double? maxAmount;

  const BookingFilters({
    this.status,
    this.paymentStatus,
    this.startDate,
    this.endDate,
    this.venueId,
    this.sportType,
    this.minAmount,
    this.maxAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      if (status != null) 'status': status.toString().split('.').last,
      if (paymentStatus != null)
        'paymentStatus': paymentStatus.toString().split('.').last,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (venueId != null) 'venueId': venueId,
      if (sportType != null) 'sportType': sportType,
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
    };
  }
}

abstract class BookingsRepository {
  /// Creates a new booking with the provided data
  Future<Either<Failure, Booking>> createBooking(
    Map<String, dynamic> bookingData,
  );

  /// Retrieves a single booking by its ID
  Future<Either<Failure, Booking>> getBooking(String bookingId);

  /// Cancels a booking with reason
  Future<Either<Failure, bool>> cancelBooking(String bookingId, String reason);

  /// Retrieves bookings for a specific user
  Future<Either<Failure, List<Booking>>> getMyBookings(
    String userId, {
    BookingFilters? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = false,
  });

  /// Gets all bookings for a venue on a specific date
  Future<Either<Failure, List<Booking>>> getVenueBookings(
    String venueId,
    DateTime date, {
    String? status,
  });

  /// Updates booking status
  Future<Either<Failure, bool>> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    String? notes,
  });

  /// Updates payment status for a booking
  Future<Either<Failure, bool>> updatePaymentStatus(
    String bookingId,
    PaymentStatus status, {
    String? transactionId,
  });

  /// Checks if a venue slot is available for booking
  Future<Either<Failure, bool>> checkSlotAvailability(
    String venueId,
    DateTime date,
    String startTime,
    String endTime, {
    String? courtNumber,
  });

  /// Gets booking conflicts for a venue
  Future<Either<Failure, List<Booking>>> getBookingConflicts(
    String venueId,
    DateTime date,
    String startTime,
    String endTime, {
    String? excludeBookingId,
  });

  /// Reschedules a booking to a new date/time
  Future<Either<Failure, Booking>> rescheduleBooking(
    String bookingId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  );

  /// Processes check-in for a booking
  Future<Either<Failure, bool>> checkInBooking(
    String bookingId,
    String? checkedInBy,
  );

  /// Processes check-out for a booking
  Future<Either<Failure, bool>> checkOutBooking(
    String bookingId,
    String? actualUsageDuration,
  );

  /// Gets booking statistics for a user
  Future<Either<Failure, Map<String, dynamic>>> getUserBookingStats(
    String userId,
  );

  /// Gets booking statistics for a venue
  Future<Either<Failure, Map<String, dynamic>>> getVenueBookingStats(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Requests refund for a cancelled booking
  Future<Either<Failure, bool>> requestRefund(
    String bookingId,
    String reason,
    double? refundAmount,
  );

  /// Processes refund for a booking
  Future<Either<Failure, bool>> processRefund(
    String bookingId,
    double refundAmount,
    String? transactionId,
  );

  /// Gets upcoming bookings for a user
  Future<Either<Failure, List<Booking>>> getUpcomingBookings(
    String userId, {
    int days = 7,
    int page = 1,
    int limit = 20,
  });

  /// Gets past bookings for a user
  Future<Either<Failure, List<Booking>>> getPastBookings(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Gets today's bookings for a user
  Future<Either<Failure, List<Booking>>> getTodayBookings(String userId);

  /// Sends booking confirmation
  Future<Either<Failure, bool>> sendBookingConfirmation(
    String bookingId,
    String method,
  );

  /// Sends booking reminder
  Future<Either<Failure, bool>> sendBookingReminder(
    String bookingId,
    String method,
    int minutesBefore,
  );

  /// Gets booking reminders for a user
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingReminders(
    String userId, {
    bool activeOnly = true,
  });

  /// Sets up automatic booking reminders
  Future<Either<Failure, bool>> setupBookingReminders(
    String bookingId,
    List<int> minutesBefore,
    List<String> methods,
  );

  /// Extends booking duration (if possible)
  Future<Either<Failure, Booking>> extendBooking(
    String bookingId,
    int additionalMinutes,
  );

  /// Gets available extension time for a booking
  Future<Either<Failure, int>> getAvailableExtensionTime(String bookingId);

  /// Adds special requests to a booking
  Future<Either<Failure, bool>> addBookingSpecialRequests(
    String bookingId,
    String requests,
  );

  /// Updates booking payment method
  Future<Either<Failure, bool>> updatePaymentMethod(
    String bookingId,
    String paymentMethod,
  );

  /// Gets booking receipt/invoice
  Future<Either<Failure, Map<String, dynamic>>> getBookingReceipt(
    String bookingId,
  );

  /// Downloads booking receipt as PDF
  Future<Either<Failure, String>> downloadBookingReceiptPdf(String bookingId);

  /// Shares booking details
  Future<Either<Failure, bool>> shareBooking(
    String bookingId,
    String method,
    List<String> recipients,
  );

  /// Gets booking QR code for check-in
  Future<Either<Failure, String>> getBookingQrCode(String bookingId);

  /// Validates booking QR code
  Future<Either<Failure, Booking>> validateBookingQrCode(String qrCode);

  /// Gets booking price breakdown
  Future<Either<Failure, Map<String, dynamic>>> getBookingPriceBreakdown(
    String venueId,
    DateTime date,
    String startTime,
    String endTime,
    String? courtNumber,
  );

  /// Applies discount/promo code to booking
  Future<Either<Failure, Map<String, dynamic>>> applyPromoCode(
    String bookingId,
    String promoCode,
  );

  /// Gets available promo codes for a user
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailablePromoCodes(
    String userId,
    String? venueId,
  );

  /// Rates and reviews a completed booking
  Future<Either<Failure, bool>> rateBooking(
    String bookingId,
    double rating,
    String? review,
  );

  /// Gets booking reviews/ratings
  Future<Either<Failure, Map<String, dynamic>>> getBookingReviews(
    String bookingId,
  );

  /// Reports an issue with a booking
  Future<Either<Failure, bool>> reportBookingIssue(
    String bookingId,
    String issueType,
    String description,
  );

  /// Gets booking analytics for venue owner
  Future<Either<Failure, Map<String, dynamic>>> getBookingAnalytics(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy,
  });

  /// Gets no-show rate for a venue
  Future<Either<Failure, double>> getNoShowRate(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Marks booking as no-show
  Future<Either<Failure, bool>> markAsNoShow(String bookingId, String? reason);

  /// Gets booking cancellation reasons analytics
  Future<Either<Failure, Map<String, dynamic>>> getCancellationReasonsAnalytics(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  });
}
