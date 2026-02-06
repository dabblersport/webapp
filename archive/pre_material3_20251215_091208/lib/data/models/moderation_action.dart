class ModerationAction {
  const ModerationAction({
    required this.id,
    this.ticketId,
    required this.subjectType,
    required this.subjectId,
    required this.action,
    this.reason,
    this.meta,
    required this.createdAt,
  });

  final String id;
  final String? ticketId;
  final String subjectType;
  final String subjectId;
  final String action;
  final String? reason;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    return ModerationAction(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String?,
      subjectType: json['subject_type'] as String,
      subjectId: json['subject_id'] as String,
      action: json['action'] as String,
      reason: json['reason'] as String?,
      meta: json['meta'] == null
          ? null
          : Map<String, dynamic>.from(json['meta'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'subject_type': subjectType,
      'subject_id': subjectId,
      'action': action,
      'reason': reason,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ModerationAction copyWith({
    String? id,
    String? ticketId,
    String? subjectType,
    String? subjectId,
    String? action,
    String? reason,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) {
    return ModerationAction(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      action: action ?? this.action,
      reason: reason ?? this.reason,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModerationAction &&
        other.id == id &&
        other.ticketId == ticketId &&
        other.subjectType == subjectType &&
        other.subjectId == subjectId &&
        other.action == action &&
        other.reason == reason &&
        _mapEquals(other.meta, meta) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    ticketId,
    subjectType,
    subjectId,
    action,
    reason,
    meta == null ? null : Object.hashAll(meta!.entries),
    createdAt,
  );

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) {
        return false;
      }
    }
    return true;
  }
}
