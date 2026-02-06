import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/games/booking.dart';
import '../../domain/repositories/bookings_repository.dart';

class BookingsState {
  final List<Booking> upcomingBookings;
  final List<Booking> pastBookings;
  final bool isLoading;
  final String? error;

  const BookingsState({
    this.upcomingBookings = const [],
    this.pastBookings = const [],
    this.isLoading = false,
    this.error,
  });

  BookingsState copyWith({
    List<Booking>? upcomingBookings,
    List<Booking>? pastBookings,
    bool? isLoading,
    String? error,
  }) {
    return BookingsState(
      upcomingBookings: upcomingBookings ?? this.upcomingBookings,
      pastBookings: pastBookings ?? this.pastBookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BookingsController extends StateNotifier<BookingsState> {
  final BookingsRepository _bookingsRepository;

  BookingsController(this._bookingsRepository) : super(const BookingsState());

  Future<void> loadUpcomingBookings(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _bookingsRepository.getMyBookings(
        userId,
        filters: const BookingFilters(status: BookingStatus.confirmed),
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load bookings: ${failure.message}',
          );
        },
        (bookings) {
          // Filter for upcoming bookings only
          final now = DateTime.now();
          final upcoming = bookings.where((booking) {
            return booking.bookingDate.isAfter(now) ||
                booking.bookingDate.isAtSameMomentAs(
                  DateTime(now.year, now.month, now.day),
                );
          }).toList();

          state = state.copyWith(upcomingBookings: upcoming, isLoading: false);
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load bookings: $e',
      );
    }
  }

  Future<void> loadPastBookings(String userId) async {
    try {
      final result = await _bookingsRepository.getMyBookings(
        userId,
        filters: const BookingFilters(status: BookingStatus.completed),
      );

      result.fold(
        (failure) {
          // Don't update error state for past bookings
        },
        (bookings) {
          state = state.copyWith(pastBookings: bookings);
        },
      );
    } catch (e) {}
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      final result = await _bookingsRepository.cancelBooking(bookingId, reason);

      result.fold(
        (failure) {
          state = state.copyWith(
            error: 'Failed to cancel booking: ${failure.message}',
          );
        },
        (success) {
          // Remove from upcoming bookings
          final updated = state.upcomingBookings
              .where((b) => b.id != bookingId)
              .toList();
          state = state.copyWith(upcomingBookings: updated);
        },
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to cancel booking: $e');
    }
  }
}
