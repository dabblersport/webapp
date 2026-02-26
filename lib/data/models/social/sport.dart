/// Lightweight model for a sport from the `sports` table.
///
/// Used by the sport picker in post creation.
class Sport {
  const Sport({
    required this.id,
    required this.nameEn,
    this.emoji,
    this.category,
  });

  final String id;
  final String nameEn;
  final String? emoji;
  final String? category;

  factory Sport.fromMap(Map<String, dynamic> map) {
    return Sport(
      id: map['id'] as String,
      nameEn: (map['name_en'] as String?) ?? '',
      emoji: map['emoji'] as String?,
      category: map['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name_en': nameEn,
    'emoji': emoji,
    'category': category,
  };

  @override
  String toString() => 'Sport(id: $id, nameEn: $nameEn, emoji: $emoji)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Sport && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
