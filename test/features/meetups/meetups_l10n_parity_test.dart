import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Meetups copy parity (KAN-432): every meetups key has Modern Standard Arabic
/// that is real (not the English), keeps the ICU placeholders and carries no
/// dialect marker.
const String _enPath = 'lib/l10n/app_en.arb';
const String _arPath = 'lib/l10n/app_ar.arb';

/// Non-`meetups_` keys that belong to the Meetups copy.
final RegExp _extraKey = RegExp(
  r'^(notif_settings_kind_meetup_|profile_stat_minutes_played$)',
);

/// Keys whose Arabic may equal the English (none today). One line of reason
/// each when one is added.
const Map<String, String> _sameAsEnglish = <String, String>{};

/// Dialect markers that must never appear in the Arabic (whole words).
const List<String> _dialect = <String>[
  'يلا',
  'يبي',
  'هاي',
  'شلون',
  'وايد',
  'ابغى',
  'شو',
  'ليش',
  'وش',
  'ايش',
];

Map<String, dynamic> _load(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String message) => RegExp(
  r'\{(\w+)\s*(?:,|\})',
).allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _load(_enPath);
  final ar = _load(_arPath);
  final keys = en.keys
      .where((k) => !k.startsWith('@'))
      .where((k) => k.startsWith('meetups_') || _extraKey.hasMatch(k))
      .toList();

  test('there are meetups keys to check', () {
    expect(keys.length, greaterThan(90));
  });

  test('every meetups key has Arabic', () {
    final missing = keys.where((k) => !ar.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'missing Arabic: $missing');
    final empty = keys
        .where((k) => ar.containsKey(k) && (ar[k] as String).trim().isEmpty)
        .toList();
    expect(empty, isEmpty, reason: 'empty Arabic: $empty');
  });

  test('Arabic differs from the English unless allow-listed', () {
    final same = keys
        .where((k) => ar[k] == en[k] && !_sameAsEnglish.containsKey(k))
        .toList();
    expect(same, isEmpty, reason: 'Arabic equals English: $same');
  });

  test('Arabic keeps the same ICU placeholders', () {
    final bad = <String>[];
    for (final k in keys) {
      final a = ar[k];
      if (a is! String) continue;
      final e = _placeholders(en[k] as String);
      final x = _placeholders(a);
      if (e.difference(x).isNotEmpty || x.difference(e).isNotEmpty) {
        bad.add('$k: en=$e ar=$x');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Arabic carries no dialect marker', () {
    final hits = <String>[];
    for (final k in keys) {
      final a = ar[k];
      if (a is! String) continue;
      final words = a.split(RegExp(r'[\s\p{P}]+', unicode: true));
      for (final d in _dialect) {
        if (words.contains(d)) hits.add('$k: $d');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('the check fails on a missing key', () {
    final fake = Map<String, dynamic>.from(ar)..remove(keys.first);
    expect(keys.where((k) => !fake.containsKey(k)), isNotEmpty);
  });

  test('allow-list entries are real and still equal the English', () {
    for (final k in _sameAsEnglish.keys) {
      expect(ar[k], en[k], reason: '$k no longer equals the English');
    }
  });
}
