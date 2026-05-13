import 'package:flutter/widgets.dart';

/// Lightweight model for a sport from the `sports` table.
///
/// Used by the sport picker in post creation.
class Sport {
  const Sport({
    required this.id,
    required this.nameEn,
    this.nameAr,
    this.sportKey,
    this.emoji,
    this.category,
    this.colorCode,
  });

  final String id;
  final String nameEn;
  final String? nameAr;
  final String? sportKey; // text key used in sport_profiles.sport_key
  final String? emoji;
  final String? category;
  final String? colorCode;

  /// Returns the locale-appropriate display name. Falls back to English when
  /// the Arabic translation is missing.
  String localizedName(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ar') {
      final ar = nameAr?.trim();
      if (ar != null && ar.isNotEmpty) return ar;
    }
    return nameEn;
  }

  factory Sport.fromMap(Map<String, dynamic> map) {
    return Sport(
      id: map['id'] as String,
      nameEn: (map['name_en'] as String?) ?? '',
      nameAr: map['name_ar'] as String?,
      sportKey: map['sport_key'] as String?,
      emoji: map['emoji'] as String?,
      category: map['category'] as String?,
      colorCode: map['color_code'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name_en': nameEn,
    'name_ar': nameAr,
    'sport_key': sportKey,
    'emoji': emoji,
    'category': category,
    'color_code': colorCode,
  };

  @override
  String toString() => 'Sport(id: $id, nameEn: $nameEn, emoji: $emoji)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Sport && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
