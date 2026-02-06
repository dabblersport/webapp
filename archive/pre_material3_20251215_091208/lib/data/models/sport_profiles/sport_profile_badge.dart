import 'package:meta/meta.dart';

@immutable
class SportProfileBadge {
  const SportProfileBadge({
    required this.id,
    required this.key,
    this.name = '',
    this.description = '',
    this.iconUrl = '',
  });

  factory SportProfileBadge.fromJson(Map<String, dynamic> json) {
    return SportProfileBadge(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? json['badge_key'] as String? ?? '',
      name: _readString(json['name']),
      description: _readString(json['description']),
      iconUrl: _readString(json['icon_url'] ?? json['iconUrl']),
    );
  }

  final String id;
  final String key;
  final String name;
  final String description;
  final String iconUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'key': key,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
    };
  }
}

String _readString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}
