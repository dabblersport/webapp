/// Model for vibes from the vibes table
class VibeModel {
  final String id;
  final String key;
  final String labelEn;
  final String? labelAr;
  final String? emoji;
  final String? colorHex;
  final Map<String, dynamic>? gradient;
  final int sortOrder;
  final List<String> contexts;
  final String? theme;
  final int urgencyLevel;
  final bool isActive;
  final String? type; // 'feeling' | 'action'
  final String? usage;
  final List<String> appFlavors;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VibeModel({
    required this.id,
    required this.key,
    required this.labelEn,
    this.labelAr,
    this.emoji,
    this.colorHex,
    this.gradient,
    this.sortOrder = 0,
    this.contexts = const [],
    this.theme,
    this.urgencyLevel = 0,
    this.isActive = true,
    this.type,
    this.usage,
    this.appFlavors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory VibeModel.fromJson(Map<String, dynamic> json) {
    return VibeModel(
      id: json['id'] as String,
      key: json['key'] as String,
      labelEn: json['label_en'] as String,
      labelAr: json['label_ar'] as String?,
      emoji: json['emoji'] as String?,
      colorHex: json['color_hex'] as String?,
      gradient: json['gradient'] as Map<String, dynamic>?,
      sortOrder: json['sort_order'] as int? ?? 0,
      contexts: (json['contexts'] as List<dynamic>?)?.cast<String>() ?? [],
      theme: json['theme'] as String?,
      urgencyLevel: json['urgency_level'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      type: json['type'] as String?,
      usage: json['usage'] as String?,
      appFlavors: (json['app_flavors'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'label_en': labelEn,
      'label_ar': labelAr,
      'emoji': emoji,
      'color_hex': colorHex,
      'gradient': gradient,
      'sort_order': sortOrder,
      'contexts': contexts,
      'theme': theme,
      'urgency_level': urgencyLevel,
      'is_active': isActive,
      'type': type,
      'usage': usage,
      'app_flavors': appFlavors,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get display label based on locale (defaults to English)
  String getLabel([String locale = 'en']) {
    if (locale == 'ar' && labelAr != null) {
      return labelAr!;
    }
    return labelEn;
  }

  @override
  String toString() => 'VibeModel(key: $key, label: $labelEn, emoji: $emoji)';
}

/// Model for post_vibes join table entries
class PostVibeModel {
  final String postId;
  final String vibeId;
  final DateTime assignedAt;
  final VibeModel? vibe; // Joined vibe data

  const PostVibeModel({
    required this.postId,
    required this.vibeId,
    required this.assignedAt,
    this.vibe,
  });

  factory PostVibeModel.fromJson(Map<String, dynamic> json) {
    return PostVibeModel(
      postId: json['post_id'] as String,
      vibeId: json['vibe_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      vibe: json['vibe'] != null || json['vibes'] != null
          ? VibeModel.fromJson(
              (json['vibe'] ?? json['vibes']) as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Model for post_reactions (vibe reactions by users)
class PostReactionModel {
  final String postId;
  final String actorProfileId;
  final String vibeId;
  final DateTime createdAt;
  final VibeModel? vibe; // Joined vibe data
  final Map<String, dynamic>? actorProfile; // Joined profile data

  const PostReactionModel({
    required this.postId,
    required this.actorProfileId,
    required this.vibeId,
    required this.createdAt,
    this.vibe,
    this.actorProfile,
  });

  factory PostReactionModel.fromJson(Map<String, dynamic> json) {
    return PostReactionModel(
      postId: json['post_id'] as String,
      actorProfileId: json['actor_profile_id'] as String,
      vibeId: json['vibe_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      vibe: json['vibe'] != null || json['vibes'] != null
          ? VibeModel.fromJson(
              (json['vibe'] ?? json['vibes']) as Map<String, dynamic>,
            )
          : null,
      actorProfile: json['profile'] != null || json['profiles'] != null
          ? (json['profile'] ?? json['profiles']) as Map<String, dynamic>
          : null,
    );
  }

  String? get actorDisplayName => actorProfile?['display_name'] as String?;
  String? get actorAvatarUrl => actorProfile?['avatar_url'] as String?;
}
