import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/games/booking_model.dart';
import 'bookings_remote_data_source.dart';

// Custom exceptions for bookings
class BookingServerException implements Exception {
  final String message;
  BookingServerException(this.message);
}

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);
}

class PaymentFailedException implements Exception {
  final String message;
  PaymentFailedException(this.message);
}

class BookingNotFoundException implements Exception {
  final String message;
  BookingNotFoundException(this.message);
}

abstract class BookingsDataSource extends BookingsRemoteDataSource {
  /// Creates a new booking with transaction support
  @override
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

  /// Gets bookings for a user
  @override
  Future<List<BookingModel>> getUserBookings(
    String userId, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = false,
  });

  /// Gets a single booking
  @override
  Future<BookingModel> getBooking(String bookingId);

  /// Updates booking details
  @override
  Future<BookingModel> updateBooking(
    String bookingId,
    Map<String, dynamic> updates,
  );

  /// Cancels a booking with refund logic
  @override
  Future<BookingModel> cancelBooking(
    String bookingId,
    String reason, {
    bool requestRefund = false,
  });

  /// Checks for booking conflicts
  Future<bool> checkBookingConflicts(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
    String? excludeBookingId,
  });

  /// Gets conflicting bookings for a time slot
  @override
  Future<List<BookingModel>> getConflictingBookings(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
  });

  /// Processes refund for a booking
  @override
  Future<Map<String, dynamic>> processRefund(
    String bookingId,
    double amount,
    String reason,
  );

  /// Gets upcoming bookings
  @override
  Future<List<BookingModel>> getUpcomingBookings(
    String userId, {
    int days = 7,
    int page = 1,
    int limit = 20,
  });

  /// Gets past bookings
  @override
  Future<List<BookingModel>> getPastBookings(
    String userId, {
    int days = 30,
    int page = 1,
    int limit = 20,
  });

  /// Extends booking duration
  @override
  Future<BookingModel> extendBooking(String bookingId, int additionalMinutes);
}

class SupabaseBookingsDataSource implements BookingsDataSource {
  final SupabaseClient _supabaseClient;

  SupabaseBookingsDataSource(this._supabaseClient);

