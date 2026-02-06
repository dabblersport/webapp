class BanTerm {
  const BanTerm({
    required this.id,
    required this.term,
    required this.kind,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final String term;
  final String kind;
  final bool enabled;
  final DateTime createdAt;

  factory BanTerm.fromJson(Map<String, dynamic> json) {
    return BanTerm(
      id: json['id'] as String,
      term: json['term'] as String,
      kind: json['kind'] as String,
      enabled: json['enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'term': term,
      'kind': kind,
      'enabled': enabled,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BanTerm copyWith({
    String? id,
    String? term,
    String? kind,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return BanTerm(
      id: id ?? this.id,
      term: term ?? this.term,
      kind: kind ?? this.kind,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BanTerm &&
        other.id == id &&
        other.term == term &&
        other.kind == kind &&
        other.enabled == enabled &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, term, kind, enabled, createdAt);
}
