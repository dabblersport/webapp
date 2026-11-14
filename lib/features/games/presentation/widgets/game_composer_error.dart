import 'package:dabbler/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Why a Create game load / submit failed. The notifier holds the code (and
/// its data); the widget turns it into words with `AppLocalizations`, so no
/// English text lives in the notifier (KAN-477).
enum GameComposerErrorCode {
  loadFailed,
  dailyLimit,
  sportUnavailable,
  invalidFormat,
  invalidTimeRange,
  profileIncomplete,
  notEditable,

  /// The game changed since the edit form read it (KAN-935).
  staleUpdate,
  playerRange,
  playerCountMin,
  priceRequired,

  /// Repeat is on but there is neither a venue nor a saved location (KAN-697).
  seriesLocationRequired,

  /// KAN-934: the server refused this persona / actor (`persona_not_allowed`,
  /// `no_profile_of_requested_type`).
  createRefused,

  /// KAN-934: no signed-in user (`not_authenticated`).
  authRequired,

  /// KAN-934: the repeat schedule was refused (`series_frequency_invalid`,
  /// `series_schedule_required`).
  seriesInvalid,

  /// KAN-934: a paid game cannot repeat (`series_paid_not_supported`,
  /// `free_meetups_only`).
  seriesPaid,

  /// KAN-934: the venue space is paid (`joining_rule` 'paid') and the price
  /// is 0. Checked before anything is sent.
  paidSpacePrice,

  /// A failure with no code of its own. Shows the generic sentence; the
  /// server's text is kept in [GameComposerError.raw] for diagnosis only and
  /// is never shown (KAN-934).
  unknown,
}

/// A [GameComposerErrorCode] with the data its message needs.
class GameComposerError {
  const GameComposerError(this.code, {this.resetAt, this.raw});

  final GameComposerErrorCode code;

  /// [GameComposerErrorCode.dailyLimit]: when the daily limit resets.
  final DateTime? resetAt;

  /// [GameComposerErrorCode.unknown]: the server's text, never shown.
  final String? raw;

  /// The code for a server error message (`rpc_create_game`,
  /// `rpc_create_game_series` and `rpc_update_game` raise these as the
  /// exception message); anything else is [unknown].
  factory GameComposerError.fromServer(String message) => switch (message) {
    'sport_not_challenge_eligible' ||
    'sport_not_challenge' ||
    'invalid_sport' => const GameComposerError(
      GameComposerErrorCode.sportUnavailable,
    ),
    'invalid_sport_variant' => const GameComposerError(
      GameComposerErrorCode.invalidFormat,
    ),
    'invalid_time_range' => const GameComposerError(
      GameComposerErrorCode.invalidTimeRange,
    ),
    'creator_profile_not_found' => const GameComposerError(
      GameComposerErrorCode.profileIncomplete,
    ),
    // KAN-935: rpc_update_game's stale guard (errcode 40001).
    'stale_update' => const GameComposerError(
      GameComposerErrorCode.staleUpdate,
    ),
    'not_host_or_not_found' => const GameComposerError(
      GameComposerErrorCode.notEditable,
    ),
    'invalid_player_range' => const GameComposerError(
      GameComposerErrorCode.playerRange,
    ),
    'price_required' => const GameComposerError(
      GameComposerErrorCode.priceRequired,
    ),
    'invalid_min_players' || 'invalid_max_players' || 'invalid_bench_slots' =>
      const GameComposerError(GameComposerErrorCode.playerCountMin),
    'persona_not_allowed' ||
    'organiser_required' ||
    'no_profile_of_requested_type' => const GameComposerError(
      GameComposerErrorCode.createRefused,
    ),
    'not_authenticated' || 'auth_required' => const GameComposerError(
      GameComposerErrorCode.authRequired,
    ),
    'series_frequency_invalid' || 'series_schedule_required' =>
      const GameComposerError(GameComposerErrorCode.seriesInvalid),
    'series_paid_not_supported' || 'free_meetups_only' =>
      const GameComposerError(GameComposerErrorCode.seriesPaid),
    _ => GameComposerError(GameComposerErrorCode.unknown, raw: message),
  };

  /// The message in [l]'s language; [locale] formats the daily-limit reset.
  String text(AppLocalizations l, String locale) => switch (code) {
    GameComposerErrorCode.loadFailed => l.game_load_failed,
    GameComposerErrorCode.dailyLimit => l.game_error_daily_limit(
      DateFormat(
        'MMM d, HH:mm',
        locale,
      ).format((resetAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal()),
    ),
    GameComposerErrorCode.sportUnavailable => l.game_error_sport_unavailable,
    GameComposerErrorCode.invalidFormat => l.game_error_invalid_format,
    GameComposerErrorCode.invalidTimeRange => l.game_error_invalid_time_range,
    GameComposerErrorCode.profileIncomplete => l.game_error_profile_incomplete,
    GameComposerErrorCode.notEditable => l.game_error_not_editable,
    GameComposerErrorCode.staleUpdate => l.game_error_stale_update,
    GameComposerErrorCode.playerRange => l.game_error_player_range,
    GameComposerErrorCode.playerCountMin => l.game_error_player_count_min,
    GameComposerErrorCode.priceRequired => l.game_price_required,
    GameComposerErrorCode.seriesLocationRequired =>
      l.recurring_location_required,
    GameComposerErrorCode.createRefused => l.game_err_create_refused,
    GameComposerErrorCode.authRequired => l.game_err_auth_required,
    GameComposerErrorCode.seriesInvalid => l.game_err_series_invalid,
    GameComposerErrorCode.seriesPaid => l.recurring_paid_disabled,
    GameComposerErrorCode.paidSpacePrice => l.game_err_paid_space_price,
    GameComposerErrorCode.unknown => l.game_error_generic,
  };
}
