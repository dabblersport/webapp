import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// KAN-552: the reported message text may live only in the panel's memory.
// None of the new source files may print, log, track, copy or persist.
const _files = [
  'lib/features/admin/presentation/screens/admin_message_reports_screen.dart',
  'lib/features/admin/presentation/widgets/admin_reported_message_panel.dart',
  'lib/features/admin/presentation/providers/admin_message_reports_providers.dart',
  'lib/features/admin/presentation/admin_message_reports_route.dart',
  'lib/features/messaging/domain/models/report_row.dart',
  'lib/features/messaging/domain/moderation_reports_repository.dart',
  'lib/features/messaging/data/fake_moderation_reports_repository.dart',
];

final _forbidden = RegExp(
  r'\bprint\(|debugPrint|\blog\(|logger|analytics|Sentry|Crashlytics|'
  r'Clipboard|SharedPreferences|shared_preferences|writeAs|FlutterSecureStorage|'
  r'Hive\b|dart:io',
  caseSensitive: false,
);

void main() {
  for (final path in _files) {
    test('$path has no logging, tracking, clipboard or storage', () {
      final lines = File(path).readAsLinesSync();
      final hits = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue; // doc comments only
        if (_forbidden.hasMatch(line)) hits.add('${i + 1}: $line');
      }
      expect(hits, isEmpty);
    });
  }

  test('the read path in the Worker repository logs nothing', () {
    final src = File(
      'lib/features/messaging/data/worker_messaging_repository.dart',
    ).readAsStringSync();
    expect(_forbidden.hasMatch(src), isFalse);
  });
}
