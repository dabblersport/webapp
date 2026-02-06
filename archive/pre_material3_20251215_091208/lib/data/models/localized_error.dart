import 'package:meta/meta.dart';

@immutable
class LocalizedError {
  final String code;
  final String locale;
  final String message;
  final String? title;
  final String? hint;
  final String? severity;
  final DateTime? updatedAt;

  const LocalizedError({
    required this.code,
    required this.locale,
    required this.message,
    required this.title,
    required this.hint,
    required this.severity,
    required this.updatedAt,
  });

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory LocalizedError.fromMap(Map<String, dynamic> m) => LocalizedError(
    code: (m['code'] ?? m['key'] ?? '').toString(),
    locale: (m['locale'] ?? m['lang'] ?? 'en').toString(),
    message: (m['message'] ?? m['text'] ?? m['value'] ?? '').toString(),
    title: m['title']?.toString(),
    hint: m['hint']?.toString(),
    severity: (m['severity'] ?? m['level'])?.toString(),
    updatedAt: _dt(m['updated_at']),
  );

  Map<String, dynamic> toMap() => {
    'code': code,
    'locale': locale,
    'message': message,
    'title': title,
    'hint': hint,
    'severity': severity,
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// `{name}` style interpolation.
  String format([Map<String, String> vars = const {}]) {
    var out = message;
    vars.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }
}