  @override
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
  }) async {
    try {
      // Start transaction for booking creation
      final response = await _supabaseClient.rpc(
        'create_booking_with_game_update',
        params: {
          'user_id': userId,
          'venue_id': venueId,
          'game_id': gameId,
          'booking_date': date,
          'start_time': startTime,
          'end_time': endTime,
          'sport_type': sport,
          'court_number': courtNumber,
          'booking_metadata': metadata ?? {},
        },
      );

      if (response['success'] != true) {
        throw BookingConflictException(
          response['message'] ?? 'Booking creation failed',
        );
      }

      // Fetch the created booking with full details
      final bookingResponse = await _supabaseClient
          .from('bookings')
          .select('''
            *,
            venue:venues(name, address),
            game:games(title, sport),
            user:profiles(full_name)
          ''')
          .eq('id', response['booking_id'])
          .single();

      return BookingModel.fromJson(bookingResponse);
    } on PostgrestException catch (e) {
      if (e.code == 'BOOKING_CONFLICT') {
        throw BookingConflictException('Time slot is already booked');
      }
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      if (e is BookingConflictException) rethrow;
      throw BookingServerException('Failed to create booking: ${e.toString()}');
    }
  }

  @override
  Future<bool> checkBookingConflicts(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
    String? excludeBookingId,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'check_booking_conflicts',
        params: {
          'venue_id': venueId,
          'booking_date': date,
          'start_time': startTime,
          'end_time': endTime,
          'sport_type': sport,
          'court_number': courtNumber,
          'exclude_booking_id': excludeBookingId,
        },
      );

      return response['has_conflicts'] as bool;
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to check booking conflicts: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<BookingModel>> getConflictingBookings(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
  }) async {
    try {
      var query = _supabaseClient
          .from('bookings')
          .select('*')
          .eq('venue_id', venueId)
          .eq('booking_date', date)
          .eq('status', 'confirmed');

      // Add time overlap conditions
      query = query.or(
        'and(start_time.lte.$startTime,end_time.gt.$startTime),'
        'and(start_time.lt.$endTime,end_time.gte.$endTime),'
        'and(start_time.gte.$startTime,end_time.lte.$endTime)',
      );

      if (sport != null) {
        query = query.eq('sport', sport);
      }
      if (courtNumber != null) {
        query = query.eq('court_number', courtNumber);
      }

      final response = await query;
      return response
          .map<BookingModel>((json) => BookingModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get conflicting bookings: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<BookingModel>> getUserBookings(
    String userId, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      var query = _supabaseClient
          .from('bookings')
          .select('''
            *,
            venue:venues(name, address),
            game:games(title, sport)
          ''')
          .eq('user_id', userId);

      // Apply filters
      if (filters != null) {
        if (filters['status'] != null) {
          query = query.eq('status', filters['status']);
        }
        if (filters['sport'] != null) {
          query = query.eq('sport', filters['sport']);
        }
        if (filters['date_from'] != null) {
          query = query.gte('booking_date', filters['date_from']);
        }
        if (filters['date_to'] != null) {
          query = query.lte('booking_date', filters['date_to']);
        }
      }

      final response = await query
          .order(sortBy ?? 'booking_date', ascending: ascending)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<BookingModel>((json) => BookingModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get user bookings: ${e.toString()}',
      );
    }
  }

  @override
  Future<BookingModel> getBooking(String bookingId) async {
    try {
      final response = await _supabaseClient
          .from('bookings')
          .select('''
            *,
            venue:venues(name, address, phone, email),
            game:games(title, sport, organizer_id),
            user:profiles(full_name, phone),
            payment_records(*)
          ''')
          .eq('id', bookingId)
          .single();

      return BookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw BookingNotFoundException('Booking not found');
      }
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException('Failed to get booking: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> updateBooking(
    String bookingId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabaseClient
          .from('bookings')
          .update(updates)
          .eq('id', bookingId)
          .select()
          .single();

      return BookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException('Failed to update booking: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> cancelBooking(
    String bookingId,
    String reason, {
    bool requestRefund = false,
  }) async {
    try {
      // Use RPC function to handle cancellation logic
      final response = await _supabaseClient.rpc(
        'cancel_booking_with_refund',
        params: {
          'booking_id': bookingId,
          'cancellation_reason': reason,
          'request_refund': requestRefund,
        },
      );

      if (response['success'] != true) {
        throw BookingServerException(
          response['message'] ?? 'Cancellation failed',
        );
      }

      // Fetch updated booking
      final bookingResponse = await _supabaseClient
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();

      return BookingModel.fromJson(bookingResponse);
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException('Failed to cancel booking: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> processRefund(
    String bookingId,
    double amount,
    String reason,
  ) async {
    try {
      final response = await _supabaseClient.rpc(
        'process_booking_refund',
        params: {
          'booking_id': bookingId,
          'refund_amount': amount,
          'refund_reason': reason,
        },
      );

      if (response['success'] != true) {
        throw PaymentFailedException(
          response['message'] ?? 'Refund processing failed',
        );
      }

      return {
        'success': true,
        'refund_id': response['refund_id'],
        'amount': amount,
        'status': response['status'],
        'processed_at': DateTime.now().toIso8601String(),
      };
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      if (e is PaymentFailedException) rethrow;
      throw PaymentFailedException('Failed to process refund: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getUpcomingBookings(
    String userId, {
    int days = 7,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final endDate = DateTime.now().add(Duration(days: days));

      final response = await _supabaseClient
          .from('bookings')
          .select('''
            *,
            venue:venues(name, address),
            game:games(title, sport)
          ''')
          .eq('user_id', userId)
          .gte('booking_date', DateTime.now().toIso8601String().split('T')[0])
          .lte('booking_date', endDate.toIso8601String().split('T')[0])
          .inFilter('status', ['confirmed', 'pending'])
          .order('booking_date')
          .order('start_time')
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<BookingModel>((json) => BookingModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get upcoming bookings: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<BookingModel>> getPastBookings(
    String userId, {
    int days = 30,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _supabaseClient
          .from('bookings')
          .select('''
            *,
            venue:venues(name, address),
            game:games(title, sport)
          ''')
          .eq('user_id', userId)
          .gte('booking_date', startDate.toIso8601String().split('T')[0])
          .lt('booking_date', DateTime.now().toIso8601String().split('T')[0])
          .order('booking_date', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<BookingModel>((json) => BookingModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get past bookings: ${e.toString()}',
      );
    }
  }

  @override
  Future<BookingModel> extendBooking(
    String bookingId,
    int additionalMinutes,
  ) async {
    try {
      final response = await _supabaseClient.rpc(
        'extend_booking',
        params: {
          'booking_id': bookingId,
          'additional_minutes': additionalMinutes,
        },
      );

      if (response['success'] != true) {
        if (response['error_code'] == 'BOOKING_CONFLICT') {
          throw BookingConflictException(
            response['message'] ?? 'Extension conflicts with another booking',
          );
        }
        throw BookingServerException(response['message'] ?? 'Extension failed');
      }

      // Fetch updated booking
      final bookingResponse = await _supabaseClient
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();

      return BookingModel.fromJson(bookingResponse);
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      if (e is BookingConflictException) rethrow;
      throw BookingServerException('Failed to extend booking: ${e.toString()}');
    }
  }

  // Additional utility methods for booking management

  /// Gets booking statistics for a user
  Future<Map<String, dynamic>> getUserBookingStats(String userId) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_user_booking_stats',
        params: {'user_id': userId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      throw BookingServerException(
        'Failed to get booking stats: ${e.toString()}',
      );
    }
  }

  /// Gets available time slots for a venue on a specific date
  Future<List<Map<String, dynamic>>> getAvailableTimeSlots(
    String venueId,
    String date, {
    String? sport,
    String? courtNumber,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_available_time_slots',
        params: {
          'venue_id': venueId,
          'booking_date': date,
          'sport_type': sport,
          'court_number': courtNumber,
        },
      );

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get available time slots: ${e.toString()}',
      );
    }
  }

  /// Sends booking reminder notifications
  Future<bool> sendBookingReminders() async {
    try {
      await _supabaseClient.rpc('send_booking_reminders');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets booking revenue analytics for venue owners
  Future<Map<String, dynamic>> getBookingRevenue(
    String venueId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_booking_revenue',
        params: {
          'venue_id': venueId,
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get booking revenue: ${e.toString()}',
      );
    }
  }

  /// Handles no-show bookings
  Future<bool> markBookingAsNoShow(String bookingId, String reason) async {
    try {
      await _supabaseClient
          .from('bookings')
          .update({
            'status': 'no_show',
            'no_show_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      return true;
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to mark booking as no-show: ${e.toString()}',
      );
    }
  }

  /// Gets booking history for a venue
  Future<List<BookingModel>> getVenueBookingHistory(
    String venueId, {
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      var query = _supabaseClient
          .from('bookings')
          .select('''
            *,
            user:profiles(full_name, phone),
            game:games(title, sport)
          ''')
          .eq('venue_id', venueId);

      if (startDate != null) {
        query = query.gte('booking_date', startDate);
      }
      if (endDate != null) {
        query = query.lte('booking_date', endDate);
      }

      final response = await query
          .order('booking_date', ascending: false)
          .order('start_time', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<BookingModel>((json) => BookingModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw BookingServerException('Database error: ${e.message}');
    } catch (e) {
      throw BookingServerException(
        'Failed to get venue booking history: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> checkSlotAvailability(
    String venueId,
    String date,
    String startTime,
    String endTime, {
    String? sport,
    String? courtNumber,
    String? excludeBookingId,
  }) async {
    try {
      // Check for conflicting bookings
      final conflicts = await getConflictingBookings(
        venueId,
        date,
        startTime,
        endTime,
        sport: sport,
        courtNumber: courtNumber,
      );

      // Filter out the excluded booking if provided
      final relevantConflicts = excludeBookingId != null
          ? conflicts.where((b) => b.id != excludeBookingId).toList()
          : conflicts;

      return relevantConflicts.isEmpty;
    } catch (e) {
      throw BookingServerException(
        'Failed to check slot availability: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> sendBookingReminder(String bookingId) async {
    try {
      // For now, return true as a placeholder
      return true;
    } catch (e) {
      throw BookingServerException(
        'Failed to send booking reminder: ${e.toString()}',
      );
    }
  }

  @override
  Future<String> getBookingQRCode(String bookingId) async {
    try {
      // For now, return a placeholder URL
      return 'https://api.qrserver.com/v1/create-qr-code/?data=$bookingId&size=200x200';
    } catch (e) {
      throw BookingServerException(
        'Failed to get booking QR code: ${e.toString()}',
      );
    }
  }
}
