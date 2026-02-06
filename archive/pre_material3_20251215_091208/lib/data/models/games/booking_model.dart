import 'package:dabbler/data/models/games/booking.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.venueId,
    required super.gameId,
    required super.bookedBy,
    required super.bookingDate,
    required super.startTime,
    required super.endTime,
    super.courtNumber,
    required super.venueName,
    required super.venueAddress,
    required super.totalAmount,
    required super.currency,
    super.deposit,
    super.tax,
    super.serviceFee,
    required super.status,
    required super.paymentStatus,
    super.paymentMethod,
    super.transactionId,
    super.cancellationReason,
    super.cancelledAt,
    super.cancelledBy,
    super.refundAmount,
    super.refundedAt,
    super.specialRequests,
    super.notes,
    super.attachments = const [],
    super.confirmationCode,
    super.confirmedAt,
    super.checkedInAt,
    super.checkedOutAt,
    super.actualUsageDuration,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final venueMap =
        _extractNestedMap(json, 'venue') ?? _extractNestedMap(json, 'venues');
    final gameMap = _extractNestedMap(json, 'game');

    final venueId =
        json['venue_id'] as String? ??
        venueMap?['id'] as String? ??
        'unknown-venue';
    final venueName =
        json['venue_name'] as String? ??
        venueMap?['name'] as String? ??
        'Unknown Venue';
    final venueAddress =
        json['venue_address'] as String? ??
        venueMap?['address'] as String? ??
        'Unknown Location';
    final gameId =
        json['game_id'] as String? ??
        gameMap?['id'] as String? ??
        'unknown-game';
    final bookedBy =
        json['booked_by'] as String? ??
        json['user_id'] as String? ??
        'unknown-user';

    return BookingModel(
      id: json['id'] as String,
      venueId: venueId,
      gameId: gameId,
      bookedBy: bookedBy,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      startTime:
          (json['start_time'] ?? gameMap?['start_time'] ?? '00:00') as String,
      endTime: (json['end_time'] ?? gameMap?['end_time'] ?? '00:00') as String,
      courtNumber: json['court_number'] as String?,
      venueName: venueName,
      venueAddress: venueAddress,
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      deposit: (json['deposit'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      serviceFee: (json['service_fee'] as num?)?.toDouble(),
      status: _parseBookingStatus(json['status']),
      paymentStatus: _parsePaymentStatus(json['payment_status']),
      paymentMethod: json['payment_method'] as String?,
      transactionId: json['transaction_id'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelledBy: json['cancelled_by'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      specialRequests: json['special_requests'] as String?,
      notes: json['notes'] as String?,
      attachments: (json['attachments'] as List?)?.cast<String>() ?? [],
      confirmationCode: json['confirmation_code'] as String?,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      checkedOutAt: json['checked_out_at'] != null
          ? DateTime.parse(json['checked_out_at'] as String)
          : null,
      actualUsageDuration: json['actual_usage_duration'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static Map<String, dynamic>? _extractNestedMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first as Map).cast<String, dynamic>();
    }
    return null;
  }

  static BookingStatus _parseBookingStatus(dynamic statusData) {
    if (statusData == null) return BookingStatus.pending;

    if (statusData is String) {
      try {
        return BookingStatus.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              statusData.toLowerCase(),
          orElse: () => BookingStatus.pending,
        );
      } catch (e) {
        return BookingStatus.pending;
      }
    }

    return BookingStatus.pending;
  }

  static PaymentStatus _parsePaymentStatus(dynamic statusData) {
    if (statusData == null) return PaymentStatus.pending;

    if (statusData is String) {
      try {
        return PaymentStatus.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              statusData.toLowerCase(),
          orElse: () => PaymentStatus.pending,
        );
      } catch (e) {
        return PaymentStatus.pending;
      }
    }

    return PaymentStatus.pending;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venue_id': venueId,
      'game_id': gameId,
      'booked_by': bookedBy,
      'booking_date': bookingDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'court_number': courtNumber,
      'venue_name': venueName,
      'venue_address': venueAddress,
      'total_amount': totalAmount,
      'currency': currency,
      'deposit': deposit,
      'tax': tax,
      'service_fee': serviceFee,
      'status': status.toString().split('.').last,
      'payment_status': paymentStatus.toString().split('.').last,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'cancellation_reason': cancellationReason,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_by': cancelledBy,
      'refund_amount': refundAmount,
      'refunded_at': refundedAt?.toIso8601String(),
      'special_requests': specialRequests,
      'notes': notes,
      'attachments': attachments,
      'confirmation_code': confirmationCode,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'actual_usage_duration': actualUsageDuration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'venue_id': venueId,
      'game_id': gameId,
      'booked_by': bookedBy,
      'booking_date': bookingDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'court_number': courtNumber,
      'venue_name': venueName,
      'venue_address': venueAddress,
      'total_amount': totalAmount,
      'currency': currency,
      'deposit': deposit,
      'tax': tax,
      'service_fee': serviceFee,
      'status': status.toString().split('.').last,
      'payment_status': paymentStatus.toString().split('.').last,
      'payment_method': paymentMethod,
      'special_requests': specialRequests,
      'notes': notes,
      'attachments': attachments,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'booking_date': bookingDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'court_number': courtNumber,
      'total_amount': totalAmount,
      'deposit': deposit,
      'tax': tax,
      'service_fee': serviceFee,
      'status': status.toString().split('.').last,
      'payment_status': paymentStatus.toString().split('.').last,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'cancellation_reason': cancellationReason,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_by': cancelledBy,
      'refund_amount': refundAmount,
      'refunded_at': refundedAt?.toIso8601String(),
      'special_requests': specialRequests,
      'notes': notes,
      'attachments': attachments,
      'confirmation_code': confirmationCode,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'actual_usage_duration': actualUsageDuration,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Format booking date for display
  String get dateDisplay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
    );

    if (bookingDay == today) {
      return 'Today';
    } else if (bookingDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (bookingDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
    }
  }

  // Get full booking time display
  String get fullTimeDisplay {
    return '$dateDisplay • $startTime - $endTime';
  }

  // Get cost breakdown display
  String get costBreakdownDisplay {
    final buffer = StringBuffer();
    buffer.write('$currency${totalAmount.toStringAsFixed(2)}');

    if (deposit != null && deposit! > 0) {
      buffer.write(' (Deposit: $currency${deposit!.toStringAsFixed(2)})');
    }

    return buffer.toString();
  }

  // Get fee breakdown text
  String get feeBreakdownDisplay {
    final buffer = StringBuffer();
    final baseAmount = totalAmount - (tax ?? 0) - (serviceFee ?? 0);

    buffer.write('Base: $currency${baseAmount.toStringAsFixed(2)}');

    if (tax != null && tax! > 0) {
      buffer.write('\nTax: $currency${tax!.toStringAsFixed(2)}');
    }

    if (serviceFee != null && serviceFee! > 0) {
      buffer.write('\nService Fee: $currency${serviceFee!.toStringAsFixed(2)}');
    }

    return buffer.toString();
  }

  // Get refund status display
  String get refundStatusDisplay {
    if (refundAmount == null) return 'No refund';

    if (refundedAt != null) {
      return 'Refunded: $currency${refundAmount!.toStringAsFixed(2)}';
    } else {
      return 'Refund pending: $currency${refundAmount!.toStringAsFixed(2)}';
    }
  }

  // Get confirmation status display
  String get confirmationStatusDisplay {
    if (confirmationCode != null) {
      return 'Confirmed - Code: $confirmationCode';
    }
    return 'Awaiting confirmation';
  }

  // Get check-in status display
  String get checkInStatusDisplay {
    if (checkedOutAt != null) {
      return 'Checked out';
    } else if (checkedInAt != null) {
      return 'Checked in';
    } else if (canCheckIn()) {
      return 'Ready for check-in';
    } else {
      return 'Not ready for check-in';
    }
  }

  // Get usage duration display
  String get usageDurationDisplay {
    if (actualUsageDuration != null) {
      return 'Used: $actualUsageDuration';
    }
    return 'Scheduled: ${durationHours.toStringAsFixed(1)}h';
  }

  factory BookingModel.fromBooking(Booking booking) {
    return BookingModel(
      id: booking.id,
      venueId: booking.venueId,
      gameId: booking.gameId,
      bookedBy: booking.bookedBy,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      endTime: booking.endTime,
      courtNumber: booking.courtNumber,
      venueName: booking.venueName,
      venueAddress: booking.venueAddress,
      totalAmount: booking.totalAmount,
      currency: booking.currency,
      deposit: booking.deposit,
      tax: booking.tax,
      serviceFee: booking.serviceFee,
      status: booking.status,
      paymentStatus: booking.paymentStatus,
      paymentMethod: booking.paymentMethod,
      transactionId: booking.transactionId,
      cancellationReason: booking.cancellationReason,
      cancelledAt: booking.cancelledAt,
      cancelledBy: booking.cancelledBy,
      refundAmount: booking.refundAmount,
      refundedAt: booking.refundedAt,
      specialRequests: booking.specialRequests,
      notes: booking.notes,
      attachments: booking.attachments,
      confirmationCode: booking.confirmationCode,
      confirmedAt: booking.confirmedAt,
      checkedInAt: booking.checkedInAt,
      checkedOutAt: booking.checkedOutAt,
      actualUsageDuration: booking.actualUsageDuration,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
    );
  }

  /// Convert this model back to the domain entity
  Booking toEntity() {
    return this;
  }

  @override
  BookingModel copyWith({
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
    return BookingModel(
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
}
