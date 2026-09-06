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
