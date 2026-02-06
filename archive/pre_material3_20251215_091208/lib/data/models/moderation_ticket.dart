class ModerationTicket {
  const ModerationTicket({
    required this.id,
    required this.flagId,
    required this.category,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String flagId;
  final String category;
  final String? notes;
  final String status;
  final DateTime createdAt;

  factory ModerationTicket.fromJson(Map<String, dynamic> json) {
    return ModerationTicket(
      id: json['id'] as String,
      flagId: json['flag_id'] as String,
      category: json['category'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flag_id': flagId,
      'category': category,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ModerationTicket copyWith({
    String? id,
    String? flagId,
    String? category,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return ModerationTicket(
      id: id ?? this.id,
      flagId: flagId ?? this.flagId,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModerationTicket &&
        other.id == id &&
        other.flagId == flagId &&
        other.category == category &&
        other.notes == notes &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, flagId, category, notes, status, createdAt);
}
