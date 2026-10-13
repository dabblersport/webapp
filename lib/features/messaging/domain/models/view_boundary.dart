import 'package:equatable/equatable.dart';

/// The kind of a [ViewBoundary]. Today only `left_at_seq`.
enum ViewBoundaryKind {
  /// The caller left the game: history is visible up to and including [ViewBoundary.seq].
  leftAtSeq('left_at_seq');

  const ViewBoundaryKind(this.wireName);
  final String wireName;

  static ViewBoundaryKind? fromWire(String? name) {
    for (final k in values) {
      if (k.wireName == name) return k;
    }
    return null;
  }
}

/// A typed limit on what the caller may view, enforced by the server (the
/// client applies no rule of its own).
class ViewBoundary extends Equatable {
  const ViewBoundary({required this.kind, required this.seq});

  final ViewBoundaryKind kind;
  final int seq;

  /// Null for a null or unrecognised boundary (a newer server kind is ignored
  /// rather than crashing an older app).
  static ViewBoundary? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final kind = ViewBoundaryKind.fromWire(json['kind'] as String?);
    final seq = json['seq'];
    if (kind == null || seq is! int) return null;
    return ViewBoundary(kind: kind, seq: seq);
  }

  Map<String, dynamic> toJson() => {'kind': kind.wireName, 'seq': seq};

  @override
  List<Object?> get props => [kind, seq];
}
