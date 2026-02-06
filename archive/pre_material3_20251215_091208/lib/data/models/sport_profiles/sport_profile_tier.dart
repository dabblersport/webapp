import 'package:meta/meta.dart';

@immutable
class SportProfileTier {
  const SportProfileTier({
    required this.id,
    required this.key,
    this.minLevel = 0.0,
    this.colorPrimary = '',
    this.colorSecondary = '',
    this.iconUrl = '',
  });

  factory SportProfileTier.fromJson(Map<String, dynamic> json) {
    return SportProfileTier(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? json['tier_key'] as String? ?? '',
      minLevel: _readDouble(json['min_level'] ?? json['minLevel']),
      colorPrimary: _readString(json['color_primary'] ?? json['colorPrimary']),
      colorSecondary: _readString(
        json['color_secondary'] ?? json['colorSecondary'],
      ),
      iconUrl: _readString(json['icon_url'] ?? json['iconUrl']),
    );
  }

  final String id;
  final String key;
  final double minLevel;
  final String colorPrimary;
  final String colorSecondary;
  final String iconUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'key': key,
      'min_level': minLevel,
      'color_primary': colorPrimary,
      'color_secondary': colorSecondary,
      'icon_url': iconUrl,
    };
  }
}

double _readDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

String _readString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}
