/// Lightweight model representing a vibe from the `vibes` table.
///
/// Vibes are now linked to posts directly via the `vibe_id` FK column.
/// The repository synthesises a `post_vibes` key for [Post.fromJson].
class Vibe {
  const Vibe({
    required this.id,
    required this.key,
    required this.labelEn,
    required this.labelAr,
    this.emoji,
    this.colorHex,
    this.contexts = const [],
    this.type,
  });

  final String id;
  final String key;
  final String labelEn;
  final String labelAr;
  final String? emoji;
  final String? colorHex;

  /// Allowed post kinds this vibe is compatible with (e.g. `['moment', 'dab']`).
  final List<String> contexts;

  /// Vibe type for filtering (e.g. `'feeling'`, `'action'`).
  final String? type;

  factory Vibe.fromMap(Map<String, dynamic> map) {
    return Vibe(
      id: map['id'] as String,
      key: map['key'] as String,
      labelEn: (map['label_en'] as String?) ?? '',
      labelAr: (map['label_ar'] as String?) ?? '',
      emoji: map['emoji'] as String?,
      colorHex: map['color_hex'] as String?,
      contexts:
          (map['contexts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      type: map['type'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'key': key,
    'label_en': labelEn,
    'label_ar': labelAr,
    'emoji': emoji,
    'color_hex': colorHex,
    'contexts': contexts,
    'type': type,
  };

  @override
  String toString() =>
      'Vibe(id: $id, key: $key, labelEn: $labelEn, emoji: $emoji, colorHex: $colorHex)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Vibe && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
