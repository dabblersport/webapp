class SportModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;
  final String? iconUrl;
  final int minPlayers;
  final int maxPlayers;
  final bool isTeamSport;
  final bool isIndividualSport;
  final bool requiresEquipment;
  final List<String> commonPositions;
  final List<String> skillLevels;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SportModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    this.iconUrl,
    required this.minPlayers,
    required this.maxPlayers,
    this.isTeamSport = false,
    this.isIndividualSport = false,
    this.requiresEquipment = false,
    this.commonPositions = const [],
    this.skillLevels = const [],
    this.metadata,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates player count is within sport limits
  bool isValidPlayerCount(int playerCount) {
    return playerCount >= minPlayers && playerCount <= maxPlayers;
  }

  /// Returns the icon path based on naming convention
  String getIconPath() {
    return 'assets/icons/sports/$iconName.png';
  }

  /// Returns sport type description
  String getSportType() {
    if (isTeamSport && isIndividualSport) return 'Team & Individual';
    if (isTeamSport) return 'Team Sport';
    if (isIndividualSport) return 'Individual Sport';
    return 'Mixed';
  }

  /// Checks if position is valid for this sport
  bool isValidPosition(String position) {
    return commonPositions.contains(position);
  }

  /// Gets recommended player count (middle of range)
  int getRecommendedPlayerCount() {
    return ((minPlayers + maxPlayers) / 2).round();
  }

  /// Creates SportModel from JSON (Supabase response)
  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      iconName: json['icon_name'] as String? ?? 'default',
      iconUrl: json['icon_url'] as String?,
      minPlayers: json['min_players'] as int? ?? 1,
      maxPlayers: json['max_players'] as int? ?? 100,
      isTeamSport: json['is_team_sport'] as bool? ?? false,
      isIndividualSport: json['is_individual_sport'] as bool? ?? false,
      requiresEquipment: json['requires_equipment'] as bool? ?? false,
      commonPositions: _parseStringList(json['common_positions']),
      skillLevels: _parseStringList(json['skill_levels']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts SportModel to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'icon_name': iconName,
      'icon_url': iconUrl,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'is_team_sport': isTeamSport,
      'is_individual_sport': isIndividualSport,
      'requires_equipment': requiresEquipment,
      'common_positions': commonPositions,
      'skill_levels': skillLevels,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Helper method to parse string arrays from JSON
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Handle comma-separated strings from database
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Creates a copy with updated fields
  SportModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? iconName,
    String? iconUrl,
    int? minPlayers,
    int? maxPlayers,
    bool? isTeamSport,
    bool? isIndividualSport,
    bool? requiresEquipment,
    List<String>? commonPositions,
    List<String>? skillLevels,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SportModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      iconUrl: iconUrl ?? this.iconUrl,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isTeamSport: isTeamSport ?? this.isTeamSport,
      isIndividualSport: isIndividualSport ?? this.isIndividualSport,
      requiresEquipment: requiresEquipment ?? this.requiresEquipment,
      commonPositions: commonPositions ?? this.commonPositions,
      skillLevels: skillLevels ?? this.skillLevels,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SportModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.iconName == iconName &&
        other.iconUrl == iconUrl &&
        other.minPlayers == minPlayers &&
        other.maxPlayers == maxPlayers &&
        other.isTeamSport == isTeamSport &&
        other.isIndividualSport == isIndividualSport &&
        other.requiresEquipment == requiresEquipment &&
        _listEquals(other.commonPositions, commonPositions) &&
        _listEquals(other.skillLevels, skillLevels) &&
        _mapEquals(other.metadata, metadata) &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      category,
      iconName,
      iconUrl,
      minPlayers,
      maxPlayers,
      isTeamSport,
      isIndividualSport,
      requiresEquipment,
      Object.hashAll(commonPositions),
      Object.hashAll(skillLevels),
      metadata,
      isActive,
      createdAt,
      updatedAt,
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (final T key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
