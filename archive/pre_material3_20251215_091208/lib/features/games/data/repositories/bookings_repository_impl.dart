import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/booking.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../datasources/bookings_remote_data_source.dart';
import 'package:dabbler/data/models/games/booking_model.dart';

// Custom exceptions for bookings
class BookingServerException implements Exception {
  final String message;
  BookingServerException(this.message);
}

class BookingCacheException implements Exception {
  final String message;
  BookingCacheException(this.message);
}

class BookingNotFoundException implements Exception {
  final String message;
  BookingNotFoundException(this.message);
}

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);
}

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
}

// Custom failure types for bookings
class BookingServerFailure extends Failure {
  const BookingServerFailure([String? message])
    : super(message: message ?? 'Booking server error');
}

class BookingCacheFailure extends Failure {
  const BookingCacheFailure([String? message])
    : super(message: message ?? 'Booking cache error');
}

class BookingNotFoundFailure extends Failure {
  const BookingNotFoundFailure([String? message])
    : super(message: message ?? 'Booking not found');
}

class BookingConflictFailure extends Failure {
  const BookingConflictFailure([String? message])
    : super(message: message ?? 'Booking conflict');
}

class PaymentFailure extends Failure {
  const PaymentFailure([String? message])
    : super(message: message ?? 'Payment error');
}

class UnknownFailure extends Failure {
  const UnknownFailure([String? message])
    : super(message: message ?? 'Unknown error');
}

class BookingsRepositoryImpl implements BookingsRepository {
  final BookingsRemoteDataSource remoteDataSource;

  // In-memory caching
  final Map<String, BookingModel> _bookingsCache = {};
  final Map<String, List<BookingModel>> _listCache = {};
  final Map<String, bool> _availabilityCache = {};
  final Map<String, List<BookingModel>> _conflictsCache = {};
  final Map<String, dynamic> _metadataCache = {};

  // Cache TTL - 2 minutes for availability, 10 minutes for bookings
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _availabilityCacheDuration = Duration(minutes: 2);
  static const Duration _bookingCacheDuration = Duration(minutes: 10);

  BookingsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Booking>> createBooking(
    Map<String, dynamic> bookingData,
  ) async {
    try {
      // Extract data from the map
      final userId = bookingData['userId'] as String;
      final venueId = bookingData['venueId'] as String;
      final gameId = bookingData['gameId'] as String;
      final date = bookingData['date'] as String;
      final startTime = bookingData['startTime'] as String;
      final endTime = bookingData['endTime'] as String;
      final sport = bookingData['sport'] as String?;
      final courtNumber = bookingData['courtNumber'] as String?;
      final metadata = bookingData['metadata'] as Map<String, dynamic>?;

      // Check availability first
      final isAvailable = await remoteDataSource.checkSlotAvailability(
        venueId,
        date,
        startTime,
        endTime,
        sport: sport,
        courtNumber: courtNumber,
      );

      if (!isAvailable) {
        return Left(BookingConflictFailure('Time slot is not available'));
      }

      // Create booking
      final bookingModel = await remoteDataSource.createBooking(
        userId,
        venueId,
        gameId,
        date,
        startTime,
        endTime,
        sport: sport,
        courtNumber: courtNumber,
        metadata: metadata,
      );

      // Update cache
      _bookingsCache[bookingModel.id] = bookingModel;
      _cacheTimestamps[bookingModel.id] = DateTime.now();

      // Clear related cache entries
      _clearUserBookingsCache(userId);
      _clearAvailabilityCache(venueId, date);

      return Right(bookingModel.toEntity());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingConflictException catch (e) {
      return Left(BookingConflictFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to create booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Booking>> getBooking(String bookingId) async {
    try {
      // Check cache first
      if (_isBookingCacheValid(bookingId)) {
        final cached = _bookingsCache[bookingId]!;
        return Right(cached.toEntity());
      }

      // Fetch from remote
      final bookingModel = await remoteDataSource.getBooking(bookingId);

      // Update cache
      _bookingsCache[bookingId] = bookingModel;
      _cacheTimestamps[bookingId] = DateTime.now();

      return Right(bookingModel.toEntity());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelBooking(
    String bookingId,
    String reason,
  ) async {
    try {
      // Cancel booking
      final bookingModel = await remoteDataSource.cancelBooking(
        bookingId,
        reason,
        requestRefund: false,
      );

      // Update cache
      _bookingsCache[bookingId] = bookingModel;
      _cacheTimestamps[bookingId] = DateTime.now();

      // Clear related cache entries
      _clearUserBookingsCache(bookingModel.bookedBy);
      _clearAvailabilityCache(
        bookingModel.venueId,
        bookingModel.bookingDate.toIso8601String(),
      );

      return Right(true);
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to cancel booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getMyBookings(
    String userId, {
    BookingFilters? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('user_bookings', {
        'userId': userId,
        'filters': filters?.toJson(),
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        'ascending': ascending,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached.map((model) => model.toEntity()).toList());
      }

      // Convert filters to map
      final filtersMap = filters?.toJson();

      // Fetch from remote
      final bookingModels = await remoteDataSource.getUserBookings(
        userId,
        filters: filtersMap,
        page: page,
        limit: limit,
        sortBy: sortBy,
        ascending: ascending,
      );

      // Update cache
      _listCache[cacheKey] = bookingModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual booking cache
      for (final model in bookingModels) {
        _bookingsCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(bookingModels.map((model) => model.toEntity()).toList());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get user bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getVenueBookings(
    String venueId,
    DateTime date, {
    String? status,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty list
      return Right([]);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
        if (notes != null) 'notes': notes,
      };

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update booking status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updatePaymentStatus(
    String bookingId,
    PaymentStatus status, {
    String? transactionId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'payment_status': status.toString().split('.').last,
        if (transactionId != null) 'transaction_id': transactionId,
      };

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update payment status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> checkSlotAvailability(
    String venueId,
    DateTime date,
    String startTime,
    String endTime, {
    String? courtNumber,
  }) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];
      final cacheKey = _generateAvailabilityCacheKey(
        venueId,
        dateString,
        startTime,
        endTime,
        null,
        courtNumber,
        null,
      );

      // Check cache first (with shorter TTL for availability)
      if (_isAvailabilityCacheValid(cacheKey)) {
        final cached = _availabilityCache[cacheKey]!;
        return Right(cached);
      }

      // Check remote
      final isAvailable = await remoteDataSource.checkSlotAvailability(
        venueId,
        dateString,
        startTime,
        endTime,
        courtNumber: courtNumber,
      );

      // Update cache
      _availabilityCache[cacheKey] = isAvailable;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(isAvailable);
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check availability: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getBookingConflicts(
    String venueId,
    DateTime date,
    String startTime,
    String endTime, {
    String? excludeBookingId,
  }) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];
      final cacheKey = _generateConflictsCacheKey(
        venueId,
        dateString,
        startTime,
        endTime,
        null,
        null,
      );

      // Check cache first
      if (_isConflictsCacheValid(cacheKey)) {
        final cached = _conflictsCache[cacheKey]!;
        return Right(cached.map((model) => model.toEntity()).toList());
      }

      // Fetch from remote
      final conflictingBookings = await remoteDataSource.getConflictingBookings(
        venueId,
        dateString,
        startTime,
        endTime,
      );

      // Update cache
      _conflictsCache[cacheKey] = conflictingBookings;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(
        conflictingBookings.map((model) => model.toEntity()).toList(),
      );
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get conflicting bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Booking>> rescheduleBooking(
    String bookingId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  ) async {
    try {
      final updates = <String, dynamic>{
        'booking_date': newDate.toIso8601String(),
        'start_time': newStartTime,
        'end_time': newEndTime,
      };

      final bookingModel = await remoteDataSource.updateBooking(
        bookingId,
        updates,
      );
      return Right(bookingModel.toEntity());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to reschedule booking: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> checkInBooking(
    String bookingId,
    String? checkedInBy,
  ) async {
    try {
      final updates = <String, dynamic>{
        'checked_in_at': DateTime.now().toIso8601String(),
        if (checkedInBy != null) 'checked_in_by': checkedInBy,
      };

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check in booking: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> checkOutBooking(
    String bookingId,
    String? actualUsageDuration,
  ) async {
    try {
      final updates = <String, dynamic>{
        'checked_out_at': DateTime.now().toIso8601String(),
        if (actualUsageDuration != null)
          'actual_usage_duration': actualUsageDuration,
      };

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check out booking: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserBookingStats(
    String userId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty stats
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get user booking stats: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueBookingStats(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty stats
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue booking stats: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> requestRefund(
    String bookingId,
    String reason,
    double? refundAmount,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(UnknownFailure('Failed to request refund: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> processRefund(
    String bookingId,
    double refundAmount,
    String? transactionId,
  ) async {
    try {
      await remoteDataSource.processRefund(
        bookingId,
        refundAmount,
        transactionId ?? 'manual_refund',
      );

      // Clear related cache entries
      final booking = _bookingsCache[bookingId];
      if (booking != null) {
        _clearUserBookingsCache(booking.bookedBy);
      }

      return Right(true);
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on PaymentException catch (e) {
      return Left(PaymentFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to process refund: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getUpcomingBookings(
    String userId, {
    int days = 7,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'upcoming_${userId}_${days}_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached.map((model) => model.toEntity()).toList());
      }

      // Fetch from remote
      final bookingModels = await remoteDataSource.getUpcomingBookings(
        userId,
        days: days,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = bookingModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual booking cache
      for (final model in bookingModels) {
        _bookingsCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(bookingModels.map((model) => model.toEntity()).toList());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get upcoming bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getPastBookings(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'past_${userId}_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached.map((model) => model.toEntity()).toList());
      }

      // Fetch from remote
      final bookingModels = await remoteDataSource.getPastBookings(
        userId,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = bookingModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual booking cache
      for (final model in bookingModels) {
        _bookingsCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(bookingModels.map((model) => model.toEntity()).toList());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get past bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getTodayBookings(String userId) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty list
      return Right([]);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get today bookings: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> sendBookingConfirmation(
    String bookingId,
    String method,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to send booking confirmation: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> sendBookingReminder(
    String bookingId,
    String method,
    int minutesBefore,
  ) async {
    try {
      final success = await remoteDataSource.sendBookingReminder(bookingId);
      return Right(success);
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to send booking reminder: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingReminders(
    String userId, {
    bool activeOnly = true,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty list
      return Right([]);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get booking reminders: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> setupBookingReminders(
    String bookingId,
    List<int> minutesBefore,
    List<String> methods,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to setup booking reminders: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Booking>> extendBooking(
    String bookingId,
    int additionalMinutes,
  ) async {
    try {
      final bookingModel = await remoteDataSource.extendBooking(
        bookingId,
        additionalMinutes,
      );

      // Update cache
      _bookingsCache[bookingId] = bookingModel;
      _cacheTimestamps[bookingId] = DateTime.now();

      // Clear related cache entries
      _clearUserBookingsCache(bookingModel.bookedBy);
      _clearAvailabilityCache(
        bookingModel.venueId,
        bookingModel.bookingDate.toIso8601String(),
      );

      return Right(bookingModel.toEntity());
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } on BookingConflictException catch (e) {
      return Left(BookingConflictFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to extend booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getAvailableExtensionTime(
    String bookingId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return 0
      return Right(0);
    } catch (e) {
      return Left(
        UnknownFailure(
          'Failed to get available extension time: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> addBookingSpecialRequests(
    String bookingId,
    String requests,
  ) async {
    try {
      final updates = <String, dynamic>{'special_requests': requests};

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to add special requests: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updatePaymentMethod(
    String bookingId,
    String paymentMethod,
  ) async {
    try {
      final updates = <String, dynamic>{'payment_method': paymentMethod};

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update payment method: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBookingReceipt(
    String bookingId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty receipt
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get booking receipt: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> downloadBookingReceiptPdf(
    String bookingId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty string
      return Right('');
    } catch (e) {
      return Left(
        UnknownFailure('Failed to download booking receipt: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> shareBooking(
    String bookingId,
    String method,
    List<String> recipients,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(UnknownFailure('Failed to share booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> getBookingQrCode(String bookingId) async {
    try {
      final cacheKey = 'qr_$bookingId';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey] as String;
        return Right(cached);
      }

      // Fetch from remote
      final qrCode = await remoteDataSource.getBookingQRCode(bookingId);

      // Update cache
      _metadataCache[cacheKey] = qrCode;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(qrCode);
    } on BookingServerException catch (e) {
      return Left(BookingServerFailure(e.message));
    } on BookingNotFoundException catch (e) {
      return Left(BookingNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get booking QR code: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Booking>> validateBookingQrCode(String qrCode) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return error
      return Left(UnknownFailure('QR code validation not implemented'));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to validate QR code: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBookingPriceBreakdown(
    String venueId,
    DateTime date,
    String startTime,
    String endTime,
    String? courtNumber,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty breakdown
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get price breakdown: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> applyPromoCode(
    String bookingId,
    String promoCode,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty result
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to apply promo code: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailablePromoCodes(
    String userId,
    String? venueId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty list
      return Right([]);
    } catch (e) {
      return Left(UnknownFailure('Failed to get promo codes: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> rateBooking(
    String bookingId,
    double rating,
    String? review,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(UnknownFailure('Failed to rate booking: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBookingReviews(
    String bookingId,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty reviews
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get booking reviews: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> reportBookingIssue(
    String bookingId,
    String issueType,
    String description,
  ) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return success
      return Right(true);
    } catch (e) {
      return Left(UnknownFailure('Failed to report issue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBookingAnalytics(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty analytics
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get booking analytics: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, double>> getNoShowRate(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return 0.0
      return Right(0.0);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get no-show rate: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> markAsNoShow(
    String bookingId,
    String? reason,
  ) async {
    try {
      final updates = <String, dynamic>{
        'status': 'noShow',
        if (reason != null) 'no_show_reason': reason,
      };

      await remoteDataSource.updateBooking(bookingId, updates);
      return Right(true);
    } catch (e) {
      return Left(UnknownFailure('Failed to mark as no-show: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCancellationReasonsAnalytics(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // This would need to be implemented in the remote data source
      // For now, return empty analytics
      return Right({});
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get cancellation analytics: ${e.toString()}'),
      );
    }
  }

  // Cache validation methods
  bool _isBookingCacheValid(String bookingId) {
    final timestamp = _cacheTimestamps[bookingId];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _bookingCacheDuration &&
        _bookingsCache.containsKey(bookingId);
  }

  bool _isListCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _bookingCacheDuration &&
        _listCache.containsKey(cacheKey);
  }

  bool _isAvailabilityCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _availabilityCacheDuration &&
        _availabilityCache.containsKey(cacheKey);
  }

  bool _isConflictsCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _availabilityCacheDuration &&
        _conflictsCache.containsKey(cacheKey);
  }

  bool _isMetadataCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _bookingCacheDuration &&
        _metadataCache.containsKey(cacheKey);
  }

  // Cache key generation
  String _generateListCacheKey(String prefix, Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final keyParts = sortedKeys.map((key) => '$key:${params[key]}').join('|');
    return '${prefix}_$keyParts';
  }

  String _generateAvailabilityCacheKey(
    String venueId,
    String date,
    String startTime,
    String endTime,
    String? sport,
    String? courtNumber,
    String? excludeBookingId,
  ) {
    return 'availability_${venueId}_${date}_${startTime}_${endTime}_${sport ?? 'any'}_${courtNumber ?? 'any'}_${excludeBookingId ?? 'none'}';
  }

  String _generateConflictsCacheKey(
    String venueId,
    String date,
    String startTime,
    String endTime,
    String? sport,
    String? courtNumber,
  ) {
    return 'conflicts_${venueId}_${date}_${startTime}_${endTime}_${sport ?? 'any'}_${courtNumber ?? 'any'}';
  }

  // Cache clearing methods
  void _clearUserBookingsCache(String userId) {
    final keysToRemove = <String>[];
    for (final key in _cacheTimestamps.keys) {
      if (key.contains(userId) ||
          key.contains('user_bookings') ||
          key.contains('upcoming') ||
          key.contains('past')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cacheTimestamps.remove(key);
      _listCache.remove(key);
    }
  }

  void _clearAvailabilityCache(String venueId, String date) {
    final keysToRemove = <String>[];
    for (final key in _cacheTimestamps.keys) {
      if (key.contains('availability') &&
          key.contains(venueId) &&
          key.contains(date)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cacheTimestamps.remove(key);
      _availabilityCache.remove(key);
      _conflictsCache.remove(key);
    }
  }

  void clearAllCache() {
    _bookingsCache.clear();
    _listCache.clear();
    _availabilityCache.clear();
    _conflictsCache.clear();
    _metadataCache.clear();
    _cacheTimestamps.clear();
  }
}
