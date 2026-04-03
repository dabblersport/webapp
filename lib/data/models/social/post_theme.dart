/// Lightweight model representing a post theme from the `post_themes` table.
///
/// System posts reference a theme via `post_theme_id` FK.
/// The repository batch-fetches themes and injects them into the row
/// so [Post.fromJson] can parse the nested `post_theme` key.
class PostTheme {
  const PostTheme({
    required this.id,
    required this.name,
    required this.backgroundType,
    this.backgroundColor,
    this.gradientStart,
    this.gradientEnd,
    this.imageUrl,
    this.fontStyle = 'regular',
    this.isSystem = false,
  });

  final String id;
  final String name;

  /// One of: `color`, `gradient`, `image`.
  final String backgroundType;

  /// Hex color string (e.g. `#1E1E1E`). Used when `backgroundType == 'color'`.
  final String? backgroundColor;

  /// Hex color for gradient start. Used when `backgroundType == 'gradient'`.
  final String? gradientStart;

  /// Hex color for gradient end. Used when `backgroundType == 'gradient'`.
  final String? gradientEnd;

  /// Optional background image URL. Used when `backgroundType == 'image'`.
  final String? imageUrl;

  /// Font style hint: `regular`, `bold`, `italic`.
  final String fontStyle;

  /// Whether this theme was system-generated.
  final bool isSystem;

  factory PostTheme.fromMap(Map<String, dynamic> map) {
    return PostTheme(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Untitled',
      backgroundType: (map['background_type'] as String?) ?? 'color',
      backgroundColor: map['background_color'] as String?,
      gradientStart: map['gradient_start'] as String?,
      gradientEnd: map['gradient_end'] as String?,
      imageUrl: map['image_url'] as String?,
      fontStyle: (map['font_style'] as String?) ?? 'regular',
      isSystem: (map['is_system'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'background_type': backgroundType,
    'background_color': backgroundColor,
    'gradient_start': gradientStart,
    'gradient_end': gradientEnd,
    'image_url': imageUrl,
    'font_style': fontStyle,
    'is_system': isSystem,
  };

  @override
  String toString() =>
      'PostTheme(id: $id, name: $name, backgroundType: $backgroundType)';
}
