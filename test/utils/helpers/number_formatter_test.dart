import 'package:dabbler/utils/helpers/number_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumberFormatter.format', () {
    test('below 1000 returns toString()', () {
      expect(NumberFormatter.format(0), '0');
      expect(NumberFormatter.format(1), '1');
      expect(NumberFormatter.format(999), '999');
      expect(NumberFormatter.format(-5), '-5');
    });

    test('at or above 1000 uses compact notation', () {
      expect(NumberFormatter.format(1000), '1K');
      expect(NumberFormatter.format(1500), '1.5K');
      expect(NumberFormatter.format(999999), '1M');
      expect(NumberFormatter.format(1000000), '1M');
      expect(NumberFormatter.format(2500000), '2.5M');
    });
  });

  group('NumberFormatter.formatWithCommas', () {
    test('below 1000 has no separator', () {
      expect(NumberFormatter.formatWithCommas(0), '0');
      expect(NumberFormatter.formatWithCommas(7), '7');
      expect(NumberFormatter.formatWithCommas(999), '999');
    });

    test('at or above 1000 inserts thousand separators', () {
      expect(NumberFormatter.formatWithCommas(1000), '1,000');
      expect(NumberFormatter.formatWithCommas(1234), '1,234');
      expect(NumberFormatter.formatWithCommas(1234567), '1,234,567');
    });

    test('negative keeps sign and separators', () {
      expect(NumberFormatter.formatWithCommas(-1234), '-1,234');
    });
  });

  group('NumberFormatter.formatPoints', () {
    test('below 1000 prints the raw value', () {
      expect(NumberFormatter.formatPoints(0), '0 pts');
      expect(NumberFormatter.formatPoints(999), '999 pts');
    });

    test('K branch', () {
      expect(NumberFormatter.formatPoints(1000), '1.0K pts');
      expect(NumberFormatter.formatPoints(1500), '1.5K pts');
      // Quirk: rounding pushes 999999 to "1000.0K" instead of "1.0M".
      expect(NumberFormatter.formatPoints(999999), '1000.0K pts');
    });

    test('M branch', () {
      expect(NumberFormatter.formatPoints(1000000), '1.0M pts');
      expect(NumberFormatter.formatPoints(2500000), '2.5M pts');
    });
  });

  group('NumberFormatter.formatRank', () {
    test('ordinal suffixes', () {
      const cases = <int, String>{
        1: '1st',
        2: '2nd',
        3: '3rd',
        4: '4th',
        11: '11th',
        12: '12th',
        13: '13th',
        21: '21st',
        22: '22nd',
        23: '23rd',
        101: '101st',
        111: '111th',
        112: '112th',
        113: '113th',
      };
      cases.forEach((input, expected) {
        expect(NumberFormatter.formatRank(input), expected, reason: '$input');
      });
    });

    test('zero and negatives (current behaviour)', () {
      expect(NumberFormatter.formatRank(0), '0th');
      // Quirk: Dart % is non-negative, so -1 % 10 == 9 -> "th".
      expect(NumberFormatter.formatRank(-1), '-1th');
      expect(NumberFormatter.formatRank(-2), '-2th');
    });
  });
}
