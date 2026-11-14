// KAN-927: the daily-limit reset time is the server's UTC instant shown in the
// viewer's local time. The Dubai expectation (14:46Z -> 18:46) runs when the
// process is in a +04:00 zone: `TZ=Asia/Dubai flutter test <this file>`; the
// zone-independent expectation runs everywhere (CI is UTC).
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;

bool get _inDubaiOffset =>
    DateTime(2026, 11, 14, 18).timeZoneOffset == const Duration(hours: 4);

Future<String> _render(WidgetTester tester, String locale) async {
  final cooldown = CooldownResult.fromJson(const {
    'allowed': false,
    'remaining': 0,
    'reset_at': '2026-11-14T14:46:00+00:00',
  });
  final error = GameComposerError(
    GameComposerErrorCode.dailyLimit,
    resetAt: cooldown.resetAt,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Text(
          error.text(AppLocalizations.of(context), locale),
          key: const Key('err'),
        ),
      ),
    ),
  );
  return tester.widget<Text>(find.byKey(const Key('err'))).data!;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('$locale: reset time is shown in local time', (tester) async {
      final text = await _render(tester, locale);
      final local = DateTime.utc(2026, 11, 14, 14, 46).toLocal();
      expect(
        text,
        contains(DateFormat('MMM d, HH:mm', locale).format(local)),
        reason: text,
      );
      if (_inDubaiOffset) {
        expect(
          text,
          contains(
            DateFormat(
              'MMM d, HH:mm',
              locale,
            ).format(DateTime(2026, 11, 14, 18, 46)),
          ),
          reason: text,
        );
        if (locale == 'en') {
          expect(text, 'Daily limit reached. Try again at Nov 14, 18:46.');
        }
      }
    });
  }
}
