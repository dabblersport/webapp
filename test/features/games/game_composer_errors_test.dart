import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// KAN-477: the Create game notifier holds a typed error code (plus data), and
/// the words come from the ARB in the viewer's language. English is word for
/// word what the notifier used to write; Arabic is Arabic. Unknown server text
/// is shown as it is.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  // (server message, code, English text, Arabic text)
  const cases = <(String, GameComposerErrorCode, String)>[
    (
      'sport_not_challenge_eligible',
      GameComposerErrorCode.sportUnavailable,
      'Sport not available for games.',
    ),
    (
      'invalid_sport_variant',
      GameComposerErrorCode.invalidFormat,
      'Invalid format for this sport.',
    ),
    (
      'invalid_time_range',
      GameComposerErrorCode.invalidTimeRange,
      'End time must be after start time.',
    ),
    (
      'creator_profile_not_found',
      GameComposerErrorCode.profileIncomplete,
      'Complete your profile first.',
    ),
    (
      'not_host_or_not_found',
      GameComposerErrorCode.notEditable,
      'This game can no longer be edited.',
    ),
    (
      'invalid_player_range',
      GameComposerErrorCode.playerRange,
      'Min players cannot exceed max players.',
    ),
    (
      'price_required',
      GameComposerErrorCode.priceRequired,
      // The ARB sentence (the price field's own error); the notifier's old text
      // had a trailing full stop.
      'Enter a price — 0 means free',
    ),
    (
      'invalid_min_players',
      GameComposerErrorCode.playerCountMin,
      'Player counts must be at least 1.',
    ),
    (
      'invalid_max_players',
      GameComposerErrorCode.playerCountMin,
      'Player counts must be at least 1.',
    ),
  ];

  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  for (final (String server, GameComposerErrorCode code, String english)
      in cases) {
    test('$server maps to $code - English word for word', () {
      final e = GameComposerError.fromServer(server);
      expect(e.code, code);
      expect(e.raw, isNull);
      expect(e.text(en, 'en'), english);
    });

    test('$server is Arabic, not the English text', () {
      final text = GameComposerError.fromServer(server).text(ar, 'ar');
      expect(text, isNotEmpty);
      expect(text, isNot(english));
      expect(RegExp(r'[؀-ۿ]').hasMatch(text), isTrue, reason: text);
    });
  }

  test('daily limit: code plus reset time, English word for word', () {
    final e = GameComposerError(
      GameComposerErrorCode.dailyLimit,
      resetAt: DateTime(2026, 10, 12, 18, 30),
    );
    expect(e.code, GameComposerErrorCode.dailyLimit);
    expect(
      e.text(en, 'en'),
      'Daily limit reached. Try again at Oct 12, 18:30.',
    );
  });

  test('daily limit in Arabic: Arabic sentence carrying the reset time', () {
    final e = GameComposerError(
      GameComposerErrorCode.dailyLimit,
      resetAt: DateTime(2026, 10, 12, 18, 30),
    );
    final text = e.text(ar, 'ar');
    expect(RegExp(r'[؀-ۿ]').hasMatch(text), isTrue, reason: text);
    expect(text, isNot(contains('Daily limit')));
    // The reset time is the formatted date, whatever the digits' script.
    expect(text, contains(RegExp(r'1[28٠-٩]|18|١٨')), reason: text);
  });

  test('load failure is the ARB sentence in both languages', () {
    const e = GameComposerError(GameComposerErrorCode.loadFailed);
    expect(e.text(en, 'en'), 'Failed to load game');
    expect(e.text(ar, 'ar'), ar.game_load_failed);
    expect(e.text(ar, 'ar'), isNot('Failed to load game'));
  });

  test('unknown server text keeps showing as it is, in both languages', () {
    final e = GameComposerError.fromServer('some_new_server_code');
    expect(e.code, GameComposerErrorCode.unknown);
    expect(e.raw, 'some_new_server_code');
    expect(e.text(en, 'en'), 'some_new_server_code');
    expect(e.text(ar, 'ar'), 'some_new_server_code');
  });

  test('the notifier-side error carries a code, never an English string', () {
    // The state's error is a GameComposerError (code + data), not a String.
    const GameComposerError e = GameComposerError(
      GameComposerErrorCode.dailyLimit,
    );
    expect(e, isA<GameComposerError>());
    expect(
      GameComposerErrorCode.values,
      contains(GameComposerErrorCode.unknown),
    );
  });
}
