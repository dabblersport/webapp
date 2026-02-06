import 'package:equatable/equatable.dart';

/// Arguments for launching the create game experience.
class CreateGameRouteArgs extends Equatable {
  const CreateGameRouteArgs({this.draftId, this.fromBooking});

  /// Identifier of an existing draft to restore.
  final String? draftId;

  /// Optional seed data captured from a recent booking flow.
  final BookingSeedData? fromBooking;

  CreateGameRouteArgs copyWith({
    String? draftId,
    BookingSeedData? fromBooking,
  }) {
    return CreateGameRouteArgs(
      draftId: draftId ?? this.draftId,
      fromBooking: fromBooking ?? this.fromBooking,
    );
  }

  @override
  List<Object?> get props => [draftId, fromBooking];
}

/// Lightweight snapshot of booking context that can be used to seed
/// game creation flows with sensible defaults.
class BookingSeedData extends Equatable {
  const BookingSeedData({
    required this.bookingId,
    this.venueId,
    required this.venueName,
    this.venueLocation,
    required this.date,
    required this.timeLabel,
    required this.sport,
  });

  /// Identifier of the booking that produced this seed.
  final String bookingId;

  /// Identifier of the venue associated with the booking if known.
  final String? venueId;

  /// Display name of the venue.
  final String venueName;

  /// Optional location summary for the venue.
  final String? venueLocation;

  /// Booking date for the reserved slot.
  final DateTime date;

  /// Human readable label describing the reserved slot timing.
  final String timeLabel;

  /// Sport associated with the booking.
  final String sport;

  @override
  List<Object?> get props => [
    bookingId,
    venueId,
    venueName,
    venueLocation,
    date,
    timeLabel,
    sport,
  ];
}
