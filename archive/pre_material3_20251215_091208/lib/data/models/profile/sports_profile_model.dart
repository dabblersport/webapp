import 'package:dabbler/data/models/profile/sports_profile.dart';

class SportProfileModel {
  final String id;
  final String userId;
  final SportProfile sportProfile;
  final bool isPublic;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SportProfileModel({
    required this.id,
    required this.userId,
    required this.sportProfile,
    this.isPublic = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates SportProfileModel from domain entity
  factory SportProfileModel.fromEntity(
    SportProfile entity, {
    required String id,
    required String userId,
    bool isPublic = true,
    bool isActive = true,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return SportProfileModel(
      id: id,
      userId: userId,
      sportProfile: entity,
      isPublic: isPublic,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Creates SportProfileModel from JSON (Supabase response)
  /// Supports simple schema: profile_id, sport_key, skill_level
  factory SportProfileModel.fromJson(Map<String, dynamic> json) {
    // Handle simple schema from database
    if (json.containsKey('sport_key')) {
      final sportKey = json['sport_key'] as String;
      final skillLevelInt = json['skill_level'] as int? ?? 0;

      final sportProfile = SportProfile(
        sportId: sportKey,
        sportName: _getSportNameFromKey(sportKey),
        skillLevel: _parseSkillLevel(skillLevelInt),
        yearsPlaying: 0,
        preferredPositions: const [],
        certifications: const [],
        achievements: const [],
        isPrimarySport: false,
        lastPlayed: null,
        gamesPlayed: 0,
        averageRating: 0.0,
      );

      return SportProfileModel(
        id: '', // Simple schema doesn't have id
        userId:
            json['profile_id'] as String? ??
            '', // Use profile_id as userId for compatibility
        sportProfile: sportProfile,
        isPublic: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Handle full schema (backward compatibility)
    final sportProfile = SportProfile(
      sportId:
          json['sport_id'] as String? ?? json['sport_key'] as String? ?? '',
      sportName:
          (json['sport_name'] as String?) ??
          (json.containsKey('sport') ? _extractSportName(json) : null) ??
          _getSportNameFromKey(json['sport_key'] as String? ?? ''),
      skillLevel: _parseSkillLevel(json['skill_level']),
      yearsPlaying: json['years_playing'] as int? ?? 0,
      preferredPositions: _parseStringList(json['positions']),
      certifications: _parseStringList(json['certifications']),
      achievements: _parseStringList(json['achievements']),
      isPrimarySport: json['is_primary_sport'] as bool? ?? false,
      lastPlayed: json['last_played'] != null
          ? DateTime.parse(json['last_played'] as String)
          : null,
      gamesPlayed: json['games_played'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
    );

    return SportProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['profile_id'] as String? ?? '',
      sportProfile: sportProfile,
      isPublic: json['is_public'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Get sport display name from sport_key
  static String _getSportNameFromKey(String sportKey) {
    final key = sportKey.toLowerCase();
    switch (key) {
      case 'football':
      case 'soccer':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'tennis':
        return 'Tennis';
      case 'badminton':
        return 'Badminton';
      case 'volleyball':
        return 'Volleyball';
      case 'tabletennis':
      case 'table_tennis':
        return 'Table Tennis';
      case 'squash':
        return 'Squash';
      case 'cricket':
        return 'Cricket';
      case 'baseball':
        return 'Baseball';
      case 'hockey':
        return 'Hockey';
      case 'rugby':
        return 'Rugby';
      case 'swimming':
        return 'Swimming';
      case 'golf':
        return 'Golf';
      case 'padel':
        return 'Padel';
      default:
        return sportKey.isEmpty
            ? 'Unknown Sport'
            : '${sportKey[0].toUpperCase()}${sportKey.substring(1)}';
    }
  }

  /// Creates SportProfileModel from Supabase with sport relation data
  factory SportProfileModel.fromSupabaseResponse(Map<String, dynamic> json) {
    // Handle nested sport data from joins
    final sportData = json['sport'] as Map<String, dynamic>?;
    final sportName =
        sportData?['name'] as String? ??
        json['sport_name'] as String? ??
        'Unknown Sport';

    final sportProfile = SportProfile(
      sportId: json['sport_id'] as String,
      sportName: sportName,
      skillLevel: _parseSkillLevel(json['skill_level']),
      yearsPlaying: json['years_playing'] as int? ?? 0,
      preferredPositions: _parseStringList(json['positions']),
      certifications: _parseStringList(json['certifications']),
      achievements: _parseStringList(json['achievements']),
      isPrimarySport: json['is_primary_sport'] as bool? ?? false,
      lastPlayed: json['last_played'] != null
          ? DateTime.parse(json['last_played'] as String)
          : null,
      gamesPlayed: json['games_played'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
    );

    return SportProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sportProfile: sportProfile,
      isPublic: json['is_public'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts SportProfileModel to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'sport_id': sportProfile.sportId,
      'sport_name': sportProfile.sportName,
      'skill_level': sportProfile.skillLevel.index,
      'years_playing': sportProfile.yearsPlaying,
      'is_primary_sport': sportProfile.isPrimarySport,
      'positions': sportProfile.preferredPositions,
      'certifications': sportProfile.certifications,
      'last_played': sportProfile.lastPlayed?.toIso8601String(),
      'games_played': sportProfile.gamesPlayed,
      'average_rating': sportProfile.averageRating,
      'achievements': sportProfile.achievements,
      'is_public': isPublic,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts to JSON for updates (excludes read-only fields)
  Map<String, dynamic> toUpdateJson() {
    return {
      'sport_id': sportProfile.sportId,
      'skill_level': sportProfile.skillLevel.index,
      'years_playing': sportProfile.yearsPlaying,
      'is_primary_sport': sportProfile.isPrimarySport,
      'positions': sportProfile.preferredPositions,
      'certifications': sportProfile.certifications,
      'last_played': sportProfile.lastPlayed?.toIso8601String(),
      'games_played': sportProfile.gamesPlayed,
      'average_rating': sportProfile.averageRating,
      'achievements': sportProfile.achievements,
      'is_public': isPublic,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Converts to JSON for inserts (includes user_id)
  Map<String, dynamic> toInsertJson() {
    final now = DateTime.now();
    return {
      'user_id': userId,
      'sport_id': sportProfile.sportId,
      'skill_level': sportProfile.skillLevel.index,
      'years_playing': sportProfile.yearsPlaying,
      'is_primary_sport': sportProfile.isPrimarySport,
      'positions': sportProfile.preferredPositions,
      'certifications': sportProfile.certifications,
      'last_played': sportProfile.lastPlayed?.toIso8601String(),
      'games_played': sportProfile.gamesPlayed,
      'average_rating': sportProfile.averageRating,
      'achievements': sportProfile.achievements,
      'is_public': isPublic,
      'is_active': isActive,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
  }

  /// Parses skill level from various formats
  static SkillLevel _parseSkillLevel(dynamic value) {
    if (value == null) return SkillLevel.beginner;

    if (value is int) {
      // Handle integer values from database
      switch (value) {
        case 0:
          return SkillLevel.beginner;
        case 1:
          return SkillLevel.intermediate;
        case 2:
          return SkillLevel.advanced;
        case 3:
          return SkillLevel.expert;
        default:
          return SkillLevel.beginner;
      }
    }

    if (value is String) {
      // Handle string values
      switch (value.toLowerCase()) {
        case 'beginner':
          return SkillLevel.beginner;
        case 'intermediate':
          return SkillLevel.intermediate;
        case 'advanced':
          return SkillLevel.advanced;
        case 'expert':
          return SkillLevel.expert;
        default:
          return SkillLevel.beginner;
      }
    }

    return SkillLevel.beginner;
  }

  /// Helper method to parse string arrays from JSON
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    if (value is String) {
      // Handle comma-separated strings from database
      if (value.isEmpty) return [];
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  /// Extract sport name from nested data
  static String _extractSportName(Map<String, dynamic> json) {
    // Try to get from sport relation
    if (json.containsKey('sport') && json['sport'] is Map) {
      final sport = json['sport'] as Map<String, dynamic>;
      if (sport.containsKey('name')) {
        return sport['name'] as String;
      }
    }

    // Try sport_name field
    if (json.containsKey('sport_name')) {
      return json['sport_name'] as String;
    }

    return 'Unknown Sport';
  }

  /// Creates a copy with updated fields
  SportProfileModel copyWith({
    String? id,
    String? userId,
    SportProfile? sportProfile,
    bool? isPublic,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SportProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sportProfile: sportProfile ?? this.sportProfile,
      isPublic: isPublic ?? this.isPublic,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts back to domain entity
  SportProfile toEntity() {
    return sportProfile;
  }

  // Getters for easy access to sport profile properties
  String get sportId => sportProfile.sportId;
  String get sportName => sportProfile.sportName;
  SkillLevel get skillLevel => sportProfile.skillLevel;
  int get yearsPlaying => sportProfile.yearsPlaying;
  List<String> get preferredPositions => sportProfile.preferredPositions;
  List<String> get positions =>
      sportProfile.preferredPositions; // Alias for backward compatibility
  List<String> get certifications => sportProfile.certifications;
  List<String> get achievements => sportProfile.achievements;
  bool get isPrimarySport => sportProfile.isPrimarySport;
  DateTime? get lastPlayed => sportProfile.lastPlayed;
  int get gamesPlayed => sportProfile.gamesPlayed;
  double get averageRating => sportProfile.averageRating;
}
