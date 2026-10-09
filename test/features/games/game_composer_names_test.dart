import 'package:dabbler/features/games/presentation/widgets/game_composer_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-484: the composer's choose-by-locale name helper.
void main() {
  group('localizedName', () {
    test('Arabic returns name_ar when present', () {
      expect(
        localizedName(nameEn: 'Doubles', nameAr: 'زوجي', arabic: true),
        'زوجي',
      );
    });
    test('Arabic falls back to name_en when name_ar is null', () {
      expect(
        localizedName(nameEn: 'Doubles', nameAr: null, arabic: true),
        'Doubles',
      );
    });
    test('Arabic falls back to name_en when name_ar is empty or blank', () {
      expect(
        localizedName(nameEn: 'Doubles', nameAr: '', arabic: true),
        'Doubles',
      );
      expect(
        localizedName(nameEn: 'Doubles', nameAr: '   ', arabic: true),
        'Doubles',
      );
    });
    test('English returns name_en even when name_ar exists', () {
      expect(
        localizedName(nameEn: 'Doubles', nameAr: 'زوجي', arabic: false),
        'Doubles',
      );
    });
    test('both missing returns an empty string', () {
      expect(localizedName(nameEn: null, nameAr: null, arabic: true), '');
      expect(localizedName(nameEn: ' ', nameAr: '', arabic: false), '');
    });
    test('localizedNameFor and localizedRowName key by language code', () {
      expect(localizedNameFor('ar', nameEn: 'A', nameAr: 'ب'), 'ب');
      expect(localizedNameFor('en', nameEn: 'A', nameAr: 'ب'), 'A');
      final row = <String, dynamic>{'name_en': 'Court 1', 'name_ar': 'ملعب 1'};
      expect(localizedRowName(row, 'ar'), 'ملعب 1');
      expect(localizedRowName(row, 'en'), 'Court 1');
    });
  });

  group('namesMatch', () {
    test('Latin is case-insensitive', () {
      expect(namesMatch('padel', <String?>['Padel Pro', null]), isTrue);
      expect(namesMatch('PRO', <String?>['Padel Pro']), isTrue);
    });
    test('Arabic is a plain contains', () {
      expect(namesMatch('بادل', <String?>[null, 'نادي بادل']), isTrue);
      expect(namesMatch('ملعب', <String?>['Court 1']), isFalse);
    });
  });
}
