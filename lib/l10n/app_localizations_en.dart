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

  @override
  String get tab_most_recent => 'Most Recent';

  @override
  String get tab_following => 'Following';

  @override
  String get tab_nearby => 'Nearby';

  @override
  String get tab_active => 'Active';

  @override
  String get tab_news => 'News';

  @override
  String get feed_empty_no_posts => 'No posts yet';

  @override
  String get feed_empty_no_posts_hint =>
      'Share moments, dabs, and kick-ins with your community.';

  @override
  String get feed_could_not_load => 'Could not load feed';

  @override
  String get feed_retry => 'Retry';

  @override
  String get news_empty_title => 'No news right now.';

  @override
  String get news_empty_hint =>
      'Check back later for updates from the Dabbler team.';

  @override
  String get news_hide_sheet_title => 'Hide news from feed?';

  @override
  String get news_hide_sheet_body =>
      'News cards will no longer appear in Most Recent. You can still read all news in the News tab.';

  @override
  String get news_hide_confirm => 'Hide news';

  @override
  String get news_hide_cancel => 'Cancel';

  @override
  String get news_hidden_snack => 'News hidden from Most Recent';

  @override
  String get news_resubscribed_snack => 'News will now appear in Most Recent';

  @override
  String get news_resubscribe_banner => 'News is hidden from Most Recent.';

  @override
  String get news_resubscribe_action => 'Show again';
}
