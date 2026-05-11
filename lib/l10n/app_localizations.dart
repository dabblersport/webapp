import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @games_browse_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No public games yet'**
  String get games_browse_empty_title;

  /// No description provided for @games_browse_empty_desc.
  ///
  /// In en, this message translates to:
  /// **'Check back later.'**
  String get games_browse_empty_desc;

  /// No description provided for @games_browse_error.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load public games.'**
  String get games_browse_error;

  /// No description provided for @my_games_empty_title.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined any games yet'**
  String get my_games_empty_title;

  /// No description provided for @my_games_empty_desc.
  ///
  /// In en, this message translates to:
  /// **'Join a public game to see it here.'**
  String get my_games_empty_desc;

  /// No description provided for @error_generic.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error_generic;

  /// No description provided for @game_full.
  ///
  /// In en, this message translates to:
  /// **'Game is full'**
  String get game_full;

  /// No description provided for @game_waitlisted.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist'**
  String get game_waitlisted;

  /// No description provided for @pull_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pull_to_refresh;

  /// No description provided for @rating_thanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your rating!'**
  String get rating_thanks;

  /// No description provided for @rating_submit_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit rating.'**
  String get rating_submit_error;

  /// No description provided for @venues_search_disabled_mvp.
  ///
  /// In en, this message translates to:
  /// **'Search is disabled in the MVP'**
  String get venues_search_disabled_mvp;

  /// No description provided for @tab_most_recent.
  ///
  /// In en, this message translates to:
  /// **'Most Recent'**
  String get tab_most_recent;

  /// No description provided for @tab_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get tab_following;

  /// No description provided for @tab_nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get tab_nearby;

  /// No description provided for @tab_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tab_active;

  /// No description provided for @tab_news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get tab_news;

  /// No description provided for @feed_empty_no_posts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get feed_empty_no_posts;

  /// No description provided for @feed_empty_no_posts_hint.
  ///
  /// In en, this message translates to:
  /// **'Share moments, dabs, and kick-ins with your community.'**
  String get feed_empty_no_posts_hint;

  /// No description provided for @feed_could_not_load.
  ///
  /// In en, this message translates to:
  /// **'Could not load feed'**
  String get feed_could_not_load;

  /// No description provided for @feed_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get feed_retry;

  /// No description provided for @news_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No news right now.'**
  String get news_empty_title;

  /// No description provided for @news_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Check back later for updates from the Dabbler team.'**
  String get news_empty_hint;

  /// No description provided for @news_hide_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Hide news from feed?'**
  String get news_hide_sheet_title;

  /// No description provided for @news_hide_sheet_body.
  ///
  /// In en, this message translates to:
  /// **'News cards will no longer appear in Most Recent. You can still read all news in the News tab.'**
  String get news_hide_sheet_body;

  /// No description provided for @news_hide_confirm.
  ///
  /// In en, this message translates to:
  /// **'Hide news'**
  String get news_hide_confirm;

  /// No description provided for @news_hide_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get news_hide_cancel;

  /// No description provided for @news_hidden_snack.
  ///
  /// In en, this message translates to:
  /// **'News hidden from Most Recent'**
  String get news_hidden_snack;

  /// No description provided for @news_resubscribed_snack.
  ///
  /// In en, this message translates to:
  /// **'News will now appear in Most Recent'**
  String get news_resubscribed_snack;

  /// No description provided for @news_resubscribe_banner.
  ///
  /// In en, this message translates to:
  /// **'News is hidden from Most Recent.'**
  String get news_resubscribe_banner;

  /// No description provided for @news_resubscribe_action.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get news_resubscribe_action;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
