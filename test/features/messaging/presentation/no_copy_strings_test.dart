import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KAN-507: the messaging presentation layer carries state, typed reasons and
/// l10n KEY identifiers only — no user-facing English. Any quoted literal that
/// contains a space followed by a letter (a phrase) fails, except imports and
/// doc/line comments.
void main() {
  test('no English phrases in lib/features/messaging/presentation', () {
    final dir = Directory('lib/features/messaging/presentation');
    expect(dir.existsSync(), isTrue);
    final phrase = RegExp(r"""(['"])[^'"\n]*[A-Za-z]+ [A-Za-z]+[^'"\n]*\1""");
    final offenders = <String>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('import ')) continue;
        if (phrase.hasMatch(line)) offenders.add('${f.path}:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
