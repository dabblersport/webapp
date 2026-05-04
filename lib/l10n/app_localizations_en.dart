// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get games_browse_empty_title => 'No public games yet';

  @override
  String get games_browse_empty_desc => 'Check back later.';

  @override
  String get games_browse_error => 'We couldn\'t load public games.';

  @override
  String get my_games_empty_title => 'You haven\'t joined any games yet';

  @override
  String get my_games_empty_desc => 'Join a public game to see it here.';

  @override
  String get error_generic => 'Something went wrong';

  @override
  String get game_full => 'Game is full';

  @override
  String get game_waitlisted => 'You\'re on the waitlist';

  @override
  String get pull_to_refresh => 'Pull to refresh';

  @override
  String get rating_thanks => 'Thanks for your rating!';

  @override
  String get rating_submit_error => 'Couldn\'t submit rating.';

  @override
  String get venues_search_disabled_mvp => 'Search is disabled in the MVP';
}
