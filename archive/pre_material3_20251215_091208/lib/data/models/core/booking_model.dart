class BookingModel {
  final String id;
  final String title;
  final String venue;
  final String sport;
  final DateTime dateTime;
  final Duration duration;
  final bool isConfirmed;
  final int playerCount;
  final double price;
  final String organizerId;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.title,
    required this.venue,
    required this.sport,
    required this.dateTime,
    required this.duration,
    required this.isConfirmed,
    required this.playerCount,
    required this.price,
    required this.organizerId,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      venue: json['venue'] as String,
      sport: json['sport'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      duration: Duration(minutes: (json['durationMinutes'] as num).toInt()),
      isConfirmed: json['isConfirmed'] as bool,
      playerCount: json['playerCount'] as int,
      price: (json['price'] as num).toDouble(),
      organizerId: json['organizerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'venue': venue,
      'sport': sport,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'isConfirmed': isConfirmed,
      'playerCount': playerCount,
      'price': price,
      'organizerId': organizerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? title,
    String? venue,
    String? sport,
    DateTime? dateTime,
    Duration? duration,
    bool? isConfirmed,
    int? playerCount,
    double? price,
    String? organizerId,
    DateTime? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      sport: sport ?? this.sport,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      playerCount: playerCount ?? this.playerCount,
      price: price ?? this.price,
      organizerId: organizerId ?? this.organizerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper getters
  DateTime get endTime => dateTime.add(duration);
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return bookingDate == today;
  }

  bool get isTomorrow {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final bookingDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return bookingDate == tomorrow;
  }

  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  bool get isPast => dateTime.isBefore(DateTime.now());

  Duration get timeUntilStart {
    final now = DateTime.now();
    return dateTime.difference(now);
  }

  @override
  String toString() {
    return 'BookingModel(id: $id, title: $title, venue: $venue, dateTime: $dateTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
