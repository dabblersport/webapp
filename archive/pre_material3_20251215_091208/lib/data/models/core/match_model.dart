import 'venue_model.dart';

// Game format for matches
class GameFormat {
  final String name;
  final String description;
  final int totalPlayers;
  final int playersPerSide;
  final Duration defaultDuration;

  const GameFormat({
    required this.name,
    required this.description,
    required this.totalPlayers,
    required this.playersPerSide,
    required this.defaultDuration,
  });
}

// Participant information
class Participant {
  final String id;
  final String name;
  final String? avatar;
  final String? email;
  final String? phone;
  final DateTime joinedAt;
  final bool isOrganizer;
  final String? skillLevel;
  final int? gamesPlayed;

  const Participant({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.phone,
    required this.joinedAt,
    this.isOrganizer = false,
    this.skillLevel,
    this.gamesPlayed,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'],
      email: json['email'],
      phone: json['phone'],
      joinedAt: DateTime.parse(json['joinedAt']),
      isOrganizer: json['isOrganizer'] ?? false,
      skillLevel: json['skillLevel'],
      gamesPlayed: json['gamesPlayed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'email': email,
      'phone': phone,
      'joinedAt': joinedAt.toIso8601String(),
      'isOrganizer': isOrganizer,
      'skillLevel': skillLevel,
      'gamesPlayed': gamesPlayed,
    };
  }
}

// Match status enum
enum MatchStatus { upcoming, inProgress, completed, cancelled }

// Match model
class Match {
  final String id;
  final String title;
  final String? description;
  final GameFormat format;
  final Venue venue;
  final DateTime startTime;
  final Duration duration;
  final double price;
  final int maxParticipants;
  final List<Participant> participants;
  final List<Participant> waitlist;
  final Participant organizer;
  final String skillLevel;
  final List<String> amenities;
  final MatchStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const Match({
    required this.id,
    required this.title,
    this.description,
    required this.format,
    required this.venue,
    required this.startTime,
    required this.duration,
    required this.price,
    required this.maxParticipants,
    required this.participants,
    this.waitlist = const [],
    required this.organizer,
    required this.skillLevel,
    this.amenities = const [],
    this.status = MatchStatus.upcoming,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  // Computed properties
  int get spotsLeft => maxParticipants - participants.length;
  bool get isFull => spotsLeft <= 0;
  bool get hasWaitlist => waitlist.isNotEmpty;
  bool get isUpcoming => status == MatchStatus.upcoming;
  bool get isInProgress => status == MatchStatus.inProgress;
  bool get isCompleted => status == MatchStatus.completed;
  bool get isCancelled => status == MatchStatus.cancelled;
  bool get isFree => price == 0;

  // Time-related computed properties
  DateTime get endTime => startTime.add(duration);
  bool get isPastDeadline => DateTime.now().isAfter(startTime);
  Duration get timeUntilStart => startTime.difference(DateTime.now());

  // Copy with method for immutability
  Match copyWith({
    String? id,
    String? title,
    String? description,
    GameFormat? format,
    Venue? venue,
    DateTime? startTime,
    Duration? duration,
    double? price,
    int? maxParticipants,
    List<Participant>? participants,
    List<Participant>? waitlist,
    Participant? organizer,
    String? skillLevel,
    List<String>? amenities,
    MatchStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Match(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      format: format ?? this.format,
      venue: venue ?? this.venue,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      waitlist: waitlist ?? this.waitlist,
      organizer: organizer ?? this.organizer,
      skillLevel: skillLevel ?? this.skillLevel,
      amenities: amenities ?? this.amenities,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'format': {
        'name': format.name,
        'description': format.description,
        'totalPlayers': format.totalPlayers,
        'playersPerSide': format.playersPerSide,
        'defaultDuration': format.defaultDuration.inMinutes,
      },
      'venue': {
        'id': venue.id,
        'name': venue.name,
        'location': venue.city,
        'imageUrl': venue.imageUrl,
        'rating': venue.rating,
        'amenities': venue.amenities,
        'coordinates': venue.coordinates,
      },
      'startTime': startTime.toIso8601String(),
      'duration': duration.inMinutes,
      'price': price,
      'maxParticipants': maxParticipants,
      'participants': participants.map((p) => p.toJson()).toList(),
      'waitlist': waitlist.map((p) => p.toJson()).toList(),
      'organizer': organizer.toJson(),
      'skillLevel': skillLevel,
      'amenities': amenities,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Factory constructor from JSON
  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      format: GameFormat(
        name: json['format']['name'],
        description: json['format']['description'],
        totalPlayers: json['format']['totalPlayers'],
        playersPerSide: json['format']['playersPerSide'],
        defaultDuration: Duration(minutes: json['format']['defaultDuration']),
      ),
      venue: Venue.fromJson(json['venue']),
      startTime: DateTime.parse(json['startTime']),
      duration: Duration(minutes: json['duration']),
      price: json['price']?.toDouble() ?? 0.0,
      maxParticipants: json['maxParticipants'],
      participants: (json['participants'] as List)
          .map((p) => Participant.fromJson(p))
          .toList(),
      waitlist: (json['waitlist'] as List? ?? [])
          .map((p) => Participant.fromJson(p))
          .toList(),
      organizer: Participant.fromJson(json['organizer']),
      skillLevel: json['skillLevel'],
      amenities: List<String>.from(json['amenities'] ?? []),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MatchStatus.upcoming,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      metadata: json['metadata'],
    );
  }
}

// Predefined game formats
class GameFormats {
  // Football formats
  static const futsal = GameFormat(
    name: 'Futsal',
    description: '5 vs 5',
    totalPlayers: 10,
    playersPerSide: 5,
    defaultDuration: Duration(minutes: 60),
  );

  static const competitive = GameFormat(
    name: 'Competitive',
    description: '6 vs 6',
    totalPlayers: 12,
    playersPerSide: 6,
    defaultDuration: Duration(minutes: 75),
  );

  static const substitutional = GameFormat(
    name: 'Substitutional',
    description: '7 vs 7',
    totalPlayers: 14,
    playersPerSide: 7,
    defaultDuration: Duration(minutes: 90),
  );

  static const association = GameFormat(
    name: 'Association',
    description: '11 vs 11',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: Duration(minutes: 90),
  );

  // Basketball formats
  static const basketball3v3 = GameFormat(
    name: '3 vs 3',
    description: 'Street basketball',
    totalPlayers: 6,
    playersPerSide: 3,
    defaultDuration: Duration(minutes: 45),
  );

  static const basketball5v5 = GameFormat(
    name: '5 vs 5',
    description: 'Full court',
    totalPlayers: 10,
    playersPerSide: 5,
    defaultDuration: Duration(minutes: 60),
  );

  // Tennis formats
  static const tennisSingles = GameFormat(
    name: 'Singles',
    description: '1 vs 1',
    totalPlayers: 2,
    playersPerSide: 1,
    defaultDuration: Duration(minutes: 90),
  );

  static const tennisDoubles = GameFormat(
    name: 'Doubles',
    description: '2 vs 2',
    totalPlayers: 4,
    playersPerSide: 2,
    defaultDuration: Duration(minutes: 120),
  );

  // Padel formats
  static const padelSingles = GameFormat(
    name: 'Singles',
    description: '1 vs 1',
    totalPlayers: 2,
    playersPerSide: 1,
    defaultDuration: Duration(minutes: 60),
  );

  static const padelDoubles = GameFormat(
    name: 'Doubles',
    description: '2 vs 2',
    totalPlayers: 4,
    playersPerSide: 2,
    defaultDuration: Duration(minutes: 90),
  );

  // Cricket formats
  static const cricketT20 = GameFormat(
    name: 'T20',
    description: '20 overs per side',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: Duration(minutes: 180),
  );

  static const cricketODI = GameFormat(
    name: 'ODI',
    description: '50 overs per side',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: Duration(minutes: 480),
  );

  static const cricketTest = GameFormat(
    name: 'Test',
    description: '5 day format',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: Duration(minutes: 1440),
  );

  static const cricketPractice = GameFormat(
    name: 'Practice',
    description: 'Net practice session',
    totalPlayers: 6,
    playersPerSide: 3,
    defaultDuration: Duration(minutes: 120),
  );

  // Squash formats
  static const squashSingles = GameFormat(
    name: 'Singles',
    description: '1 vs 1',
    totalPlayers: 2,
    playersPerSide: 1,
    defaultDuration: Duration(minutes: 45),
  );

  static const squashDoubles = GameFormat(
    name: 'Doubles',
    description: '2 vs 2',
    totalPlayers: 4,
    playersPerSide: 2,
    defaultDuration: Duration(minutes: 60),
  );

  // Get all formats for a sport
  static List<GameFormat> getFormatsForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return [futsal, competitive, substitutional, association];
      case 'basketball':
        return [basketball3v3, basketball5v5];
      case 'tennis':
        return [tennisSingles, tennisDoubles];
      case 'padel':
        return [padelSingles, padelDoubles];
      case 'cricket':
        return [cricketT20, cricketODI, cricketTest, cricketPractice];
      case 'squash':
        return [squashSingles, squashDoubles];
      default:
        return [];
    }
  }
}
