import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('This weekend (UAE: Saturday + Sunday)', () {
    const f = GamesDateFilter.thisWeekend;
    // 2026-10-05 is a Monday.
    final mon = DateTime(2026, 10, 5, 9);
    test('from Monday: the coming Saturday and Sunday only', () {
      expect(f.matches(DateTime(2026, 10, 9, 20), mon), isFalse); // Friday
      expect(f.matches(DateTime(2026, 10, 10, 8), mon), isTrue); // Saturday
      expect(f.matches(DateTime(2026, 10, 11, 23), mon), isTrue); // Sunday
      expect(f.matches(DateTime(2026, 10, 17, 8), mon), isFalse); // next Sat
    });
    test('on Saturday: today and tomorrow', () {
      final sat = DateTime(2026, 10, 10, 9);
      expect(f.matches(DateTime(2026, 10, 10, 20), sat), isTrue);
      expect(f.matches(DateTime(2026, 10, 11, 20), sat), isTrue);
      expect(f.matches(DateTime(2026, 10, 17, 20), sat), isFalse);
    });
    test('on Sunday: today only', () {
      final sun = DateTime(2026, 10, 11, 9);
      expect(f.matches(DateTime(2026, 10, 11, 20), sun), isTrue);
      expect(f.matches(DateTime(2026, 10, 17, 20), sun), isFalse);
      expect(f.matches(null, sun), isFalse);
    });
  });

  group('card status', () {
    final now = DateTime(2026, 10, 8, 18);
    GamesCardStatus st(int spots, int inMin) => gamesCardStatus(
      spotsRemaining: spots,
      startsAt: now.add(Duration(minutes: inMin)),
      now: now,
    );
    test('order and tones', () {
      expect(st(0, 30), GamesCardStatus.full);
      expect(st(5, 30), GamesCardStatus.startsSoon);
      expect(st(2, 90), GamesCardStatus.almostFull);
      expect(st(3, 90), GamesCardStatus.open);
      expect(st(3, 60), GamesCardStatus.open);
      expect(st(3, -5), GamesCardStatus.open);
      expect(gamesStatusTone(GamesCardStatus.open), DabblerProgressBarTone.info);
      expect(
        gamesStatusTone(GamesCardStatus.almostFull),
        DabblerProgressBarTone.warning,
      );
      expect(
        gamesStatusTone(GamesCardStatus.full),
        DabblerProgressBarTone.error,
      );
    });
  });

  for (final loc in const [Locale('en'), Locale('ar')]) {
    test('empty text variants - ${loc.languageCode}', () {
      final l = lookupAppLocalizations(loc);
      expect(
        gamesEmptyText(l, radiusMeters: 5000, date: GamesDateFilter.thisWeek),
        l.listing_games_empty_radius_window(5, l.listing_window_days(7)),
      );
      expect(
        gamesEmptyText(l, radiusMeters: 10000, date: GamesDateFilter.any),
        l.listing_games_empty_radius(10),
      );
      expect(
        gamesEmptyText(l, radiusMeters: null, date: GamesDateFilter.today),
        l.listing_games_empty_window(l.listing_window_today),
      );
      expect(
        gamesEmptyText(l, radiusMeters: null, date: GamesDateFilter.any),
        l.listing_games_empty_fallback,
      );
    });
  }
}
