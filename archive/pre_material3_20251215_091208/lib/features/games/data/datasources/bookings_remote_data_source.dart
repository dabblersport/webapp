import 'package:dabbler/data/models/games/booking_model.dart';

abstract class BookingsRemoteDataSource {
  Future<BookingModel> createBooking(
    String userId,
    String venueId,
    String gameId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
    Map<String, dynamic>? metadata,
  });

  Future<List<BookingModel>> getUserBookings(
    String userId, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = false,
  });

  Future<BookingModel> getBooking(String bookingId);

  Future<BookingModel> updateBooking(
    String bookingId,
    Map<String, dynamic> updates,
  );

  Future<BookingModel> cancelBooking(
    String bookingId,
    String reason, {
    bool requestRefund = false,
  });

  Future<bool> checkSlotAvailability(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
    String? excludeBookingId,
  });

  Future<List<BookingModel>> getConflictingBookings(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
  });

  Future<Map<String, dynamic>> processRefund(
    String bookingId,
    double amount,
    String reason,
  );

  Future<List<BookingModel>> getUpcomingBookings(
    String userId, {
    int days = 7,
    int page = 1,
    int limit = 20,
  });

  Future<List<BookingModel>> getPastBookings(
    String userId, {
    int days = 30,
    int page = 1,
    int limit = 20,
  });

  Future<bool> sendBookingReminder(String bookingId);

  Future<String> getBookingQRCode(String bookingId);

  Future<BookingModel> extendBooking(String bookingId, int additionalMinutes);
}
