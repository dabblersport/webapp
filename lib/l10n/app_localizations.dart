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
  /// **'For you'**
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
  /// **'News cards will no longer appear in For you. You can still read all news in the News tab.'**
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
  /// **'News hidden from For you'**
  String get news_hidden_snack;

  /// No description provided for @news_resubscribed_snack.
  ///
  /// In en, this message translates to:
  /// **'News will now appear in For you'**
  String get news_resubscribed_snack;

  /// No description provided for @news_resubscribe_banner.
  ///
  /// In en, this message translates to:
  /// **'News is hidden from For you.'**
  String get news_resubscribe_banner;

  /// No description provided for @news_resubscribe_action.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get news_resubscribe_action;

  /// No description provided for @auth_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get auth_welcome_title;

  /// No description provided for @auth_welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We are stoked to have you join us. Create an account and start dabbing in local sports.'**
  String get auth_welcome_subtitle;

  /// No description provided for @auth_welcome_trust_heading.
  ///
  /// In en, this message translates to:
  /// **'Built for trust'**
  String get auth_welcome_trust_heading;

  /// No description provided for @auth_welcome_trust_verified.
  ///
  /// In en, this message translates to:
  /// **'Reviewed players, verified memberships and rated venues'**
  String get auth_welcome_trust_verified;

  /// No description provided for @auth_welcome_trust_personalised.
  ///
  /// In en, this message translates to:
  /// **'Connections and recommendations personalised to your sports'**
  String get auth_welcome_trust_personalised;

  /// No description provided for @auth_welcome_trust_privacy.
  ///
  /// In en, this message translates to:
  /// **'We do not sell your data — privacy-first by design'**
  String get auth_welcome_trust_privacy;

  /// No description provided for @auth_welcome_get_started.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get auth_welcome_get_started;

  /// No description provided for @auth_welcome_get_started_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account or log in'**
  String get auth_welcome_get_started_subtitle;

  /// No description provided for @auth_welcome_btn_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get auth_welcome_btn_google;

  /// No description provided for @auth_welcome_btn_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get auth_welcome_btn_apple;

  /// No description provided for @auth_welcome_btn_email.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get auth_welcome_btn_email;

  /// No description provided for @auth_welcome_btn_login.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get auth_welcome_btn_login;

  /// No description provided for @auth_welcome_apple_soon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in is coming soon.'**
  String get auth_welcome_apple_soon;

  /// No description provided for @auth_welcome_google_error.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google: {error}'**
  String auth_welcome_google_error(String error);

  /// No description provided for @auth_welcome_country_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Choose your country'**
  String get auth_welcome_country_picker_title;

  /// No description provided for @auth_welcome_language_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get auth_welcome_language_picker_title;

  /// No description provided for @landing_quote1.
  ///
  /// In en, this message translates to:
  /// **'I promised myself I\'d play at least twice a week.'**
  String get landing_quote1;

  /// No description provided for @landing_quote2.
  ///
  /// In en, this message translates to:
  /// **'Between work and life finding a game feels harder than a 90-minute run.'**
  String get landing_quote2;

  /// No description provided for @landing_tagline.
  ///
  /// In en, this message translates to:
  /// **'Dabbler connects players, captains, and venues so you can stop searching and start playing'**
  String get landing_tagline;

  /// No description provided for @landing_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get landing_continue;

  /// No description provided for @landing_choose_language.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get landing_choose_language;

  /// No description provided for @auth_already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get auth_already_have_account;

  /// No description provided for @auth_log_in.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get auth_log_in;

  /// No description provided for @auth_new_here.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get auth_new_here;

  /// No description provided for @auth_create_account.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get auth_create_account;

  /// No description provided for @auth_sheet_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get auth_sheet_done;

  /// No description provided for @auth_sheet_got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get auth_sheet_got_it;

  /// No description provided for @auth_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get auth_back;

  /// No description provided for @landing_dc_tagline.
  ///
  /// In en, this message translates to:
  /// **'Dabbler connects players, organisers and venues, so you can stop searching and start playing.'**
  String get landing_dc_tagline;

  /// No description provided for @landing_dc_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get landing_dc_continue;

  /// No description provided for @landing_vignette_marcus_quote.
  ///
  /// In en, this message translates to:
  /// **'Half the group chat’s flaky. The other half changes their mind by Friday.'**
  String get landing_vignette_marcus_quote;

  /// No description provided for @landing_vignette_marcus_want.
  ///
  /// In en, this message translates to:
  /// **'I just want one place to organise a 5-a-side and stop chasing replies.'**
  String get landing_vignette_marcus_want;

  /// No description provided for @landing_vignette_aisha_quote.
  ///
  /// In en, this message translates to:
  /// **'New city, decent left foot, nobody to pass to.'**
  String get landing_vignette_aisha_quote;

  /// No description provided for @landing_vignette_aisha_want.
  ///
  /// In en, this message translates to:
  /// **'I want a game this week, not a group chat about a game.'**
  String get landing_vignette_aisha_want;

  /// No description provided for @landing_vignette_priya_quote.
  ///
  /// In en, this message translates to:
  /// **'I follow more padel than I’ve ever actually played.'**
  String get landing_vignette_priya_quote;

  /// No description provided for @landing_vignette_priya_want.
  ///
  /// In en, this message translates to:
  /// **'Show me who’s playing near me and I’ll find my way in.'**
  String get landing_vignette_priya_want;

  /// No description provided for @landing_vignette_sevens_quote.
  ///
  /// In en, this message translates to:
  /// **'Three pitches free at 9pm and nobody knows about it.'**
  String get landing_vignette_sevens_quote;

  /// No description provided for @landing_vignette_sevens_want.
  ///
  /// In en, this message translates to:
  /// **'Put my courts in front of players already looking for one.'**
  String get landing_vignette_sevens_want;

  /// No description provided for @auth_entry_title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get you playing'**
  String get auth_entry_title;

  /// No description provided for @auth_entry_subtitle.
  ///
  /// In en, this message translates to:
  /// **'One account for games, squads and venues.'**
  String get auth_entry_subtitle;

  /// No description provided for @auth_entry_trust_verified.
  ///
  /// In en, this message translates to:
  /// **'Reviewed players, verified venues, rated games'**
  String get auth_entry_trust_verified;

  /// No description provided for @auth_entry_trust_personalised.
  ///
  /// In en, this message translates to:
  /// **'Games and people picked around your sports'**
  String get auth_entry_trust_personalised;

  /// No description provided for @auth_entry_trust_privacy.
  ///
  /// In en, this message translates to:
  /// **'We don’t sell your data. Privacy-first by design'**
  String get auth_entry_trust_privacy;

  /// No description provided for @auth_entry_continue_email.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get auth_entry_continue_email;

  /// No description provided for @auth_entry_continue_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get auth_entry_continue_google;

  /// No description provided for @auth_entry_continue_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get auth_entry_continue_apple;

  /// No description provided for @auth_legal_prefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our '**
  String get auth_legal_prefix;

  /// No description provided for @auth_legal_terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get auth_legal_terms;

  /// No description provided for @auth_legal_and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get auth_legal_and;

  /// No description provided for @auth_legal_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get auth_legal_privacy;

  /// No description provided for @auth_sheet_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get auth_sheet_language;

  /// No description provided for @auth_sheet_region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get auth_sheet_region;

  /// No description provided for @auth_email_title.
  ///
  /// In en, this message translates to:
  /// **'What\'s your email?'**
  String get auth_email_title;

  /// No description provided for @auth_email_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a code. If you\'ve been here before, we\'ll pick up where you left off.'**
  String get auth_email_subtitle;

  /// No description provided for @auth_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email_label;

  /// No description provided for @auth_email_placeholder.
  ///
  /// In en, this message translates to:
  /// **'you@email.com'**
  String get auth_email_placeholder;

  /// No description provided for @auth_email_marketing.
  ///
  /// In en, this message translates to:
  /// **'Keep me posted on games and features near me'**
  String get auth_email_marketing;

  /// No description provided for @auth_email_send_code.
  ///
  /// In en, this message translates to:
  /// **'Send me a code'**
  String get auth_email_send_code;

  /// No description provided for @auth_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email address.'**
  String get auth_email_invalid;

  /// No description provided for @auth_login_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get auth_login_title;

  /// No description provided for @auth_login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in your way — password, a one-time code, or a connected account.'**
  String get auth_login_subtitle;

  /// No description provided for @auth_login_password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_login_password_label;

  /// No description provided for @auth_login_password_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get auth_login_password_placeholder;

  /// No description provided for @auth_login_button.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get auth_login_button;

  /// No description provided for @auth_login_email_code.
  ///
  /// In en, this message translates to:
  /// **'Email me a code instead'**
  String get auth_login_email_code;

  /// No description provided for @auth_login_password_wrong.
  ///
  /// In en, this message translates to:
  /// **'That password does not match. Try again, or email yourself a code.'**
  String get auth_login_password_wrong;

  /// No description provided for @auth_otp_title.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get auth_otp_title;

  /// No description provided for @auth_otp_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email.'**
  String get auth_otp_subtitle;

  /// No description provided for @auth_otp_change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get auth_otp_change;

  /// No description provided for @auth_otp_invalid.
  ///
  /// In en, this message translates to:
  /// **'That code is not right. Check the email and try again.'**
  String get auth_otp_invalid;

  /// No description provided for @auth_otp_expired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Send a new one.'**
  String get auth_otp_expired;

  /// No description provided for @auth_otp_resend.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get auth_otp_resend;

  /// No description provided for @auth_otp_resend_in.
  ///
  /// In en, this message translates to:
  /// **'Send a new code in {seconds}s'**
  String auth_otp_resend_in(int seconds);

  /// No description provided for @auth_otp_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get auth_otp_continue;

  /// No description provided for @auth_welcome_back_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String auth_welcome_back_title(String name);

  /// No description provided for @auth_welcome_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get auth_welcome_continue;

  /// No description provided for @auth_welcome_list_title.
  ///
  /// In en, this message translates to:
  /// **'Don’t forget'**
  String get auth_welcome_list_title;

  /// No description provided for @persona_player_name.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get persona_player_name;

  /// No description provided for @persona_player_headline.
  ///
  /// In en, this message translates to:
  /// **'You’re in. Let’s play.'**
  String get persona_player_headline;

  /// No description provided for @persona_player_principle.
  ///
  /// In en, this message translates to:
  /// **'Show up, play fair, build your rep.'**
  String get persona_player_principle;

  /// No description provided for @persona_player_list_title.
  ///
  /// In en, this message translates to:
  /// **'Don’t forget'**
  String get persona_player_list_title;

  /// No description provided for @persona_player_item1.
  ///
  /// In en, this message translates to:
  /// **'Only confirm when you know you can play.'**
  String get persona_player_item1;

  /// No description provided for @persona_player_item2.
  ///
  /// In en, this message translates to:
  /// **'Respect the organiser’s rules and kickoff time.'**
  String get persona_player_item2;

  /// No description provided for @persona_player_item3.
  ///
  /// In en, this message translates to:
  /// **'Turning up is what builds your reputation.'**
  String get persona_player_item3;

  /// No description provided for @persona_player_cta.
  ///
  /// In en, this message translates to:
  /// **'Find my first game'**
  String get persona_player_cta;

  /// No description provided for @persona_organiser_name.
  ///
  /// In en, this message translates to:
  /// **'Organiser'**
  String get persona_organiser_name;

  /// No description provided for @persona_organiser_headline.
  ///
  /// In en, this message translates to:
  /// **'Time to bring the game together.'**
  String get persona_organiser_headline;

  /// No description provided for @persona_organiser_principle.
  ///
  /// In en, this message translates to:
  /// **'Good games start with good organisation.'**
  String get persona_organiser_principle;

  /// No description provided for @persona_organiser_list_title.
  ///
  /// In en, this message translates to:
  /// **'What players expect'**
  String get persona_organiser_list_title;

  /// No description provided for @persona_organiser_item1.
  ///
  /// In en, this message translates to:
  /// **'Accurate details — venue, time, level, price.'**
  String get persona_organiser_item1;

  /// No description provided for @persona_organiser_item2.
  ///
  /// In en, this message translates to:
  /// **'Changes shared early, not at kickoff.'**
  String get persona_organiser_item2;

  /// No description provided for @persona_organiser_item3.
  ///
  /// In en, this message translates to:
  /// **'Attendance managed fairly, every time.'**
  String get persona_organiser_item3;

  /// No description provided for @persona_organiser_cta.
  ///
  /// In en, this message translates to:
  /// **'Create my first game'**
  String get persona_organiser_cta;

  /// No description provided for @persona_host_name.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get persona_host_name;

  /// No description provided for @persona_host_headline.
  ///
  /// In en, this message translates to:
  /// **'Your venue’s on the map.'**
  String get persona_host_headline;

  /// No description provided for @persona_host_principle.
  ///
  /// In en, this message translates to:
  /// **'Great venues make playing easy.'**
  String get persona_host_principle;

  /// No description provided for @persona_host_list_title.
  ///
  /// In en, this message translates to:
  /// **'What players expect'**
  String get persona_host_list_title;

  /// No description provided for @persona_host_item1.
  ///
  /// In en, this message translates to:
  /// **'Availability that matches reality.'**
  String get persona_host_item1;

  /// No description provided for @persona_host_item2.
  ///
  /// In en, this message translates to:
  /// **'Pricing and facilities kept current.'**
  String get persona_host_item2;

  /// No description provided for @persona_host_item3.
  ///
  /// In en, this message translates to:
  /// **'Bookings honoured — that’s what brings them back.'**
  String get persona_host_item3;

  /// No description provided for @persona_host_cta.
  ///
  /// In en, this message translates to:
  /// **'Set up my venue'**
  String get persona_host_cta;

  /// No description provided for @persona_socialiser_name.
  ///
  /// In en, this message translates to:
  /// **'Socialiser'**
  String get persona_socialiser_name;

  /// No description provided for @persona_socialiser_headline.
  ///
  /// In en, this message translates to:
  /// **'Your sports circle starts here.'**
  String get persona_socialiser_headline;

  /// No description provided for @persona_socialiser_principle.
  ///
  /// In en, this message translates to:
  /// **'Follow what you love, meet your people, join when it feels right.'**
  String get persona_socialiser_principle;

  /// No description provided for @persona_socialiser_list_title.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get persona_socialiser_list_title;

  /// No description provided for @persona_socialiser_item1.
  ///
  /// In en, this message translates to:
  /// **'Follow the sports and people you actually care about.'**
  String get persona_socialiser_item1;

  /// No description provided for @persona_socialiser_item2.
  ///
  /// In en, this message translates to:
  /// **'Join the conversation before you join the game.'**
  String get persona_socialiser_item2;

  /// No description provided for @persona_socialiser_item3.
  ///
  /// In en, this message translates to:
  /// **'Keep it friendly — everyone here is someone’s teammate.'**
  String get persona_socialiser_item3;

  /// No description provided for @persona_socialiser_cta.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get persona_socialiser_cta;

  /// No description provided for @auth_or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get auth_or;

  /// No description provided for @email_input_title.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get email_input_title;

  /// No description provided for @email_input_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to get started'**
  String get email_input_subtitle;

  /// No description provided for @email_input_label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email_input_label;

  /// No description provided for @email_input_hint.
  ///
  /// In en, this message translates to:
  /// **'email@domain.com'**
  String get email_input_hint;

  /// No description provided for @email_input_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get email_input_continue;

  /// No description provided for @email_input_keep_in_loop.
  ///
  /// In en, this message translates to:
  /// **'Keep me in the loop with emails about updates & more'**
  String get email_input_keep_in_loop;

  /// No description provided for @email_input_already_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get email_input_already_account;

  /// No description provided for @email_input_btn_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get email_input_btn_google;

  /// No description provided for @email_input_btn_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get email_input_btn_apple;

  /// No description provided for @email_input_terms_prefix.
  ///
  /// In en, this message translates to:
  /// **'By clicking Continue, you are indicating that you have read and agree to the '**
  String get email_input_terms_prefix;

  /// No description provided for @email_input_terms_link.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get email_input_terms_link;

  /// No description provided for @email_input_terms_and.
  ///
  /// In en, this message translates to:
  /// **' & '**
  String get email_input_terms_and;

  /// No description provided for @email_input_privacy_link.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get email_input_privacy_link;

  /// No description provided for @email_input_validate_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get email_input_validate_required;

  /// No description provided for @email_input_validate_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get email_input_validate_invalid;

  /// No description provided for @email_input_error_generic.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get email_input_error_generic;

  /// No description provided for @email_input_google_failed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get email_input_google_failed;

  /// No description provided for @email_password_title.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get email_password_title;

  /// No description provided for @email_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password\nor login using OTP'**
  String get email_password_subtitle;

  /// No description provided for @email_password_forgot.
  ///
  /// In en, this message translates to:
  /// **'Forget password?'**
  String get email_password_forgot;

  /// No description provided for @email_password_send_otp.
  ///
  /// In en, this message translates to:
  /// **'Send email OTP'**
  String get email_password_send_otp;

  /// No description provided for @email_password_login_btn.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get email_password_login_btn;

  /// No description provided for @email_password_btn_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get email_password_btn_google;

  /// No description provided for @email_password_btn_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get email_password_btn_apple;

  /// No description provided for @email_password_hint_email.
  ///
  /// In en, this message translates to:
  /// **'email@domain.com'**
  String get email_password_hint_email;

  /// No description provided for @email_password_hint_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get email_password_hint_password;

  /// No description provided for @email_password_show_password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get email_password_show_password;

  /// No description provided for @email_password_hide_password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get email_password_hide_password;

  /// No description provided for @email_password_validate_email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get email_password_validate_email_required;

  /// No description provided for @email_password_validate_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get email_password_validate_email_invalid;

  /// No description provided for @email_password_validate_password_required.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get email_password_validate_password_required;

  /// No description provided for @email_password_error_invalid_creds.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get email_password_error_invalid_creds;

  /// No description provided for @email_password_error_login_failed.
  ///
  /// In en, this message translates to:
  /// **'Login failed.'**
  String get email_password_error_login_failed;

  /// No description provided for @email_password_error_otp_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Please try again.'**
  String get email_password_error_otp_failed;

  /// No description provided for @email_password_apple_soon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in is coming soon.'**
  String get email_password_apple_soon;

  /// No description provided for @email_password_google_failed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed.'**
  String get email_password_google_failed;

  /// No description provided for @email_password_validate_email_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get email_password_validate_email_hint;

  /// No description provided for @email_verify_appbar.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get email_verify_appbar;

  /// No description provided for @email_verify_title.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get email_verify_title;

  /// No description provided for @email_verify_body_with_email.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a confirmation link to {email}.\n\nPlease confirm your email to finish setting up your account.'**
  String email_verify_body_with_email(String email);

  /// No description provided for @email_verify_body_no_email.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a confirmation link to your email.\n\nPlease confirm your email to finish setting up your account.'**
  String get email_verify_body_no_email;

  /// No description provided for @email_verify_instruction.
  ///
  /// In en, this message translates to:
  /// **'After confirming your email, come back to the app and tap \"I\'ve confirmed my email\" to continue.'**
  String get email_verify_instruction;

  /// No description provided for @email_verify_confirmed_btn.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed my email'**
  String get email_verify_confirmed_btn;

  /// No description provided for @email_verify_resend_btn.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get email_verify_resend_btn;

  /// No description provided for @email_verify_different_account.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get email_verify_different_account;

  /// No description provided for @email_verify_no_email_error.
  ///
  /// In en, this message translates to:
  /// **'No email found for the current user.'**
  String get email_verify_no_email_error;

  /// No description provided for @email_verify_spam_note.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t see the email, please check your spam folder or request a new link from the sign-in screen.'**
  String get email_verify_spam_note;

  /// No description provided for @forgot_password_title.
  ///
  /// In en, this message translates to:
  /// **'Reset Your Password'**
  String get forgot_password_title;

  /// No description provided for @forgot_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get forgot_password_subtitle;

  /// No description provided for @forgot_password_email_hint.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get forgot_password_email_hint;

  /// No description provided for @forgot_password_send_btn.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgot_password_send_btn;

  /// No description provided for @forgot_password_sent_msg.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent! Check your email inbox and spam folder for instructions to reset your password.'**
  String get forgot_password_sent_msg;

  /// No description provided for @forgot_password_back_to_signin.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get forgot_password_back_to_signin;

  /// No description provided for @forgot_password_validate_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get forgot_password_validate_email;

  /// No description provided for @otp_verify_title_email.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get otp_verify_title_email;

  /// No description provided for @otp_verify_title_phone.
  ///
  /// In en, this message translates to:
  /// **'Verify phone'**
  String get otp_verify_title_phone;

  /// No description provided for @otp_verify_subtitle_email.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits we\'ve sent to your email'**
  String get otp_verify_subtitle_email;

  /// No description provided for @otp_verify_subtitle_phone.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits we\'ve sent to your phone'**
  String get otp_verify_subtitle_phone;

  /// No description provided for @otp_verify_change_email.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get otp_verify_change_email;

  /// No description provided for @otp_verify_change_phone.
  ///
  /// In en, this message translates to:
  /// **'Change phone'**
  String get otp_verify_change_phone;

  /// No description provided for @otp_verify_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get otp_verify_continue;

  /// No description provided for @otp_verify_didnt_get.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get a code? '**
  String get otp_verify_didnt_get;

  /// No description provided for @otp_verify_resend_countdown.
  ///
  /// In en, this message translates to:
  /// **'Resend code ({seconds}s)'**
  String otp_verify_resend_countdown(int seconds);

  /// No description provided for @otp_verify_resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otp_verify_resend;

  /// No description provided for @otp_verify_sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get otp_verify_sending;

  /// No description provided for @otp_verify_sent_email.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully to your email'**
  String get otp_verify_sent_email;

  /// No description provided for @otp_verify_sent_phone.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully to your phone'**
  String get otp_verify_sent_phone;

  /// No description provided for @otp_verify_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String otp_verify_error_prefix(String error);

  /// No description provided for @reset_password_title.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get reset_password_title;

  /// No description provided for @reset_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account'**
  String get reset_password_subtitle;

  /// No description provided for @reset_password_new_label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get reset_password_new_label;

  /// No description provided for @reset_password_confirm_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get reset_password_confirm_label;

  /// No description provided for @reset_password_update_btn.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get reset_password_update_btn;

  /// No description provided for @reset_password_validate_enter.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get reset_password_validate_enter;

  /// No description provided for @reset_password_validate_min.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get reset_password_validate_min;

  /// No description provided for @reset_password_validate_confirm.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the password'**
  String get reset_password_validate_confirm;

  /// No description provided for @reset_password_validate_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get reset_password_validate_match;

  /// No description provided for @set_password_title.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get set_password_title;

  /// No description provided for @set_password_email_prefix.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String set_password_email_prefix(String email);

  /// No description provided for @set_password_username_label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get set_password_username_label;

  /// No description provided for @set_password_username_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose a unique username'**
  String get set_password_username_hint;

  /// No description provided for @set_password_password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get set_password_password_label;

  /// No description provided for @set_password_password_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter a strong password'**
  String get set_password_password_hint;

  /// No description provided for @set_password_confirm_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get set_password_confirm_label;

  /// No description provided for @set_password_confirm_hint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get set_password_confirm_hint;

  /// No description provided for @set_password_create_btn.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get set_password_create_btn;

  /// No description provided for @set_password_creating_btn.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get set_password_creating_btn;

  /// No description provided for @set_password_wait_btn.
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds} s'**
  String set_password_wait_btn(int seconds);

  /// No description provided for @set_password_validate_username_required.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get set_password_validate_username_required;

  /// No description provided for @set_password_validate_username_min.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get set_password_validate_username_min;

  /// No description provided for @set_password_validate_username_max.
  ///
  /// In en, this message translates to:
  /// **'Username must be 20 characters or less'**
  String get set_password_validate_username_max;

  /// No description provided for @set_password_validate_username_chars.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, and underscores allowed'**
  String get set_password_validate_username_chars;

  /// No description provided for @set_password_validate_username_taken.
  ///
  /// In en, this message translates to:
  /// **'Username is already taken'**
  String get set_password_validate_username_taken;

  /// No description provided for @set_password_validate_username_checking.
  ///
  /// In en, this message translates to:
  /// **'Error checking username'**
  String get set_password_validate_username_checking;

  /// No description provided for @set_password_validate_password_required.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get set_password_validate_password_required;

  /// No description provided for @set_password_validate_password_min.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get set_password_validate_password_min;

  /// No description provided for @set_password_validate_confirm_required.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get set_password_validate_confirm_required;

  /// No description provided for @set_password_validate_confirm_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get set_password_validate_confirm_match;

  /// No description provided for @set_password_wait_validation.
  ///
  /// In en, this message translates to:
  /// **'Please wait for username validation'**
  String get set_password_wait_validation;

  /// No description provided for @set_password_account_exists.
  ///
  /// In en, this message translates to:
  /// **'Account already exists. Please sign in with your password.'**
  String get set_password_account_exists;

  /// No description provided for @set_password_rate_limit.
  ///
  /// In en, this message translates to:
  /// **'Please wait a few seconds before trying again.'**
  String get set_password_rate_limit;

  /// No description provided for @set_password_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String set_password_error_prefix(String error);

  /// No description provided for @create_info_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us a bit about you'**
  String get create_info_title;

  /// No description provided for @create_info_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your age, you have to be 16+ to use dabbler'**
  String get create_info_subtitle;

  /// No description provided for @create_info_birth_date.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get create_info_birth_date;

  /// No description provided for @create_info_birth_date_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Select your birth date'**
  String get create_info_birth_date_placeholder;

  /// No description provided for @create_info_age_display.
  ///
  /// In en, this message translates to:
  /// **'{age} years old'**
  String create_info_age_display(int age);

  /// No description provided for @create_info_gender.
  ///
  /// In en, this message translates to:
  /// **'Gender (optional)'**
  String get create_info_gender;

  /// No description provided for @create_info_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get create_info_continue;

  /// No description provided for @create_info_error_fill_required.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields correctly'**
  String get create_info_error_fill_required;

  /// No description provided for @create_info_error_select_birth.
  ///
  /// In en, this message translates to:
  /// **'Please select your birth date'**
  String get create_info_error_select_birth;

  /// No description provided for @create_info_error_min_age.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 16 years old to register'**
  String get create_info_error_min_age;

  /// No description provided for @create_info_error_max_age.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 16 and {max} years'**
  String create_info_error_max_age(int max);

  /// No description provided for @create_info_error_select_gender.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get create_info_error_select_gender;

  /// No description provided for @create_info_error_occurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String create_info_error_occurred(String error);

  /// No description provided for @set_username_title_onboarding.
  ///
  /// In en, this message translates to:
  /// **'Identify yourself'**
  String get set_username_title_onboarding;

  /// No description provided for @set_username_title_conversion.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Conversion'**
  String get set_username_title_conversion;

  /// No description provided for @set_username_title_new_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your New Profile'**
  String get set_username_title_new_profile;

  /// No description provided for @set_username_subtitle_onboarding.
  ///
  /// In en, this message translates to:
  /// **'Choose how others should call you and set a username'**
  String get set_username_subtitle_onboarding;

  /// No description provided for @set_username_subtitle_persona.
  ///
  /// In en, this message translates to:
  /// **'Choose a display name and username for your {persona} profile'**
  String set_username_subtitle_persona(String persona);

  /// No description provided for @set_username_display_name_label.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get set_username_display_name_label;

  /// No description provided for @set_username_display_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get set_username_display_name_hint;

  /// No description provided for @set_username_username_label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get set_username_username_label;

  /// No description provided for @set_username_username_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose a unique username'**
  String get set_username_username_hint;

  /// No description provided for @set_username_suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get set_username_suggestions;

  /// No description provided for @set_username_btn_complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get set_username_btn_complete;

  /// No description provided for @set_username_btn_create_profile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get set_username_btn_create_profile;

  /// No description provided for @set_username_btn_complete_conversion.
  ///
  /// In en, this message translates to:
  /// **'Complete Conversion'**
  String get set_username_btn_complete_conversion;

  /// No description provided for @set_username_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get set_username_back;

  /// No description provided for @set_username_converting_to.
  ///
  /// In en, this message translates to:
  /// **'Converting to {persona}'**
  String set_username_converting_to(String persona);

  /// No description provided for @set_username_adding_profile.
  ///
  /// In en, this message translates to:
  /// **'Adding {persona} profile'**
  String set_username_adding_profile(String persona);

  /// No description provided for @set_username_validate_display_required.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get set_username_validate_display_required;

  /// No description provided for @set_username_validate_display_min.
  ///
  /// In en, this message translates to:
  /// **'Display name must be at least 2 characters'**
  String get set_username_validate_display_min;

  /// No description provided for @set_username_validate_username_required.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get set_username_validate_username_required;

  /// No description provided for @set_username_validate_username_min.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get set_username_validate_username_min;

  /// No description provided for @set_username_validate_username_chars.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, and underscores'**
  String get set_username_validate_username_chars;

  /// No description provided for @set_username_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Username unavailable'**
  String get set_username_unavailable;

  /// No description provided for @set_username_check_error.
  ///
  /// In en, this message translates to:
  /// **'Error checking username'**
  String get set_username_check_error;

  /// No description provided for @set_username_missing_onboarding.
  ///
  /// In en, this message translates to:
  /// **'Missing onboarding data. Please start over.'**
  String get set_username_missing_onboarding;

  /// No description provided for @set_username_missing_steps.
  ///
  /// In en, this message translates to:
  /// **'Missing required information. Please complete all steps.'**
  String get set_username_missing_steps;

  /// No description provided for @set_username_session_expired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please verify your phone number again.'**
  String get set_username_session_expired;

  /// No description provided for @set_username_missing_persona_data.
  ///
  /// In en, this message translates to:
  /// **'Missing data. Please start over.'**
  String get set_username_missing_persona_data;

  /// No description provided for @intent_title.
  ///
  /// In en, this message translates to:
  /// **'What brings you here?'**
  String get intent_title;

  /// No description provided for @intent_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us tailor Dabbler'**
  String get intent_subtitle;

  /// No description provided for @intent_compete_title.
  ///
  /// In en, this message translates to:
  /// **'Compete'**
  String get intent_compete_title;

  /// No description provided for @intent_compete_desc.
  ///
  /// In en, this message translates to:
  /// **'Join games, track your level, play regularly'**
  String get intent_compete_desc;

  /// No description provided for @intent_organise_title.
  ///
  /// In en, this message translates to:
  /// **'Organise'**
  String get intent_organise_title;

  /// No description provided for @intent_organise_desc.
  ///
  /// In en, this message translates to:
  /// **'Create games, set rules, manage players'**
  String get intent_organise_desc;

  /// No description provided for @intent_host_title.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get intent_host_title;

  /// No description provided for @intent_host_desc.
  ///
  /// In en, this message translates to:
  /// **'Manage venues, availability, and bookings'**
  String get intent_host_desc;

  /// No description provided for @intent_socialise_title.
  ///
  /// In en, this message translates to:
  /// **'Socialise'**
  String get intent_socialise_title;

  /// No description provided for @intent_socialise_desc.
  ///
  /// In en, this message translates to:
  /// **'Follow sports, people, and communities'**
  String get intent_socialise_desc;

  /// No description provided for @intent_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get intent_continue;

  /// No description provided for @intent_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get intent_back;

  /// No description provided for @intent_select_role.
  ///
  /// In en, this message translates to:
  /// **'Please select your role'**
  String get intent_select_role;

  /// No description provided for @interests_title_player.
  ///
  /// In en, this message translates to:
  /// **'What do you regularly practice?'**
  String get interests_title_player;

  /// No description provided for @interests_title_organiser.
  ///
  /// In en, this message translates to:
  /// **'What do you intend to organise?'**
  String get interests_title_organiser;

  /// No description provided for @interests_title_host.
  ///
  /// In en, this message translates to:
  /// **'Which sports do you host?'**
  String get interests_title_host;

  /// No description provided for @interests_title_socialiser.
  ///
  /// In en, this message translates to:
  /// **'Which sports are you interested in?'**
  String get interests_title_socialiser;

  /// No description provided for @interests_title_default.
  ///
  /// In en, this message translates to:
  /// **'What do you regularly practice?'**
  String get interests_title_default;

  /// No description provided for @interests_subtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change and add more sports later'**
  String get interests_subtitle;

  /// No description provided for @interests_available_sports.
  ///
  /// In en, this message translates to:
  /// **'Available sports'**
  String get interests_available_sports;

  /// No description provided for @interests_selected_count_one.
  ///
  /// In en, this message translates to:
  /// **'{count} sport selected'**
  String interests_selected_count_one(int count);

  /// No description provided for @interests_selected_count_many.
  ///
  /// In en, this message translates to:
  /// **'{count} sports selected'**
  String interests_selected_count_many(int count);

  /// No description provided for @interests_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get interests_continue;

  /// No description provided for @interests_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get interests_back;

  /// No description provided for @interests_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get interests_cancel;

  /// No description provided for @interests_select_one.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one sport'**
  String get interests_select_one;

  /// No description provided for @interests_failed_load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sports'**
  String get interests_failed_load;

  /// No description provided for @interests_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get interests_retry;

  /// No description provided for @primary_sport_title.
  ///
  /// In en, this message translates to:
  /// **'Choose your primary sport'**
  String get primary_sport_title;

  /// No description provided for @primary_sport_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This sport will appear on your profile and be used by default.'**
  String get primary_sport_subtitle;

  /// No description provided for @primary_sport_helper.
  ///
  /// In en, this message translates to:
  /// **'You can change it later.'**
  String get primary_sport_helper;

  /// No description provided for @primary_sport_badge.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary_sport_badge;

  /// No description provided for @primary_sport_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get primary_sport_continue;

  /// No description provided for @primary_sport_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get primary_sport_back;

  /// No description provided for @primary_sport_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get primary_sport_cancel;

  /// No description provided for @primary_sport_select_error.
  ///
  /// In en, this message translates to:
  /// **'Please select your primary sport'**
  String get primary_sport_select_error;

  /// No description provided for @primary_sport_failed_load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sports'**
  String get primary_sport_failed_load;

  /// No description provided for @primary_sport_no_sports.
  ///
  /// In en, this message translates to:
  /// **'No sports selected. Please go back.'**
  String get primary_sport_no_sports;

  /// No description provided for @onb_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onb_back;

  /// No description provided for @onb_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onb_continue;

  /// No description provided for @onb_step_label.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onb_step_label(int current, int total);

  /// No description provided for @onb_dob_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us a bit about you'**
  String get onb_dob_title;

  /// No description provided for @onb_dob_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your age keeps games and communities age-appropriate. It stays off your profile.'**
  String get onb_dob_subtitle;

  /// No description provided for @onb_dob_label.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get onb_dob_label;

  /// No description provided for @onb_dob_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get onb_dob_placeholder;

  /// No description provided for @onb_dob_helper_min.
  ///
  /// In en, this message translates to:
  /// **'You need to be 16 or over to use Dabbler.'**
  String get onb_dob_helper_min;

  /// No description provided for @onb_dob_helper_ok.
  ///
  /// In en, this message translates to:
  /// **'Age {age}. You are all set.'**
  String onb_dob_helper_ok(int age);

  /// No description provided for @onb_dob_error_min.
  ///
  /// In en, this message translates to:
  /// **'You need to be 16 or over.'**
  String get onb_dob_error_min;

  /// No description provided for @onb_dob_error_max.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 16 and {max}.'**
  String onb_dob_error_max(int max);

  /// No description provided for @onb_gender_label.
  ///
  /// In en, this message translates to:
  /// **'Gender (optional)'**
  String get onb_gender_label;

  /// No description provided for @onb_gender_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get onb_gender_male;

  /// No description provided for @onb_gender_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get onb_gender_female;

  /// No description provided for @onb_dob_sheet_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get onb_dob_sheet_confirm;

  /// No description provided for @onb_dob_sheet_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get onb_dob_sheet_cancel;

  /// No description provided for @onb_day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get onb_day;

  /// No description provided for @onb_month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get onb_month;

  /// No description provided for @onb_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get onb_year;

  /// No description provided for @onb_month_1.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get onb_month_1;

  /// No description provided for @onb_month_2.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get onb_month_2;

  /// No description provided for @onb_month_3.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get onb_month_3;

  /// No description provided for @onb_month_4.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get onb_month_4;

  /// No description provided for @onb_month_5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get onb_month_5;

  /// No description provided for @onb_month_6.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get onb_month_6;

  /// No description provided for @onb_month_7.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get onb_month_7;

  /// No description provided for @onb_month_8.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get onb_month_8;

  /// No description provided for @onb_month_9.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get onb_month_9;

  /// No description provided for @onb_month_10.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get onb_month_10;

  /// No description provided for @onb_month_11.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get onb_month_11;

  /// No description provided for @onb_month_12.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get onb_month_12;

  /// No description provided for @onb_persona_title.
  ///
  /// In en, this message translates to:
  /// **'Why are you here?'**
  String get onb_persona_title;

  /// No description provided for @onb_persona_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the one that fits best today. You can add another later.'**
  String get onb_persona_subtitle;

  /// No description provided for @onb_persona_footnote.
  ///
  /// In en, this message translates to:
  /// **'You can add another way to use Dabbler later in settings.'**
  String get onb_persona_footnote;

  /// No description provided for @onb_persona_socialiser_name.
  ///
  /// In en, this message translates to:
  /// **'Socialiser'**
  String get onb_persona_socialiser_name;

  /// No description provided for @onb_persona_socialiser_hook.
  ///
  /// In en, this message translates to:
  /// **'Find your people'**
  String get onb_persona_socialiser_hook;

  /// No description provided for @onb_persona_socialiser_body.
  ///
  /// In en, this message translates to:
  /// **'Follow sports, discover communities, and stay in the loop.'**
  String get onb_persona_socialiser_body;

  /// No description provided for @onb_sports_title_socialiser.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get onb_sports_title_socialiser;

  /// No description provided for @onb_sports_subtitle_socialiser.
  ///
  /// In en, this message translates to:
  /// **'Pick the sports you want to see more of.'**
  String get onb_sports_subtitle_socialiser;

  /// No description provided for @onb_primary_title_socialiser.
  ///
  /// In en, this message translates to:
  /// **'What is your favourite sport?'**
  String get onb_primary_title_socialiser;

  /// No description provided for @onb_primary_subtitle_socialiser.
  ///
  /// In en, this message translates to:
  /// **'We will show more communities, people and activity around it.'**
  String get onb_primary_subtitle_socialiser;

  /// No description provided for @onb_persona_player_name.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get onb_persona_player_name;

  /// No description provided for @onb_persona_player_hook.
  ///
  /// In en, this message translates to:
  /// **'Get in the game'**
  String get onb_persona_player_hook;

  /// No description provided for @onb_persona_player_body.
  ///
  /// In en, this message translates to:
  /// **'Join matches, build your level, and play more often.'**
  String get onb_persona_player_body;

  /// No description provided for @onb_sports_title_player.
  ///
  /// In en, this message translates to:
  /// **'What do you play?'**
  String get onb_sports_title_player;

  /// No description provided for @onb_sports_subtitle_player.
  ///
  /// In en, this message translates to:
  /// **'Pick the sports you’re into. You can change these anytime.'**
  String get onb_sports_subtitle_player;

  /// No description provided for @onb_primary_title_player.
  ///
  /// In en, this message translates to:
  /// **'What’s your go-to sport?'**
  String get onb_primary_title_player;

  /// No description provided for @onb_primary_subtitle_player.
  ///
  /// In en, this message translates to:
  /// **'We’ll make it your default and build your main sport profile around it.'**
  String get onb_primary_subtitle_player;

  /// No description provided for @onb_persona_organiser_name.
  ///
  /// In en, this message translates to:
  /// **'Organiser'**
  String get onb_persona_organiser_name;

  /// No description provided for @onb_persona_organiser_hook.
  ///
  /// In en, this message translates to:
  /// **'Bring the game together'**
  String get onb_persona_organiser_hook;

  /// No description provided for @onb_persona_organiser_body.
  ///
  /// In en, this message translates to:
  /// **'Create sessions, manage players, and keep everything organised.'**
  String get onb_persona_organiser_body;

  /// No description provided for @onb_sports_title_organiser.
  ///
  /// In en, this message translates to:
  /// **'What do you organise?'**
  String get onb_sports_title_organiser;

  /// No description provided for @onb_sports_subtitle_organiser.
  ///
  /// In en, this message translates to:
  /// **'Choose the sports you usually create games for.'**
  String get onb_sports_subtitle_organiser;

  /// No description provided for @onb_primary_title_organiser.
  ///
  /// In en, this message translates to:
  /// **'What do you organise most?'**
  String get onb_primary_title_organiser;

  /// No description provided for @onb_primary_subtitle_organiser.
  ///
  /// In en, this message translates to:
  /// **'We’ll use it as the default when you create games and events.'**
  String get onb_primary_subtitle_organiser;

  /// No description provided for @onb_persona_host_name.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get onb_persona_host_name;

  /// No description provided for @onb_persona_host_hook.
  ///
  /// In en, this message translates to:
  /// **'Fill your venue'**
  String get onb_persona_host_hook;

  /// No description provided for @onb_persona_host_body.
  ///
  /// In en, this message translates to:
  /// **'Show your spaces, reach players, and manage bookings.'**
  String get onb_persona_host_body;

  /// No description provided for @onb_sports_title_host.
  ///
  /// In en, this message translates to:
  /// **'What can people play at your venue?'**
  String get onb_sports_title_host;

  /// No description provided for @onb_sports_subtitle_host.
  ///
  /// In en, this message translates to:
  /// **'Select the sports your spaces can host.'**
  String get onb_sports_subtitle_host;

  /// No description provided for @onb_primary_title_host.
  ///
  /// In en, this message translates to:
  /// **'What’s your venue known for?'**
  String get onb_primary_title_host;

  /// No description provided for @onb_primary_subtitle_host.
  ///
  /// In en, this message translates to:
  /// **'We’ll make it the primary sport on your venue profile.'**
  String get onb_primary_subtitle_host;

  /// No description provided for @onb_sports_search.
  ///
  /// In en, this message translates to:
  /// **'Search sports'**
  String get onb_sports_search;

  /// No description provided for @onb_sports_none.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that. Try another name.'**
  String get onb_sports_none;

  /// No description provided for @onb_sports_count_zero.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one to continue.'**
  String get onb_sports_count_zero;

  /// No description provided for @onb_sports_count_one.
  ///
  /// In en, this message translates to:
  /// **'1 sport selected'**
  String get onb_sports_count_one;

  /// No description provided for @onb_sports_count_many.
  ///
  /// In en, this message translates to:
  /// **'{count} sports selected'**
  String onb_sports_count_many(int count);

  /// No description provided for @onb_primary_more.
  ///
  /// In en, this message translates to:
  /// **'Add more sports'**
  String get onb_primary_more;

  /// No description provided for @onb_identity_title.
  ///
  /// In en, this message translates to:
  /// **'What should people call you?'**
  String get onb_identity_title;

  /// No description provided for @onb_identity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Set the name and username people will see around Dabbler.'**
  String get onb_identity_subtitle;

  /// No description provided for @onb_display_name_label.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get onb_display_name_label;

  /// No description provided for @onb_display_name_helper.
  ///
  /// In en, this message translates to:
  /// **'This is the name people see around Dabbler.'**
  String get onb_display_name_helper;

  /// No description provided for @onb_suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get onb_suggestions;

  /// No description provided for @onb_username_label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onb_username_label;

  /// No description provided for @onb_username_placeholder.
  ///
  /// In en, this message translates to:
  /// **'@yourname'**
  String get onb_username_placeholder;

  /// No description provided for @onb_username_helper.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers and underscores.'**
  String get onb_username_helper;

  /// No description provided for @onb_username_short.
  ///
  /// In en, this message translates to:
  /// **'A username needs at least 3 characters.'**
  String get onb_username_short;

  /// No description provided for @onb_username_invalid.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers and underscores only.'**
  String get onb_username_invalid;

  /// No description provided for @onb_username_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking availability…'**
  String get onb_username_checking;

  /// No description provided for @onb_username_taken.
  ///
  /// In en, this message translates to:
  /// **'That one is taken. Try another.'**
  String get onb_username_taken;

  /// No description provided for @onb_username_available.
  ///
  /// In en, this message translates to:
  /// **'Available — this one is yours.'**
  String get onb_username_available;

  /// No description provided for @onb_username_check_error.
  ///
  /// In en, this message translates to:
  /// **'We could not check that username. Try again.'**
  String get onb_username_check_error;

  /// No description provided for @onb_create_account.
  ///
  /// In en, this message translates to:
  /// **'Create my account'**
  String get onb_create_account;

  /// No description provided for @onb_setup_title.
  ///
  /// In en, this message translates to:
  /// **'Setting up your account'**
  String get onb_setup_title;

  /// No description provided for @onb_setup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This only takes a moment.'**
  String get onb_setup_subtitle;

  /// No description provided for @onb_setup_stage_profile.
  ///
  /// In en, this message translates to:
  /// **'Creating your profile'**
  String get onb_setup_stage_profile;

  /// No description provided for @onb_setup_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Setup did not finish'**
  String get onb_setup_failed_title;

  /// No description provided for @primary_sport_adding.
  ///
  /// In en, this message translates to:
  /// **'Adding {label} Profile'**
  String primary_sport_adding(String label);

  /// No description provided for @identity_verify_title.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get identity_verify_title;

  /// No description provided for @identity_verify_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get identity_verify_email_label;

  /// No description provided for @identity_verify_email_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get identity_verify_email_hint;

  /// No description provided for @identity_verify_continue_sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get identity_verify_continue_sending;

  /// No description provided for @identity_verify_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get identity_verify_continue;

  /// No description provided for @identity_verify_or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get identity_verify_or;

  /// No description provided for @identity_verify_google_btn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get identity_verify_google_btn;

  /// No description provided for @identity_verify_terms_prefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get identity_verify_terms_prefix;

  /// No description provided for @identity_verify_terms_link.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get identity_verify_terms_link;

  /// No description provided for @identity_verify_terms_and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get identity_verify_terms_and;

  /// No description provided for @identity_verify_privacy_link.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get identity_verify_privacy_link;

  /// No description provided for @identity_verify_otp_sent_email.
  ///
  /// In en, this message translates to:
  /// **'OTP sent! Please check your email.'**
  String get identity_verify_otp_sent_email;

  /// No description provided for @identity_verify_otp_sent_phone.
  ///
  /// In en, this message translates to:
  /// **'OTP sent! Please check your phone.'**
  String get identity_verify_otp_sent_phone;

  /// No description provided for @identity_verify_phone_disabled.
  ///
  /// In en, this message translates to:
  /// **'Phone authentication is not available yet. Please use email to continue.'**
  String get identity_verify_phone_disabled;

  /// No description provided for @identity_verify_service_error.
  ///
  /// In en, this message translates to:
  /// **'Service error: {error}'**
  String identity_verify_service_error(String error);

  /// No description provided for @identity_verify_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Please try again.'**
  String get identity_verify_error_generic;

  /// No description provided for @identity_verify_nav_failed.
  ///
  /// In en, this message translates to:
  /// **'Navigation failed: {error}'**
  String identity_verify_nav_failed(String error);

  /// No description provided for @identity_verify_use_email.
  ///
  /// In en, this message translates to:
  /// **'Please use your email address'**
  String get identity_verify_use_email;

  /// No description provided for @identity_verify_required.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number is required'**
  String get identity_verify_required;

  /// No description provided for @identity_verify_google_failed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get identity_verify_google_failed;

  /// No description provided for @welcome_screen_title_first_time.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Dabbler 😉'**
  String get welcome_screen_title_first_time;

  /// No description provided for @welcome_screen_title_returning.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back! 👋'**
  String get welcome_screen_title_returning;

  /// No description provided for @welcome_screen_title_conversion.
  ///
  /// In en, this message translates to:
  /// **'Conversion Complete! 🎉'**
  String get welcome_screen_title_conversion;

  /// No description provided for @welcome_screen_dont_forget.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget'**
  String get welcome_screen_dont_forget;

  /// No description provided for @welcome_screen_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get welcome_screen_continue;

  /// No description provided for @welcome_screen_chip_player.
  ///
  /// In en, this message translates to:
  /// **'Sports player'**
  String get welcome_screen_chip_player;

  /// No description provided for @welcome_screen_chip_organiser.
  ///
  /// In en, this message translates to:
  /// **'Games organiser'**
  String get welcome_screen_chip_organiser;

  /// No description provided for @welcome_screen_chip_host.
  ///
  /// In en, this message translates to:
  /// **'Venue host'**
  String get welcome_screen_chip_host;

  /// No description provided for @welcome_screen_chip_socialiser.
  ///
  /// In en, this message translates to:
  /// **'Sports socialiser'**
  String get welcome_screen_chip_socialiser;

  /// No description provided for @welcome_screen_player_guidance.
  ///
  /// In en, this message translates to:
  /// **'Join games that match your level, respect the rules set by the organiser, and confirm only when you\'re ready to play.'**
  String get welcome_screen_player_guidance;

  /// No description provided for @welcome_screen_player_philosophy.
  ///
  /// In en, this message translates to:
  /// **'Your reliability builds your reputation.'**
  String get welcome_screen_player_philosophy;

  /// No description provided for @welcome_screen_player_reminder.
  ///
  /// In en, this message translates to:
  /// **'Confirm only when you\'re sure you can play.\nRespect the rules, timing, and other players.'**
  String get welcome_screen_player_reminder;

  /// No description provided for @welcome_screen_player_emphasis.
  ///
  /// In en, this message translates to:
  /// **'Confirm only when you\'re ready to play'**
  String get welcome_screen_player_emphasis;

  /// No description provided for @welcome_screen_organiser_guidance.
  ///
  /// In en, this message translates to:
  /// **'Create games with clear rules, fair skill levels, and realistic timings.'**
  String get welcome_screen_organiser_guidance;

  /// No description provided for @welcome_screen_organiser_philosophy.
  ///
  /// In en, this message translates to:
  /// **'You set the tone — great games start with great organisation.'**
  String get welcome_screen_organiser_philosophy;

  /// No description provided for @welcome_screen_organiser_reminder.
  ///
  /// In en, this message translates to:
  /// **'Set clear rules and realistic timings.\nCommunicate changes early and clearly.'**
  String get welcome_screen_organiser_reminder;

  /// No description provided for @welcome_screen_organiser_emphasis.
  ///
  /// In en, this message translates to:
  /// **'Continue only when you\'re ready!'**
  String get welcome_screen_organiser_emphasis;

  /// No description provided for @welcome_screen_host_guidance.
  ///
  /// In en, this message translates to:
  /// **'Help players feel welcome by keeping information accurate and spaces ready.'**
  String get welcome_screen_host_guidance;

  /// No description provided for @welcome_screen_host_philosophy.
  ///
  /// In en, this message translates to:
  /// **'Clear availability and smooth coordination make everyone\'s experience better.'**
  String get welcome_screen_host_philosophy;

  /// No description provided for @welcome_screen_host_reminder.
  ///
  /// In en, this message translates to:
  /// **'Keep availability and details accurate.\nUpdate information as soon as things change.'**
  String get welcome_screen_host_reminder;

  /// No description provided for @welcome_screen_host_emphasis.
  ///
  /// In en, this message translates to:
  /// **'Continue only when you\'re ready!'**
  String get welcome_screen_host_emphasis;

  /// No description provided for @welcome_screen_socialiser_guidance.
  ///
  /// In en, this message translates to:
  /// **'Connect with players, spark conversations, and help games feel more human.'**
  String get welcome_screen_socialiser_guidance;

  /// No description provided for @welcome_screen_socialiser_philosophy.
  ///
  /// In en, this message translates to:
  /// **'Your presence shapes the community — friendly, inclusive, and respectful.'**
  String get welcome_screen_socialiser_philosophy;

  /// No description provided for @welcome_screen_socialiser_reminder.
  ///
  /// In en, this message translates to:
  /// **'Be respectful and inclusive.\nAdd value without disrupting the game.'**
  String get welcome_screen_socialiser_reminder;

  /// No description provided for @welcome_screen_socialiser_emphasis.
  ///
  /// In en, this message translates to:
  /// **'Continue only when you\'re ready!'**
  String get welcome_screen_socialiser_emphasis;

  /// No description provided for @onboarding_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Setting up your account'**
  String get onboarding_welcome_title;

  /// No description provided for @onboarding_welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This only takes a moment…'**
  String get onboarding_welcome_subtitle;

  /// No description provided for @onboarding_welcome_step_profile.
  ///
  /// In en, this message translates to:
  /// **'Creating your profile'**
  String get onboarding_welcome_step_profile;

  /// No description provided for @social_onboarding_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Social'**
  String get social_onboarding_welcome_title;

  /// No description provided for @social_onboarding_welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with fellow players, share your game experiences, and build your sports community.'**
  String get social_onboarding_welcome_subtitle;

  /// No description provided for @social_onboarding_welcome_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get social_onboarding_welcome_skip;

  /// No description provided for @social_onboarding_welcome_get_started.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get social_onboarding_welcome_get_started;

  /// No description provided for @social_onboarding_welcome_find_friends_title.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get social_onboarding_welcome_find_friends_title;

  /// No description provided for @social_onboarding_welcome_find_friends_desc.
  ///
  /// In en, this message translates to:
  /// **'Connect with players in your area'**
  String get social_onboarding_welcome_find_friends_desc;

  /// No description provided for @social_onboarding_welcome_chat_title.
  ///
  /// In en, this message translates to:
  /// **'Chat & Share'**
  String get social_onboarding_welcome_chat_title;

  /// No description provided for @social_onboarding_welcome_chat_desc.
  ///
  /// In en, this message translates to:
  /// **'Message friends and share game moments'**
  String get social_onboarding_welcome_chat_desc;

  /// No description provided for @social_onboarding_welcome_game_title.
  ///
  /// In en, this message translates to:
  /// **'Game Together'**
  String get social_onboarding_welcome_game_title;

  /// No description provided for @social_onboarding_welcome_game_desc.
  ///
  /// In en, this message translates to:
  /// **'Discover and join games with your network'**
  String get social_onboarding_welcome_game_desc;

  /// No description provided for @social_onboarding_friends_appbar.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get social_onboarding_friends_appbar;

  /// No description provided for @social_onboarding_friends_title.
  ///
  /// In en, this message translates to:
  /// **'Find Your Sports Community'**
  String get social_onboarding_friends_title;

  /// No description provided for @social_onboarding_friends_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with friends to share game experiences and discover new opportunities.'**
  String get social_onboarding_friends_subtitle;

  /// No description provided for @social_onboarding_friends_sync_btn.
  ///
  /// In en, this message translates to:
  /// **'Sync Contacts'**
  String get social_onboarding_friends_sync_btn;

  /// No description provided for @social_onboarding_friends_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get social_onboarding_friends_syncing;

  /// No description provided for @social_onboarding_friends_or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get social_onboarding_friends_or;

  /// No description provided for @social_onboarding_friends_suggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested for You'**
  String get social_onboarding_friends_suggested;

  /// No description provided for @social_onboarding_friends_selected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String social_onboarding_friends_selected(int count);

  /// No description provided for @social_onboarding_friends_mutual_one.
  ///
  /// In en, this message translates to:
  /// **'{count} mutual friend'**
  String social_onboarding_friends_mutual_one(int count);

  /// No description provided for @social_onboarding_friends_mutual_many.
  ///
  /// In en, this message translates to:
  /// **'{count} mutual friends'**
  String social_onboarding_friends_mutual_many(int count);

  /// No description provided for @social_onboarding_friends_add_btn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get social_onboarding_friends_add_btn;

  /// No description provided for @social_onboarding_friends_added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get social_onboarding_friends_added;

  /// No description provided for @social_onboarding_friends_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get social_onboarding_friends_skip;

  /// No description provided for @social_onboarding_friends_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get social_onboarding_friends_continue;

  /// No description provided for @social_onboarding_friends_send_requests.
  ///
  /// In en, this message translates to:
  /// **'Send {count} Requests & Continue'**
  String social_onboarding_friends_send_requests(int count);

  /// No description provided for @social_onboarding_friends_send_request.
  ///
  /// In en, this message translates to:
  /// **'Send Request & Continue'**
  String get social_onboarding_friends_send_request;

  /// No description provided for @social_onboarding_friends_synced.
  ///
  /// In en, this message translates to:
  /// **'Contacts synced successfully!'**
  String get social_onboarding_friends_synced;

  /// No description provided for @social_onboarding_friends_sync_error.
  ///
  /// In en, this message translates to:
  /// **'Error accessing contacts. Please try again.'**
  String get social_onboarding_friends_sync_error;

  /// No description provided for @social_onboarding_friends_sent.
  ///
  /// In en, this message translates to:
  /// **'Friend requests sent to {count} people!'**
  String social_onboarding_friends_sent(int count);

  /// No description provided for @social_onboarding_notif_appbar.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get social_onboarding_notif_appbar;

  /// No description provided for @social_onboarding_notif_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications Paused'**
  String get social_onboarding_notif_title;

  /// No description provided for @social_onboarding_notif_body.
  ///
  /// In en, this message translates to:
  /// **'We\'re rebuilding notification preferences. You can finish onboarding now and we\'ll add configuration options in a future update.'**
  String get social_onboarding_notif_body;

  /// No description provided for @social_onboarding_notif_finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get social_onboarding_notif_finish;

  /// No description provided for @social_onboarding_privacy_appbar.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get social_onboarding_privacy_appbar;

  /// No description provided for @social_onboarding_privacy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get social_onboarding_privacy_title;

  /// No description provided for @social_onboarding_privacy_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Control who can see your profile and interact with you. You can always change these settings later.'**
  String get social_onboarding_privacy_subtitle;

  /// No description provided for @social_onboarding_privacy_step.
  ///
  /// In en, this message translates to:
  /// **'3 of 4'**
  String get social_onboarding_privacy_step;

  /// No description provided for @social_onboarding_privacy_profile_visible_title.
  ///
  /// In en, this message translates to:
  /// **'Profile Visible to Friends'**
  String get social_onboarding_privacy_profile_visible_title;

  /// No description provided for @social_onboarding_privacy_profile_visible_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile is visible to your friends'**
  String get social_onboarding_privacy_profile_visible_subtitle;

  /// No description provided for @social_onboarding_privacy_posts_public_title.
  ///
  /// In en, this message translates to:
  /// **'Posts Visible to Public'**
  String get social_onboarding_privacy_posts_public_title;

  /// No description provided for @social_onboarding_privacy_posts_public_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see your posts'**
  String get social_onboarding_privacy_posts_public_subtitle;

  /// No description provided for @social_onboarding_privacy_allow_requests_title.
  ///
  /// In en, this message translates to:
  /// **'Allow Friend Requests'**
  String get social_onboarding_privacy_allow_requests_title;

  /// No description provided for @social_onboarding_privacy_allow_requests_subtitle.
  ///
  /// In en, this message translates to:
  /// **'People can send you friend requests'**
  String get social_onboarding_privacy_allow_requests_subtitle;

  /// No description provided for @social_onboarding_privacy_allow_messages_title.
  ///
  /// In en, this message translates to:
  /// **'Allow Message Requests'**
  String get social_onboarding_privacy_allow_messages_title;

  /// No description provided for @social_onboarding_privacy_allow_messages_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Non-friends can send you messages'**
  String get social_onboarding_privacy_allow_messages_subtitle;

  /// No description provided for @social_onboarding_privacy_online_status_title.
  ///
  /// In en, this message translates to:
  /// **'Show Online Status'**
  String get social_onboarding_privacy_online_status_title;

  /// No description provided for @social_onboarding_privacy_online_status_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Friends can see when you\'re online'**
  String get social_onboarding_privacy_online_status_subtitle;

  /// No description provided for @social_onboarding_privacy_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get social_onboarding_privacy_back;

  /// No description provided for @social_onboarding_privacy_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get social_onboarding_privacy_continue;

  /// No description provided for @social_onboarding_complete_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Social!'**
  String get social_onboarding_complete_title;

  /// No description provided for @social_onboarding_complete_subtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set up! Start connecting with friends, sharing your game experiences, and discovering new players in your area.'**
  String get social_onboarding_complete_subtitle;

  /// No description provided for @social_onboarding_complete_connect_title.
  ///
  /// In en, this message translates to:
  /// **'Connect with Players'**
  String get social_onboarding_complete_connect_title;

  /// No description provided for @social_onboarding_complete_connect_desc.
  ///
  /// In en, this message translates to:
  /// **'Find and add friends who love the same sports'**
  String get social_onboarding_complete_connect_desc;

  /// No description provided for @social_onboarding_complete_share_title.
  ///
  /// In en, this message translates to:
  /// **'Share Your Journey'**
  String get social_onboarding_complete_share_title;

  /// No description provided for @social_onboarding_complete_share_desc.
  ///
  /// In en, this message translates to:
  /// **'Post updates, photos, and celebrate your wins'**
  String get social_onboarding_complete_share_desc;

  /// No description provided for @social_onboarding_complete_discover_title.
  ///
  /// In en, this message translates to:
  /// **'Discover Games'**
  String get social_onboarding_complete_discover_title;

  /// No description provided for @social_onboarding_complete_discover_desc.
  ///
  /// In en, this message translates to:
  /// **'See what games your friends are playing'**
  String get social_onboarding_complete_discover_desc;

  /// No description provided for @social_onboarding_complete_explore_btn.
  ///
  /// In en, this message translates to:
  /// **'Explore Social'**
  String get social_onboarding_complete_explore_btn;

  /// No description provided for @social_onboarding_complete_home_btn.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get social_onboarding_complete_home_btn;

  /// No description provided for @social_onboarding_complete_later.
  ///
  /// In en, this message translates to:
  /// **'I\'ll explore later'**
  String get social_onboarding_complete_later;

  /// No description provided for @language_select_title.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get language_select_title;

  /// No description provided for @language_select_saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get language_select_saving;

  /// No description provided for @register_title.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register_title;

  /// No description provided for @register_btn.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register_btn;

  /// No description provided for @post_card_author_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get post_card_author_anonymous;

  /// No description provided for @post_card_user_fallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get post_card_user_fallback;

  /// No description provided for @post_card_persona_organiser.
  ///
  /// In en, this message translates to:
  /// **'Organiser'**
  String get post_card_persona_organiser;

  /// No description provided for @post_card_persona_player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get post_card_persona_player;

  /// No description provided for @post_card_near_you.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get post_card_near_you;

  /// No description provided for @post_card_edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get post_card_edited;

  /// No description provided for @post_card_menu_repost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get post_card_menu_repost;

  /// No description provided for @post_card_menu_quote_repost.
  ///
  /// In en, this message translates to:
  /// **'Quote Repost'**
  String get post_card_menu_quote_repost;

  /// No description provided for @post_card_kind_moment.
  ///
  /// In en, this message translates to:
  /// **'Moment'**
  String get post_card_kind_moment;

  /// No description provided for @post_card_kind_dab.
  ///
  /// In en, this message translates to:
  /// **'Dab'**
  String get post_card_kind_dab;

  /// No description provided for @post_card_kind_kick_in.
  ///
  /// In en, this message translates to:
  /// **'Kick-in'**
  String get post_card_kind_kick_in;

  /// No description provided for @post_card_kind_game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get post_card_kind_game;

  /// No description provided for @post_card_kind_achievement.
  ///
  /// In en, this message translates to:
  /// **'Achievement'**
  String get post_card_kind_achievement;

  /// No description provided for @post_card_kind_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get post_card_kind_venue;

  /// No description provided for @post_card_kind_admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get post_card_kind_admin;

  /// No description provided for @post_card_kind_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get post_card_kind_system;

  /// No description provided for @post_card_kind_repost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get post_card_kind_repost;

  /// No description provided for @post_card_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get post_card_expired;

  /// No description provided for @post_card_expires_in_days.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}d'**
  String post_card_expires_in_days(int n);

  /// No description provided for @post_card_expires_in_hours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}h'**
  String post_card_expires_in_hours(int n);

  /// No description provided for @post_card_expires_in_minutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}m'**
  String post_card_expires_in_minutes(int n);

  /// No description provided for @post_card_expiring_soon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get post_card_expiring_soon;

  /// No description provided for @repost_card_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Original post is no longer available.'**
  String get repost_card_unavailable;

  /// No description provided for @post_type_original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get post_type_original;

  /// No description provided for @post_type_news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get post_type_news;

  /// No description provided for @post_type_announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get post_type_announcement;

  /// No description provided for @post_type_alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get post_type_alert;

  /// No description provided for @post_type_highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get post_type_highlight;

  /// No description provided for @post_type_general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get post_type_general;

  /// No description provided for @post_type_feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get post_type_feature;

  /// No description provided for @post_card_my_story.
  ///
  /// In en, this message translates to:
  /// **'My Story'**
  String get post_card_my_story;

  /// No description provided for @post_card_kick_in_label.
  ///
  /// In en, this message translates to:
  /// **'Kick-In'**
  String get post_card_kick_in_label;

  /// No description provided for @post_card_allocated.
  ///
  /// In en, this message translates to:
  /// **'Allocated'**
  String get post_card_allocated;

  /// No description provided for @nav_feeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get nav_feeds;

  /// No description provided for @nav_community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get nav_community;

  /// No description provided for @nav_venues.
  ///
  /// In en, this message translates to:
  /// **'Venues'**
  String get nav_venues;

  /// No description provided for @nav_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get nav_games;

  /// No description provided for @nav_meetups.
  ///
  /// In en, this message translates to:
  /// **'Meetups'**
  String get nav_meetups;

  /// No description provided for @nav_create_post.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get nav_create_post;

  /// No description provided for @nav_create_game.
  ///
  /// In en, this message translates to:
  /// **'Create Game'**
  String get nav_create_game;

  /// No description provided for @nav_create_meetup.
  ///
  /// In en, this message translates to:
  /// **'Create Meetup'**
  String get nav_create_meetup;

  /// No description provided for @nav_meetups_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Meetups coming soon!'**
  String get nav_meetups_coming_soon;

  /// No description provided for @nav_exit_app_title.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get nav_exit_app_title;

  /// No description provided for @nav_exit_app_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit Dabbler?'**
  String get nav_exit_app_body;

  /// No description provided for @nav_exit_app_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get nav_exit_app_cancel;

  /// No description provided for @nav_exit_app_confirm.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get nav_exit_app_confirm;

  /// No description provided for @nav_press_back_to_exit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get nav_press_back_to_exit;

  /// No description provided for @nav_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search Dabbler'**
  String get nav_search_hint;

  /// No description provided for @nav_whats_happening.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening'**
  String get nav_whats_happening;

  /// No description provided for @nav_trend_sports_category.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get nav_trend_sports_category;

  /// No description provided for @nav_trend_sports_title.
  ///
  /// In en, this message translates to:
  /// **'New games near you'**
  String get nav_trend_sports_title;

  /// No description provided for @nav_trend_sports_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Check out the latest games in your area'**
  String get nav_trend_sports_subtitle;

  /// No description provided for @nav_trend_community_category.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get nav_trend_community_category;

  /// No description provided for @nav_trend_community_title.
  ///
  /// In en, this message translates to:
  /// **'Growing squads'**
  String get nav_trend_community_title;

  /// No description provided for @nav_trend_community_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Join a squad to play regularly'**
  String get nav_trend_community_subtitle;

  /// No description provided for @nav_trend_dabbler_category.
  ///
  /// In en, this message translates to:
  /// **'Dabbler'**
  String get nav_trend_dabbler_category;

  /// No description provided for @nav_trend_dabbler_title.
  ///
  /// In en, this message translates to:
  /// **'Share your moments'**
  String get nav_trend_dabbler_title;

  /// No description provided for @nav_trend_dabbler_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Post updates and connect with players'**
  String get nav_trend_dabbler_subtitle;

  /// No description provided for @nav_quick_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get nav_quick_actions;

  /// No description provided for @nav_find_friends.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get nav_find_friends;

  /// No description provided for @nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// No description provided for @settings_header_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_header_title;

  /// No description provided for @settings_header_help_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get settings_header_help_tooltip;

  /// No description provided for @settings_hero_eyebrow.
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get settings_hero_eyebrow;

  /// No description provided for @settings_hero_title.
  ///
  /// In en, this message translates to:
  /// **'Tune Dabbler to match how you play'**
  String get settings_hero_title;

  /// No description provided for @settings_hero_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, preferences, and notifications all in one place.'**
  String get settings_hero_subtitle;

  /// No description provided for @settings_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settings_search_hint;

  /// No description provided for @settings_section_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_section_account;

  /// No description provided for @settings_section_display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settings_section_display;

  /// No description provided for @settings_section_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_section_about;

  /// No description provided for @settings_section_profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settings_section_profiles;

  /// No description provided for @settings_item_account_management_title.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get settings_item_account_management_title;

  /// No description provided for @settings_item_account_management_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Email, password, security'**
  String get settings_item_account_management_subtitle;

  /// No description provided for @settings_item_privacy_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get settings_item_privacy_settings_title;

  /// No description provided for @settings_item_privacy_settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage privacy settings and blocked users'**
  String get settings_item_privacy_settings_subtitle;

  /// No description provided for @settings_item_theme_title.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_item_theme_title;

  /// No description provided for @settings_item_theme_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Light, dark, or system default'**
  String get settings_item_theme_subtitle;

  /// No description provided for @settings_item_language_title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_item_language_title;

  /// No description provided for @settings_item_country_title.
  ///
  /// In en, this message translates to:
  /// **'App Country'**
  String get settings_item_country_title;

  /// No description provided for @settings_item_country_default_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Egypt · UAE · KSA · Morocco'**
  String get settings_item_country_default_subtitle;

  /// No description provided for @settings_country_picker_helper.
  ///
  /// In en, this message translates to:
  /// **'Sets which sports and venues you see'**
  String get settings_country_picker_helper;

  /// No description provided for @settings_item_terms_title.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settings_item_terms_title;

  /// No description provided for @settings_item_terms_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our terms and conditions'**
  String get settings_item_terms_subtitle;

  /// No description provided for @settings_item_privacy_policy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settings_item_privacy_policy_title;

  /// No description provided for @settings_item_privacy_policy_subtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get settings_item_privacy_policy_subtitle;

  /// No description provided for @settings_item_licenses_title.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settings_item_licenses_title;

  /// No description provided for @settings_item_licenses_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settings_item_licenses_subtitle;

  /// No description provided for @settings_sign_out_title.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settings_sign_out_title;

  /// No description provided for @settings_sign_out_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave your account on this device'**
  String get settings_sign_out_subtitle;

  /// No description provided for @settings_sign_out_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settings_sign_out_dialog_title;

  /// No description provided for @settings_sign_out_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of your account?'**
  String get settings_sign_out_dialog_body;

  /// No description provided for @settings_sign_out_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_sign_out_dialog_cancel;

  /// No description provided for @settings_sign_out_error.
  ///
  /// In en, this message translates to:
  /// **'Error signing out: {error}'**
  String settings_sign_out_error(String error);

  /// No description provided for @account_delete_dialog_warning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. Your profile and personal data are deleted. Payment and booking records are retained for accounting purposes, for a period that is still being finalized.'**
  String get account_delete_dialog_warning;

  /// No description provided for @account_delete_success_snack.
  ///
  /// In en, this message translates to:
  /// **'Your account and personal data have been deleted.'**
  String get account_delete_success_snack;

  /// No description provided for @danger_zone_delete_confirmation_message.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account and personal data and cannot be undone. Payment and booking records are retained for accounting purposes, for a period that is still being finalized.'**
  String get danger_zone_delete_confirmation_message;

  /// No description provided for @settings_version_app_name.
  ///
  /// In en, this message translates to:
  /// **'Dabbler'**
  String get settings_version_app_name;

  /// No description provided for @settings_version_label.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settings_version_label(String version);

  /// No description provided for @settings_tile_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settings_tile_privacy;

  /// No description provided for @settings_tile_profile_shown.
  ///
  /// In en, this message translates to:
  /// **'Shown on your profile'**
  String get settings_tile_profile_shown;

  /// No description provided for @settings_tile_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_tile_notifications;

  /// No description provided for @settings_tile_appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_tile_appearance;

  /// No description provided for @settings_tile_language_region.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get settings_tile_language_region;

  /// No description provided for @settings_tile_activity_shown.
  ///
  /// In en, this message translates to:
  /// **'Activity & stats shown'**
  String get settings_tile_activity_shown;

  /// No description provided for @settings_tile_blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get settings_tile_blocked;

  /// No description provided for @settings_tile_privacy_label.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get settings_tile_privacy_label;

  /// No description provided for @settings_version_copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Dabbler. All rights reserved.'**
  String get settings_version_copyright;

  /// No description provided for @settings_persona_become_title.
  ///
  /// In en, this message translates to:
  /// **'Become a {persona}'**
  String settings_persona_become_title(String persona);

  /// No description provided for @settings_persona_convert_title.
  ///
  /// In en, this message translates to:
  /// **'Convert to {persona}'**
  String settings_persona_convert_title(String persona);

  /// No description provided for @settings_persona_convert_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace your {persona} profile'**
  String settings_persona_convert_subtitle(String persona);

  /// No description provided for @settings_persona_convert_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate your {fromPersona} profile and create a new {toPersona} profile.\n\nYour account data (age, gender) will be preserved.'**
  String settings_persona_convert_confirm_body(
    String fromPersona,
    String toPersona,
  );

  /// No description provided for @persona_label_host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get persona_label_host;

  /// No description provided for @persona_label_socialiser.
  ///
  /// In en, this message translates to:
  /// **'Socialiser'**
  String get persona_label_socialiser;

  /// No description provided for @profile_header_fallback.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile_header_fallback;

  /// No description provided for @profile_section_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get profile_section_sports;

  /// No description provided for @profile_complete_your_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profile_complete_your_profile;

  /// No description provided for @profile_bio_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Add a short bio so teammates know what to expect.'**
  String get profile_bio_placeholder;

  /// No description provided for @settings_item_edit_profile_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, photo, bio and sports'**
  String get settings_item_edit_profile_subtitle;

  /// No description provided for @profile_btn_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profile_btn_edit;

  /// No description provided for @profile_btn_share.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get profile_btn_share;

  /// No description provided for @profile_btn_manage_profiles_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage profiles'**
  String get profile_btn_manage_profiles_tooltip;

  /// No description provided for @profile_manage_profiles_title.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get profile_manage_profiles_title;

  /// No description provided for @profile_add_profile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get profile_add_profile;

  /// No description provided for @profile_no_profiles_found.
  ///
  /// In en, this message translates to:
  /// **'No profiles found'**
  String get profile_no_profiles_found;

  /// No description provided for @profile_error_loading_profiles.
  ///
  /// In en, this message translates to:
  /// **'Error loading profiles'**
  String get profile_error_loading_profiles;

  /// No description provided for @profile_error_switch_profile_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch profile'**
  String get profile_error_switch_profile_failed;

  /// No description provided for @profile_btn_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profile_btn_cancel;

  /// No description provided for @profile_btn_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profile_btn_continue;

  /// No description provided for @profile_persona_convert_badge.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get profile_persona_convert_badge;

  /// No description provided for @profile_convert_to.
  ///
  /// In en, this message translates to:
  /// **'Convert to {persona}?'**
  String profile_convert_to(String persona);

  /// No description provided for @profile_convert_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to convert from {fromPersona} to {toPersona}. Your current profile will be replaced.'**
  String profile_convert_confirm_body(String fromPersona, String toPersona);

  /// No description provided for @profile_tab_posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profile_tab_posts;

  /// No description provided for @profile_tab_replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get profile_tab_replies;

  /// No description provided for @profile_tab_liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get profile_tab_liked;

  /// No description provided for @profile_tab_reposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get profile_tab_reposts;

  /// No description provided for @profile_tab_activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profile_tab_activity;

  /// No description provided for @profile_empty_no_activity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get profile_empty_no_activity;

  /// No description provided for @profile_empty_no_posts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get profile_empty_no_posts;

  /// No description provided for @profile_empty_no_replies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet'**
  String get profile_empty_no_replies;

  /// No description provided for @profile_empty_no_liked.
  ///
  /// In en, this message translates to:
  /// **'No liked posts yet'**
  String get profile_empty_no_liked;

  /// No description provided for @profile_empty_no_reposts.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get profile_empty_no_reposts;

  /// No description provided for @profile_empty_no_sports.
  ///
  /// In en, this message translates to:
  /// **'No sports added yet'**
  String get profile_empty_no_sports;

  /// No description provided for @profile_error_failed_load_posts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load posts.'**
  String get profile_error_failed_load_posts;

  /// No description provided for @profile_post_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Post} other{Posts}}'**
  String profile_post_count(int count);

  /// No description provided for @profile_follower_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Follower} other{Followers}}'**
  String profile_follower_count(int count);

  /// No description provided for @profile_following_label.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profile_following_label;

  /// No description provided for @profile_takedown_title.
  ///
  /// In en, this message translates to:
  /// **'Content Removed'**
  String get profile_takedown_title;

  /// No description provided for @profile_takedown_body.
  ///
  /// In en, this message translates to:
  /// **'This content has been removed due to a violation of our community guidelines.'**
  String get profile_takedown_body;

  /// No description provided for @user_profile_error_not_found_title.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get user_profile_error_not_found_title;

  /// No description provided for @user_profile_error_unable_to_load.
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile'**
  String get user_profile_error_unable_to_load;

  /// No description provided for @user_profile_btn_go_back.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get user_profile_btn_go_back;

  /// No description provided for @user_profile_btn_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get user_profile_btn_loading;

  /// No description provided for @user_profile_btn_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get user_profile_btn_unblock;

  /// No description provided for @user_profile_btn_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get user_profile_btn_follow;

  /// No description provided for @user_profile_btn_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get user_profile_btn_following;

  /// No description provided for @user_profile_age_suffix.
  ///
  /// In en, this message translates to:
  /// **'Yo'**
  String get user_profile_age_suffix;

  /// No description provided for @user_profile_stat_games.
  ///
  /// In en, this message translates to:
  /// **'Games played'**
  String get user_profile_stat_games;

  /// No description provided for @user_profile_stat_win_rate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get user_profile_stat_win_rate;

  /// No description provided for @user_profile_stat_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports played'**
  String get user_profile_stat_sports;

  /// No description provided for @user_profile_stat_reliability.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get user_profile_stat_reliability;

  /// No description provided for @user_profile_stat_activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get user_profile_stat_activity;

  /// No description provided for @user_profile_stat_last_play.
  ///
  /// In en, this message translates to:
  /// **'Last play'**
  String get user_profile_stat_last_play;

  /// No description provided for @user_profile_block_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get user_profile_block_dialog_title;

  /// No description provided for @user_profile_block_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block this user? They won\'t be able to see your profile or contact you.'**
  String get user_profile_block_dialog_body;

  /// No description provided for @user_profile_block_btn_block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get user_profile_block_btn_block;

  /// No description provided for @user_profile_blocked_snack.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get user_profile_blocked_snack;

  /// No description provided for @user_profile_unblocked_snack.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get user_profile_unblocked_snack;

  /// No description provided for @user_profile_menu_unblock_user.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get user_profile_menu_unblock_user;

  /// No description provided for @user_profile_menu_block_user.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get user_profile_menu_block_user;

  /// No description provided for @user_profile_menu_report_user.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get user_profile_menu_report_user;

  /// No description provided for @user_profile_cannot_message_blocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot message a blocked user'**
  String get user_profile_cannot_message_blocked;

  /// No description provided for @notif_signin_required.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view notifications'**
  String get notif_signin_required;

  /// No description provided for @notif_title_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notif_title_notifications;

  /// No description provided for @notif_title_activity_log.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get notif_title_activity_log;

  /// No description provided for @notif_chip_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notif_chip_all;

  /// No description provided for @notif_chip_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get notif_chip_games;

  /// No description provided for @notif_chip_bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get notif_chip_bookings;

  /// No description provided for @notif_chip_social.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get notif_chip_social;

  /// No description provided for @notif_chip_achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get notif_chip_achievements;

  /// No description provided for @notif_chip_you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get notif_chip_you;

  /// No description provided for @notif_chip_rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get notif_chip_rewards;

  /// No description provided for @notif_chip_security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get notif_chip_security;

  /// No description provided for @notif_section_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notif_section_today;

  /// No description provided for @notif_section_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notif_section_yesterday;

  /// No description provided for @notif_section_earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notif_section_earlier;

  /// No description provided for @notif_mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notif_mark_all_read;

  /// No description provided for @notif_action_respond.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get notif_action_respond;

  /// No description provided for @notif_action_follow_back.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get notif_action_follow_back;

  /// No description provided for @notif_action_view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get notif_action_view;

  /// No description provided for @notif_action_see_circle.
  ///
  /// In en, this message translates to:
  /// **'See circle'**
  String get notif_action_see_circle;

  /// No description provided for @notif_load_older.
  ///
  /// In en, this message translates to:
  /// **'Load older'**
  String get notif_load_older;

  /// No description provided for @notif_empty_no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notif_empty_no_notifications;

  /// No description provided for @notif_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify you when something happens'**
  String get notif_empty_subtitle;

  /// No description provided for @notif_btn_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notif_btn_retry;

  /// No description provided for @notif_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String notif_error_prefix(String message);

  /// No description provided for @activity_last_7_days.
  ///
  /// In en, this message translates to:
  /// **'LAST 7 DAYS'**
  String get activity_last_7_days;

  /// No description provided for @activity_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search activity…'**
  String get activity_search_hint;

  /// No description provided for @activity_pill_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get activity_pill_upcoming;

  /// No description provided for @activity_pill_live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get activity_pill_live;

  /// No description provided for @activity_subject_reward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get activity_subject_reward;

  /// No description provided for @activity_subject_security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get activity_subject_security;

  /// No description provided for @activity_all_normal_title.
  ///
  /// In en, this message translates to:
  /// **'All activity looks normal'**
  String get activity_all_normal_title;

  /// No description provided for @activity_all_normal_body.
  ///
  /// In en, this message translates to:
  /// **'No unusual sign-ins or device changes in the past 30 days. '**
  String get activity_all_normal_body;

  /// No description provided for @activity_manage_devices.
  ///
  /// In en, this message translates to:
  /// **'Manage devices →'**
  String get activity_manage_devices;

  /// No description provided for @activity_empty_no_activity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get activity_empty_no_activity;

  /// No description provided for @activity_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your activity will appear here'**
  String get activity_empty_subtitle;

  /// No description provided for @activity_day_streak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get activity_day_streak;

  /// No description provided for @activity_participants_count.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String activity_participants_count(int count);

  /// No description provided for @time_just_now.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get time_just_now;

  /// No description provided for @time_minutes_ago.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String time_minutes_ago(int n);

  /// No description provided for @time_hours_ago.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String time_hours_ago(int n);

  /// No description provided for @time_days_ago.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String time_days_ago(int n);

  /// No description provided for @notif_kind_friend_requested.
  ///
  /// In en, this message translates to:
  /// **'{actor} sent you a friend request'**
  String notif_kind_friend_requested(String actor);

  /// No description provided for @notif_kind_friend_requested_anon.
  ///
  /// In en, this message translates to:
  /// **'You have a new friend request'**
  String get notif_kind_friend_requested_anon;

  /// No description provided for @notif_kind_friend_accepted.
  ///
  /// In en, this message translates to:
  /// **'{actor} accepted your friend request'**
  String notif_kind_friend_accepted(String actor);

  /// No description provided for @notif_kind_friend_accepted_anon.
  ///
  /// In en, this message translates to:
  /// **'Your friend request was accepted'**
  String get notif_kind_friend_accepted_anon;

  /// No description provided for @notif_kind_social_followed.
  ///
  /// In en, this message translates to:
  /// **'{actor} started following you'**
  String notif_kind_social_followed(String actor);

  /// No description provided for @notif_kind_social_followed_anon.
  ///
  /// In en, this message translates to:
  /// **'You have a new follower'**
  String get notif_kind_social_followed_anon;

  /// No description provided for @notif_kind_social_circle_joined.
  ///
  /// In en, this message translates to:
  /// **'{actor} joined your circle'**
  String notif_kind_social_circle_joined(String actor);

  /// No description provided for @notif_kind_social_circle_joined_anon.
  ///
  /// In en, this message translates to:
  /// **'Someone joined your circle'**
  String get notif_kind_social_circle_joined_anon;

  /// No description provided for @notif_kind_social_post_liked.
  ///
  /// In en, this message translates to:
  /// **'{actor} liked your post'**
  String notif_kind_social_post_liked(String actor);

  /// No description provided for @notif_kind_social_post_liked_anon.
  ///
  /// In en, this message translates to:
  /// **'Someone liked your post'**
  String get notif_kind_social_post_liked_anon;

  /// No description provided for @notif_kind_social_post_commented.
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on your post'**
  String notif_kind_social_post_commented(String actor);

  /// No description provided for @notif_kind_social_post_commented_anon.
  ///
  /// In en, this message translates to:
  /// **'New comment on your post'**
  String get notif_kind_social_post_commented_anon;

  /// No description provided for @notif_kind_social_comment_liked.
  ///
  /// In en, this message translates to:
  /// **'{actor} liked your comment'**
  String notif_kind_social_comment_liked(String actor);

  /// No description provided for @notif_kind_social_comment_liked_anon.
  ///
  /// In en, this message translates to:
  /// **'Someone liked your comment'**
  String get notif_kind_social_comment_liked_anon;

  /// No description provided for @notif_kind_social_mentioned.
  ///
  /// In en, this message translates to:
  /// **'{actor} mentioned you'**
  String notif_kind_social_mentioned(String actor);

  /// No description provided for @notif_kind_social_mentioned_anon.
  ///
  /// In en, this message translates to:
  /// **'You were mentioned'**
  String get notif_kind_social_mentioned_anon;

  /// No description provided for @notif_kind_game_invited.
  ///
  /// In en, this message translates to:
  /// **'{actor} invited you to a game'**
  String notif_kind_game_invited(String actor);

  /// No description provided for @notif_kind_game_invited_anon.
  ///
  /// In en, this message translates to:
  /// **'You have a new game invite'**
  String get notif_kind_game_invited_anon;

  /// No description provided for @notif_kind_game_updated.
  ///
  /// In en, this message translates to:
  /// **'Game details updated'**
  String get notif_kind_game_updated;

  /// No description provided for @notif_kind_game_join_request.
  ///
  /// In en, this message translates to:
  /// **'{actor} requested to join your game'**
  String notif_kind_game_join_request(String actor);

  /// No description provided for @notif_kind_game_join_request_anon.
  ///
  /// In en, this message translates to:
  /// **'Someone requested to join your game'**
  String get notif_kind_game_join_request_anon;

  /// No description provided for @notif_kind_game_waitlist_promoted.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! A spot opened up'**
  String get notif_kind_game_waitlist_promoted;

  /// No description provided for @notif_kind_game_reminder.
  ///
  /// In en, this message translates to:
  /// **'Game reminder'**
  String get notif_kind_game_reminder;

  /// No description provided for @notif_kind_arena_payment_required.
  ///
  /// In en, this message translates to:
  /// **'Payment required for your booking'**
  String get notif_kind_arena_payment_required;

  /// No description provided for @notif_kind_reward_badge_awarded.
  ///
  /// In en, this message translates to:
  /// **'You earned a new badge'**
  String get notif_kind_reward_badge_awarded;

  /// No description provided for @notif_kind_achievement_earned.
  ///
  /// In en, this message translates to:
  /// **'You unlocked a new achievement'**
  String get notif_kind_achievement_earned;

  /// No description provided for @settings_identity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, password & security'**
  String get settings_identity_subtitle;

  /// No description provided for @settings_tile_privacy_preset.
  ///
  /// In en, this message translates to:
  /// **'Privacy preset'**
  String get settings_tile_privacy_preset;

  /// No description provided for @settings_preset_public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get settings_preset_public;

  /// No description provided for @settings_preset_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get settings_preset_friends;

  /// No description provided for @settings_preset_private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get settings_preset_private;

  /// No description provided for @settings_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_theme_light;

  /// No description provided for @settings_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_theme_dark;

  /// No description provided for @settings_theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settings_theme_system;

  /// No description provided for @settings_country_short_eg.
  ///
  /// In en, this message translates to:
  /// **'Egypt'**
  String get settings_country_short_eg;

  /// No description provided for @settings_country_short_ae.
  ///
  /// In en, this message translates to:
  /// **'UAE'**
  String get settings_country_short_ae;

  /// No description provided for @settings_country_short_sa.
  ///
  /// In en, this message translates to:
  /// **'Saudi'**
  String get settings_country_short_sa;

  /// No description provided for @settings_country_short_ma.
  ///
  /// In en, this message translates to:
  /// **'Morocco'**
  String get settings_country_short_ma;

  /// No description provided for @settings_organiser_title.
  ///
  /// In en, this message translates to:
  /// **'Become an organiser'**
  String get settings_organiser_title;

  /// No description provided for @settings_organiser_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and manage sports events'**
  String get settings_organiser_subtitle;

  /// No description provided for @settings_organiser_info_body.
  ///
  /// In en, this message translates to:
  /// **'Organisers create games, set venues and prices, and manage who joins. Setting one up takes a few minutes and you keep your player profile.'**
  String get settings_organiser_info_body;

  /// No description provided for @settings_organiser_start.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get settings_organiser_start;

  /// No description provided for @settings_about_title.
  ///
  /// In en, this message translates to:
  /// **'About Dabbler'**
  String get settings_about_title;

  /// No description provided for @settings_about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms, privacy policy, licenses'**
  String get settings_about_subtitle;

  /// No description provided for @settings_search_results.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String settings_search_results(int count);

  /// No description provided for @settings_search_no_match.
  ///
  /// In en, this message translates to:
  /// **'No settings match that'**
  String get settings_search_no_match;

  /// No description provided for @settings_path_account.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get settings_path_account;

  /// No description provided for @settings_path_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settings_path_privacy;

  /// No description provided for @settings_path_privacy_safety.
  ///
  /// In en, this message translates to:
  /// **'Privacy › Safety'**
  String get settings_path_privacy_safety;

  /// No description provided for @settings_path_appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_path_appearance;

  /// No description provided for @settings_path_profiles.
  ///
  /// In en, this message translates to:
  /// **'Settings › Profiles'**
  String get settings_path_profiles;

  /// No description provided for @settings_path_root.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_path_root;

  /// No description provided for @settings_sign_out_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out on this device. Your games and profile stay on your account.'**
  String get settings_sign_out_confirm_body;

  /// No description provided for @notif_group_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String notif_group_count(int count);

  /// No description provided for @notif_prefs_title.
  ///
  /// In en, this message translates to:
  /// **'What reaches you'**
  String get notif_prefs_title;

  /// No description provided for @notif_prefs_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notif_prefs_done;

  /// No description provided for @notif_pref_invites_title.
  ///
  /// In en, this message translates to:
  /// **'Game invites'**
  String get notif_pref_invites_title;

  /// No description provided for @notif_pref_invites_sub.
  ///
  /// In en, this message translates to:
  /// **'When someone adds you to a game'**
  String get notif_pref_invites_sub;

  /// No description provided for @notif_pref_waitlist_title.
  ///
  /// In en, this message translates to:
  /// **'Waitlist spots'**
  String get notif_pref_waitlist_title;

  /// No description provided for @notif_pref_waitlist_sub.
  ///
  /// In en, this message translates to:
  /// **'The moment a place frees up'**
  String get notif_pref_waitlist_sub;

  /// No description provided for @notif_pref_payments_title.
  ///
  /// In en, this message translates to:
  /// **'Payments and splits'**
  String get notif_pref_payments_title;

  /// No description provided for @notif_pref_payments_sub.
  ///
  /// In en, this message translates to:
  /// **'Requests, receipts, refunds'**
  String get notif_pref_payments_sub;

  /// No description provided for @notif_pref_social_title.
  ///
  /// In en, this message translates to:
  /// **'Social activity'**
  String get notif_pref_social_title;

  /// No description provided for @notif_pref_social_sub.
  ///
  /// In en, this message translates to:
  /// **'Follows, replies, mentions'**
  String get notif_pref_social_sub;

  /// No description provided for @notif_quiet_hours_title.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notif_quiet_hours_title;

  /// No description provided for @notif_quiet_hours_sub.
  ///
  /// In en, this message translates to:
  /// **'Nothing buzzes between these times'**
  String get notif_quiet_hours_sub;

  /// No description provided for @notif_quiet_hours_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notif_quiet_hours_off;

  /// No description provided for @notif_quiet_hours_range.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String notif_quiet_hours_range(String start, String end);

  /// No description provided for @acct_title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get acct_title;

  /// No description provided for @acct_group_signin.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get acct_group_signin;

  /// No description provided for @acct_row_email.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get acct_row_email;

  /// No description provided for @acct_row_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get acct_row_password;

  /// No description provided for @acct_group_security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get acct_group_security;

  /// No description provided for @acct_group_security_note.
  ///
  /// In en, this message translates to:
  /// **'Protect your account with additional security measures'**
  String get acct_group_security_note;

  /// No description provided for @acct_2fa_title.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get acct_2fa_title;

  /// No description provided for @acct_2fa_sub.
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of security'**
  String get acct_2fa_sub;

  /// No description provided for @acct_alerts_title.
  ///
  /// In en, this message translates to:
  /// **'Login alerts'**
  String get acct_alerts_title;

  /// No description provided for @acct_alerts_sub.
  ///
  /// In en, this message translates to:
  /// **'Get notified of new sign-ins'**
  String get acct_alerts_sub;

  /// No description provided for @acct_group_danger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get acct_group_danger;

  /// No description provided for @acct_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get acct_delete_title;

  /// No description provided for @acct_delete_sub.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all data'**
  String get acct_delete_sub;

  /// No description provided for @acct_delete_body.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and all data, including games, stats and messages. It cannot be undone.'**
  String get acct_delete_body;

  /// No description provided for @acct_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get acct_delete_confirm;

  /// No description provided for @acct_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get acct_cancel;

  /// No description provided for @acct_delete_type_error.
  ///
  /// In en, this message translates to:
  /// **'Please type \"DELETE\" to confirm'**
  String get acct_delete_type_error;

  /// No description provided for @acct_delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String acct_delete_failed(String error);

  /// No description provided for @acct_email_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get acct_email_sheet_title;

  /// No description provided for @acct_email_field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get acct_email_field;

  /// No description provided for @acct_email_helper.
  ///
  /// In en, this message translates to:
  /// **'We send a confirmation link to the new address before it replaces the old one.'**
  String get acct_email_helper;

  /// No description provided for @acct_email_update.
  ///
  /// In en, this message translates to:
  /// **'Update email'**
  String get acct_email_update;

  /// No description provided for @acct_email_updating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get acct_email_updating;

  /// No description provided for @acct_email_empty.
  ///
  /// In en, this message translates to:
  /// **'Email cannot be empty'**
  String get acct_email_empty;

  /// No description provided for @acct_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get acct_email_invalid;

  /// No description provided for @acct_email_same.
  ///
  /// In en, this message translates to:
  /// **'New email is the same as current email'**
  String get acct_email_same;

  /// No description provided for @acct_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation sent'**
  String get acct_email_sent;

  /// No description provided for @acct_email_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update email: {error}'**
  String acct_email_failed(String error);

  /// No description provided for @acct_password_change_title.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get acct_password_change_title;

  /// No description provided for @acct_password_set_title.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get acct_password_set_title;

  /// No description provided for @acct_password_set_note.
  ///
  /// In en, this message translates to:
  /// **'You signed in with Google or Apple. Set a password to also sign in with your email.'**
  String get acct_password_set_note;

  /// No description provided for @acct_password_current.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get acct_password_current;

  /// No description provided for @acct_password_new.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get acct_password_new;

  /// No description provided for @acct_password_new_helper.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get acct_password_new_helper;

  /// No description provided for @acct_password_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get acct_password_confirm;

  /// No description provided for @acct_password_change.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get acct_password_change;

  /// No description provided for @acct_password_set.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get acct_password_set;

  /// No description provided for @acct_password_changing.
  ///
  /// In en, this message translates to:
  /// **'Changing…'**
  String get acct_password_changing;

  /// No description provided for @acct_password_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting…'**
  String get acct_password_setting;

  /// No description provided for @acct_password_changed.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get acct_password_changed;

  /// No description provided for @acct_password_was_set.
  ///
  /// In en, this message translates to:
  /// **'Password set. You can now sign in with your email and password.'**
  String get acct_password_was_set;

  /// No description provided for @acct_password_err_current.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get acct_password_err_current;

  /// No description provided for @acct_password_err_new.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get acct_password_err_new;

  /// No description provided for @acct_password_err_short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters long'**
  String get acct_password_err_short;

  /// No description provided for @acct_password_err_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get acct_password_err_mismatch;

  /// No description provided for @acct_password_err_same.
  ///
  /// In en, this message translates to:
  /// **'New password must be different from current password'**
  String get acct_password_err_same;

  /// No description provided for @acct_password_err_incorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get acct_password_err_incorrect;

  /// No description provided for @acct_password_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password: {error}'**
  String acct_password_failed(String error);

  /// No description provided for @acct_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load account data: {error}'**
  String acct_load_failed(String error);

  /// No description provided for @acct_export_title.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get acct_export_title;

  /// No description provided for @acct_export_sub.
  ///
  /// In en, this message translates to:
  /// **'Request a copy of your Dabbler data (PDPL data portability)'**
  String get acct_export_sub;

  /// No description provided for @acct_export_started.
  ///
  /// In en, this message translates to:
  /// **'We\'re preparing your data export. You\'ll be notified by email when it\'s ready.'**
  String get acct_export_started;

  /// No description provided for @acct_export_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not request data export: {error}'**
  String acct_export_failed(String error);

  /// No description provided for @priv_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get priv_title;

  /// No description provided for @priv_preset_header.
  ///
  /// In en, this message translates to:
  /// **'Privacy preset'**
  String get priv_preset_header;

  /// No description provided for @priv_preset_note.
  ///
  /// In en, this message translates to:
  /// **'Choose a preset to quickly configure your privacy settings'**
  String get priv_preset_note;

  /// No description provided for @priv_preset_public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get priv_preset_public;

  /// No description provided for @priv_preset_public_desc.
  ///
  /// In en, this message translates to:
  /// **'Your profile is visible to everyone for easy discovery'**
  String get priv_preset_public_desc;

  /// No description provided for @priv_preset_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get priv_preset_friends;

  /// No description provided for @priv_preset_friends_desc.
  ///
  /// In en, this message translates to:
  /// **'Only your friends can see your full profile'**
  String get priv_preset_friends_desc;

  /// No description provided for @priv_preset_private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get priv_preset_private;

  /// No description provided for @priv_preset_private_desc.
  ///
  /// In en, this message translates to:
  /// **'Minimal information is shared publicly'**
  String get priv_preset_private_desc;

  /// No description provided for @priv_preset_applied.
  ///
  /// In en, this message translates to:
  /// **'{preset} preset applied'**
  String priv_preset_applied(String preset);

  /// No description provided for @priv_preset_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get priv_preset_custom;

  /// No description provided for @priv_preset_custom_desc.
  ///
  /// In en, this message translates to:
  /// **'Your own mix of the settings below'**
  String get priv_preset_custom_desc;

  /// No description provided for @priv_hint.
  ///
  /// In en, this message translates to:
  /// **'You can always customize individual settings below. Changes save automatically.'**
  String get priv_hint;

  /// No description provided for @priv_group_see.
  ///
  /// In en, this message translates to:
  /// **'What others see'**
  String get priv_group_see;

  /// No description provided for @priv_profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile & identity'**
  String get priv_profile_title;

  /// No description provided for @priv_profile_sub.
  ///
  /// In en, this message translates to:
  /// **'Photo, name, bio, age, contact details'**
  String get priv_profile_sub;

  /// No description provided for @priv_activity_title.
  ///
  /// In en, this message translates to:
  /// **'Activity & stats'**
  String get priv_activity_title;

  /// No description provided for @priv_activity_sub.
  ///
  /// In en, this message translates to:
  /// **'Status, check-ins, history, achievements'**
  String get priv_activity_sub;

  /// No description provided for @priv_discover_title.
  ///
  /// In en, this message translates to:
  /// **'Discoverability'**
  String get priv_discover_title;

  /// No description provided for @priv_discover_sub.
  ///
  /// In en, this message translates to:
  /// **'Search indexing and nearby players'**
  String get priv_discover_sub;

  /// No description provided for @priv_group_comm.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get priv_group_comm;

  /// No description provided for @priv_contact_title.
  ///
  /// In en, this message translates to:
  /// **'Who can contact you'**
  String get priv_contact_title;

  /// No description provided for @priv_contact_sub.
  ///
  /// In en, this message translates to:
  /// **'Messages, game invites, friend requests'**
  String get priv_contact_sub;

  /// No description provided for @priv_group_data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get priv_group_data;

  /// No description provided for @priv_data_title.
  ///
  /// In en, this message translates to:
  /// **'Data & analytics'**
  String get priv_data_title;

  /// No description provided for @priv_data_sub.
  ///
  /// In en, this message translates to:
  /// **'Location, recommendations, analytics'**
  String get priv_data_sub;

  /// No description provided for @priv_notif_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get priv_notif_title;

  /// No description provided for @priv_notif_sub.
  ///
  /// In en, this message translates to:
  /// **'Push and email'**
  String get priv_notif_sub;

  /// No description provided for @priv_group_safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get priv_group_safety;

  /// No description provided for @priv_blocked_title.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get priv_blocked_title;

  /// No description provided for @priv_blocked_sub.
  ///
  /// In en, this message translates to:
  /// **'People you\'ve blocked from contacting you'**
  String get priv_blocked_sub;

  /// No description provided for @priv_count_all.
  ///
  /// In en, this message translates to:
  /// **'All {total} on'**
  String priv_count_all(int total);

  /// No description provided for @priv_count_none.
  ///
  /// In en, this message translates to:
  /// **'All off'**
  String get priv_count_none;

  /// No description provided for @priv_count_some.
  ///
  /// In en, this message translates to:
  /// **'{on} of {total} on'**
  String priv_count_some(int on, int total);

  /// No description provided for @priv_contact_nav.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get priv_contact_nav;

  /// No description provided for @priv_dm_title.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get priv_dm_title;

  /// No description provided for @priv_dm_sub.
  ///
  /// In en, this message translates to:
  /// **'Who can send you messages'**
  String get priv_dm_sub;

  /// No description provided for @priv_invites_title.
  ///
  /// In en, this message translates to:
  /// **'Game invites'**
  String get priv_invites_title;

  /// No description provided for @priv_invites_sub.
  ///
  /// In en, this message translates to:
  /// **'Who can invite you to games'**
  String get priv_invites_sub;

  /// No description provided for @priv_requests_title.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get priv_requests_title;

  /// No description provided for @priv_requests_sub.
  ///
  /// In en, this message translates to:
  /// **'Who can send you friend requests'**
  String get priv_requests_sub;

  /// No description provided for @priv_audience_anyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get priv_audience_anyone;

  /// No description provided for @priv_audience_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get priv_audience_friends;

  /// No description provided for @priv_audience_organizers.
  ///
  /// In en, this message translates to:
  /// **'Organizers only'**
  String get priv_audience_organizers;

  /// No description provided for @priv_audience_none.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get priv_audience_none;

  /// No description provided for @priv_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get priv_unblock;

  /// No description provided for @priv_unblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get priv_unblocked;

  /// No description provided for @priv_blocked_empty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get priv_blocked_empty;

  /// No description provided for @priv_blocked_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unblock: {error}'**
  String priv_blocked_failed(String error);

  /// No description provided for @priv_blocked_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load blocked accounts: {error}'**
  String priv_blocked_load_failed(String error);

  /// No description provided for @priv_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings. Please try again.'**
  String get priv_save_failed;

  /// No description provided for @priv_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get priv_saved;

  /// No description provided for @priv_t_photo.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get priv_t_photo;

  /// No description provided for @priv_t_photo_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your profile picture'**
  String get priv_t_photo_sub;

  /// No description provided for @priv_t_name.
  ///
  /// In en, this message translates to:
  /// **'Real name'**
  String get priv_t_name;

  /// No description provided for @priv_t_name_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your full name'**
  String get priv_t_name_sub;

  /// No description provided for @priv_t_bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get priv_t_bio;

  /// No description provided for @priv_t_bio_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your bio on your profile'**
  String get priv_t_bio_sub;

  /// No description provided for @priv_t_age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get priv_t_age;

  /// No description provided for @priv_t_age_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your age on your profile'**
  String get priv_t_age_sub;

  /// No description provided for @priv_t_email.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get priv_t_email;

  /// No description provided for @priv_t_email_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your email to others'**
  String get priv_t_email_sub;

  /// No description provided for @priv_t_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get priv_t_phone;

  /// No description provided for @priv_t_phone_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your phone number'**
  String get priv_t_phone_sub;

  /// No description provided for @priv_t_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get priv_t_location;

  /// No description provided for @priv_t_location_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your general location'**
  String get priv_t_location_sub;

  /// No description provided for @priv_t_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends list'**
  String get priv_t_friends;

  /// No description provided for @priv_t_friends_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your friends publicly'**
  String get priv_t_friends_sub;

  /// No description provided for @priv_t_online.
  ///
  /// In en, this message translates to:
  /// **'Online status'**
  String get priv_t_online;

  /// No description provided for @priv_t_online_sub.
  ///
  /// In en, this message translates to:
  /// **'Show when you\'re online'**
  String get priv_t_online_sub;

  /// No description provided for @priv_t_activity.
  ///
  /// In en, this message translates to:
  /// **'Activity status'**
  String get priv_t_activity;

  /// No description provided for @priv_t_activity_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your recent activity'**
  String get priv_t_activity_sub;

  /// No description provided for @priv_t_checkins.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get priv_t_checkins;

  /// No description provided for @priv_t_checkins_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your venue check-ins'**
  String get priv_t_checkins_sub;

  /// No description provided for @priv_t_posts.
  ///
  /// In en, this message translates to:
  /// **'Posts to public'**
  String get priv_t_posts;

  /// No description provided for @priv_t_posts_sub.
  ///
  /// In en, this message translates to:
  /// **'Make your posts visible to everyone'**
  String get priv_t_posts_sub;

  /// No description provided for @priv_t_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports profiles'**
  String get priv_t_sports;

  /// No description provided for @priv_t_sports_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your sports and skill levels'**
  String get priv_t_sports_sub;

  /// No description provided for @priv_t_history.
  ///
  /// In en, this message translates to:
  /// **'Game history'**
  String get priv_t_history;

  /// No description provided for @priv_t_history_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your past games'**
  String get priv_t_history_sub;

  /// No description provided for @priv_t_stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get priv_t_stats;

  /// No description provided for @priv_t_stats_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your performance stats'**
  String get priv_t_stats_sub;

  /// No description provided for @priv_t_achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get priv_t_achievements;

  /// No description provided for @priv_t_achievements_sub.
  ///
  /// In en, this message translates to:
  /// **'Show your earned achievements'**
  String get priv_t_achievements_sub;

  /// No description provided for @priv_t_indexing.
  ///
  /// In en, this message translates to:
  /// **'Search engine indexing'**
  String get priv_t_indexing;

  /// No description provided for @priv_t_indexing_sub.
  ///
  /// In en, this message translates to:
  /// **'Allow external services to find your profile'**
  String get priv_t_indexing_sub;

  /// No description provided for @priv_t_nearby.
  ///
  /// In en, this message translates to:
  /// **'Hide from nearby'**
  String get priv_t_nearby;

  /// No description provided for @priv_t_nearby_sub.
  ///
  /// In en, this message translates to:
  /// **'Don\'t appear in nearby player searches'**
  String get priv_t_nearby_sub;

  /// No description provided for @priv_t_tracking.
  ///
  /// In en, this message translates to:
  /// **'Location tracking'**
  String get priv_t_tracking;

  /// No description provided for @priv_t_tracking_sub.
  ///
  /// In en, this message translates to:
  /// **'Allow location-based features'**
  String get priv_t_tracking_sub;

  /// No description provided for @priv_t_recs.
  ///
  /// In en, this message translates to:
  /// **'Game recommendations'**
  String get priv_t_recs;

  /// No description provided for @priv_t_recs_sub.
  ///
  /// In en, this message translates to:
  /// **'Personalized game suggestions'**
  String get priv_t_recs_sub;

  /// No description provided for @priv_t_analytics.
  ///
  /// In en, this message translates to:
  /// **'Anonymous analytics'**
  String get priv_t_analytics;

  /// No description provided for @priv_t_analytics_sub.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app'**
  String get priv_t_analytics_sub;

  /// No description provided for @priv_t_push.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get priv_t_push;

  /// No description provided for @priv_t_push_sub.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications on your device'**
  String get priv_t_push_sub;

  /// No description provided for @priv_t_mail.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get priv_t_mail;

  /// No description provided for @priv_t_mail_sub.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via email'**
  String get priv_t_mail_sub;

  /// No description provided for @appr_title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appr_title;

  /// No description provided for @appr_group_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appr_group_theme;

  /// No description provided for @appr_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appr_light;

  /// No description provided for @appr_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appr_dark;

  /// No description provided for @appr_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appr_system;

  /// No description provided for @appr_theme_applied.
  ///
  /// In en, this message translates to:
  /// **'{theme} theme'**
  String appr_theme_applied(String theme);

  /// No description provided for @appr_group_color.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get appr_group_color;

  /// No description provided for @appr_group_color_note.
  ///
  /// In en, this message translates to:
  /// **'Apply one token set across the entire app'**
  String get appr_group_color_note;

  /// No description provided for @appr_color_use.
  ///
  /// In en, this message translates to:
  /// **'Use {name} tokens app-wide'**
  String appr_color_use(String name);

  /// No description provided for @appr_group_auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic theme'**
  String get appr_group_auto;

  /// No description provided for @appr_group_auto_note.
  ///
  /// In en, this message translates to:
  /// **'Automatically switch between light and dark themes'**
  String get appr_group_auto_note;

  /// No description provided for @appr_auto_title.
  ///
  /// In en, this message translates to:
  /// **'Time-based theme'**
  String get appr_auto_title;

  /// No description provided for @appr_auto_sub.
  ///
  /// In en, this message translates to:
  /// **'Switch themes based on time of day'**
  String get appr_auto_sub;

  /// No description provided for @appr_group_schedule.
  ///
  /// In en, this message translates to:
  /// **'Day & night schedule'**
  String get appr_group_schedule;

  /// No description provided for @appr_group_schedule_note.
  ///
  /// In en, this message translates to:
  /// **'Set when light and dark themes should activate'**
  String get appr_group_schedule_note;

  /// No description provided for @appr_day_title.
  ///
  /// In en, this message translates to:
  /// **'Day starts at'**
  String get appr_day_title;

  /// No description provided for @appr_day_sub.
  ///
  /// In en, this message translates to:
  /// **'Light theme will activate'**
  String get appr_day_sub;

  /// No description provided for @appr_night_title.
  ///
  /// In en, this message translates to:
  /// **'Night starts at'**
  String get appr_night_title;

  /// No description provided for @appr_night_sub.
  ///
  /// In en, this message translates to:
  /// **'Dark theme will activate'**
  String get appr_night_sub;

  /// No description provided for @region_title.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get region_title;

  /// No description provided for @region_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get region_language;

  /// No description provided for @region_language_sub.
  ///
  /// In en, this message translates to:
  /// **'App and content language'**
  String get region_language_sub;

  /// No description provided for @region_language_updated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get region_language_updated;

  /// No description provided for @region_country.
  ///
  /// In en, this message translates to:
  /// **'App country'**
  String get region_country;

  /// No description provided for @region_country_sub.
  ///
  /// In en, this message translates to:
  /// **'Games, venues and currency'**
  String get region_country_sub;

  /// No description provided for @region_country_updated.
  ///
  /// In en, this message translates to:
  /// **'Country updated'**
  String get region_country_updated;

  /// No description provided for @region_lang_en.
  ///
  /// In en, this message translates to:
  /// **'English · English'**
  String get region_lang_en;

  /// No description provided for @region_lang_ar.
  ///
  /// In en, this message translates to:
  /// **'Arabic · العربية'**
  String get region_lang_ar;

  /// No description provided for @region_country_Egypt.
  ///
  /// In en, this message translates to:
  /// **'Egypt'**
  String get region_country_Egypt;

  /// No description provided for @region_country_UAE.
  ///
  /// In en, this message translates to:
  /// **'United Arab Emirates'**
  String get region_country_UAE;

  /// No description provided for @region_country_KSA.
  ///
  /// In en, this message translates to:
  /// **'Saudi Arabia'**
  String get region_country_KSA;

  /// No description provided for @region_country_Morocco.
  ///
  /// In en, this message translates to:
  /// **'Morocco'**
  String get region_country_Morocco;

  /// No description provided for @region_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String region_error(String error);

  /// No description provided for @listing_set_location.
  ///
  /// In en, this message translates to:
  /// **'Set location'**
  String get listing_set_location;

  /// No description provided for @listing_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get listing_search;

  /// No description provided for @listing_filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get listing_filters;

  /// No description provided for @listing_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get listing_reset;

  /// No description provided for @listing_clear_all.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get listing_clear_all;

  /// No description provided for @listing_all_sports.
  ///
  /// In en, this message translates to:
  /// **'All sports'**
  String get listing_all_sports;

  /// No description provided for @listing_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get listing_upcoming;

  /// No description provided for @listing_open_spots.
  ///
  /// In en, this message translates to:
  /// **'Open spots'**
  String get listing_open_spots;

  /// No description provided for @listing_sort_nearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get listing_sort_nearest;

  /// No description provided for @listing_sort_soonest.
  ///
  /// In en, this message translates to:
  /// **'Starting soonest'**
  String get listing_sort_soonest;

  /// No description provided for @listing_group_distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get listing_group_distance;

  /// No description provided for @listing_group_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get listing_group_date;

  /// No description provided for @listing_group_skill.
  ///
  /// In en, this message translates to:
  /// **'Skill level'**
  String get listing_group_skill;

  /// No description provided for @listing_group_availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get listing_group_availability;

  /// No description provided for @listing_group_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get listing_group_sort;

  /// No description provided for @listing_within_km.
  ///
  /// In en, this message translates to:
  /// **'Within {km} km'**
  String listing_within_km(int km);

  /// No description provided for @listing_any_distance.
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get listing_any_distance;

  /// No description provided for @listing_date_any.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get listing_date_any;

  /// No description provided for @listing_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get listing_today;

  /// No description provided for @listing_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get listing_tomorrow;

  /// No description provided for @listing_this_week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get listing_this_week;

  /// No description provided for @listing_skill_beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get listing_skill_beginner;

  /// No description provided for @listing_skill_intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get listing_skill_intermediate;

  /// No description provided for @listing_skill_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get listing_skill_advanced;

  /// No description provided for @listing_skill_pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get listing_skill_pro;

  /// No description provided for @listing_load_sports_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sports'**
  String get listing_load_sports_failed;

  /// No description provided for @listing_load_games_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load games'**
  String get listing_load_games_failed;

  /// No description provided for @listing_load_venues_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load venues'**
  String get listing_load_venues_failed;

  /// No description provided for @listing_games_filtered_title.
  ///
  /// In en, this message translates to:
  /// **'No games match your filters'**
  String get listing_games_filtered_title;

  /// No description provided for @listing_games_filtered_text.
  ///
  /// In en, this message translates to:
  /// **'Adjust or clear the filters.'**
  String get listing_games_filtered_text;

  /// No description provided for @listing_games_nearby_title.
  ///
  /// In en, this message translates to:
  /// **'No games found nearby.'**
  String get listing_games_nearby_title;

  /// No description provided for @listing_games_nearby_text.
  ///
  /// In en, this message translates to:
  /// **'Try widening your search radius in the filter.'**
  String get listing_games_nearby_text;

  /// No description provided for @listing_games_none_title.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get listing_games_none_title;

  /// No description provided for @listing_games_none_text.
  ///
  /// In en, this message translates to:
  /// **'Be the first to create a game in your area!'**
  String get listing_games_none_text;

  /// No description provided for @listing_change_filters.
  ///
  /// In en, this message translates to:
  /// **'Change filters'**
  String get listing_change_filters;

  /// No description provided for @listing_created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get listing_created;

  /// No description provided for @listing_joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get listing_joined;

  /// No description provided for @listing_full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get listing_full;

  /// No description provided for @listing_join_game.
  ///
  /// In en, this message translates to:
  /// **'Join game'**
  String get listing_join_game;

  /// No description provided for @listing_on_waitlist.
  ///
  /// In en, this message translates to:
  /// **'On waitlist'**
  String get listing_on_waitlist;

  /// No description provided for @listing_request_sent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get listing_request_sent;

  /// No description provided for @listing_spots_left.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 spot left} other{{count} spots left}}'**
  String listing_spots_left(int count);

  /// No description provided for @listing_spots_almost_full.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 spot left · almost full} other{{count} spots left · almost full}}'**
  String listing_spots_almost_full(int count);

  /// No description provided for @listing_players_in.
  ///
  /// In en, this message translates to:
  /// **'{joined} of {total} players in'**
  String listing_players_in(int joined, int total);

  /// No description provided for @listing_show_games.
  ///
  /// In en, this message translates to:
  /// **'Show {count} games'**
  String listing_show_games(int count);

  /// No description provided for @listing_show_games_plain.
  ///
  /// In en, this message translates to:
  /// **'Show games'**
  String get listing_show_games_plain;

  /// No description provided for @listing_show_venues.
  ///
  /// In en, this message translates to:
  /// **'Show venues'**
  String get listing_show_venues;

  /// No description provided for @listing_unit_day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get listing_unit_day;

  /// No description provided for @listing_unit_days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get listing_unit_days;

  /// No description provided for @listing_unit_hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get listing_unit_hour;

  /// No description provided for @listing_unit_hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get listing_unit_hours;

  /// No description provided for @listing_unit_min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get listing_unit_min;

  /// No description provided for @listing_saved_venues.
  ///
  /// In en, this message translates to:
  /// **'Saved venues'**
  String get listing_saved_venues;

  /// No description provided for @listing_add_venue.
  ///
  /// In en, this message translates to:
  /// **'Add venue'**
  String get listing_add_venue;

  /// No description provided for @listing_venues_none_title.
  ///
  /// In en, this message translates to:
  /// **'No venues found'**
  String get listing_venues_none_title;

  /// No description provided for @listing_venues_none_text.
  ///
  /// In en, this message translates to:
  /// **'Try selecting a different sport.'**
  String get listing_venues_none_text;

  /// No description provided for @listing_venues_radius_text.
  ///
  /// In en, this message translates to:
  /// **'No venues within {km} km — try widening your search radius.'**
  String listing_venues_radius_text(int km);

  /// No description provided for @listing_starting_from.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get listing_starting_from;

  /// No description provided for @listing_view_venue.
  ///
  /// In en, this message translates to:
  /// **'View venue'**
  String get listing_view_venue;

  /// No description provided for @listing_save_venue.
  ///
  /// In en, this message translates to:
  /// **'Save venue'**
  String get listing_save_venue;

  /// No description provided for @listing_remove_saved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get listing_remove_saved;

  /// No description provided for @listing_indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get listing_indoor;

  /// No description provided for @listing_outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get listing_outdoor;

  /// No description provided for @listing_km_away.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String listing_km_away(String distance);

  /// No description provided for @listing_free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get listing_free;

  /// No description provided for @listing_price_per_hour.
  ///
  /// In en, this message translates to:
  /// **'AED {amount} / hour'**
  String listing_price_per_hour(String amount);

  /// No description provided for @location_change_title.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get location_change_title;

  /// No description provided for @location_search_areas.
  ///
  /// In en, this message translates to:
  /// **'Search areas…'**
  String get location_search_areas;

  /// No description provided for @location_use_current.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get location_use_current;

  /// No description provided for @location_detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get location_detecting;

  /// No description provided for @location_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get location_saved;

  /// No description provided for @location_add.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get location_add;

  /// No description provided for @location_no_areas.
  ///
  /// In en, this message translates to:
  /// **'No areas match \"{query}\"'**
  String location_no_areas(String query);

  /// No description provided for @location_access_required.
  ///
  /// In en, this message translates to:
  /// **'Location access required'**
  String get location_access_required;

  /// No description provided for @location_permission_denied_forever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Open Settings to enable it.'**
  String get location_permission_denied_forever;

  /// No description provided for @location_open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get location_open_settings;

  /// No description provided for @location_enable_services.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services'**
  String get location_enable_services;

  /// No description provided for @location_permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get location_permission_denied;

  /// No description provided for @location_timeout.
  ///
  /// In en, this message translates to:
  /// **'Could not get location — try again'**
  String get location_timeout;

  /// No description provided for @location_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String location_error(String message);

  /// No description provided for @listing_skill_any.
  ///
  /// In en, this message translates to:
  /// **'Any skill'**
  String get listing_skill_any;

  /// No description provided for @home_upcoming_title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get home_upcoming_title;

  /// No description provided for @home_upcoming_title_count.
  ///
  /// In en, this message translates to:
  /// **'Upcoming · {count}'**
  String home_upcoming_title_count(int count);

  /// No description provided for @home_upcoming_strip_count.
  ///
  /// In en, this message translates to:
  /// **'{count} upcoming'**
  String home_upcoming_strip_count(int count);

  /// No description provided for @home_upcoming_more.
  ///
  /// In en, this message translates to:
  /// **'{count} more this week'**
  String home_upcoming_more(int count);

  /// No description provided for @home_upcoming_show_less.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get home_upcoming_show_less;

  /// No description provided for @home_upcoming_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get home_upcoming_hide;

  /// No description provided for @home_upcoming_see_all.
  ///
  /// In en, this message translates to:
  /// **'See all {count} upcoming'**
  String home_upcoming_see_all(int count);

  /// No description provided for @home_upcoming_day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get home_upcoming_day;

  /// No description provided for @home_upcoming_days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get home_upcoming_days;

  /// No description provided for @home_upcoming_hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get home_upcoming_hour;

  /// No description provided for @home_upcoming_hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get home_upcoming_hours;

  /// No description provided for @home_upcoming_min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get home_upcoming_min;

  /// No description provided for @home_upcoming_in_days.
  ///
  /// In en, this message translates to:
  /// **'in {days}d'**
  String home_upcoming_in_days(int days);

  /// No description provided for @home_upcoming_in_hours.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h {minutes}m'**
  String home_upcoming_in_hours(int hours, int minutes);

  /// No description provided for @home_upcoming_in_minutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes}m'**
  String home_upcoming_in_minutes(int minutes);

  /// No description provided for @home_post_options_title.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get home_post_options_title;

  /// No description provided for @home_post_options_by.
  ///
  /// In en, this message translates to:
  /// **'Posted by {name}'**
  String home_post_options_by(String name);

  /// No description provided for @home_post_report.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get home_post_report;

  /// No description provided for @home_post_report_note.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is wrong with this post'**
  String get home_post_report_note;

  /// No description provided for @home_post_block.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get home_post_block;

  /// No description provided for @home_vibe_title.
  ///
  /// In en, this message translates to:
  /// **'What\'s the vibe?'**
  String get home_vibe_title;

  /// No description provided for @home_location_title.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get home_location_title;

  /// No description provided for @home_location_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get home_location_done;

  /// No description provided for @home_location_search.
  ///
  /// In en, this message translates to:
  /// **'Search area, street or city'**
  String get home_location_search;

  /// No description provided for @home_location_use_current.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get home_location_use_current;

  /// No description provided for @home_location_add.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get home_location_add;

  /// No description provided for @home_location_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get home_location_cancel;

  /// No description provided for @home_location_search_venues.
  ///
  /// In en, this message translates to:
  /// **'Search venues and areas'**
  String get home_location_search_venues;

  /// No description provided for @home_location_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get home_location_recent;

  /// No description provided for @home_location_no_match.
  ///
  /// In en, this message translates to:
  /// **'No areas match \"{query}\"'**
  String home_location_no_match(String query);

  /// No description provided for @blocked_accounts_note.
  ///
  /// In en, this message translates to:
  /// **'Manage users you\'ve blocked from contacting you.'**
  String get blocked_accounts_note;

  /// No description provided for @blocked_accounts_empty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get blocked_accounts_empty;

  /// No description provided for @blocked_accounts_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your blocked accounts.'**
  String get blocked_accounts_load_failed;

  /// No description provided for @blocked_accounts_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get blocked_accounts_unknown;

  /// No description provided for @blocked_accounts_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blocked_accounts_unblock;

  /// No description provided for @blocked_accounts_unblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get blocked_accounts_unblocked;

  /// No description provided for @blocked_accounts_unblock_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not unblock: {message}'**
  String blocked_accounts_unblock_failed(String message);

  /// No description provided for @notif_settings_push.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notif_settings_push;

  /// No description provided for @notif_settings_push_sub.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications on your device'**
  String get notif_settings_push_sub;

  /// No description provided for @notif_settings_email.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get notif_settings_email;

  /// No description provided for @notif_settings_email_sub.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via email'**
  String get notif_settings_email_sub;

  /// No description provided for @notif_settings_sms.
  ///
  /// In en, this message translates to:
  /// **'SMS notifications'**
  String get notif_settings_sms;

  /// No description provided for @notif_settings_sms_sub.
  ///
  /// In en, this message translates to:
  /// **'Receive important updates via SMS'**
  String get notif_settings_sms_sub;

  /// No description provided for @notif_settings_quiet_header.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notif_settings_quiet_header;

  /// No description provided for @notif_settings_quiet_mute.
  ///
  /// In en, this message translates to:
  /// **'Mute during quiet hours'**
  String get notif_settings_quiet_mute;

  /// No description provided for @notif_settings_quiet_mute_off.
  ///
  /// In en, this message translates to:
  /// **'Pause push notifications overnight'**
  String get notif_settings_quiet_mute_off;

  /// No description provided for @notif_settings_quiet_mute_on.
  ///
  /// In en, this message translates to:
  /// **'No push between {start} and {end}'**
  String notif_settings_quiet_mute_on(String start, String end);

  /// No description provided for @notif_settings_quiet_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get notif_settings_quiet_start;

  /// No description provided for @notif_settings_quiet_end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get notif_settings_quiet_end;

  /// No description provided for @notif_settings_quiet_urgent.
  ///
  /// In en, this message translates to:
  /// **'Allow urgent notifications'**
  String get notif_settings_quiet_urgent;

  /// No description provided for @notif_settings_quiet_urgent_sub.
  ///
  /// In en, this message translates to:
  /// **'High-priority alerts still come through during quiet hours'**
  String get notif_settings_quiet_urgent_sub;

  /// No description provided for @notif_settings_quiet_all.
  ///
  /// In en, this message translates to:
  /// **'Allow all notifications'**
  String get notif_settings_quiet_all;

  /// No description provided for @notif_settings_quiet_all_sub.
  ///
  /// In en, this message translates to:
  /// **'Every push still comes through during quiet hours'**
  String get notif_settings_quiet_all_sub;

  /// No description provided for @notif_settings_group_game.
  ///
  /// In en, this message translates to:
  /// **'Game notifications'**
  String get notif_settings_group_game;

  /// No description provided for @notif_settings_group_social.
  ///
  /// In en, this message translates to:
  /// **'Social notifications'**
  String get notif_settings_group_social;

  /// No description provided for @notif_settings_group_connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get notif_settings_group_connections;

  /// No description provided for @notif_settings_kind_game_invites.
  ///
  /// In en, this message translates to:
  /// **'Game invites & requests'**
  String get notif_settings_kind_game_invites;

  /// No description provided for @notif_settings_kind_game_invites_sub.
  ///
  /// In en, this message translates to:
  /// **'Invites, join requests, approvals'**
  String get notif_settings_kind_game_invites_sub;

  /// No description provided for @notif_settings_kind_game_reminders.
  ///
  /// In en, this message translates to:
  /// **'Game reminders'**
  String get notif_settings_kind_game_reminders;

  /// No description provided for @notif_settings_kind_game_reminders_sub.
  ///
  /// In en, this message translates to:
  /// **'Reminders for upcoming games'**
  String get notif_settings_kind_game_reminders_sub;

  /// No description provided for @notif_settings_kind_game_updates.
  ///
  /// In en, this message translates to:
  /// **'Game updates'**
  String get notif_settings_kind_game_updates;

  /// No description provided for @notif_settings_kind_game_updates_sub.
  ///
  /// In en, this message translates to:
  /// **'Changes, waitlist promotions, players joining'**
  String get notif_settings_kind_game_updates_sub;

  /// No description provided for @notif_settings_kind_booking.
  ///
  /// In en, this message translates to:
  /// **'Booking payments'**
  String get notif_settings_kind_booking;

  /// No description provided for @notif_settings_kind_booking_sub.
  ///
  /// In en, this message translates to:
  /// **'When a booking needs payment'**
  String get notif_settings_kind_booking_sub;

  /// No description provided for @notif_settings_kind_likes.
  ///
  /// In en, this message translates to:
  /// **'Likes & reactions'**
  String get notif_settings_kind_likes;

  /// No description provided for @notif_settings_kind_likes_sub.
  ///
  /// In en, this message translates to:
  /// **'Likes and reactions on your content'**
  String get notif_settings_kind_likes_sub;

  /// No description provided for @notif_settings_kind_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notif_settings_kind_comments;

  /// No description provided for @notif_settings_kind_comments_sub.
  ///
  /// In en, this message translates to:
  /// **'Comments on your posts'**
  String get notif_settings_kind_comments_sub;

  /// No description provided for @notif_settings_kind_mentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notif_settings_kind_mentions;

  /// No description provided for @notif_settings_kind_mentions_sub.
  ///
  /// In en, this message translates to:
  /// **'When someone mentions you'**
  String get notif_settings_kind_mentions_sub;

  /// No description provided for @notif_settings_kind_followers.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get notif_settings_kind_followers;

  /// No description provided for @notif_settings_kind_followers_sub.
  ///
  /// In en, this message translates to:
  /// **'When someone follows you'**
  String get notif_settings_kind_followers_sub;

  /// No description provided for @notif_settings_kind_friends.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get notif_settings_kind_friends;

  /// No description provided for @notif_settings_kind_friends_sub.
  ///
  /// In en, this message translates to:
  /// **'New and accepted friend requests'**
  String get notif_settings_kind_friends_sub;

  /// No description provided for @notif_settings_kind_squads.
  ///
  /// In en, this message translates to:
  /// **'Squad invites'**
  String get notif_settings_kind_squads;

  /// No description provided for @notif_settings_kind_squads_sub.
  ///
  /// In en, this message translates to:
  /// **'Invites to join a squad'**
  String get notif_settings_kind_squads_sub;

  /// No description provided for @notif_settings_kind_meetups.
  ///
  /// In en, this message translates to:
  /// **'Meetup invites'**
  String get notif_settings_kind_meetups;

  /// No description provided for @notif_settings_kind_meetups_sub.
  ///
  /// In en, this message translates to:
  /// **'Invites and players joining meetups'**
  String get notif_settings_kind_meetups_sub;

  /// No description provided for @notif_settings_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update settings: {error}'**
  String notif_settings_update_failed(String error);

  /// No description provided for @game_prefs_title.
  ///
  /// In en, this message translates to:
  /// **'Game preferences'**
  String get game_prefs_title;

  /// No description provided for @game_prefs_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get game_prefs_save;

  /// No description provided for @game_prefs_saved.
  ///
  /// In en, this message translates to:
  /// **'Game preferences saved'**
  String get game_prefs_saved;

  /// No description provided for @game_prefs_types_header.
  ///
  /// In en, this message translates to:
  /// **'Preferred game types'**
  String get game_prefs_types_header;

  /// No description provided for @game_prefs_types_note.
  ///
  /// In en, this message translates to:
  /// **'Select the types of games you enjoy most'**
  String get game_prefs_types_note;

  /// No description provided for @game_prefs_type_pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup games'**
  String get game_prefs_type_pickup;

  /// No description provided for @game_prefs_type_pickup_sub.
  ///
  /// In en, this message translates to:
  /// **'Casual games with other players'**
  String get game_prefs_type_pickup_sub;

  /// No description provided for @game_prefs_type_tournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get game_prefs_type_tournaments;

  /// No description provided for @game_prefs_type_tournaments_sub.
  ///
  /// In en, this message translates to:
  /// **'Competitive organized events'**
  String get game_prefs_type_tournaments_sub;

  /// No description provided for @game_prefs_type_practice.
  ///
  /// In en, this message translates to:
  /// **'Practice sessions'**
  String get game_prefs_type_practice;

  /// No description provided for @game_prefs_type_practice_sub.
  ///
  /// In en, this message translates to:
  /// **'Skill development and training'**
  String get game_prefs_type_practice_sub;

  /// No description provided for @game_prefs_type_leagues.
  ///
  /// In en, this message translates to:
  /// **'Leagues'**
  String get game_prefs_type_leagues;

  /// No description provided for @game_prefs_type_leagues_sub.
  ///
  /// In en, this message translates to:
  /// **'Season-long competitions'**
  String get game_prefs_type_leagues_sub;

  /// No description provided for @game_prefs_type_friendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly matches'**
  String get game_prefs_type_friendly;

  /// No description provided for @game_prefs_type_friendly_sub.
  ///
  /// In en, this message translates to:
  /// **'Non-competitive social games'**
  String get game_prefs_type_friendly_sub;

  /// No description provided for @game_prefs_type_camps.
  ///
  /// In en, this message translates to:
  /// **'Training camps'**
  String get game_prefs_type_camps;

  /// No description provided for @game_prefs_type_camps_sub.
  ///
  /// In en, this message translates to:
  /// **'Intensive skill workshops'**
  String get game_prefs_type_camps_sub;

  /// No description provided for @game_prefs_duration_header.
  ///
  /// In en, this message translates to:
  /// **'Game duration'**
  String get game_prefs_duration_header;

  /// No description provided for @game_prefs_duration_note.
  ///
  /// In en, this message translates to:
  /// **'How long do you prefer games to last?'**
  String get game_prefs_duration_note;

  /// No description provided for @game_prefs_duration_short.
  ///
  /// In en, this message translates to:
  /// **'Short games'**
  String get game_prefs_duration_short;

  /// No description provided for @game_prefs_duration_short_sub.
  ///
  /// In en, this message translates to:
  /// **'30-60 minutes'**
  String get game_prefs_duration_short_sub;

  /// No description provided for @game_prefs_duration_medium.
  ///
  /// In en, this message translates to:
  /// **'Medium games'**
  String get game_prefs_duration_medium;

  /// No description provided for @game_prefs_duration_medium_sub.
  ///
  /// In en, this message translates to:
  /// **'60-90 minutes'**
  String get game_prefs_duration_medium_sub;

  /// No description provided for @game_prefs_duration_long.
  ///
  /// In en, this message translates to:
  /// **'Long games'**
  String get game_prefs_duration_long;

  /// No description provided for @game_prefs_duration_long_sub.
  ///
  /// In en, this message translates to:
  /// **'90+ minutes'**
  String get game_prefs_duration_long_sub;

  /// No description provided for @game_prefs_duration_flexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible duration'**
  String get game_prefs_duration_flexible;

  /// No description provided for @game_prefs_duration_flexible_sub.
  ///
  /// In en, this message translates to:
  /// **'Any duration'**
  String get game_prefs_duration_flexible_sub;

  /// No description provided for @game_prefs_duration_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom duration range'**
  String get game_prefs_duration_custom;

  /// No description provided for @game_prefs_duration_min.
  ///
  /// In en, this message translates to:
  /// **'Min duration'**
  String get game_prefs_duration_min;

  /// No description provided for @game_prefs_duration_max.
  ///
  /// In en, this message translates to:
  /// **'Max duration'**
  String get game_prefs_duration_max;

  /// No description provided for @game_prefs_minutes_hint.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String game_prefs_minutes_hint(String value);

  /// No description provided for @game_prefs_minutes_suffix.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get game_prefs_minutes_suffix;

  /// No description provided for @game_prefs_team_header.
  ///
  /// In en, this message translates to:
  /// **'Team size'**
  String get game_prefs_team_header;

  /// No description provided for @game_prefs_team_note.
  ///
  /// In en, this message translates to:
  /// **'What team sizes do you prefer?'**
  String get game_prefs_team_note;

  /// No description provided for @game_prefs_team_flexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible team size'**
  String get game_prefs_team_flexible;

  /// No description provided for @game_prefs_team_flexible_sub.
  ///
  /// In en, this message translates to:
  /// **'Open to various team sizes'**
  String get game_prefs_team_flexible_sub;

  /// No description provided for @game_prefs_team_preferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred team size: {low} - {high} players'**
  String game_prefs_team_preferred(String low, String high);

  /// No description provided for @game_prefs_team_min_label.
  ///
  /// In en, this message translates to:
  /// **'2 players'**
  String get game_prefs_team_min_label;

  /// No description provided for @game_prefs_team_max_label.
  ///
  /// In en, this message translates to:
  /// **'22 players'**
  String get game_prefs_team_max_label;

  /// No description provided for @game_prefs_level_header.
  ///
  /// In en, this message translates to:
  /// **'Competition level'**
  String get game_prefs_level_header;

  /// No description provided for @game_prefs_level_note.
  ///
  /// In en, this message translates to:
  /// **'What level of competition do you prefer?'**
  String get game_prefs_level_note;

  /// No description provided for @game_prefs_level_casual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get game_prefs_level_casual;

  /// No description provided for @game_prefs_level_casual_sub.
  ///
  /// In en, this message translates to:
  /// **'Just for fun, relaxed atmosphere'**
  String get game_prefs_level_casual_sub;

  /// No description provided for @game_prefs_level_recreational.
  ///
  /// In en, this message translates to:
  /// **'Recreational'**
  String get game_prefs_level_recreational;

  /// No description provided for @game_prefs_level_recreational_sub.
  ///
  /// In en, this message translates to:
  /// **'Friendly competition, moderate intensity'**
  String get game_prefs_level_recreational_sub;

  /// No description provided for @game_prefs_level_competitive.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get game_prefs_level_competitive;

  /// No description provided for @game_prefs_level_competitive_sub.
  ///
  /// In en, this message translates to:
  /// **'Serious competition, high intensity'**
  String get game_prefs_level_competitive_sub;

  /// No description provided for @game_prefs_level_professional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get game_prefs_level_professional;

  /// No description provided for @game_prefs_level_professional_sub.
  ///
  /// In en, this message translates to:
  /// **'Elite level competition'**
  String get game_prefs_level_professional_sub;

  /// No description provided for @game_prefs_equipment_header.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get game_prefs_equipment_header;

  /// No description provided for @game_prefs_equipment_note.
  ///
  /// In en, this message translates to:
  /// **'What are your equipment needs?'**
  String get game_prefs_equipment_note;

  /// No description provided for @game_prefs_equipment_own.
  ///
  /// In en, this message translates to:
  /// **'I have my own equipment'**
  String get game_prefs_equipment_own;

  /// No description provided for @game_prefs_equipment_own_sub.
  ///
  /// In en, this message translates to:
  /// **'You can bring your own gear'**
  String get game_prefs_equipment_own_sub;

  /// No description provided for @game_prefs_equipment_provide.
  ///
  /// In en, this message translates to:
  /// **'I can provide equipment for others'**
  String get game_prefs_equipment_provide;

  /// No description provided for @game_prefs_equipment_provide_sub.
  ///
  /// In en, this message translates to:
  /// **'You can share equipment with teammates'**
  String get game_prefs_equipment_provide_sub;

  /// No description provided for @game_prefs_equipment_need.
  ///
  /// In en, this message translates to:
  /// **'I need equipment provided'**
  String get game_prefs_equipment_need;

  /// No description provided for @game_prefs_equipment_need_sub.
  ///
  /// In en, this message translates to:
  /// **'Equipment should be available at the venue'**
  String get game_prefs_equipment_need_sub;

  /// No description provided for @game_prefs_equipment_types.
  ///
  /// In en, this message translates to:
  /// **'Equipment types'**
  String get game_prefs_equipment_types;

  /// No description provided for @game_prefs_equipment_ball.
  ///
  /// In en, this message translates to:
  /// **'Ball'**
  String get game_prefs_equipment_ball;

  /// No description provided for @game_prefs_equipment_gear.
  ///
  /// In en, this message translates to:
  /// **'Protective gear'**
  String get game_prefs_equipment_gear;

  /// No description provided for @game_prefs_equipment_uniforms.
  ///
  /// In en, this message translates to:
  /// **'Uniforms'**
  String get game_prefs_equipment_uniforms;

  /// No description provided for @game_prefs_equipment_goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get game_prefs_equipment_goals;

  /// No description provided for @game_prefs_equipment_nets.
  ///
  /// In en, this message translates to:
  /// **'Nets'**
  String get game_prefs_equipment_nets;

  /// No description provided for @game_prefs_equipment_markers.
  ///
  /// In en, this message translates to:
  /// **'Markers'**
  String get game_prefs_equipment_markers;

  /// No description provided for @game_prefs_referee_header.
  ///
  /// In en, this message translates to:
  /// **'Referee'**
  String get game_prefs_referee_header;

  /// No description provided for @game_prefs_referee_note.
  ///
  /// In en, this message translates to:
  /// **'How do you prefer games to be officiated?'**
  String get game_prefs_referee_note;

  /// No description provided for @game_prefs_referee_prefer.
  ///
  /// In en, this message translates to:
  /// **'Prefer games with a referee'**
  String get game_prefs_referee_prefer;

  /// No description provided for @game_prefs_referee_prefer_sub.
  ///
  /// In en, this message translates to:
  /// **'Official referee for fair play'**
  String get game_prefs_referee_prefer_sub;

  /// No description provided for @game_prefs_referee_can.
  ///
  /// In en, this message translates to:
  /// **'I can referee games'**
  String get game_prefs_referee_can;

  /// No description provided for @game_prefs_referee_can_sub.
  ///
  /// In en, this message translates to:
  /// **'You\'re qualified to officiate'**
  String get game_prefs_referee_can_sub;

  /// No description provided for @game_prefs_referee_strict.
  ///
  /// In en, this message translates to:
  /// **'Strict rule enforcement'**
  String get game_prefs_referee_strict;

  /// No description provided for @game_prefs_referee_strict_sub.
  ///
  /// In en, this message translates to:
  /// **'Games should follow official rules closely'**
  String get game_prefs_referee_strict_sub;

  /// No description provided for @composer_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get composer_cancel;

  /// No description provided for @composer_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get composer_confirm;

  /// No description provided for @composer_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get composer_clear;

  /// No description provided for @composer_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get composer_none;

  /// No description provided for @composer_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get composer_select;

  /// No description provided for @composer_tap_to_change.
  ///
  /// In en, this message translates to:
  /// **'Tap to change.'**
  String get composer_tap_to_change;

  /// No description provided for @composer_create_post.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get composer_create_post;

  /// No description provided for @composer_post_cta.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get composer_post_cta;

  /// No description provided for @composer_you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get composer_you;

  /// No description provided for @composer_post_as.
  ///
  /// In en, this message translates to:
  /// **'Post As'**
  String get composer_post_as;

  /// No description provided for @composer_switch_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch profile'**
  String get composer_switch_failed;

  /// No description provided for @composer_body_hint.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind? Use #hashtags'**
  String get composer_body_hint;

  /// No description provided for @composer_add_media.
  ///
  /// In en, this message translates to:
  /// **'Add media'**
  String get composer_add_media;

  /// No description provided for @composer_add_vibe.
  ///
  /// In en, this message translates to:
  /// **'Add vibe'**
  String get composer_add_vibe;

  /// No description provided for @composer_add_sport.
  ///
  /// In en, this message translates to:
  /// **'Add sport'**
  String get composer_add_sport;

  /// No description provided for @composer_add_location.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get composer_add_location;

  /// No description provided for @composer_link_game.
  ///
  /// In en, this message translates to:
  /// **'Link a game'**
  String get composer_link_game;

  /// No description provided for @composer_add_more_media.
  ///
  /// In en, this message translates to:
  /// **'Add more media'**
  String get composer_add_more_media;

  /// No description provided for @composer_remove_media.
  ///
  /// In en, this message translates to:
  /// **'Remove media'**
  String get composer_remove_media;

  /// No description provided for @composer_allow_reposts.
  ///
  /// In en, this message translates to:
  /// **'Allow reposts'**
  String get composer_allow_reposts;

  /// No description provided for @composer_allow_reposts_sub.
  ///
  /// In en, this message translates to:
  /// **'Others can share this post'**
  String get composer_allow_reposts_sub;

  /// No description provided for @composer_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin to profile'**
  String get composer_pin;

  /// No description provided for @composer_pin_sub.
  ///
  /// In en, this message translates to:
  /// **'Keep at the top of your profile'**
  String get composer_pin_sub;

  /// No description provided for @composer_expiry.
  ///
  /// In en, this message translates to:
  /// **'Set expiry'**
  String get composer_expiry;

  /// No description provided for @composer_expiry_sub.
  ///
  /// In en, this message translates to:
  /// **'Auto-hides after date'**
  String get composer_expiry_sub;

  /// No description provided for @composer_who_can_see.
  ///
  /// In en, this message translates to:
  /// **'Who can see this?'**
  String get composer_who_can_see;

  /// No description provided for @composer_which_sport.
  ///
  /// In en, this message translates to:
  /// **'Which sport?'**
  String get composer_which_sport;

  /// No description provided for @composer_kind_of_post.
  ///
  /// In en, this message translates to:
  /// **'What kind of post?'**
  String get composer_kind_of_post;

  /// No description provided for @composer_link_a_game.
  ///
  /// In en, this message translates to:
  /// **'Link a game'**
  String get composer_link_a_game;

  /// No description provided for @composer_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get composer_location;

  /// No description provided for @composer_add_media_title.
  ///
  /// In en, this message translates to:
  /// **'Add media'**
  String get composer_add_media_title;

  /// No description provided for @composer_take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get composer_take_photo;

  /// No description provided for @composer_choose_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get composer_choose_gallery;

  /// No description provided for @composer_search_gifs.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs'**
  String get composer_search_gifs;

  /// No description provided for @composer_powered_giphy.
  ///
  /// In en, this message translates to:
  /// **'Powered by GIPHY'**
  String get composer_powered_giphy;

  /// No description provided for @composer_vis_public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get composer_vis_public;

  /// No description provided for @composer_vis_followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get composer_vis_followers;

  /// No description provided for @composer_vis_circle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get composer_vis_circle;

  /// No description provided for @composer_vis_squad.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get composer_vis_squad;

  /// No description provided for @composer_vis_private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get composer_vis_private;

  /// No description provided for @composer_vis_link.
  ///
  /// In en, this message translates to:
  /// **'Link Only'**
  String get composer_vis_link;

  /// No description provided for @composer_vis_public_sub.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see this post'**
  String get composer_vis_public_sub;

  /// No description provided for @composer_vis_followers_sub.
  ///
  /// In en, this message translates to:
  /// **'Only your followers can see this'**
  String get composer_vis_followers_sub;

  /// No description provided for @composer_vis_circle_sub.
  ///
  /// In en, this message translates to:
  /// **'Shared with a specific circle'**
  String get composer_vis_circle_sub;

  /// No description provided for @composer_vis_squad_sub.
  ///
  /// In en, this message translates to:
  /// **'Shared with your squad'**
  String get composer_vis_squad_sub;

  /// No description provided for @composer_vis_private_sub.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this'**
  String get composer_vis_private_sub;

  /// No description provided for @composer_vis_link_sub.
  ///
  /// In en, this message translates to:
  /// **'Only people with the link can see this'**
  String get composer_vis_link_sub;

  /// No description provided for @composer_type_moment.
  ///
  /// In en, this message translates to:
  /// **'Moment'**
  String get composer_type_moment;

  /// No description provided for @composer_type_dab.
  ///
  /// In en, this message translates to:
  /// **'Dab'**
  String get composer_type_dab;

  /// No description provided for @composer_type_kickin.
  ///
  /// In en, this message translates to:
  /// **'Kick-in'**
  String get composer_type_kickin;

  /// No description provided for @composer_type_moment_sub.
  ///
  /// In en, this message translates to:
  /// **'A quick snapshot of right now'**
  String get composer_type_moment_sub;

  /// No description provided for @composer_type_dab_sub.
  ///
  /// In en, this message translates to:
  /// **'Share what you\'re vibing with'**
  String get composer_type_dab_sub;

  /// No description provided for @composer_type_kickin_sub.
  ///
  /// In en, this message translates to:
  /// **'Invite others to join in'**
  String get composer_type_kickin_sub;

  /// No description provided for @composer_vibe_search.
  ///
  /// In en, this message translates to:
  /// **'Search vibes'**
  String get composer_vibe_search;

  /// No description provided for @composer_vibe_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vibes'**
  String get composer_vibe_failed;

  /// No description provided for @composer_vibe_none.
  ///
  /// In en, this message translates to:
  /// **'No vibes match that search'**
  String get composer_vibe_none;

  /// No description provided for @composer_sports_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sports'**
  String get composer_sports_failed;

  /// No description provided for @composer_sports_none.
  ///
  /// In en, this message translates to:
  /// **'No sports available'**
  String get composer_sports_none;

  /// No description provided for @composer_venue_search.
  ///
  /// In en, this message translates to:
  /// **'Search venues...'**
  String get composer_venue_search;

  /// No description provided for @composer_type_location.
  ///
  /// In en, this message translates to:
  /// **'Type a location'**
  String get composer_type_location;

  /// No description provided for @composer_use_location.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get composer_use_location;

  /// No description provided for @composer_search_failed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get composer_search_failed;

  /// No description provided for @composer_no_venues.
  ///
  /// In en, this message translates to:
  /// **'No venues found'**
  String get composer_no_venues;

  /// No description provided for @composer_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get composer_venue;

  /// No description provided for @composer_venue_hint.
  ///
  /// In en, this message translates to:
  /// **'Search for a venue or type a location'**
  String get composer_venue_hint;

  /// No description provided for @composer_games_search.
  ///
  /// In en, this message translates to:
  /// **'Search games by title...'**
  String get composer_games_search;

  /// No description provided for @composer_no_games.
  ///
  /// In en, this message translates to:
  /// **'No games found'**
  String get composer_no_games;

  /// No description provided for @composer_untitled_game.
  ///
  /// In en, this message translates to:
  /// **'Untitled Game'**
  String get composer_untitled_game;

  /// No description provided for @composer_games_hint.
  ///
  /// In en, this message translates to:
  /// **'Search for a game to link to your post'**
  String get composer_games_hint;

  /// No description provided for @game_create.
  ///
  /// In en, this message translates to:
  /// **'Create game'**
  String get game_create;

  /// No description provided for @game_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Game'**
  String get game_edit;

  /// No description provided for @game_save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get game_save_changes;

  /// No description provided for @game_sport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get game_sport;

  /// No description provided for @game_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get game_format;

  /// No description provided for @game_format_sub.
  ///
  /// In en, this message translates to:
  /// **'Game format'**
  String get game_format_sub;

  /// No description provided for @game_select_sport_first.
  ///
  /// In en, this message translates to:
  /// **'Select sport first'**
  String get game_select_sport_first;

  /// No description provided for @game_select_format.
  ///
  /// In en, this message translates to:
  /// **'Select format'**
  String get game_select_format;

  /// No description provided for @game_venue_sub.
  ///
  /// In en, this message translates to:
  /// **'Where to play'**
  String get game_venue_sub;

  /// No description provided for @game_date_time.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get game_date_time;

  /// No description provided for @game_date_time_sub.
  ///
  /// In en, this message translates to:
  /// **'When is the game'**
  String get game_date_time_sub;

  /// No description provided for @game_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get game_duration;

  /// No description provided for @game_duration_sub.
  ///
  /// In en, this message translates to:
  /// **'How long it runs'**
  String get game_duration_sub;

  /// No description provided for @game_join_policy.
  ///
  /// In en, this message translates to:
  /// **'Join policy'**
  String get game_join_policy;

  /// No description provided for @game_join_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get game_join_open;

  /// No description provided for @game_join_request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get game_join_request;

  /// No description provided for @game_join_invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get game_join_invite;

  /// No description provided for @game_join_link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get game_join_link;

  /// No description provided for @game_visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get game_visibility;

  /// No description provided for @game_skill_level.
  ///
  /// In en, this message translates to:
  /// **'Skill Level'**
  String get game_skill_level;

  /// No description provided for @game_skill_sub.
  ///
  /// In en, this message translates to:
  /// **'Player experience'**
  String get game_skill_sub;

  /// No description provided for @game_any_level.
  ///
  /// In en, this message translates to:
  /// **'Any level'**
  String get game_any_level;

  /// No description provided for @game_players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get game_players;

  /// No description provided for @game_players_sub.
  ///
  /// In en, this message translates to:
  /// **'Min & max players'**
  String get game_players_sub;

  /// No description provided for @game_fewer_min.
  ///
  /// In en, this message translates to:
  /// **'Fewer minimum players'**
  String get game_fewer_min;

  /// No description provided for @game_more_min.
  ///
  /// In en, this message translates to:
  /// **'More minimum players'**
  String get game_more_min;

  /// No description provided for @game_fewer_max.
  ///
  /// In en, this message translates to:
  /// **'Fewer maximum players'**
  String get game_fewer_max;

  /// No description provided for @game_more_max.
  ///
  /// In en, this message translates to:
  /// **'More maximum players'**
  String get game_more_max;

  /// No description provided for @game_waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get game_waitlist;

  /// No description provided for @game_waitlist_sub.
  ///
  /// In en, this message translates to:
  /// **'Let players queue when full'**
  String get game_waitlist_sub;

  /// No description provided for @game_spectators.
  ///
  /// In en, this message translates to:
  /// **'Spectators'**
  String get game_spectators;

  /// No description provided for @game_spectators_sub.
  ///
  /// In en, this message translates to:
  /// **'Allow spectators to watch'**
  String get game_spectators_sub;

  /// No description provided for @game_details.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get game_details;

  /// No description provided for @game_title_hint.
  ///
  /// In en, this message translates to:
  /// **'Game title'**
  String get game_title_hint;

  /// No description provided for @game_note_hint.
  ///
  /// In en, this message translates to:
  /// **'Add a note for players...'**
  String get game_note_hint;

  /// No description provided for @game_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get game_date;

  /// No description provided for @game_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get game_time;

  /// No description provided for @game_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get game_today;

  /// No description provided for @game_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get game_tomorrow;

  /// No description provided for @game_select_venue.
  ///
  /// In en, this message translates to:
  /// **'Select Venue'**
  String get game_select_venue;

  /// No description provided for @game_select_format_title.
  ///
  /// In en, this message translates to:
  /// **'Select Format'**
  String get game_select_format_title;

  /// No description provided for @game_no_formats.
  ///
  /// In en, this message translates to:
  /// **'No formats available'**
  String get game_no_formats;

  /// No description provided for @game_no_matches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get game_no_matches;

  /// No description provided for @game_skill_beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get game_skill_beginner;

  /// No description provided for @game_skill_intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get game_skill_intermediate;

  /// No description provided for @game_skill_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get game_skill_advanced;

  /// No description provided for @game_skill_pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get game_skill_pro;

  /// No description provided for @game_skill_beginner_sub.
  ///
  /// In en, this message translates to:
  /// **'Just getting started'**
  String get game_skill_beginner_sub;

  /// No description provided for @game_skill_intermediate_sub.
  ///
  /// In en, this message translates to:
  /// **'Plays regularly'**
  String get game_skill_intermediate_sub;

  /// No description provided for @game_skill_advanced_sub.
  ///
  /// In en, this message translates to:
  /// **'Competitive level'**
  String get game_skill_advanced_sub;

  /// No description provided for @game_skill_pro_sub.
  ///
  /// In en, this message translates to:
  /// **'Elite / professional'**
  String get game_skill_pro_sub;

  /// No description provided for @post_detail_title.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post_detail_title;

  /// No description provided for @post_detail_more.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get post_detail_more;

  /// No description provided for @post_detail_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get post_detail_follow;

  /// No description provided for @post_detail_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get post_detail_following;

  /// No description provided for @post_detail_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get post_detail_anonymous;

  /// No description provided for @post_detail_no_replies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet'**
  String get post_detail_no_replies;

  /// No description provided for @post_detail_first_reply.
  ///
  /// In en, this message translates to:
  /// **'Be the first to reply.'**
  String get post_detail_first_reply;

  /// No description provided for @post_detail_reply_hint.
  ///
  /// In en, this message translates to:
  /// **'Post your reply…'**
  String get post_detail_reply_hint;

  /// No description provided for @post_detail_reply_to_hint.
  ///
  /// In en, this message translates to:
  /// **'Reply…'**
  String get post_detail_reply_to_hint;

  /// No description provided for @post_detail_add_image.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get post_detail_add_image;

  /// No description provided for @post_detail_add_location.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get post_detail_add_location;

  /// No description provided for @post_detail_send_reply.
  ///
  /// In en, this message translates to:
  /// **'Send reply'**
  String get post_detail_send_reply;

  /// No description provided for @post_detail_reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get post_detail_reply;

  /// No description provided for @post_detail_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get post_detail_add;

  /// No description provided for @post_detail_hide_replies.
  ///
  /// In en, this message translates to:
  /// **'Hide replies'**
  String get post_detail_hide_replies;

  /// No description provided for @post_detail_view_replies.
  ///
  /// In en, this message translates to:
  /// **'View replies'**
  String get post_detail_view_replies;

  /// No description provided for @post_detail_copy_link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get post_detail_copy_link;

  /// No description provided for @post_detail_link_copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get post_detail_link_copied;

  /// No description provided for @post_detail_delete_post.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get post_detail_delete_post;

  /// No description provided for @post_detail_delete_reply.
  ///
  /// In en, this message translates to:
  /// **'Delete reply'**
  String get post_detail_delete_reply;

  /// No description provided for @post_detail_report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get post_detail_report;

  /// No description provided for @post_detail_edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get post_detail_edited;

  /// No description provided for @post_detail_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load post'**
  String get post_detail_failed;

  /// No description provided for @post_detail_replies_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load replies'**
  String get post_detail_replies_failed;

  /// No description provided for @post_detail_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get post_detail_retry;

  /// No description provided for @post_detail_remove_image.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get post_detail_remove_image;

  /// No description provided for @post_detail_remove_location.
  ///
  /// In en, this message translates to:
  /// **'Remove location'**
  String get post_detail_remove_location;

  /// No description provided for @post_detail_image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get post_detail_image;

  /// No description provided for @post_detail_org.
  ///
  /// In en, this message translates to:
  /// **'Org'**
  String get post_detail_org;

  /// No description provided for @post_detail_player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get post_detail_player;

  /// No description provided for @post_detail_replies_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply} other{{count} replies}}'**
  String post_detail_replies_count(int count);

  /// No description provided for @post_detail_views.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String post_detail_views(String count);

  /// No description provided for @post_detail_replying_to.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get post_detail_replying_to;

  /// No description provided for @post_detail_cancel_reply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get post_detail_cancel_reply;

  /// No description provided for @help_center_title.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get help_center_title;

  /// No description provided for @help_center_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get help_center_empty_title;

  /// No description provided for @help_center_empty_text.
  ///
  /// In en, this message translates to:
  /// **'This screen is under development'**
  String get help_center_empty_text;

  /// No description provided for @contact_title.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contact_title;

  /// No description provided for @contact_intro_title.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get contact_intro_title;

  /// No description provided for @contact_intro_message.
  ///
  /// In en, this message translates to:
  /// **'Send us a message and we\'ll get back to you as soon as possible.'**
  String get contact_intro_message;

  /// No description provided for @contact_section.
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get contact_section;

  /// No description provided for @contact_email.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get contact_email;

  /// No description provided for @contact_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get contact_category;

  /// No description provided for @contact_subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get contact_subject;

  /// No description provided for @contact_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contact_message;

  /// No description provided for @contact_send.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get contact_send;

  /// No description provided for @contact_cat_general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get contact_cat_general;

  /// No description provided for @contact_cat_account.
  ///
  /// In en, this message translates to:
  /// **'Account issues'**
  String get contact_cat_account;

  /// No description provided for @contact_cat_technical.
  ///
  /// In en, this message translates to:
  /// **'Technical problem'**
  String get contact_cat_technical;

  /// No description provided for @contact_cat_billing.
  ///
  /// In en, this message translates to:
  /// **'Payment & billing'**
  String get contact_cat_billing;

  /// No description provided for @contact_cat_feature.
  ///
  /// In en, this message translates to:
  /// **'Feature request'**
  String get contact_cat_feature;

  /// No description provided for @contact_cat_abuse.
  ///
  /// In en, this message translates to:
  /// **'Report abuse'**
  String get contact_cat_abuse;

  /// No description provided for @contact_cat_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy concern'**
  String get contact_cat_privacy;

  /// No description provided for @contact_cat_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get contact_cat_other;

  /// No description provided for @contact_err_email_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get contact_err_email_required;

  /// No description provided for @contact_err_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get contact_err_email_invalid;

  /// No description provided for @contact_err_subject_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter a subject'**
  String get contact_err_subject_required;

  /// No description provided for @contact_err_message_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your message'**
  String get contact_err_message_required;

  /// No description provided for @contact_err_message_short.
  ///
  /// In en, this message translates to:
  /// **'Message must be at least 10 characters long'**
  String get contact_err_message_short;

  /// No description provided for @contact_sent.
  ///
  /// In en, this message translates to:
  /// **'Message sent. We\'ll get back to you soon.'**
  String get contact_sent;

  /// No description provided for @contact_send_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message: {error}'**
  String contact_send_failed(String error);

  /// No description provided for @bug_title.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get bug_title;

  /// No description provided for @bug_intro_title.
  ///
  /// In en, this message translates to:
  /// **'Found a bug?'**
  String get bug_intro_title;

  /// No description provided for @bug_intro_message.
  ///
  /// In en, this message translates to:
  /// **'Help us improve by reporting any issues you encounter. The more details you provide, the faster we can fix it.'**
  String get bug_intro_message;

  /// No description provided for @bug_details.
  ///
  /// In en, this message translates to:
  /// **'Bug details'**
  String get bug_details;

  /// No description provided for @bug_category.
  ///
  /// In en, this message translates to:
  /// **'Bug category'**
  String get bug_category;

  /// No description provided for @bug_severity.
  ///
  /// In en, this message translates to:
  /// **'Severity level'**
  String get bug_severity;

  /// No description provided for @bug_field_title.
  ///
  /// In en, this message translates to:
  /// **'Bug title'**
  String get bug_field_title;

  /// No description provided for @bug_field_title_hint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the issue'**
  String get bug_field_title_hint;

  /// No description provided for @bug_field_description.
  ///
  /// In en, this message translates to:
  /// **'Detailed description'**
  String get bug_field_description;

  /// No description provided for @bug_field_description_hint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened and what you expected to happen'**
  String get bug_field_description_hint;

  /// No description provided for @bug_field_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps to reproduce'**
  String get bug_field_steps;

  /// No description provided for @bug_field_steps_hint.
  ///
  /// In en, this message translates to:
  /// **'1. Go to...\n2. Tap on...\n3. See the error'**
  String get bug_field_steps_hint;

  /// No description provided for @bug_cat_general.
  ///
  /// In en, this message translates to:
  /// **'General bug'**
  String get bug_cat_general;

  /// No description provided for @bug_cat_ui.
  ///
  /// In en, this message translates to:
  /// **'UI / visual issue'**
  String get bug_cat_ui;

  /// No description provided for @bug_cat_performance.
  ///
  /// In en, this message translates to:
  /// **'Performance issue'**
  String get bug_cat_performance;

  /// No description provided for @bug_cat_crash.
  ///
  /// In en, this message translates to:
  /// **'Crash / freeze'**
  String get bug_cat_crash;

  /// No description provided for @bug_cat_login.
  ///
  /// In en, this message translates to:
  /// **'Login / authentication'**
  String get bug_cat_login;

  /// No description provided for @bug_cat_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile / settings'**
  String get bug_cat_profile;

  /// No description provided for @bug_cat_games.
  ///
  /// In en, this message translates to:
  /// **'Games / activities'**
  String get bug_cat_games;

  /// No description provided for @bug_cat_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get bug_cat_notifications;

  /// No description provided for @bug_cat_social.
  ///
  /// In en, this message translates to:
  /// **'Social features'**
  String get bug_cat_social;

  /// No description provided for @bug_cat_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get bug_cat_other;

  /// No description provided for @bug_sev_low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get bug_sev_low;

  /// No description provided for @bug_sev_medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get bug_sev_medium;

  /// No description provided for @bug_sev_high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get bug_sev_high;

  /// No description provided for @bug_sev_critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get bug_sev_critical;

  /// No description provided for @bug_additional.
  ///
  /// In en, this message translates to:
  /// **'Additional information'**
  String get bug_additional;

  /// No description provided for @bug_include_device.
  ///
  /// In en, this message translates to:
  /// **'Include device information'**
  String get bug_include_device;

  /// No description provided for @bug_include_device_sub.
  ///
  /// In en, this message translates to:
  /// **'OS version, device model, screen size'**
  String get bug_include_device_sub;

  /// No description provided for @bug_include_logs.
  ///
  /// In en, this message translates to:
  /// **'Include app logs'**
  String get bug_include_logs;

  /// No description provided for @bug_include_logs_sub.
  ///
  /// In en, this message translates to:
  /// **'Recent app activity and error logs'**
  String get bug_include_logs_sub;

  /// No description provided for @bug_device_heading.
  ///
  /// In en, this message translates to:
  /// **'Device information to include:'**
  String get bug_device_heading;

  /// No description provided for @bug_device_platform.
  ///
  /// In en, this message translates to:
  /// **'Platform: {value}'**
  String bug_device_platform(String value);

  /// No description provided for @bug_device_app_version.
  ///
  /// In en, this message translates to:
  /// **'App version: {value}'**
  String bug_device_app_version(String value);

  /// No description provided for @bug_device_resolution.
  ///
  /// In en, this message translates to:
  /// **'Screen resolution: {value}'**
  String bug_device_resolution(String value);

  /// No description provided for @bug_platform_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get bug_platform_unknown;

  /// No description provided for @bug_platform_web.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get bug_platform_web;

  /// No description provided for @bug_err_email_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get bug_err_email_required;

  /// No description provided for @bug_err_title_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bug title'**
  String get bug_err_title_required;

  /// No description provided for @bug_err_description_required.
  ///
  /// In en, this message translates to:
  /// **'Please describe the bug'**
  String get bug_err_description_required;

  /// No description provided for @bug_err_description_short.
  ///
  /// In en, this message translates to:
  /// **'Please provide more details (at least 20 characters)'**
  String get bug_err_description_short;

  /// No description provided for @bug_err_steps_required.
  ///
  /// In en, this message translates to:
  /// **'Please provide steps to reproduce the bug'**
  String get bug_err_steps_required;

  /// No description provided for @bug_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit bug report'**
  String get bug_submit;

  /// No description provided for @bug_submitted.
  ///
  /// In en, this message translates to:
  /// **'Bug report submitted. Thank you for helping us improve.'**
  String get bug_submitted;

  /// No description provided for @bug_submit_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit bug report: {error}'**
  String bug_submit_failed(String error);

  /// No description provided for @sports_prefs_title.
  ///
  /// In en, this message translates to:
  /// **'Sports preferences'**
  String get sports_prefs_title;

  /// No description provided for @sports_prefs_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sports_prefs_save;

  /// No description provided for @sports_prefs_create_game.
  ///
  /// In en, this message translates to:
  /// **'Create game'**
  String get sports_prefs_create_game;

  /// No description provided for @sports_prefs_my_sports.
  ///
  /// In en, this message translates to:
  /// **'My sports'**
  String get sports_prefs_my_sports;

  /// No description provided for @sports_prefs_my_sports_note.
  ///
  /// In en, this message translates to:
  /// **'Enable sports you want to play and set your skill level'**
  String get sports_prefs_my_sports_note;

  /// No description provided for @sports_prefs_general.
  ///
  /// In en, this message translates to:
  /// **'General preferences'**
  String get sports_prefs_general;

  /// No description provided for @sports_prefs_auto_join.
  ///
  /// In en, this message translates to:
  /// **'Auto-join compatible games'**
  String get sports_prefs_auto_join;

  /// No description provided for @sports_prefs_auto_join_sub.
  ///
  /// In en, this message translates to:
  /// **'Automatically join games that match your preferences'**
  String get sports_prefs_auto_join_sub;

  /// No description provided for @sports_prefs_location.
  ///
  /// In en, this message translates to:
  /// **'Use location for recommendations'**
  String get sports_prefs_location;

  /// No description provided for @sports_prefs_location_sub.
  ///
  /// In en, this message translates to:
  /// **'Find games near your current location'**
  String get sports_prefs_location_sub;

  /// No description provided for @sports_prefs_flexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible timing'**
  String get sports_prefs_flexible;

  /// No description provided for @sports_prefs_flexible_sub.
  ///
  /// In en, this message translates to:
  /// **'Show games with flexible start times'**
  String get sports_prefs_flexible_sub;

  /// No description provided for @sports_prefs_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get sports_prefs_disabled;

  /// No description provided for @sports_prefs_skill_level.
  ///
  /// In en, this message translates to:
  /// **'Skill level'**
  String get sports_prefs_skill_level;

  /// No description provided for @sports_prefs_position.
  ///
  /// In en, this message translates to:
  /// **'Preferred position'**
  String get sports_prefs_position;

  /// No description provided for @sports_prefs_level_beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get sports_prefs_level_beginner;

  /// No description provided for @sports_prefs_level_intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get sports_prefs_level_intermediate;

  /// No description provided for @sports_prefs_level_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sports_prefs_level_advanced;

  /// No description provided for @sports_prefs_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sports preferences: {error}'**
  String sports_prefs_load_failed(String error);

  /// No description provided for @sports_prefs_saved.
  ///
  /// In en, this message translates to:
  /// **'Sports preferences saved'**
  String get sports_prefs_saved;

  /// No description provided for @sports_prefs_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save preferences: {error}'**
  String sports_prefs_save_failed(String error);

  /// No description provided for @sports_prefs_enable_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable sport: {error}'**
  String sports_prefs_enable_failed(String error);

  /// No description provided for @sports_prefs_remove_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove sport: {error}'**
  String sports_prefs_remove_failed(String error);

  /// No description provided for @sports_prefs_need_one.
  ///
  /// In en, this message translates to:
  /// **'You must have at least one sport enabled'**
  String get sports_prefs_need_one;

  /// No description provided for @sports_prefs_remove_title.
  ///
  /// In en, this message translates to:
  /// **'Remove {sport}?'**
  String sports_prefs_remove_title(String sport);

  /// No description provided for @sports_prefs_remove_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {sport} from your profile?'**
  String sports_prefs_remove_body(String sport);

  /// No description provided for @sports_prefs_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sports_prefs_cancel;

  /// No description provided for @sports_prefs_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get sports_prefs_remove;

  /// No description provided for @sports_pos_goalkeeper.
  ///
  /// In en, this message translates to:
  /// **'Goalkeeper'**
  String get sports_pos_goalkeeper;

  /// No description provided for @sports_pos_defender.
  ///
  /// In en, this message translates to:
  /// **'Defender'**
  String get sports_pos_defender;

  /// No description provided for @sports_pos_midfielder.
  ///
  /// In en, this message translates to:
  /// **'Midfielder'**
  String get sports_pos_midfielder;

  /// No description provided for @sports_pos_forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get sports_pos_forward;

  /// No description provided for @sports_pos_point_guard.
  ///
  /// In en, this message translates to:
  /// **'Point Guard'**
  String get sports_pos_point_guard;

  /// No description provided for @sports_pos_shooting_guard.
  ///
  /// In en, this message translates to:
  /// **'Shooting Guard'**
  String get sports_pos_shooting_guard;

  /// No description provided for @sports_pos_small_forward.
  ///
  /// In en, this message translates to:
  /// **'Small Forward'**
  String get sports_pos_small_forward;

  /// No description provided for @sports_pos_power_forward.
  ///
  /// In en, this message translates to:
  /// **'Power Forward'**
  String get sports_pos_power_forward;

  /// No description provided for @sports_pos_center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get sports_pos_center;

  /// No description provided for @sports_pos_setter.
  ///
  /// In en, this message translates to:
  /// **'Setter'**
  String get sports_pos_setter;

  /// No description provided for @sports_pos_outside_hitter.
  ///
  /// In en, this message translates to:
  /// **'Outside Hitter'**
  String get sports_pos_outside_hitter;

  /// No description provided for @sports_pos_middle_blocker.
  ///
  /// In en, this message translates to:
  /// **'Middle Blocker'**
  String get sports_pos_middle_blocker;

  /// No description provided for @sports_pos_opposite_hitter.
  ///
  /// In en, this message translates to:
  /// **'Opposite Hitter'**
  String get sports_pos_opposite_hitter;

  /// No description provided for @sports_pos_libero.
  ///
  /// In en, this message translates to:
  /// **'Libero'**
  String get sports_pos_libero;

  /// No description provided for @about_terms_intro.
  ///
  /// In en, this message translates to:
  /// **'Please read these terms carefully before using our service.'**
  String get about_terms_intro;

  /// No description provided for @about_privacy_intro.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important to us. This policy explains how we collect, use, and protect your information.'**
  String get about_privacy_intro;

  /// No description provided for @about_last_updated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String about_last_updated(String date);

  /// No description provided for @about_privacy_settings_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get about_privacy_settings_tooltip;

  /// No description provided for @licenses_title.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get licenses_title;

  /// No description provided for @licenses_about_tooltip.
  ///
  /// In en, this message translates to:
  /// **'About licenses'**
  String get licenses_about_tooltip;

  /// No description provided for @licenses_intro.
  ///
  /// In en, this message translates to:
  /// **'This app is built with amazing open source libraries. We thank all contributors for their work.'**
  String get licenses_intro;

  /// No description provided for @licenses_count.
  ///
  /// In en, this message translates to:
  /// **'{count} open source packages'**
  String licenses_count(String count);

  /// No description provided for @licenses_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search licenses...'**
  String get licenses_search_hint;

  /// No description provided for @licenses_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No licenses found'**
  String get licenses_empty_title;

  /// No description provided for @licenses_empty_text.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search query'**
  String get licenses_empty_text;

  /// No description provided for @licenses_info_title.
  ///
  /// In en, this message translates to:
  /// **'About open source licenses'**
  String get licenses_info_title;

  /// No description provided for @licenses_info_body.
  ///
  /// In en, this message translates to:
  /// **'This app uses various open source libraries and packages. Each license defines the terms under which the code can be used, modified, and distributed.\n\nWe are grateful to all the developers and contributors who make their work available under open source licenses.'**
  String get licenses_info_body;

  /// No description provided for @licenses_got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get licenses_got_it;

  /// No description provided for @licenses_detail_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get licenses_detail_version;

  /// No description provided for @licenses_detail_license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get licenses_detail_license;

  /// No description provided for @licenses_detail_copyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get licenses_detail_copyright;

  /// No description provided for @licenses_detail_url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get licenses_detail_url;

  /// No description provided for @licenses_detail_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get licenses_detail_description;

  /// No description provided for @licenses_view_web.
  ///
  /// In en, this message translates to:
  /// **'View on web'**
  String get licenses_view_web;

  /// No description provided for @licenses_opening.
  ///
  /// In en, this message translates to:
  /// **'Opening {url}'**
  String licenses_opening(String url);

  /// No description provided for @sfx_search_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search people, games, posts…'**
  String get sfx_search_placeholder;

  /// No description provided for @sfx_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get sfx_recent;

  /// No description provided for @sfx_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get sfx_clear;

  /// No description provided for @sfx_remove_recent.
  ///
  /// In en, this message translates to:
  /// **'Remove {query}'**
  String sfx_remove_recent(String query);

  /// No description provided for @sfx_quick_filters.
  ///
  /// In en, this message translates to:
  /// **'Quick filters'**
  String get sfx_quick_filters;

  /// No description provided for @sfx_near_me.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get sfx_near_me;

  /// No description provided for @sfx_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sfx_today;

  /// No description provided for @sfx_this_week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get sfx_this_week;

  /// No description provided for @sfx_friends_only.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get sfx_friends_only;

  /// No description provided for @sfx_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get sfx_popular;

  /// No description provided for @sfx_free_entry.
  ///
  /// In en, this message translates to:
  /// **'Free entry'**
  String get sfx_free_entry;

  /// No description provided for @sfx_people_nearby.
  ///
  /// In en, this message translates to:
  /// **'People nearby'**
  String get sfx_people_nearby;

  /// No description provided for @sfx_people_nearby_sub.
  ///
  /// In en, this message translates to:
  /// **'Find players near you'**
  String get sfx_people_nearby_sub;

  /// No description provided for @sfx_popular_games.
  ///
  /// In en, this message translates to:
  /// **'Popular games'**
  String get sfx_popular_games;

  /// No description provided for @sfx_popular_games_sub.
  ///
  /// In en, this message translates to:
  /// **'Open spots today'**
  String get sfx_popular_games_sub;

  /// No description provided for @sfx_trending_posts.
  ///
  /// In en, this message translates to:
  /// **'Trending posts'**
  String get sfx_trending_posts;

  /// No description provided for @sfx_trending_posts_sub.
  ///
  /// In en, this message translates to:
  /// **'What everyone’s on'**
  String get sfx_trending_posts_sub;

  /// No description provided for @sfx_showing_results_for.
  ///
  /// In en, this message translates to:
  /// **'Showing results for'**
  String get sfx_showing_results_for;

  /// No description provided for @sfx_view_all.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get sfx_view_all;

  /// No description provided for @sfx_people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get sfx_people;

  /// No description provided for @sfx_hashtags.
  ///
  /// In en, this message translates to:
  /// **'Hashtags'**
  String get sfx_hashtags;

  /// No description provided for @sfx_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get sfx_games;

  /// No description provided for @sfx_venues.
  ///
  /// In en, this message translates to:
  /// **'Venues'**
  String get sfx_venues;

  /// No description provided for @sfx_posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get sfx_posts;

  /// No description provided for @sfx_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get sfx_comments;

  /// No description provided for @sfx_meetups.
  ///
  /// In en, this message translates to:
  /// **'Meet-ups'**
  String get sfx_meetups;

  /// No description provided for @sfx_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get sfx_follow;

  /// No description provided for @sfx_join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get sfx_join;

  /// No description provided for @sfx_kind_game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get sfx_kind_game;

  /// No description provided for @sfx_kind_meetup.
  ///
  /// In en, this message translates to:
  /// **'Meet-up'**
  String get sfx_kind_meetup;

  /// No description provided for @sfx_spots.
  ///
  /// In en, this message translates to:
  /// **'spots'**
  String get sfx_spots;

  /// No description provided for @sfx_spots_meta.
  ///
  /// In en, this message translates to:
  /// **'{joined}/{max} spots'**
  String sfx_spots_meta(int joined, int max);

  /// No description provided for @sfx_posts_count.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String sfx_posts_count(int count);

  /// No description provided for @sfx_on_post.
  ///
  /// In en, this message translates to:
  /// **'on {title}'**
  String sfx_on_post(String title);

  /// No description provided for @sfx_no_results_for.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String sfx_no_results_for(String query);

  /// No description provided for @sfx_none_found.
  ///
  /// In en, this message translates to:
  /// **'No {label} found'**
  String sfx_none_found(String label);

  /// No description provided for @sfx_list_header.
  ///
  /// In en, this message translates to:
  /// **'{count} {label} for \"{query}\"'**
  String sfx_list_header(int count, String label, String query);

  /// No description provided for @sfx_hashtag_empty.
  ///
  /// In en, this message translates to:
  /// **'No posts found for #{slug}'**
  String sfx_hashtag_empty(String slug);

  /// No description provided for @sfx_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sfx_retry;

  /// No description provided for @sfx_news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get sfx_news;

  /// No description provided for @sfx_add_comment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get sfx_add_comment;

  /// No description provided for @sfx_discuss.
  ///
  /// In en, this message translates to:
  /// **'Discuss'**
  String get sfx_discuss;

  /// No description provided for @sfx_be_first.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment.'**
  String get sfx_be_first;

  /// No description provided for @sfx_like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get sfx_like;

  /// No description provided for @sfx_send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sfx_send;

  /// No description provided for @sfx_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sfx_share;

  /// No description provided for @sfx_share_article.
  ///
  /// In en, this message translates to:
  /// **'Share article'**
  String get sfx_share_article;

  /// No description provided for @sfx_copy_link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get sfx_copy_link;

  /// No description provided for @sfx_share_to.
  ///
  /// In en, this message translates to:
  /// **'Share to…'**
  String get sfx_share_to;

  /// No description provided for @sfx_link_copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get sfx_link_copied;

  /// No description provided for @sfx_events.
  ///
  /// In en, this message translates to:
  /// **'games and meet-ups'**
  String get sfx_events;

  /// No description provided for @composer_place_search.
  ///
  /// In en, this message translates to:
  /// **'Search venues and areas'**
  String get composer_place_search;

  /// No description provided for @composer_results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get composer_results;

  /// No description provided for @composer_places_none.
  ///
  /// In en, this message translates to:
  /// **'No places match that search'**
  String get composer_places_none;

  /// No description provided for @composer_pick_date.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get composer_pick_date;

  /// No description provided for @composer_pick_time.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get composer_pick_time;

  /// No description provided for @composer_step_1.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2'**
  String get composer_step_1;

  /// No description provided for @composer_step_2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2'**
  String get composer_step_2;

  /// No description provided for @composer_kickoff_time.
  ///
  /// In en, this message translates to:
  /// **'Kickoff time'**
  String get composer_kickoff_time;

  /// No description provided for @composer_continue_time.
  ///
  /// In en, this message translates to:
  /// **'Continue to time'**
  String get composer_continue_time;

  /// No description provided for @composer_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get composer_done;

  /// No description provided for @composer_use_typed.
  ///
  /// In en, this message translates to:
  /// **'Use “{query}”'**
  String composer_use_typed(String query);

  /// No description provided for @composer_format_title.
  ///
  /// In en, this message translates to:
  /// **'{sport} format'**
  String composer_format_title(String sport);

  /// No description provided for @composer_players_count.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String composer_players_count(int count);

  /// No description provided for @sfx_comments_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String sfx_comments_count(int count);

  /// No description provided for @profile_section_my_sports.
  ///
  /// In en, this message translates to:
  /// **'My sports'**
  String get profile_section_my_sports;

  /// No description provided for @profile_section_their_sports.
  ///
  /// In en, this message translates to:
  /// **'Their sports'**
  String get profile_section_their_sports;

  /// No description provided for @profile_btn_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get profile_btn_manage;

  /// No description provided for @profile_sport_picker_all.
  ///
  /// In en, this message translates to:
  /// **'All sports'**
  String get profile_sport_picker_all;

  /// No description provided for @profile_stat_rated.
  ///
  /// In en, this message translates to:
  /// **'Rated by players'**
  String get profile_stat_rated;

  /// No description provided for @profile_stat_primary_sports.
  ///
  /// In en, this message translates to:
  /// **'Primary sports'**
  String get profile_stat_primary_sports;

  /// No description provided for @profile_stat_sport_matches.
  ///
  /// In en, this message translates to:
  /// **'{sport} matches'**
  String profile_stat_sport_matches(String sport);

  /// No description provided for @profile_create_another_profile.
  ///
  /// In en, this message translates to:
  /// **'Create another profile'**
  String get profile_create_another_profile;

  /// No description provided for @profile_create_persona_profile.
  ///
  /// In en, this message translates to:
  /// **'Create {persona} profile'**
  String profile_create_persona_profile(String persona);

  /// No description provided for @sport_profile_overall_level.
  ///
  /// In en, this message translates to:
  /// **'{sport} · overall level {level}'**
  String sport_profile_overall_level(String sport, String level);

  /// No description provided for @profile_sports_followed_note.
  ///
  /// In en, this message translates to:
  /// **'Sports followed — feeds and results only'**
  String get profile_sports_followed_note;

  /// No description provided for @profile_stat_sports_followed.
  ///
  /// In en, this message translates to:
  /// **'Sports followed'**
  String get profile_stat_sports_followed;

  /// No description provided for @profile_stat_minutes_played.
  ///
  /// In en, this message translates to:
  /// **'Minutes played'**
  String get profile_stat_minutes_played;

  /// No description provided for @meetups_tab_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get meetups_tab_all;

  /// No description provided for @meetups_none_title.
  ///
  /// In en, this message translates to:
  /// **'No meetups available.'**
  String get meetups_none_title;

  /// No description provided for @meetups_explore_another.
  ///
  /// In en, this message translates to:
  /// **'Explore another activity'**
  String get meetups_explore_another;

  /// No description provided for @meetups_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load meetups'**
  String get meetups_load_failed;

  /// No description provided for @meetups_join.
  ///
  /// In en, this message translates to:
  /// **'Join meetup'**
  String get meetups_join;

  /// No description provided for @meetups_request.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get meetups_request;

  /// No description provided for @meetups_going_count.
  ///
  /// In en, this message translates to:
  /// **'{count} going'**
  String meetups_going_count(int count);

  /// No description provided for @meetups_max.
  ///
  /// In en, this message translates to:
  /// **'Max {count}'**
  String meetups_max(int count);

  /// No description provided for @meetups_free_note.
  ///
  /// In en, this message translates to:
  /// **'no charge'**
  String get meetups_free_note;

  /// No description provided for @meetups_distance_km.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String meetups_distance_km(String km);

  /// No description provided for @meetups_cta_going.
  ///
  /// In en, this message translates to:
  /// **'Joining'**
  String get meetups_cta_going;

  /// No description provided for @meetups_cta_interested.
  ///
  /// In en, this message translates to:
  /// **'Maybe going'**
  String get meetups_cta_interested;

  /// No description provided for @meetups_cta_full.
  ///
  /// In en, this message translates to:
  /// **'Full - you\'re interested'**
  String get meetups_cta_full;

  /// No description provided for @meetups_cta_closed.
  ///
  /// In en, this message translates to:
  /// **'Registration closed'**
  String get meetups_cta_closed;

  /// No description provided for @meetups_cta_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get meetups_cta_cancelled;

  /// No description provided for @meetups_cta_started.
  ///
  /// In en, this message translates to:
  /// **'Already started'**
  String get meetups_cta_started;

  /// No description provided for @meetups_cta_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get meetups_cta_unavailable;

  /// No description provided for @meetups_cta_not_allowed.
  ///
  /// In en, this message translates to:
  /// **'Switch profile to join'**
  String get meetups_cta_not_allowed;

  /// No description provided for @meetups_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Are you going to this meetup?'**
  String get meetups_sheet_title;

  /// No description provided for @meetups_sheet_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get meetups_sheet_cancel;

  /// No description provided for @meetups_sheet_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I am going'**
  String get meetups_sheet_yes;

  /// No description provided for @meetups_sheet_maybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get meetups_sheet_maybe;

  /// No description provided for @meetups_sheet_no.
  ///
  /// In en, this message translates to:
  /// **'No, not this time'**
  String get meetups_sheet_no;

  /// No description provided for @meetups_sheet_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get meetups_sheet_confirm;

  /// No description provided for @meetups_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get meetups_error_generic;

  /// No description provided for @meetups_error_cancelled.
  ///
  /// In en, this message translates to:
  /// **'This meetup was cancelled.'**
  String get meetups_error_cancelled;

  /// No description provided for @meetups_host_caption.
  ///
  /// In en, this message translates to:
  /// **'Community host'**
  String get meetups_host_caption;

  /// No description provided for @meetups_tile_meeting_point.
  ///
  /// In en, this message translates to:
  /// **'Meeting point'**
  String get meetups_tile_meeting_point;

  /// No description provided for @meetups_tile_entry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get meetups_tile_entry;

  /// No description provided for @meetups_load_detail_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this meetup'**
  String get meetups_load_detail_failed;

  /// No description provided for @meetups_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get meetups_back;

  /// No description provided for @meetups_names_and_others.
  ///
  /// In en, this message translates to:
  /// **'{names} and {count} others'**
  String meetups_names_and_others(String names, int count);
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
