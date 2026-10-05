// EN/AR parity gate (KAN-435). Reads the ARB sources directly; no codegen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AR value may equal EN only for these keys (provisional; align with the
/// content review once it lists the legitimately identical keys).
const Map<String, String> _identicalAllowed = {
  'auth_email_placeholder': 'sample email address, LTR token',
  'email_input_hint': 'email format hint, LTR token',
  'email_password_hint_email': 'email format hint, LTR token',
  'post_card_kind_dab': 'brand term "Dab"',
  'post_card_kind_kick_in': 'brand term "Kick-in"',
  'post_card_kick_in_label': 'brand term "Kick-in"',
  'settings_version_app_name': 'brand name "Dabbler"',
  'notif_quiet_hours_range': 'time range placeholders only',
  'region_lang_en': 'language endonym is shown in its own script',
  'region_lang_ar': 'language endonym is shown in its own script',
  'refine': 'provisional: identical until the content review decides',
};

const _validCategories = {'zero', 'one', 'two', 'few', 'many', 'other'};

class _Msg {
  _Msg(this.placeholders, this.plurals);
  final Set<String> placeholders;

  /// selector arg -> set of categories (`one`, `=1`, ...).
  final Map<String, Set<String>> plurals;
}

/// Brace-aware ICU scan: collects argument names and plural clauses.
_Msg parseIcu(String s) {
  final ph = <String>{};
  final pl = <String, Set<String>>{};
  void scan(String text) {
    var i = 0;
    while (i < text.length) {
      if (text[i] != '{') {
        i++;
        continue;
      }
      var depth = 1;
      var j = i + 1;
      while (j < text.length && depth > 0) {
        if (text[j] == '{') depth++;
        if (text[j] == '}') depth--;
        j++;
      }
      final body = text.substring(i + 1, j - 1);
      final m = RegExp(
        r'^\s*(\w+)\s*(?:,\s*(plural|select)\s*,(.*))?$',
        dotAll: true,
      ).firstMatch(body);
      if (m != null) {
        ph.add(m.group(1)!);
        if (m.group(2) != null) {
          final cats = <String>{};
          final rest = m.group(3)!;
          var k = 0;
          while (k < rest.length) {
            final c = RegExp(r'\s*(=?\w+)\s*\{').matchAsPrefix(rest, k);
            if (c == null) break;
            cats.add(c.group(1)!);
            var d = 1;
            var e = c.end;
            while (e < rest.length && d > 0) {
              if (rest[e] == '{') d++;
              if (rest[e] == '}') d--;
              e++;
            }
            scan(rest.substring(c.end, e - 1));
            k = e;
          }
          if (m.group(2) == 'plural') pl[m.group(1)!] = cats;
        }
      }
      i = j;
    }
  }

  scan(s);
  return _Msg(ph, pl);
}

/// Returns human-readable problems; empty means parity holds.
List<String> checkParity(
  Map<String, dynamic> en,
  Map<String, dynamic> ar, {
  Map<String, String> allowIdentical = _identicalAllowed,
}) {
  final out = <String>[];
  for (final k in en.keys.where((k) => !k.startsWith('@'))) {
    final e = en[k];
    if (e is! String) continue;
    final a = ar[k];
    if (a is! String) {
      out.add('$k: missing in AR');
      continue;
    }
    if (a.trim().isEmpty) {
      out.add('$k: empty AR value');
      continue;
    }
    if (a.trim() == e.trim() && !allowIdentical.containsKey(k)) {
      out.add('$k: AR equals English text');
    }
    final pe = parseIcu(e);
    final pa = parseIcu(a);
    if (pe.placeholders.difference(pa.placeholders).isNotEmpty ||
        pa.placeholders.difference(pe.placeholders).isNotEmpty) {
      out.add(
        '$k: placeholder mismatch EN ${(pe.placeholders.toList()..sort())}'
        ' vs AR ${(pa.placeholders.toList()..sort())}',
      );
    }
    for (final arg in pe.plurals.keys) {
      final cats = pa.plurals[arg];
      if (cats == null) {
        out.add('$k: EN plural on {$arg} but AR has no plural on it');
        continue;
      }
      final bad = cats.where(
        (c) => !c.startsWith('=') && !_validCategories.contains(c),
      );
      if (bad.isNotEmpty) out.add('$k: invalid AR plural category $bad');
      if (!cats.contains('other')) out.add('$k: AR plural lacks "other"');
      final shows = e.contains('{$arg}');
      if (shows && !cats.contains('few') && !cats.contains('many')) {
        out.add('$k: AR plural shows {$arg} but has no few/many category');
      }
    }
  }
  return out;
}

void main() {
  Map<String, dynamic> load(String p) =>
      json.decode(File(p).readAsStringSync()) as Map<String, dynamic>;

  test('real ARBs: every EN key has a proper AR value', () {
    final problems = checkParity(
      load('lib/l10n/app_en.arb'),
      load('lib/l10n/app_ar.arb'),
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('self-test (synthetic maps)', () {
    final en = {
      'a': 'Hello',
      'b': 'Hi {name}',
      'c': '{count, plural, =1{1 item} other{{count} items}}',
    };
    final good = {
      'a': 'مرحبا',
      'b': 'أهلا {name}',
      'c':
          '{count, plural, =1{عنصر} =2{عنصران} few{{count} عناصر} '
          'other{{count} عنصرا}}',
    };
    test('passes on a correct map', () {
      expect(checkParity(en, good), isEmpty);
    });
    test('fails on a missing key', () {
      expect(checkParity(en, {...good}..remove('a')), isNotEmpty);
    });
    test('fails on an empty value', () {
      expect(checkParity(en, {...good, 'a': '  '}), isNotEmpty);
    });
    test('fails on an English-equal value, unless allow-listed', () {
      expect(checkParity(en, {...good, 'a': 'Hello'}), isNotEmpty);
      expect(
        checkParity(
          en,
          {...good, 'a': 'Hello'},
          allowIdentical: {'a': 'brand'},
        ),
        isEmpty,
      );
    });
    test('fails on a placeholder mismatch', () {
      expect(checkParity(en, {...good, 'b': 'أهلا {nom}'}), isNotEmpty);
    });
    test('fails on plural without Arabic categories', () {
      expect(
        checkParity(en, {
          ...good,
          'c': '{count, plural, =1{عنصر} other{{count} عنصر}}',
        }),
        isNotEmpty,
      );
      expect(checkParity(en, {...good, 'c': 'عناصر {count}'}), isNotEmpty);
    });
  });
}
