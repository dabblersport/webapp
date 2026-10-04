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
  /// **'Manage Profiles'**
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
  /// **'Games'**
  String get user_profile_stat_games;

  /// No description provided for @user_profile_stat_win_rate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get user_profile_stat_win_rate;

  /// No description provided for @user_profile_stat_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
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

  /// No description provided for @listing_spots_left.
  ///
  /// In en, this message translates to:
  /// **'{count} spots left'**
  String listing_spots_left(int count);

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
