import 'package:dabbler/core/utils/json.dart';

class Vibe {
  final String postId;
  final String vibe; // e.g. "fire", "clap", "100" or any product-defined token
  final DateTime createdAt;

  const Vibe({
    required this.postId,
    required this.vibe,
    required this.createdAt,
  });

  factory Vibe.fromMap(Map<String, dynamic> map) {
    final m = asMap(map);
    return Vibe(
      postId: asString(m['post_id']),
      vibe: asString(m['vibe']),
      createdAt: DateTime.parse(asString(m['created_at'])).toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
    'post_id': postId,
    'vibe': vibe,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}
