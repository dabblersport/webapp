import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KAN-617 criteria 2 and 3: the public profile's city/country and the private
/// saved places are separate data paths.
///
/// profile_edit_screen.dart saves through `Supabase.instance` and a private
/// `AuthService()` with no seam, so its payload cannot be recorded at run time
/// without a lib/ change (forbidden here). These tests pin the source of the
/// save instead.
String _read(String path) => File(path).readAsStringSync();

/// The text of the `{ ... }` or `( ... )` block that opens at [open] in [src].
String _block(String src, int open) {
  final opener = src[open];
  final closer = opener == '{' ? '}' : ')';
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == opener) depth++;
    if (src[i] == closer && --depth == 0) return src.substring(open, i + 1);
  }
  fail('unbalanced $opener at $open');
}

/// Whitespace-collapsed, so formatting changes do not matter but values do.
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

/// The exact expressions that tie the saved city and country to the edited
/// fields. Each is matched whole, so replacing the value side of the city
/// ternary, or an assignment to `countryToSave`, makes it go missing.
const _pins = [
  // city: the saved value is the trimmed field, null when empty
  "'city': _cityController.text.trim().isEmpty ? null : "
      '_cityController.text.trim(),',
  // country: the payload carries countryToSave, nothing else
  "'country': countryToSave,",
  // countryToSave derives only from the trimmed country field
  'final rawCountry = _countryController.text.trim();',
  'if (rawCountry.isNotEmpty) { if (rawCountry.length == 2) { '
      'countryToSave = rawCountry.toUpperCase();',
  ".eq('name_en', rawCountry)",
  'countryToSave = rows.isNotEmpty ? rows.first[\'code\'] as String? : null;',
];

/// The pins missing from [src], and any assignment to `countryToSave` beyond
/// the two pinned ones.
List<String> _unpinned(String src) {
  final flat = _flat(src);
  final missing = [
    for (final p in _pins)
      if (!flat.contains(p)) p,
  ];
  final assigns = RegExp(r'countryToSave\s*=[^=]').allMatches(flat).length;
  if (assigns != 2) missing.add('countryToSave assigned $assigns times');
  return missing;
}

const _savedPlaceTokens = [
  'profile_locations',
  'profileLocationsTable',
  'ProfileLocation',
  'profileLocationNotifierProvider',
  'profileLocationRepositoryProvider',
  'geo_location',
  'is_primary',
  'location_id',
];

void main() {
  const editScreen =
      'lib/features/profile/presentation/screens/profile_edit_screen.dart';

  group('profile edit save (criterion 2)', () {
    late String src;
    late String save;
    late String usersUpdate;

    setUpAll(() {
      src = _read(editScreen);
      // The save method: from its first updateUserProfile that is followed by
      // the direct users-table update, up to the method end.
      final updateAt = src.indexOf(
        '.from(SupabaseConfig.usersTable)\n            .update(',
      );
      expect(updateAt, greaterThan(0), reason: 'users-table update moved');
      usersUpdate = _block(src, src.indexOf('{', updateAt));
      final start = src.lastIndexOf('Future<void> ', updateAt);
      final end = src.indexOf('Future<void> _saveSportsProfiles');
      save = src.substring(start, end);
    });

    test('city and country are written from the edited fields only', () {
      expect(_unpinned(src), isEmpty);
    });

    test('the pin catches a constant city or country (counterexamples)', () {
      final constantCity = src.replaceFirst(
        ': _cityController.text.trim(),',
        ": 'Dubai',",
      );
      expect(constantCity, isNot(src));
      expect(_unpinned(constantCity), isNotEmpty);

      final constantCountry = src.replaceFirst(
        'countryToSave = rawCountry.toUpperCase();',
        "countryToSave = 'AE';",
      );
      expect(constantCountry, isNot(src));
      expect(_unpinned(constantCountry), isNotEmpty);

      final constantLookup = src.replaceFirst(
        "? rows.first['code'] as String?",
        "? 'AE'",
      );
      expect(constantLookup, isNot(src));
      expect(_unpinned(constantLookup), isNotEmpty);

      final constantPayload = src.replaceFirst(
        "'country': countryToSave,",
        "'country': 'AE',",
      );
      expect(constantPayload, isNot(src));
      expect(_unpinned(constantPayload), isNotEmpty);
    });

    test('the users payload carries no saved-place key', () {
      for (final token in _savedPlaceTokens) {
        expect(usersUpdate, isNot(contains(token)), reason: token);
      }
      // The coordinates are not part of the profile edit either.
      expect(usersUpdate, isNot(contains("'latitude'")));
      expect(usersUpdate, isNot(contains("'longitude'")));
    });

    test('the whole save path never references saved places', () {
      for (final token in _savedPlaceTokens) {
        expect(save, isNot(contains(token)), reason: token);
      }
    });

    test('the screen imports nothing from the saved-places providers', () {
      expect(src, isNot(contains('profile_location')));
      expect(src, isNot(contains('features/location/providers')));
    });
  });

  group('no saved places under profile presentation (criterion 3)', () {
    final profileUi = Directory('lib/features/profile/presentation');
    final publicScreens = ['user_profile_screen.dart', 'profile_screen.dart'];

    test('lib/features/profile/presentation/** does not read them', () {
      final files = profileUi
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      final offenders = <String>[];
      for (final f in files) {
        final text = f.readAsStringSync();
        for (final token in [
          'profile_locations',
          'profileLocationsTable',
          'ProfileLocation',
          'profileLocationNotifierProvider',
          'profileLocationRepositoryProvider',
          'profile_location_repository',
          'profile_location_providers',
        ]) {
          if (text.contains(token)) offenders.add('${f.path}: $token');
        }
      }
      expect(offenders, isEmpty);
    });

    test('the public profile screens do not read them', () {
      final found = <String>[];
      for (final name in publicScreens) {
        final hits = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('/$name'));
        for (final f in hits) {
          found.add(f.path);
          final text = f.readAsStringSync();
          for (final token in [
            'profile_locations',
            'ProfileLocation',
            'profileLocationNotifierProvider',
            'profile_location_providers',
          ]) {
            expect(text, isNot(contains(token)), reason: '${f.path}: $token');
          }
        }
      }
      expect(found, isNotEmpty, reason: 'public profile screens not found');
    });

    test('the only profile-feature reader is the owner export', () {
      final readers = Directory('lib/features/profile')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) {
            final t = f.readAsStringSync();
            return t.contains('profile_locations') ||
                t.contains('profileLocationsTable');
          })
          .map((f) => f.path)
          .toList();
      expect(readers, [
        'lib/features/profile/services/data_export_service.dart',
      ]);
    });
  });
}
