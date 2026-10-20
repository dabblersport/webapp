import 'dart:io';

import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/service_region_labels.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-584: the service region is one of five countries or Global, chosen by
/// the user, stored per account, never inferred.
class _Remote implements ServiceRegionRemote {
  _Remote([Map<String, String>? rows]) : rows = rows ?? <String, String>{};
  final Map<String, String> rows;
  @override
  Future<String?> fetch(String userId) async => rows[userId];
  @override
  Future<void> save(String userId, String region) async =>
      rows[userId] = region;
}

Future<String> _settled(SelectedLocationNotifier n) async {
  for (var i = 0; i < 50; i++) {
    final s = n.state;
    if (s.hasValue) return s.value!.country;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('still loading');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AC1 options and order', () {
    test('English: Egypt, Morocco, Qatar, Saudi Arabia, UAE, then Global', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(serviceRegionOptions(l, 'en').map((e) => e.$2).toList(), [
        'Egypt',
        'Morocco',
        'Qatar',
        'Saudi Arabia',
        'United Arab Emirates',
        'Global',
      ]);
    });

    test(
      'Arabic: one collation policy (article and alef variants ignored)',
      () {
        final l = lookupAppLocalizations(const Locale('ar'));
        expect(serviceRegionOptions(l, 'ar').map((e) => e.$1).toList(), [
          'United Arab Emirates', // الإمارات
          'Saudi Arabia', // السعودية
          'Qatar', // قطر
          'Egypt', // مصر
          'Morocco', // المغرب
          'Global',
        ]);
      },
    );

    test('no United Kingdom or other country appears in either language', () {
      for (final lang in ['en', 'ar']) {
        final l = lookupAppLocalizations(Locale(lang));
        final names = serviceRegionOptions(l, lang).map((e) => e.$1);
        expect(names, isNot(contains('United Kingdom')));
        expect(names.length, 6);
      }
    });
  });

  group('AC2 normalisation, no inference', () {
    test('unsupported values become Global; supported are canonical', () {
      expect(normalizeServiceRegion('United Kingdom'), 'Global');
      expect(normalizeServiceRegion('GB'), 'Global');
      expect(normalizeServiceRegion(null), 'Global');
      expect(normalizeServiceRegion(''), 'Global');
      expect(normalizeServiceRegion(' qatar '), 'Qatar');
      expect(
        normalizeServiceRegion('UNITED ARAB EMIRATES'),
        'United Arab Emirates',
      );
    });

    test(
      'a saved United Kingdom is normalised to Global and rewritten',
      () async {
        SharedPreferences.setMockInitialValues({
          'selected_country': 'United Kingdom',
        });
        final n = SelectedLocationNotifier(remote: _Remote());
        expect(await _settled(n), 'Global');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('selected_country'), 'Global');
      },
    );

    test('nothing saved: Global, with no IP or locale lookup', () async {
      final n = SelectedLocationNotifier(remote: _Remote());
      expect(await _settled(n), 'Global');
    });

    test('the region code never reads IP, locale or network detection', () {
      final src = File(
        'lib/features/auth_onboarding/presentation/providers/'
        'selected_country_provider.dart',
      ).readAsStringSync();
      expect(src.contains('LocationDetector'), isFalse);
      expect(src.contains('ip_country'), isFalse);
      expect(src.contains('PlatformDispatcher'), isFalse);
    });
  });

  group('AC3 persistence across sessions and devices', () {
    test('a choice survives a restart (same device)', () async {
      final remote = _Remote();
      final a = SelectedLocationNotifier(userId: 'u1', remote: remote);
      await _settled(a);
      await a.setCountry('Qatar');
      final b = SelectedLocationNotifier(userId: 'u1', remote: remote);
      expect(await _settled(b), 'Qatar');
    });

    test(
      'a second device of the same account gets the stored region',
      () async {
        final remote = _Remote();
        final deviceA = SelectedLocationNotifier(userId: 'u1', remote: remote);
        await _settled(deviceA);
        await deviceA.setCountry('Qatar');
        expect(remote.rows['u1'], 'Qatar');

        // Device B: its own empty local storage.
        SharedPreferences.setMockInitialValues({});
        final deviceB = SelectedLocationNotifier(userId: 'u1', remote: remote);
        expect(await _settled(deviceB), 'Qatar');
      },
    );

    test('another account on the device does not inherit the region', () async {
      final remote = _Remote();
      final a = SelectedLocationNotifier(userId: 'u1', remote: remote);
      await _settled(a);
      await a.setCountry('Egypt');
      final b = SelectedLocationNotifier(userId: 'u2', remote: remote);
      expect(await _settled(b), 'Global');
    });

    test(
      'an unsupported value cannot be selected: it becomes Global',
      () async {
        final n = SelectedLocationNotifier(userId: 'u1', remote: _Remote());
        await _settled(n);
        await n.setCountry('United Kingdom');
        expect(n.state.value!.country, 'Global');
      },
    );
  });

  group('AC4 first screen and Settings agree', () {
    test('welcome sheet, Language & region page and Settings sheet all use '
        'the one option list, with no hand-kept country list', () {
      for (final f in [
        'lib/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart',
        'lib/features/auth_onboarding/presentation/screens/language_selection_screen.dart',
        'lib/features/profile/presentation/screens/settings/settings_sheets.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('serviceRegionOptions'), reason: f);
        expect(src.contains('United Kingdom'), isFalse, reason: f);
        expect(src.contains("'Kuwait'"), isFalse, reason: f);
        expect(src.contains('refCountriesTable'), isFalse, reason: f);
      }
    });
  });

  group('AC4 separation and the migration', () {
    test('migration: own table, five countries + Global, RLS, no anon', () {
      final sql = File(
        'supabase/migrations/20261020130000_kan584_account_service_region.sql',
      ).readAsStringSync();
      expect(sql, contains('account_service_region'));
      expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('FROM PUBLIC, anon'));
      expect(sql, contains("'United Arab Emirates', 'Global'"));
      expect(sql.toLowerCase(), isNot(contains('united kingdom')));
      expect(sql.toLowerCase(), isNot(contains('drop ')));
      // Separate from the public profile country.
      expect(sql.contains('profiles'), isFalse);
    });

    test('the region code touches neither the profile country nor the device '
        'location store', () {
      final src = File(
        'lib/features/auth_onboarding/presentation/providers/'
        'selected_country_provider.dart',
      ).readAsStringSync();
      expect(src.contains('profiles'), isFalse);
      expect(src.contains('device_location'), isFalse);
    });
  });
}
