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
  String get tab_most_recent => 'For you';

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
      'News cards will no longer appear in For you. You can still read all news in the News tab.';

  @override
  String get news_hide_confirm => 'Hide news';

  @override
  String get news_hide_cancel => 'Cancel';

  @override
  String get news_hidden_snack => 'News hidden from For you';

  @override
  String get news_resubscribed_snack => 'News will now appear in For you';

  @override
  String get news_resubscribe_banner => 'News is hidden from For you.';

  @override
  String get news_resubscribe_action => 'Show again';

  @override
  String get auth_welcome_title => 'Welcome';

  @override
  String get auth_welcome_subtitle =>
      'We are stoked to have you join us. Create an account and start dabbing in local sports.';

  @override
  String get auth_welcome_trust_heading => 'Built for trust';

  @override
  String get auth_welcome_trust_verified =>
      'Reviewed players, verified memberships and rated venues';

  @override
  String get auth_welcome_trust_personalised =>
      'Connections and recommendations personalised to your sports';

  @override
  String get auth_welcome_trust_privacy =>
      'We do not sell your data — privacy-first by design';

  @override
  String get auth_welcome_get_started => 'Get started';

  @override
  String get auth_welcome_get_started_subtitle => 'Create an account or log in';

  @override
  String get auth_welcome_btn_google => 'Continue with Google';

  @override
  String get auth_welcome_btn_apple => 'Continue with Apple';

  @override
  String get auth_welcome_btn_email => 'Continue with Email';

  @override
  String get auth_welcome_btn_login => 'Already have an account? Log in';

  @override
  String get auth_welcome_apple_soon => 'Apple sign-in is coming soon.';

  @override
  String auth_welcome_google_error(String error) {
    return 'Could not sign in with Google: $error';
  }

  @override
  String get auth_welcome_country_picker_title => 'Choose your country';

  @override
  String get auth_welcome_language_picker_title => 'Choose language';

  @override
  String get landing_quote1 =>
      'I promised myself I\'d play at least twice a week.';

  @override
  String get landing_quote2 =>
      'Between work and life finding a game feels harder than a 90-minute run.';

  @override
  String get landing_tagline =>
      'Dabbler connects players, captains, and venues so you can stop searching and start playing';

  @override
  String get landing_continue => 'Continue';

  @override
  String get landing_choose_language => 'Choose language';

  @override
  String get auth_already_have_account => 'Already have an account?';

  @override
  String get auth_log_in => 'Log in';

  @override
  String get auth_new_here => 'New here?';

  @override
  String get auth_create_account => 'Create an account';

  @override
  String get auth_sheet_done => 'Done';

  @override
  String get auth_sheet_got_it => 'Got it';

  @override
  String get auth_back => 'Back';

  @override
  String get landing_dc_tagline =>
      'Dabbler connects players, organisers and venues, so you can stop searching and start playing.';

  @override
  String get landing_dc_continue => 'Continue';

  @override
  String get landing_vignette_marcus_quote =>
      'Half the group chat’s flaky. The other half changes their mind by Friday.';

  @override
  String get landing_vignette_marcus_want =>
      'I just want one place to organise a 5-a-side and stop chasing replies.';

  @override
  String get landing_vignette_aisha_quote =>
      'New city, decent left foot, nobody to pass to.';

  @override
  String get landing_vignette_aisha_want =>
      'I want a game this week, not a group chat about a game.';

  @override
  String get landing_vignette_priya_quote =>
      'I follow more padel than I’ve ever actually played.';

  @override
  String get landing_vignette_priya_want =>
      'Show me who’s playing near me and I’ll find my way in.';

  @override
  String get landing_vignette_sevens_quote =>
      'Three pitches free at 9pm and nobody knows about it.';

  @override
  String get landing_vignette_sevens_want =>
      'Put my courts in front of players already looking for one.';

  @override
  String get auth_entry_title => 'Let\'s get you playing';

  @override
  String get auth_entry_subtitle => 'One account for games, squads and venues.';

  @override
  String get auth_entry_trust_verified =>
      'Reviewed players, verified venues, rated games';

  @override
  String get auth_entry_trust_personalised =>
      'Games and people picked around your sports';

  @override
  String get auth_entry_trust_privacy =>
      'We don’t sell your data. Privacy-first by design';

  @override
  String get auth_entry_continue_email => 'Continue with email';

  @override
  String get auth_entry_continue_google => 'Continue with Google';

  @override
  String get auth_entry_continue_apple => 'Continue with Apple';

  @override
  String get auth_legal_prefix => 'By continuing you agree to our ';

  @override
  String get auth_legal_terms => 'Terms of Service';

  @override
  String get auth_legal_and => ' and ';

  @override
  String get auth_legal_privacy => 'Privacy Policy';

  @override
  String get auth_sheet_language => 'Language';

  @override
  String get auth_sheet_region => 'Region';

  @override
  String get auth_email_title => 'What\'s your email?';

  @override
  String get auth_email_subtitle =>
      'We\'ll send a code. If you\'ve been here before, we\'ll pick up where you left off.';

  @override
  String get auth_email_label => 'Email';

  @override
  String get auth_email_placeholder => 'you@email.com';

  @override
  String get auth_email_marketing =>
      'Keep me posted on games and features near me';

  @override
  String get auth_email_send_code => 'Send me a code';

  @override
  String get auth_email_invalid => 'That does not look like an email address.';

  @override
  String get auth_login_title => 'Welcome back';

  @override
  String get auth_login_subtitle =>
      'Log in your way — password, a one-time code, or a connected account.';

  @override
  String get auth_login_password_label => 'Password';

  @override
  String get auth_login_password_placeholder => 'Your password';

  @override
  String get auth_login_button => 'Log in';

  @override
  String get auth_login_email_code => 'Email me a code instead';

  @override
  String get auth_login_password_wrong =>
      'That password does not match. Try again, or email yourself a code.';

  @override
  String get auth_otp_title => 'Check your inbox';

  @override
  String get auth_otp_subtitle => 'We sent a 6-digit code to your email.';

  @override
  String get auth_otp_change => 'Change';

  @override
  String get auth_otp_invalid =>
      'That code is not right. Check the email and try again.';

  @override
  String get auth_otp_expired => 'This code has expired. Send a new one.';

  @override
  String get auth_otp_resend => 'Send a new code';

  @override
  String auth_otp_resend_in(int seconds) {
    return 'Send a new code in ${seconds}s';
  }

  @override
  String get auth_otp_continue => 'Continue';

  @override
  String auth_welcome_back_title(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get auth_welcome_continue => 'Continue';

  @override
  String get auth_welcome_list_title => 'Don’t forget';

  @override
  String get persona_player_name => 'Player';

  @override
  String get persona_player_headline => 'You’re in. Let’s play.';

  @override
  String get persona_player_principle => 'Show up, play fair, build your rep.';

  @override
  String get persona_player_list_title => 'Don’t forget';

  @override
  String get persona_player_item1 => 'Only confirm when you know you can play.';

  @override
  String get persona_player_item2 =>
      'Respect the organiser’s rules and kickoff time.';

  @override
  String get persona_player_item3 =>
      'Turning up is what builds your reputation.';

  @override
  String get persona_player_cta => 'Find my first game';

  @override
  String get persona_organiser_name => 'Organiser';

  @override
  String get persona_organiser_headline => 'Time to bring the game together.';

  @override
  String get persona_organiser_principle =>
      'Good games start with good organisation.';

  @override
  String get persona_organiser_list_title => 'What players expect';

  @override
  String get persona_organiser_item1 =>
      'Accurate details — venue, time, level, price.';

  @override
  String get persona_organiser_item2 => 'Changes shared early, not at kickoff.';

  @override
  String get persona_organiser_item3 =>
      'Attendance managed fairly, every time.';

  @override
  String get persona_organiser_cta => 'Create my first game';

  @override
  String get persona_host_name => 'Host';

  @override
  String get persona_host_headline => 'Your venue’s on the map.';

  @override
  String get persona_host_principle => 'Great venues make playing easy.';

  @override
  String get persona_host_list_title => 'What players expect';

  @override
  String get persona_host_item1 => 'Availability that matches reality.';

  @override
  String get persona_host_item2 => 'Pricing and facilities kept current.';

  @override
  String get persona_host_item3 =>
      'Bookings honoured — that’s what brings them back.';

  @override
  String get persona_host_cta => 'Set up my venue';

  @override
  String get persona_socialiser_name => 'Socialiser';

  @override
  String get persona_socialiser_headline => 'Your sports circle starts here.';

  @override
  String get persona_socialiser_principle =>
      'Follow what you love, meet your people, join when it feels right.';

  @override
  String get persona_socialiser_list_title => 'How this works';

  @override
  String get persona_socialiser_item1 =>
      'Follow the sports and people you actually care about.';

  @override
  String get persona_socialiser_item2 =>
      'Join the conversation before you join the game.';

  @override
  String get persona_socialiser_item3 =>
      'Keep it friendly — everyone here is someone’s teammate.';

  @override
  String get persona_socialiser_cta => 'Start exploring';

  @override
  String get auth_or => 'or';

  @override
  String get email_input_title => 'Authenticate';

  @override
  String get email_input_subtitle => 'Enter your email to get started';

  @override
  String get email_input_label => 'Email';

  @override
  String get email_input_hint => 'email@domain.com';

  @override
  String get email_input_continue => 'Continue';

  @override
  String get email_input_keep_in_loop =>
      'Keep me in the loop with emails about updates & more';

  @override
  String get email_input_already_account => 'Already have an account? Log in';

  @override
  String get email_input_btn_google => 'Continue with Google';

  @override
  String get email_input_btn_apple => 'Continue with Apple';

  @override
  String get email_input_terms_prefix =>
      'By clicking Continue, you are indicating that you have read and agree to the ';

  @override
  String get email_input_terms_link => 'Terms of Service';

  @override
  String get email_input_terms_and => ' & ';

  @override
  String get email_input_privacy_link => 'Privacy Policy';

  @override
  String get email_input_validate_required => 'Email is required';

  @override
  String get email_input_validate_invalid => 'Enter a valid email address';

  @override
  String get email_input_error_generic =>
      'An error occurred. Please try again.';

  @override
  String get email_input_google_failed =>
      'Google sign-in failed. Please try again.';

  @override
  String get email_password_title => 'Login';

  @override
  String get email_password_subtitle =>
      'Enter your email and password\nor login using OTP';

  @override
  String get email_password_forgot => 'Forget password?';

  @override
  String get email_password_send_otp => 'Send email OTP';

  @override
  String get email_password_login_btn => 'Login';

  @override
  String get email_password_btn_google => 'Continue with Google';

  @override
  String get email_password_btn_apple => 'Continue with Apple';

  @override
  String get email_password_hint_email => 'email@domain.com';

  @override
  String get email_password_hint_password => 'Password';

  @override
  String get email_password_show_password => 'Show password';

  @override
  String get email_password_hide_password => 'Hide password';

  @override
  String get email_password_validate_email_required => 'Email is required';

  @override
  String get email_password_validate_email_invalid =>
      'Enter a valid email address';

  @override
  String get email_password_validate_password_required => 'Enter password';

  @override
  String get email_password_error_invalid_creds => 'Invalid email or password';

  @override
  String get email_password_error_login_failed => 'Login failed.';

  @override
  String get email_password_error_otp_failed =>
      'Failed to send OTP. Please try again.';

  @override
  String get email_password_apple_soon => 'Apple sign-in is coming soon.';

  @override
  String get email_password_google_failed => 'Google sign-in failed.';

  @override
  String get email_password_validate_email_hint =>
      'Enter a valid email address.';

  @override
  String get email_verify_appbar => 'Confirm your email';

  @override
  String get email_verify_title => 'Check your inbox';

  @override
  String email_verify_body_with_email(String email) {
    return 'We\'ve sent a confirmation link to $email.\n\nPlease confirm your email to finish setting up your account.';
  }

  @override
  String get email_verify_body_no_email =>
      'We\'ve sent a confirmation link to your email.\n\nPlease confirm your email to finish setting up your account.';

  @override
  String get email_verify_instruction =>
      'After confirming your email, come back to the app and tap \"I\'ve confirmed my email\" to continue.';

  @override
  String get email_verify_confirmed_btn => 'I\'ve confirmed my email';

  @override
  String get email_verify_resend_btn => 'Resend confirmation email';

  @override
  String get email_verify_different_account => 'Use a different account';

  @override
  String get email_verify_no_email_error =>
      'No email found for the current user.';

  @override
  String get email_verify_spam_note =>
      'If you don\'t see the email, please check your spam folder or request a new link from the sign-in screen.';

  @override
  String get forgot_password_title => 'Reset Your Password';

  @override
  String get forgot_password_subtitle =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgot_password_email_hint => 'Email Address';

  @override
  String get forgot_password_send_btn => 'Send Reset Link';

  @override
  String get forgot_password_sent_msg =>
      'Reset link sent! Check your email inbox and spam folder for instructions to reset your password.';

  @override
  String get forgot_password_back_to_signin => 'Back to Sign In';

  @override
  String get forgot_password_validate_email => 'Enter a valid email';

  @override
  String get otp_verify_title_email => 'Verify email';

  @override
  String get otp_verify_title_phone => 'Verify phone';

  @override
  String get otp_verify_subtitle_email =>
      'Enter the 6 digits we\'ve sent to your email';

  @override
  String get otp_verify_subtitle_phone =>
      'Enter the 6 digits we\'ve sent to your phone';

  @override
  String get otp_verify_change_email => 'Change email';

  @override
  String get otp_verify_change_phone => 'Change phone';

  @override
  String get otp_verify_continue => 'Continue';

  @override
  String get otp_verify_didnt_get => 'Didn\'t get a code? ';

  @override
  String otp_verify_resend_countdown(int seconds) {
    return 'Resend code (${seconds}s)';
  }

  @override
  String get otp_verify_resend => 'Resend code';

  @override
  String get otp_verify_sending => 'Sending...';

  @override
  String get otp_verify_sent_email => 'OTP sent successfully to your email';

  @override
  String get otp_verify_sent_phone => 'OTP sent successfully to your phone';

  @override
  String otp_verify_error_prefix(String error) {
    return 'Error: $error';
  }

  @override
  String get reset_password_title => 'Reset Password';

  @override
  String get reset_password_subtitle =>
      'Create a new password for your account';

  @override
  String get reset_password_new_label => 'New password';

  @override
  String get reset_password_confirm_label => 'Confirm password';

  @override
  String get reset_password_update_btn => 'Update Password';

  @override
  String get reset_password_validate_enter => 'Enter a password';

  @override
  String get reset_password_validate_min => 'Use at least 8 characters';

  @override
  String get reset_password_validate_confirm => 'Re-enter the password';

  @override
  String get reset_password_validate_match => 'Passwords don\'t match';

  @override
  String get set_password_title => 'Create Your Account';

  @override
  String set_password_email_prefix(String email) {
    return 'Email: $email';
  }

  @override
  String get set_password_username_label => 'Username';

  @override
  String get set_password_username_hint => 'Choose a unique username';

  @override
  String get set_password_password_label => 'Password';

  @override
  String get set_password_password_hint => 'Enter a strong password';

  @override
  String get set_password_confirm_label => 'Confirm Password';

  @override
  String get set_password_confirm_hint => 'Re-enter your password';

  @override
  String get set_password_create_btn => 'Create Account';

  @override
  String get set_password_creating_btn => 'Creating account...';

  @override
  String set_password_wait_btn(int seconds) {
    return 'Wait $seconds s';
  }

  @override
  String get set_password_validate_username_required => 'Username is required';

  @override
  String get set_password_validate_username_min =>
      'Username must be at least 3 characters';

  @override
  String get set_password_validate_username_max =>
      'Username must be 20 characters or less';

  @override
  String get set_password_validate_username_chars =>
      'Only letters, numbers, and underscores allowed';

  @override
  String get set_password_validate_username_taken =>
      'Username is already taken';

  @override
  String get set_password_validate_username_checking =>
      'Error checking username';

  @override
  String get set_password_validate_password_required => 'Password is required';

  @override
  String get set_password_validate_password_min =>
      'Password must be at least 6 characters';

  @override
  String get set_password_validate_confirm_required =>
      'Please confirm your password';

  @override
  String get set_password_validate_confirm_match => 'Passwords do not match';

  @override
  String get set_password_wait_validation =>
      'Please wait for username validation';

  @override
  String get set_password_account_exists =>
      'Account already exists. Please sign in with your password.';

  @override
  String get set_password_rate_limit =>
      'Please wait a few seconds before trying again.';

  @override
  String set_password_error_prefix(String error) {
    return 'Error: $error';
  }

  @override
  String get create_info_title => 'Tell us a bit about you';

  @override
  String get create_info_subtitle =>
      'Confirm your age, you have to be 16+ to use dabbler';

  @override
  String get create_info_birth_date => 'Birth Date';

  @override
  String get create_info_birth_date_placeholder => 'Select your birth date';

  @override
  String create_info_age_display(int age) {
    return '$age years old';
  }

  @override
  String get create_info_gender => 'Gender (optional)';

  @override
  String get create_info_continue => 'Continue';

  @override
  String get create_info_error_fill_required =>
      'Please fill in all required fields correctly';

  @override
  String get create_info_error_select_birth => 'Please select your birth date';

  @override
  String get create_info_error_min_age =>
      'You must be at least 16 years old to register';

  @override
  String create_info_error_max_age(int max) {
    return 'Age must be between 16 and $max years';
  }

  @override
  String get create_info_error_select_gender => 'Please select your gender';

  @override
  String create_info_error_occurred(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get set_username_title_onboarding => 'Identify yourself';

  @override
  String get set_username_title_conversion => 'Complete Your Conversion';

  @override
  String get set_username_title_new_profile => 'Complete Your New Profile';

  @override
  String get set_username_subtitle_onboarding =>
      'Choose how others should call you and set a username';

  @override
  String set_username_subtitle_persona(String persona) {
    return 'Choose a display name and username for your $persona profile';
  }

  @override
  String get set_username_display_name_label => 'Display Name';

  @override
  String get set_username_display_name_hint => 'Enter your display name';

  @override
  String get set_username_username_label => 'Username';

  @override
  String get set_username_username_hint => 'Choose a unique username';

  @override
  String get set_username_suggestions => 'Suggestions';

  @override
  String get set_username_btn_complete => 'Complete';

  @override
  String get set_username_btn_create_profile => 'Create Profile';

  @override
  String get set_username_btn_complete_conversion => 'Complete Conversion';

  @override
  String get set_username_back => 'Back';

  @override
  String set_username_converting_to(String persona) {
    return 'Converting to $persona';
  }

  @override
  String set_username_adding_profile(String persona) {
    return 'Adding $persona profile';
  }

  @override
  String get set_username_validate_display_required =>
      'Display name is required';

  @override
  String get set_username_validate_display_min =>
      'Display name must be at least 2 characters';

  @override
  String get set_username_validate_username_required => 'Username is required';

  @override
  String get set_username_validate_username_min =>
      'Username must be at least 3 characters';

  @override
  String get set_username_validate_username_chars =>
      'Only letters, numbers, and underscores';

  @override
  String get set_username_unavailable => 'Username unavailable';

  @override
  String get set_username_check_error => 'Error checking username';

  @override
  String get set_username_missing_onboarding =>
      'Missing onboarding data. Please start over.';

  @override
  String get set_username_missing_steps =>
      'Missing required information. Please complete all steps.';

  @override
  String get set_username_session_expired =>
      'Your session has expired. Please verify your phone number again.';

  @override
  String get set_username_missing_persona_data =>
      'Missing data. Please start over.';

  @override
  String get intent_title => 'What brings you here?';

  @override
  String get intent_subtitle => 'Help us tailor Dabbler';

  @override
  String get intent_compete_title => 'Compete';

  @override
  String get intent_compete_desc =>
      'Join games, track your level, play regularly';

  @override
  String get intent_organise_title => 'Organise';

  @override
  String get intent_organise_desc => 'Create games, set rules, manage players';

  @override
  String get intent_host_title => 'Host';

  @override
  String get intent_host_desc => 'Manage venues, availability, and bookings';

  @override
  String get intent_socialise_title => 'Socialise';

  @override
  String get intent_socialise_desc => 'Follow sports, people, and communities';

  @override
  String get intent_continue => 'Continue';

  @override
  String get intent_back => 'Back';

  @override
  String get intent_select_role => 'Please select your role';

  @override
  String get interests_title_player => 'What do you regularly practice?';

  @override
  String get interests_title_organiser => 'What do you intend to organise?';

  @override
  String get interests_title_host => 'Which sports do you host?';

  @override
  String get interests_title_socialiser =>
      'Which sports are you interested in?';

  @override
  String get interests_title_default => 'What do you regularly practice?';

  @override
  String get interests_subtitle => 'You can change and add more sports later';

  @override
  String get interests_available_sports => 'Available sports';

  @override
  String interests_selected_count_one(int count) {
    return '$count sport selected';
  }

  @override
  String interests_selected_count_many(int count) {
    return '$count sports selected';
  }

  @override
  String get interests_continue => 'Continue';

  @override
  String get interests_back => 'Back';

  @override
  String get interests_cancel => 'Cancel';

  @override
  String get interests_select_one => 'Please select at least one sport';

  @override
  String get interests_failed_load => 'Failed to load sports';

  @override
  String get interests_retry => 'Retry';

  @override
  String get primary_sport_title => 'Choose your primary sport';

  @override
  String get primary_sport_subtitle =>
      'This sport will appear on your profile and be used by default.';

  @override
  String get primary_sport_helper => 'You can change it later.';

  @override
  String get primary_sport_badge => 'Primary';

  @override
  String get primary_sport_continue => 'Continue';

  @override
  String get primary_sport_back => 'Back';

  @override
  String get primary_sport_cancel => 'Cancel';

  @override
  String get primary_sport_select_error => 'Please select your primary sport';

  @override
  String get primary_sport_failed_load => 'Failed to load sports';

  @override
  String get primary_sport_no_sports => 'No sports selected. Please go back.';

  @override
  String get onb_back => 'Back';

  @override
  String get onb_continue => 'Continue';

  @override
  String onb_step_label(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onb_dob_title => 'Tell us a bit about you';

  @override
  String get onb_dob_subtitle =>
      'Your age keeps games and communities age-appropriate. It stays off your profile.';

  @override
  String get onb_dob_label => 'Date of birth';

  @override
  String get onb_dob_placeholder => 'Select your date of birth';

  @override
  String get onb_dob_helper_min => 'You need to be 16 or over to use Dabbler.';

  @override
  String onb_dob_helper_ok(int age) {
    return 'Age $age. You are all set.';
  }

  @override
  String get onb_dob_error_min => 'You need to be 16 or over.';

  @override
  String onb_dob_error_max(int max) {
    return 'Age must be between 16 and $max.';
  }

  @override
  String get onb_gender_label => 'Gender (optional)';

  @override
  String get onb_gender_male => 'Male';

  @override
  String get onb_gender_female => 'Female';

  @override
  String get onb_dob_sheet_confirm => 'Confirm';

  @override
  String get onb_dob_sheet_cancel => 'Cancel';

  @override
  String get onb_day => 'Day';

  @override
  String get onb_month => 'Month';

  @override
  String get onb_year => 'Year';

  @override
  String get onb_month_1 => 'January';

  @override
  String get onb_month_2 => 'February';

  @override
  String get onb_month_3 => 'March';

  @override
  String get onb_month_4 => 'April';

  @override
  String get onb_month_5 => 'May';

  @override
  String get onb_month_6 => 'June';

  @override
  String get onb_month_7 => 'July';

  @override
  String get onb_month_8 => 'August';

  @override
  String get onb_month_9 => 'September';

  @override
  String get onb_month_10 => 'October';

  @override
  String get onb_month_11 => 'November';

  @override
  String get onb_month_12 => 'December';

  @override
  String get onb_persona_title => 'Why are you here?';

  @override
  String get onb_persona_subtitle =>
      'Pick the one that fits best today. You can add another later.';

  @override
  String get onb_persona_footnote =>
      'You can add another way to use Dabbler later in settings.';

  @override
  String get onb_persona_socialiser_name => 'Socialiser';

  @override
  String get onb_persona_socialiser_hook => 'Find your people';

  @override
  String get onb_persona_socialiser_body =>
      'Follow sports, discover communities, and stay in the loop.';

  @override
  String get onb_sports_title_socialiser => 'What are you into?';

  @override
  String get onb_sports_subtitle_socialiser =>
      'Pick the sports you want to see more of.';

  @override
  String get onb_primary_title_socialiser => 'What is your favourite sport?';

  @override
  String get onb_primary_subtitle_socialiser =>
      'We will show more communities, people and activity around it.';

  @override
  String get onb_persona_player_name => 'Player';

  @override
  String get onb_persona_player_hook => 'Get in the game';

  @override
  String get onb_persona_player_body =>
      'Join matches, build your level, and play more often.';

  @override
  String get onb_sports_title_player => 'What do you play?';

  @override
  String get onb_sports_subtitle_player =>
      'Pick the sports you’re into. You can change these anytime.';

  @override
  String get onb_primary_title_player => 'What’s your go-to sport?';

  @override
  String get onb_primary_subtitle_player =>
      'We’ll make it your default and build your main sport profile around it.';

  @override
  String get onb_persona_organiser_name => 'Organiser';

  @override
  String get onb_persona_organiser_hook => 'Bring the game together';

  @override
  String get onb_persona_organiser_body =>
      'Create sessions, manage players, and keep everything organised.';

  @override
  String get onb_sports_title_organiser => 'What do you organise?';

  @override
  String get onb_sports_subtitle_organiser =>
      'Choose the sports you usually create games for.';

  @override
  String get onb_primary_title_organiser => 'What do you organise most?';

  @override
  String get onb_primary_subtitle_organiser =>
      'We’ll use it as the default when you create games and events.';

  @override
  String get onb_persona_host_name => 'Host';

  @override
  String get onb_persona_host_hook => 'Fill your venue';

  @override
  String get onb_persona_host_body =>
      'Show your spaces, reach players, and manage bookings.';

  @override
  String get onb_sports_title_host => 'What can people play at your venue?';

  @override
  String get onb_sports_subtitle_host =>
      'Select the sports your spaces can host.';

  @override
  String get onb_primary_title_host => 'What’s your venue known for?';

  @override
  String get onb_primary_subtitle_host =>
      'We’ll make it the primary sport on your venue profile.';

  @override
  String get onb_sports_search => 'Search sports';

  @override
  String get onb_sports_none => 'Nothing matches that. Try another name.';

  @override
  String get onb_sports_count_zero => 'Pick at least one to continue.';

  @override
  String get onb_sports_count_one => '1 sport selected';

  @override
  String onb_sports_count_many(int count) {
    return '$count sports selected';
  }

  @override
  String get onb_primary_more => 'Add more sports';

  @override
  String get onb_identity_title => 'What should people call you?';

  @override
  String get onb_identity_subtitle =>
      'Set the name and username people will see around Dabbler.';

  @override
  String get onb_display_name_label => 'Display name';

  @override
  String get onb_display_name_helper =>
      'This is the name people see around Dabbler.';

  @override
  String get onb_suggestions => 'Suggestions';

  @override
  String get onb_username_label => 'Username';

  @override
  String get onb_username_placeholder => '@yourname';

  @override
  String get onb_username_helper => 'Letters, numbers and underscores.';

  @override
  String get onb_username_short => 'A username needs at least 3 characters.';

  @override
  String get onb_username_invalid => 'Letters, numbers and underscores only.';

  @override
  String get onb_username_checking => 'Checking availability…';

  @override
  String get onb_username_taken => 'That one is taken. Try another.';

  @override
  String get onb_username_available => 'Available — this one is yours.';

  @override
  String get onb_username_check_error =>
      'We could not check that username. Try again.';

  @override
  String get onb_create_account => 'Create my account';

  @override
  String get onb_setup_title => 'Setting up your account';

  @override
  String get onb_setup_subtitle => 'This only takes a moment.';

  @override
  String get onb_setup_stage_profile => 'Creating your profile';

  @override
  String get onb_setup_failed_title => 'Setup did not finish';

  @override
  String primary_sport_adding(String label) {
    return 'Adding $label Profile';
  }

  @override
  String get identity_verify_title => 'Identity verification';

  @override
  String get identity_verify_email_label => 'Email address';

  @override
  String get identity_verify_email_hint => 'Enter your email address';

  @override
  String get identity_verify_continue_sending => 'Sending...';

  @override
  String get identity_verify_continue => 'Continue';

  @override
  String get identity_verify_or => 'or';

  @override
  String get identity_verify_google_btn => 'Continue with Google';

  @override
  String get identity_verify_terms_prefix => 'By continuing, you agree to our ';

  @override
  String get identity_verify_terms_link => 'Terms of Service';

  @override
  String get identity_verify_terms_and => ' and ';

  @override
  String get identity_verify_privacy_link => 'Privacy Policy';

  @override
  String get identity_verify_otp_sent_email =>
      'OTP sent! Please check your email.';

  @override
  String get identity_verify_otp_sent_phone =>
      'OTP sent! Please check your phone.';

  @override
  String get identity_verify_phone_disabled =>
      'Phone authentication is not available yet. Please use email to continue.';

  @override
  String identity_verify_service_error(String error) {
    return 'Service error: $error';
  }

  @override
  String get identity_verify_error_generic =>
      'Failed to send OTP. Please try again.';

  @override
  String identity_verify_nav_failed(String error) {
    return 'Navigation failed: $error';
  }

  @override
  String get identity_verify_use_email => 'Please use your email address';

  @override
  String get identity_verify_required => 'Email or phone number is required';

  @override
  String get identity_verify_google_failed =>
      'Google sign-in failed. Please try again.';

  @override
  String get welcome_screen_title_first_time => 'Welcome to Dabbler 😉';

  @override
  String get welcome_screen_title_returning => 'Welcome Back! 👋';

  @override
  String get welcome_screen_title_conversion => 'Conversion Complete! 🎉';

  @override
  String get welcome_screen_dont_forget => 'Don\'t forget';

  @override
  String get welcome_screen_continue => 'Continue';

  @override
  String get welcome_screen_chip_player => 'Sports player';

  @override
  String get welcome_screen_chip_organiser => 'Games organiser';

  @override
  String get welcome_screen_chip_host => 'Venue host';

  @override
  String get welcome_screen_chip_socialiser => 'Sports socialiser';

  @override
  String get welcome_screen_player_guidance =>
      'Join games that match your level, respect the rules set by the organiser, and confirm only when you\'re ready to play.';

  @override
  String get welcome_screen_player_philosophy =>
      'Your reliability builds your reputation.';

  @override
  String get welcome_screen_player_reminder =>
      'Confirm only when you\'re sure you can play.\nRespect the rules, timing, and other players.';

  @override
  String get welcome_screen_player_emphasis =>
      'Confirm only when you\'re ready to play';

  @override
  String get welcome_screen_organiser_guidance =>
      'Create games with clear rules, fair skill levels, and realistic timings.';

  @override
  String get welcome_screen_organiser_philosophy =>
      'You set the tone — great games start with great organisation.';

  @override
  String get welcome_screen_organiser_reminder =>
      'Set clear rules and realistic timings.\nCommunicate changes early and clearly.';

  @override
  String get welcome_screen_organiser_emphasis =>
      'Continue only when you\'re ready!';

  @override
  String get welcome_screen_host_guidance =>
      'Help players feel welcome by keeping information accurate and spaces ready.';

  @override
  String get welcome_screen_host_philosophy =>
      'Clear availability and smooth coordination make everyone\'s experience better.';

  @override
  String get welcome_screen_host_reminder =>
      'Keep availability and details accurate.\nUpdate information as soon as things change.';

  @override
  String get welcome_screen_host_emphasis =>
      'Continue only when you\'re ready!';

  @override
  String get welcome_screen_socialiser_guidance =>
      'Connect with players, spark conversations, and help games feel more human.';

  @override
  String get welcome_screen_socialiser_philosophy =>
      'Your presence shapes the community — friendly, inclusive, and respectful.';

  @override
  String get welcome_screen_socialiser_reminder =>
      'Be respectful and inclusive.\nAdd value without disrupting the game.';

  @override
  String get welcome_screen_socialiser_emphasis =>
      'Continue only when you\'re ready!';

  @override
  String get onboarding_welcome_title => 'Setting up your account';

  @override
  String get onboarding_welcome_subtitle => 'This only takes a moment…';

  @override
  String get onboarding_welcome_step_profile => 'Creating your profile';

  @override
  String get social_onboarding_welcome_title => 'Welcome to Social';

  @override
  String get social_onboarding_welcome_subtitle =>
      'Connect with fellow players, share your game experiences, and build your sports community.';

  @override
  String get social_onboarding_welcome_skip => 'Skip';

  @override
  String get social_onboarding_welcome_get_started => 'Get Started';

  @override
  String get social_onboarding_welcome_find_friends_title => 'Find Friends';

  @override
  String get social_onboarding_welcome_find_friends_desc =>
      'Connect with players in your area';

  @override
  String get social_onboarding_welcome_chat_title => 'Chat & Share';

  @override
  String get social_onboarding_welcome_chat_desc =>
      'Message friends and share game moments';

  @override
  String get social_onboarding_welcome_game_title => 'Game Together';

  @override
  String get social_onboarding_welcome_game_desc =>
      'Discover and join games with your network';

  @override
  String get social_onboarding_friends_appbar => 'Find Friends';

  @override
  String get social_onboarding_friends_title => 'Find Your Sports Community';

  @override
  String get social_onboarding_friends_subtitle =>
      'Connect with friends to share game experiences and discover new opportunities.';

  @override
  String get social_onboarding_friends_sync_btn => 'Sync Contacts';

  @override
  String get social_onboarding_friends_syncing => 'Syncing...';

  @override
  String get social_onboarding_friends_or => 'or';

  @override
  String get social_onboarding_friends_suggested => 'Suggested for You';

  @override
  String social_onboarding_friends_selected(int count) {
    return '$count selected';
  }

  @override
  String social_onboarding_friends_mutual_one(int count) {
    return '$count mutual friend';
  }

  @override
  String social_onboarding_friends_mutual_many(int count) {
    return '$count mutual friends';
  }

  @override
  String get social_onboarding_friends_add_btn => 'Add';

  @override
  String get social_onboarding_friends_added => 'Added';

  @override
  String get social_onboarding_friends_skip => 'Skip';

  @override
  String get social_onboarding_friends_continue => 'Continue';

  @override
  String social_onboarding_friends_send_requests(int count) {
    return 'Send $count Requests & Continue';
  }

  @override
  String get social_onboarding_friends_send_request =>
      'Send Request & Continue';

  @override
  String get social_onboarding_friends_synced =>
      'Contacts synced successfully!';

  @override
  String get social_onboarding_friends_sync_error =>
      'Error accessing contacts. Please try again.';

  @override
  String social_onboarding_friends_sent(int count) {
    return 'Friend requests sent to $count people!';
  }

  @override
  String get social_onboarding_notif_appbar => 'Notifications';

  @override
  String get social_onboarding_notif_title => 'Notifications Paused';

  @override
  String get social_onboarding_notif_body =>
      'We\'re rebuilding notification preferences. You can finish onboarding now and we\'ll add configuration options in a future update.';

  @override
  String get social_onboarding_notif_finish => 'Finish';

  @override
  String get social_onboarding_privacy_appbar => 'Privacy Settings';

  @override
  String get social_onboarding_privacy_title => 'Privacy & Safety';

  @override
  String get social_onboarding_privacy_subtitle =>
      'Control who can see your profile and interact with you. You can always change these settings later.';

  @override
  String get social_onboarding_privacy_step => '3 of 4';

  @override
  String get social_onboarding_privacy_profile_visible_title =>
      'Profile Visible to Friends';

  @override
  String get social_onboarding_privacy_profile_visible_subtitle =>
      'Your profile is visible to your friends';

  @override
  String get social_onboarding_privacy_posts_public_title =>
      'Posts Visible to Public';

  @override
  String get social_onboarding_privacy_posts_public_subtitle =>
      'Anyone can see your posts';

  @override
  String get social_onboarding_privacy_allow_requests_title =>
      'Allow Friend Requests';

  @override
  String get social_onboarding_privacy_allow_requests_subtitle =>
      'People can send you friend requests';

  @override
  String get social_onboarding_privacy_allow_messages_title =>
      'Allow Message Requests';

  @override
  String get social_onboarding_privacy_allow_messages_subtitle =>
      'Non-friends can send you messages';

  @override
  String get social_onboarding_privacy_online_status_title =>
      'Show Online Status';

  @override
  String get social_onboarding_privacy_online_status_subtitle =>
      'Friends can see when you\'re online';

  @override
  String get social_onboarding_privacy_back => 'Back';

  @override
  String get social_onboarding_privacy_continue => 'Continue';

  @override
  String get social_onboarding_complete_title => 'Welcome to Social!';

  @override
  String get social_onboarding_complete_subtitle =>
      'You\'re all set up! Start connecting with friends, sharing your game experiences, and discovering new players in your area.';

  @override
  String get social_onboarding_complete_connect_title => 'Connect with Players';

  @override
  String get social_onboarding_complete_connect_desc =>
      'Find and add friends who love the same sports';

  @override
  String get social_onboarding_complete_share_title => 'Share Your Journey';

  @override
  String get social_onboarding_complete_share_desc =>
      'Post updates, photos, and celebrate your wins';

  @override
  String get social_onboarding_complete_discover_title => 'Discover Games';

  @override
  String get social_onboarding_complete_discover_desc =>
      'See what games your friends are playing';

  @override
  String get social_onboarding_complete_explore_btn => 'Explore Social';

  @override
  String get social_onboarding_complete_home_btn => 'Go to Home';

  @override
  String get social_onboarding_complete_later => 'I\'ll explore later';

  @override
  String get language_select_title => 'Select Language';

  @override
  String get language_select_saving => 'Saving...';

  @override
  String get register_title => 'Register';

  @override
  String get register_btn => 'Register';

  @override
  String get post_card_author_anonymous => 'Anonymous';

  @override
  String get post_card_user_fallback => 'User';

  @override
  String get post_card_persona_organiser => 'Organiser';

  @override
  String get post_card_persona_player => 'Player';

  @override
  String get post_card_near_you => 'Near you';

  @override
  String get post_card_edited => 'edited';

  @override
  String get post_card_menu_repost => 'Repost';

  @override
  String get post_card_menu_quote_repost => 'Quote Repost';

  @override
  String get post_card_kind_moment => 'Moment';

  @override
  String get post_card_kind_dab => 'Dab';

  @override
  String get post_card_kind_kick_in => 'Kick-in';

  @override
  String get post_card_kind_game => 'Game';

  @override
  String get post_card_kind_achievement => 'Achievement';

  @override
  String get post_card_kind_venue => 'Venue';

  @override
  String get post_card_kind_admin => 'Admin';

  @override
  String get post_card_kind_system => 'System';

  @override
  String get post_card_kind_repost => 'Repost';

  @override
  String get post_card_expired => 'Expired';

  @override
  String post_card_expires_in_days(int n) {
    return 'Expires in ${n}d';
  }

  @override
  String post_card_expires_in_hours(int n) {
    return 'Expires in ${n}h';
  }

  @override
  String post_card_expires_in_minutes(int n) {
    return 'Expires in ${n}m';
  }

  @override
  String get post_card_expiring_soon => 'Expiring soon';

  @override
  String get repost_card_unavailable => 'Original post is no longer available.';

  @override
  String get post_type_original => 'Original';

  @override
  String get post_type_news => 'News';

  @override
  String get post_type_announcement => 'Announcement';

  @override
  String get post_type_alert => 'Alert';

  @override
  String get post_type_highlight => 'Highlight';

  @override
  String get post_type_general => 'General';

  @override
  String get post_type_feature => 'Feature';

  @override
  String get post_card_my_story => 'My Story';

  @override
  String get post_card_kick_in_label => 'Kick-In';

  @override
  String get post_card_allocated => 'Allocated';

  @override
  String get nav_feeds => 'Feeds';

  @override
  String get nav_community => 'Community';

  @override
  String get nav_venues => 'Venues';

  @override
  String get nav_games => 'Games';

  @override
  String get nav_meetups => 'Meetups';

  @override
  String get nav_create_post => 'Create post';

  @override
  String get nav_create_game => 'Create game';

  @override
  String get nav_create_meetup => 'Create meetup';

  @override
  String get nav_meetups_coming_soon => 'Meetups coming soon!';

  @override
  String get nav_exit_app_title => 'Exit app?';

  @override
  String get nav_exit_app_body => 'Are you sure you want to exit Dabbler?';

  @override
  String get nav_exit_app_cancel => 'Cancel';

  @override
  String get nav_exit_app_confirm => 'Exit';

  @override
  String get nav_press_back_to_exit => 'Press back again to exit';

  @override
  String get nav_search_hint => 'Search Dabbler';

  @override
  String get nav_whats_happening => 'What\'s happening';

  @override
  String get nav_trend_sports_category => 'Sports';

  @override
  String get nav_trend_sports_title => 'New games near you';

  @override
  String get nav_trend_sports_subtitle =>
      'Check out the latest games in your area';

  @override
  String get nav_trend_community_category => 'Community';

  @override
  String get nav_trend_community_title => 'Growing squads';

  @override
  String get nav_trend_community_subtitle => 'Join a squad to play regularly';

  @override
  String get nav_trend_dabbler_category => 'Dabbler';

  @override
  String get nav_trend_dabbler_title => 'Share your moments';

  @override
  String get nav_trend_dabbler_subtitle =>
      'Post updates and connect with players';

  @override
  String get nav_quick_actions => 'Quick actions';

  @override
  String get nav_find_friends => 'Find friends';

  @override
  String get nav_settings => 'Settings';

  @override
  String get settings_header_title => 'Settings';

  @override
  String get settings_header_help_tooltip => 'Help center';

  @override
  String get settings_hero_eyebrow => 'Customize your experience';

  @override
  String get settings_hero_title => 'Tune Dabbler to match how you play';

  @override
  String get settings_hero_subtitle =>
      'Manage your account, preferences, and notifications all in one place.';

  @override
  String get settings_search_hint => 'Search settings';

  @override
  String get settings_section_account => 'Account';

  @override
  String get settings_section_display => 'Display';

  @override
  String get settings_section_about => 'About';

  @override
  String get settings_section_profiles => 'Profiles';

  @override
  String get settings_item_account_management_title => 'Account Management';

  @override
  String get settings_item_account_management_subtitle =>
      'Email, password, security';

  @override
  String get settings_item_privacy_settings_title => 'Privacy Settings';

  @override
  String get settings_item_privacy_settings_subtitle =>
      'Manage privacy settings and blocked users';

  @override
  String get settings_item_theme_title => 'Theme';

  @override
  String get settings_item_theme_subtitle => 'Light, dark, or system default';

  @override
  String get settings_item_language_title => 'Language';

  @override
  String get settings_item_country_title => 'App Country';

  @override
  String get settings_item_country_default_subtitle =>
      'Egypt · UAE · KSA · Morocco';

  @override
  String get settings_country_picker_helper =>
      'Sets which sports and venues you see';

  @override
  String get settings_item_terms_title => 'Terms of Service';

  @override
  String get settings_item_terms_subtitle => 'Read our terms and conditions';

  @override
  String get settings_item_privacy_policy_title => 'Privacy Policy';

  @override
  String get settings_item_privacy_policy_subtitle => 'How we handle your data';

  @override
  String get settings_item_licenses_title => 'Licenses';

  @override
  String get settings_item_licenses_subtitle => 'Open source licenses';

  @override
  String get settings_sign_out_title => 'Sign out';

  @override
  String get settings_sign_out_subtitle => 'Leave your account on this device';

  @override
  String get settings_sign_out_dialog_title => 'Sign Out';

  @override
  String get settings_sign_out_dialog_body =>
      'Are you sure you want to sign out of your account?';

  @override
  String get settings_sign_out_dialog_cancel => 'Cancel';

  @override
  String settings_sign_out_error(String error) {
    return 'Error signing out: $error';
  }

  @override
  String get account_delete_dialog_warning =>
      'This action cannot be undone. Your profile and personal data are deleted. Payment and booking records are retained for accounting purposes, for a period that is still being finalized.';

  @override
  String get account_delete_success_snack =>
      'Your account and personal data have been deleted.';

  @override
  String get danger_zone_delete_confirmation_message =>
      'This deletes your account and personal data and cannot be undone. Payment and booking records are retained for accounting purposes, for a period that is still being finalized.';

  @override
  String get settings_version_app_name => 'Dabbler';

  @override
  String settings_version_label(String version) {
    return 'Version $version';
  }

  @override
  String get settings_tile_privacy => 'Privacy';

  @override
  String get settings_tile_profile_shown => 'Shown on your profile';

  @override
  String get settings_tile_notifications => 'Notifications';

  @override
  String get settings_tile_appearance => 'Appearance';

  @override
  String get settings_tile_language_region => 'Language & region';

  @override
  String get settings_tile_activity_shown => 'Activity & stats shown';

  @override
  String get settings_tile_blocked => 'Blocked accounts';

  @override
  String get settings_tile_privacy_label => 'Privacy settings';

  @override
  String get settings_version_copyright =>
      '© 2026 Dabbler. All rights reserved.';

  @override
  String settings_persona_become_title(String persona) {
    return 'Become a $persona';
  }

  @override
  String settings_persona_convert_title(String persona) {
    return 'Convert to $persona';
  }

  @override
  String settings_persona_convert_subtitle(String persona) {
    return 'Replace your $persona profile';
  }

  @override
  String settings_persona_convert_confirm_body(
    String fromPersona,
    String toPersona,
  ) {
    return 'This will deactivate your $fromPersona profile and create a new $toPersona profile.\n\nYour account data (age, gender) will be preserved.';
  }

  @override
  String get persona_label_host => 'Host';

  @override
  String get persona_label_socialiser => 'Socialiser';

  @override
  String get profile_header_fallback => 'Profile';

  @override
  String get profile_section_sports => 'Sports';

  @override
  String get profile_complete_your_profile => 'Complete your profile';

  @override
  String get profile_bio_placeholder =>
      'Add a short bio so teammates know what to expect.';

  @override
  String get settings_item_edit_profile_subtitle =>
      'Name, photo, bio and sports';

  @override
  String get profile_btn_edit => 'Edit profile';

  @override
  String get profile_btn_share => 'Share profile';

  @override
  String get profile_btn_manage_profiles_tooltip => 'Manage profiles';

  @override
  String get profile_manage_profiles_title => 'Switch profile';

  @override
  String get profile_add_profile => 'Add Profile';

  @override
  String get profile_no_profiles_found => 'No profiles found';

  @override
  String get profile_error_loading_profiles => 'Error loading profiles';

  @override
  String get profile_error_switch_profile_failed => 'Failed to switch profile';

  @override
  String get profile_btn_cancel => 'Cancel';

  @override
  String get profile_btn_continue => 'Continue';

  @override
  String get profile_persona_convert_badge => 'Convert';

  @override
  String profile_convert_to(String persona) {
    return 'Convert to $persona?';
  }

  @override
  String profile_convert_confirm_body(String fromPersona, String toPersona) {
    return 'You\'re about to convert from $fromPersona to $toPersona. Your current profile will be replaced.';
  }

  @override
  String get profile_tab_posts => 'Posts';

  @override
  String get profile_tab_replies => 'Replies';

  @override
  String get profile_tab_liked => 'Liked';

  @override
  String get profile_tab_reposts => 'Reposts';

  @override
  String get profile_tab_activity => 'Activity';

  @override
  String get profile_empty_no_activity => 'No activity yet';

  @override
  String get profile_empty_no_posts => 'No posts yet';

  @override
  String get profile_empty_no_replies => 'No replies yet';

  @override
  String get profile_empty_no_liked => 'No liked posts yet';

  @override
  String get profile_empty_no_reposts => 'No reposts yet';

  @override
  String get profile_empty_no_sports => 'No sports added yet';

  @override
  String get profile_error_failed_load_posts => 'Failed to load posts.';

  @override
  String profile_post_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posts',
      one: 'Post',
    );
    return '$_temp0';
  }

  @override
  String profile_follower_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Followers',
      one: 'Follower',
    );
    return '$_temp0';
  }

  @override
  String get profile_following_label => 'Following';

  @override
  String get profile_takedown_title => 'Content Removed';

  @override
  String get profile_takedown_body =>
      'This content has been removed due to a violation of our community guidelines.';

  @override
  String get user_profile_error_not_found_title => 'Profile not found';

  @override
  String get user_profile_error_unable_to_load => 'Unable to load profile';

  @override
  String get user_profile_btn_go_back => 'Go back';

  @override
  String get user_profile_btn_loading => 'Loading';

  @override
  String get user_profile_btn_unblock => 'Unblock';

  @override
  String get user_profile_btn_follow => 'Follow';

  @override
  String get user_profile_btn_following => 'Following';

  @override
  String get user_profile_age_suffix => 'Yo';

  @override
  String get user_profile_stat_games => 'Games played';

  @override
  String get user_profile_stat_win_rate => 'Win rate';

  @override
  String get user_profile_stat_sports => 'Sports played';

  @override
  String get user_profile_stat_reliability => 'Reliability';

  @override
  String get user_profile_stat_activity => 'Activity';

  @override
  String get user_profile_stat_last_play => 'Last play';

  @override
  String get user_profile_block_dialog_title => 'Block User';

  @override
  String get user_profile_block_dialog_body =>
      'Are you sure you want to block this user? They won\'t be able to see your profile or contact you.';

  @override
  String get user_profile_block_btn_block => 'Block';

  @override
  String get user_profile_blocked_snack => 'User blocked';

  @override
  String get user_profile_unblocked_snack => 'User unblocked';

  @override
  String get user_profile_menu_unblock_user => 'Unblock user';

  @override
  String get user_profile_menu_block_user => 'Block user';

  @override
  String get user_profile_menu_report_user => 'Report user';

  @override
  String get user_profile_cannot_message_blocked =>
      'Cannot message a blocked user';

  @override
  String get notif_signin_required => 'Please sign in to view notifications';

  @override
  String get notif_title_notifications => 'Notifications';

  @override
  String get notif_title_activity_log => 'Activity log';

  @override
  String get notif_chip_all => 'All';

  @override
  String get notif_chip_games => 'Games';

  @override
  String get notif_chip_bookings => 'Bookings';

  @override
  String get notif_chip_social => 'Social';

  @override
  String get notif_chip_achievements => 'Achievements';

  @override
  String get notif_chip_you => 'You';

  @override
  String get notif_chip_rewards => 'Rewards';

  @override
  String get notif_chip_security => 'Security';

  @override
  String get notif_section_today => 'Today';

  @override
  String get notif_section_yesterday => 'Yesterday';

  @override
  String get notif_section_earlier => 'Earlier';

  @override
  String get notif_mark_all_read => 'Mark all read';

  @override
  String get notif_action_respond => 'Respond';

  @override
  String get notif_action_follow_back => 'Follow back';

  @override
  String get notif_action_view => 'View';

  @override
  String get notif_action_see_circle => 'See circle';

  @override
  String get notif_load_older => 'Load older';

  @override
  String get notif_empty_no_notifications => 'No notifications yet';

  @override
  String get notif_empty_subtitle => 'We\'ll notify you when something happens';

  @override
  String get notif_btn_retry => 'Retry';

  @override
  String notif_error_prefix(String message) {
    return 'Error: $message';
  }

  @override
  String get activity_last_7_days => 'LAST 7 DAYS';

  @override
  String get activity_search_hint => 'Search activity…';

  @override
  String get activity_pill_upcoming => 'Upcoming';

  @override
  String get activity_pill_live => 'Live';

  @override
  String get activity_subject_reward => 'Reward';

  @override
  String get activity_subject_security => 'Security';

  @override
  String get activity_all_normal_title => 'All activity looks normal';

  @override
  String get activity_all_normal_body =>
      'No unusual sign-ins or device changes in the past 30 days. ';

  @override
  String get activity_manage_devices => 'Manage devices →';

  @override
  String get activity_empty_no_activity => 'No activity yet';

  @override
  String get activity_empty_subtitle => 'Your activity will appear here';

  @override
  String get activity_day_streak => 'day streak';

  @override
  String activity_participants_count(int count) {
    return '$count participants';
  }

  @override
  String get time_just_now => 'Just now';

  @override
  String time_minutes_ago(int n) {
    return '${n}m ago';
  }

  @override
  String time_hours_ago(int n) {
    return '${n}h ago';
  }

  @override
  String time_days_ago(int n) {
    return '${n}d ago';
  }

  @override
  String notif_kind_friend_requested(String actor) {
    return '$actor sent you a friend request';
  }

  @override
  String get notif_kind_friend_requested_anon =>
      'You have a new friend request';

  @override
  String notif_kind_friend_accepted(String actor) {
    return '$actor accepted your friend request';
  }

  @override
  String get notif_kind_friend_accepted_anon =>
      'Your friend request was accepted';

  @override
  String notif_kind_social_followed(String actor) {
    return '$actor started following you';
  }

  @override
  String get notif_kind_social_followed_anon => 'You have a new follower';

  @override
  String notif_kind_social_circle_joined(String actor) {
    return '$actor joined your circle';
  }

  @override
  String get notif_kind_social_circle_joined_anon =>
      'Someone joined your circle';

  @override
  String notif_kind_social_post_liked(String actor) {
    return '$actor liked your post';
  }

  @override
  String get notif_kind_social_post_liked_anon => 'Someone liked your post';

  @override
  String notif_kind_social_post_commented(String actor) {
    return '$actor commented on your post';
  }

  @override
  String get notif_kind_social_post_commented_anon =>
      'New comment on your post';

  @override
  String notif_kind_social_comment_liked(String actor) {
    return '$actor liked your comment';
  }

  @override
  String get notif_kind_social_comment_liked_anon =>
      'Someone liked your comment';

  @override
  String notif_kind_social_mentioned(String actor) {
    return '$actor mentioned you';
  }

  @override
  String get notif_kind_social_mentioned_anon => 'You were mentioned';

  @override
  String notif_kind_game_invited(String actor) {
    return '$actor invited you to a game';
  }

  @override
  String get notif_kind_game_invited_anon => 'You have a new game invite';

  @override
  String get notif_kind_game_updated => 'Game details updated';

  @override
  String notif_kind_game_join_request(String actor) {
    return '$actor requested to join your game';
  }

  @override
  String get notif_kind_game_join_request_anon =>
      'Someone requested to join your game';

  @override
  String get notif_kind_game_waitlist_promoted =>
      'You\'re in! A spot opened up';

  @override
  String get notif_kind_game_reminder => 'Game reminder';

  @override
  String get notif_kind_arena_payment_required =>
      'Payment required for your booking';

  @override
  String get notif_kind_reward_badge_awarded => 'You earned a new badge';

  @override
  String get notif_kind_achievement_earned => 'You unlocked a new achievement';

  @override
  String get settings_identity_subtitle => 'Account, password & security';

  @override
  String get settings_tile_privacy_preset => 'Privacy preset';

  @override
  String get settings_preset_public => 'Public';

  @override
  String get settings_preset_friends => 'Friends only';

  @override
  String get settings_preset_private => 'Private';

  @override
  String get settings_theme_light => 'Light';

  @override
  String get settings_theme_dark => 'Dark';

  @override
  String get settings_theme_system => 'System';

  @override
  String get settings_country_short_eg => 'Egypt';

  @override
  String get settings_country_short_ae => 'UAE';

  @override
  String get settings_country_short_sa => 'Saudi';

  @override
  String get settings_country_short_ma => 'Morocco';

  @override
  String get settings_organiser_title => 'Become an organiser';

  @override
  String get settings_organiser_subtitle => 'Create and manage sports events';

  @override
  String get settings_organiser_info_body =>
      'Organisers create games, set venues and prices, and manage who joins. Setting one up takes a few minutes and you keep your player profile.';

  @override
  String get settings_organiser_start => 'Start setup';

  @override
  String get settings_about_title => 'About Dabbler';

  @override
  String get settings_about_subtitle => 'Terms, privacy policy, licenses';

  @override
  String settings_search_results(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get settings_search_no_match => 'No settings match that';

  @override
  String get settings_path_account => 'Account & security';

  @override
  String get settings_path_privacy => 'Privacy';

  @override
  String get settings_path_privacy_safety => 'Privacy › Safety';

  @override
  String get settings_path_appearance => 'Appearance';

  @override
  String get settings_path_profiles => 'Settings › Profiles';

  @override
  String get settings_path_root => 'Settings';

  @override
  String get settings_sign_out_confirm_body =>
      'You will be signed out on this device. Your games and profile stay on your account.';

  @override
  String notif_group_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get notif_prefs_title => 'What reaches you';

  @override
  String get notif_prefs_done => 'Done';

  @override
  String get notif_pref_invites_title => 'Game invites';

  @override
  String get notif_pref_invites_sub => 'When someone adds you to a game';

  @override
  String get notif_pref_waitlist_title => 'Waitlist spots';

  @override
  String get notif_pref_waitlist_sub => 'The moment a place frees up';

  @override
  String get notif_pref_payments_title => 'Payments and splits';

  @override
  String get notif_pref_payments_sub => 'Requests, receipts, refunds';

  @override
  String get notif_pref_social_title => 'Social activity';

  @override
  String get notif_pref_social_sub => 'Follows, replies, mentions';

  @override
  String get notif_quiet_hours_title => 'Quiet hours';

  @override
  String get notif_quiet_hours_sub => 'Nothing buzzes between these times';

  @override
  String get notif_quiet_hours_off => 'Off';

  @override
  String notif_quiet_hours_range(String start, String end) {
    return '$start – $end';
  }

  @override
  String get acct_title => 'Account';

  @override
  String get acct_group_signin => 'Sign-in';

  @override
  String get acct_row_email => 'Email address';

  @override
  String get acct_row_password => 'Password';

  @override
  String get acct_group_security => 'Security';

  @override
  String get acct_group_security_note =>
      'Protect your account with additional security measures';

  @override
  String get acct_2fa_title => 'Two-factor authentication';

  @override
  String get acct_2fa_sub => 'Add an extra layer of security';

  @override
  String get acct_alerts_title => 'Login alerts';

  @override
  String get acct_alerts_sub => 'Get notified of new sign-ins';

  @override
  String get acct_group_danger => 'Danger zone';

  @override
  String get acct_delete_title => 'Delete account';

  @override
  String get acct_delete_sub => 'Permanently delete your account and all data';

  @override
  String get acct_delete_body =>
      'This permanently deletes your account and all data, including games, stats and messages. It cannot be undone.';

  @override
  String get acct_delete_confirm => 'Delete permanently';

  @override
  String get acct_cancel => 'Cancel';

  @override
  String get acct_delete_type_error => 'Please type \"DELETE\" to confirm';

  @override
  String acct_delete_failed(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get acct_email_sheet_title => 'Email address';

  @override
  String get acct_email_field => 'Email';

  @override
  String get acct_email_helper =>
      'We send a confirmation link to the new address before it replaces the old one.';

  @override
  String get acct_email_update => 'Update email';

  @override
  String get acct_email_updating => 'Updating…';

  @override
  String get acct_email_empty => 'Email cannot be empty';

  @override
  String get acct_email_invalid => 'Please enter a valid email address';

  @override
  String get acct_email_same => 'New email is the same as current email';

  @override
  String get acct_email_sent => 'Confirmation sent';

  @override
  String acct_email_failed(String error) {
    return 'Failed to update email: $error';
  }

  @override
  String get acct_password_change_title => 'Change password';

  @override
  String get acct_password_set_title => 'Set password';

  @override
  String get acct_password_set_note =>
      'You signed in with Google or Apple. Set a password to also sign in with your email.';

  @override
  String get acct_password_current => 'Current password';

  @override
  String get acct_password_new => 'New password';

  @override
  String get acct_password_new_helper => 'At least 6 characters';

  @override
  String get acct_password_confirm => 'Confirm new password';

  @override
  String get acct_password_change => 'Change password';

  @override
  String get acct_password_set => 'Set password';

  @override
  String get acct_password_changing => 'Changing…';

  @override
  String get acct_password_setting => 'Setting…';

  @override
  String get acct_password_changed => 'Password changed';

  @override
  String get acct_password_was_set =>
      'Password set. You can now sign in with your email and password.';

  @override
  String get acct_password_err_current => 'Please enter your current password';

  @override
  String get acct_password_err_new => 'Please enter a new password';

  @override
  String get acct_password_err_short =>
      'Password must be at least 6 characters long';

  @override
  String get acct_password_err_mismatch => 'Passwords do not match';

  @override
  String get acct_password_err_same =>
      'New password must be different from current password';

  @override
  String get acct_password_err_incorrect => 'Current password is incorrect';

  @override
  String acct_password_failed(String error) {
    return 'Failed to change password: $error';
  }

  @override
  String acct_load_failed(String error) {
    return 'Failed to load account data: $error';
  }

  @override
  String get acct_export_title => 'Export my data';

  @override
  String get acct_export_sub =>
      'Request a copy of your Dabbler data (PDPL data portability)';

  @override
  String get acct_export_started =>
      'We\'re preparing your data export. You\'ll be notified by email when it\'s ready.';

  @override
  String acct_export_failed(String error) {
    return 'Could not request data export: $error';
  }

  @override
  String get priv_title => 'Privacy';

  @override
  String get priv_preset_header => 'Privacy preset';

  @override
  String get priv_preset_note =>
      'Choose a preset to quickly configure your privacy settings';

  @override
  String get priv_preset_public => 'Public';

  @override
  String get priv_preset_public_desc =>
      'Your profile is visible to everyone for easy discovery';

  @override
  String get priv_preset_friends => 'Friends only';

  @override
  String get priv_preset_friends_desc =>
      'Only your friends can see your full profile';

  @override
  String get priv_preset_private => 'Private';

  @override
  String get priv_preset_private_desc =>
      'Minimal information is shared publicly';

  @override
  String priv_preset_applied(String preset) {
    return '$preset preset applied';
  }

  @override
  String get priv_preset_custom => 'Custom';

  @override
  String get priv_preset_custom_desc => 'Your own mix of the settings below';

  @override
  String get priv_hint =>
      'You can always customize individual settings below. Changes save automatically.';

  @override
  String get priv_group_see => 'What others see';

  @override
  String get priv_profile_title => 'Profile & identity';

  @override
  String get priv_profile_sub => 'Photo, name, bio, age, contact details';

  @override
  String get priv_activity_title => 'Activity & stats';

  @override
  String get priv_activity_sub => 'Status, check-ins, history, achievements';

  @override
  String get priv_discover_title => 'Discoverability';

  @override
  String get priv_discover_sub => 'Search indexing and nearby players';

  @override
  String get priv_group_comm => 'Communication';

  @override
  String get priv_contact_title => 'Who can contact you';

  @override
  String get priv_contact_sub => 'Messages, game invites, friend requests';

  @override
  String get priv_group_data => 'Data';

  @override
  String get priv_data_title => 'Data & analytics';

  @override
  String get priv_data_sub => 'Location, recommendations, analytics';

  @override
  String get priv_notif_title => 'Notifications';

  @override
  String get priv_notif_sub => 'Push and email';

  @override
  String get priv_group_safety => 'Safety';

  @override
  String get priv_blocked_title => 'Blocked accounts';

  @override
  String get priv_blocked_sub => 'People you\'ve blocked from contacting you';

  @override
  String priv_count_all(int total) {
    return 'All $total on';
  }

  @override
  String get priv_count_none => 'All off';

  @override
  String priv_count_some(int on, int total) {
    return '$on of $total on';
  }

  @override
  String get priv_contact_nav => 'Contact';

  @override
  String get priv_dm_title => 'Direct messages';

  @override
  String get priv_dm_sub => 'Who can send you messages';

  @override
  String get priv_invites_title => 'Game invites';

  @override
  String get priv_invites_sub => 'Who can invite you to games';

  @override
  String get priv_requests_title => 'Friend requests';

  @override
  String get priv_requests_sub => 'Who can send you friend requests';

  @override
  String get priv_audience_anyone => 'Anyone';

  @override
  String get priv_audience_friends => 'Friends only';

  @override
  String get priv_audience_organizers => 'Organizers only';

  @override
  String get priv_audience_none => 'No one';

  @override
  String get priv_unblock => 'Unblock';

  @override
  String get priv_unblocked => 'Unblocked';

  @override
  String get priv_blocked_empty => 'You haven\'t blocked anyone.';

  @override
  String priv_blocked_failed(String error) {
    return 'Failed to unblock: $error';
  }

  @override
  String priv_blocked_load_failed(String error) {
    return 'Failed to load blocked accounts: $error';
  }

  @override
  String get priv_save_failed => 'Failed to save settings. Please try again.';

  @override
  String get priv_saved => 'Saved';

  @override
  String get priv_t_photo => 'Profile photo';

  @override
  String get priv_t_photo_sub => 'Show your profile picture';

  @override
  String get priv_t_name => 'Real name';

  @override
  String get priv_t_name_sub => 'Show your full name';

  @override
  String get priv_t_bio => 'Bio';

  @override
  String get priv_t_bio_sub => 'Show your bio on your profile';

  @override
  String get priv_t_age => 'Age';

  @override
  String get priv_t_age_sub => 'Show your age on your profile';

  @override
  String get priv_t_email => 'Email address';

  @override
  String get priv_t_email_sub => 'Show your email to others';

  @override
  String get priv_t_phone => 'Phone number';

  @override
  String get priv_t_phone_sub => 'Show your phone number';

  @override
  String get priv_t_location => 'Location';

  @override
  String get priv_t_location_sub => 'Show your general location';

  @override
  String get priv_t_friends => 'Friends list';

  @override
  String get priv_t_friends_sub => 'Show your friends publicly';

  @override
  String get priv_t_online => 'Online status';

  @override
  String get priv_t_online_sub => 'Show when you\'re online';

  @override
  String get priv_t_activity => 'Activity status';

  @override
  String get priv_t_activity_sub => 'Show your recent activity';

  @override
  String get priv_t_checkins => 'Check-ins';

  @override
  String get priv_t_checkins_sub => 'Show your venue check-ins';

  @override
  String get priv_t_posts => 'Posts to public';

  @override
  String get priv_t_posts_sub => 'Make your posts visible to everyone';

  @override
  String get priv_t_sports => 'Sports profiles';

  @override
  String get priv_t_sports_sub => 'Show your sports and skill levels';

  @override
  String get priv_t_history => 'Game history';

  @override
  String get priv_t_history_sub => 'Show your past games';

  @override
  String get priv_t_stats => 'Statistics';

  @override
  String get priv_t_stats_sub => 'Show your performance stats';

  @override
  String get priv_t_achievements => 'Achievements';

  @override
  String get priv_t_achievements_sub => 'Show your earned achievements';

  @override
  String get priv_t_indexing => 'Search engine indexing';

  @override
  String get priv_t_indexing_sub =>
      'Allow external services to find your profile';

  @override
  String get priv_t_nearby => 'Hide from nearby';

  @override
  String get priv_t_nearby_sub => 'Don\'t appear in nearby player searches';

  @override
  String get priv_t_tracking => 'Location tracking';

  @override
  String get priv_t_tracking_sub => 'Allow location-based features';

  @override
  String get priv_t_recs => 'Game recommendations';

  @override
  String get priv_t_recs_sub => 'Personalized game suggestions';

  @override
  String get priv_t_analytics => 'Anonymous analytics';

  @override
  String get priv_t_analytics_sub => 'Help improve the app';

  @override
  String get priv_t_push => 'Push notifications';

  @override
  String get priv_t_push_sub => 'Receive push notifications on your device';

  @override
  String get priv_t_mail => 'Email notifications';

  @override
  String get priv_t_mail_sub => 'Receive notifications via email';

  @override
  String get appr_title => 'Appearance';

  @override
  String get appr_group_theme => 'Theme';

  @override
  String get appr_light => 'Light';

  @override
  String get appr_dark => 'Dark';

  @override
  String get appr_system => 'System';

  @override
  String appr_theme_applied(String theme) {
    return '$theme theme';
  }

  @override
  String get appr_group_color => 'Color theme';

  @override
  String get appr_group_color_note =>
      'Apply one token set across the entire app';

  @override
  String appr_color_use(String name) {
    return 'Use $name tokens app-wide';
  }

  @override
  String get appr_group_auto => 'Automatic theme';

  @override
  String get appr_group_auto_note =>
      'Automatically switch between light and dark themes';

  @override
  String get appr_auto_title => 'Time-based theme';

  @override
  String get appr_auto_sub => 'Switch themes based on time of day';

  @override
  String get appr_group_schedule => 'Day & night schedule';

  @override
  String get appr_group_schedule_note =>
      'Set when light and dark themes should activate';

  @override
  String get appr_day_title => 'Day starts at';

  @override
  String get appr_day_sub => 'Light theme will activate';

  @override
  String get appr_night_title => 'Night starts at';

  @override
  String get appr_night_sub => 'Dark theme will activate';

  @override
  String get region_title => 'Language & region';

  @override
  String get region_language => 'Language';

  @override
  String get region_language_sub => 'App and content language';

  @override
  String get region_language_updated => 'Language updated';

  @override
  String get region_country => 'App country';

  @override
  String get region_country_sub => 'Games, venues and currency';

  @override
  String get region_country_updated => 'Country updated';

  @override
  String get region_lang_en => 'English · English';

  @override
  String get region_lang_ar => 'Arabic · العربية';

  @override
  String get region_country_Egypt => 'Egypt';

  @override
  String get region_country_UAE => 'United Arab Emirates';

  @override
  String get region_country_KSA => 'Saudi Arabia';

  @override
  String get region_country_Morocco => 'Morocco';

  @override
  String region_error(String error) {
    return 'Error: $error';
  }

  @override
  String get listing_set_location => 'Set location';

  @override
  String get listing_search => 'Search';

  @override
  String get listing_filters => 'Filters';

  @override
  String get listing_reset => 'Reset';

  @override
  String get listing_clear_all => 'Clear all';

  @override
  String get listing_all_sports => 'All sports';

  @override
  String get listing_upcoming => 'Upcoming';

  @override
  String get listing_open_spots => 'Open spots';

  @override
  String get listing_sort_nearest => 'Nearest';

  @override
  String get listing_sort_soonest => 'Starting soonest';

  @override
  String get listing_group_distance => 'Distance';

  @override
  String get listing_group_date => 'Date';

  @override
  String get listing_group_skill => 'Skill level';

  @override
  String get listing_group_availability => 'Availability';

  @override
  String get listing_group_sort => 'Sort by';

  @override
  String listing_within_km(int km) {
    return 'Within $km km';
  }

  @override
  String get listing_any_distance => 'Any distance';

  @override
  String get listing_date_any => 'Any date';

  @override
  String get listing_today => 'Today';

  @override
  String get listing_tomorrow => 'Tomorrow';

  @override
  String get listing_this_week => 'This week';

  @override
  String listing_distance_km(String km) {
    return '$km km';
  }

  @override
  String listing_distance_m(int meters) {
    return '$meters m';
  }

  @override
  String get listing_no_charge => 'no charge';

  @override
  String get listing_share_game => 'Share game';

  @override
  String get listing_favourite_add => 'Add to favourites';

  @override
  String get listing_favourite_remove => 'Remove from favourites';

  @override
  String get listing_verified_host => 'Verified host';

  @override
  String listing_duration_min(int minutes) {
    return '$minutes min';
  }

  @override
  String get listing_skill_all_levels => 'All levels';

  @override
  String get listing_starts_soon => 'Starts soon';

  @override
  String get listing_filters_open => 'Open filters';

  @override
  String listing_games_empty_radius_window(int km, String window) {
    return 'Nothing within $km km $window. Widen the date or sport.';
  }

  @override
  String listing_games_empty_radius(int km) {
    return 'Nothing within $km km. Widen the distance or sport.';
  }

  @override
  String listing_games_empty_window(String window) {
    return 'Nothing $window. Widen the date or sport.';
  }

  @override
  String get listing_games_empty_fallback =>
      'Nothing matches these filters. Widen the date or sport.';

  @override
  String get listing_window_today => 'today';

  @override
  String get listing_window_tomorrow => 'tomorrow';

  @override
  String listing_window_days(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in the next $days days',
      one: 'in the next day',
    );
    return '$_temp0';
  }

  @override
  String get listing_window_weekend => 'this weekend';

  @override
  String get listing_skill_beginner => 'Beginner';

  @override
  String get listing_skill_intermediate => 'Intermediate';

  @override
  String get listing_skill_advanced => 'Advanced';

  @override
  String get listing_load_sports_failed => 'Failed to load sports';

  @override
  String get listing_load_games_failed => 'Couldn\'t load games';

  @override
  String get listing_load_venues_failed => 'Couldn\'t load venues';

  @override
  String get listing_games_filtered_title => 'No games match your filters';

  @override
  String get listing_games_filtered_text => 'Adjust or clear the filters.';

  @override
  String get listing_games_nearby_title => 'No games found nearby.';

  @override
  String get listing_games_nearby_text =>
      'Try widening your search radius in the filter.';

  @override
  String get listing_games_none_title => 'No games yet';

  @override
  String get listing_games_none_text =>
      'Be the first to create a game in your area!';

  @override
  String get listing_change_filters => 'Change filters';

  @override
  String get listing_created => 'Created';

  @override
  String get listing_joined => 'Joined';

  @override
  String get listing_full => 'Full';

  @override
  String get listing_join_game => 'Join game';

  @override
  String get listing_on_waitlist => 'On waitlist';

  @override
  String get listing_request_sent => 'Request sent';

  @override
  String listing_spots_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots left',
      one: '1 spot left',
    );
    return '$_temp0';
  }

  @override
  String listing_spots_almost_full(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots left · almost full',
      one: '1 spot left · almost full',
    );
    return '$_temp0';
  }

  @override
  String listing_players_in(int joined, int total) {
    return '$joined of $total players in';
  }

  @override
  String listing_show_games(int count) {
    return 'Show $count games';
  }

  @override
  String get listing_show_games_plain => 'Show games';

  @override
  String get listing_show_venues => 'Show venues';

  @override
  String get listing_unit_day => 'day';

  @override
  String get listing_unit_days => 'days';

  @override
  String get listing_unit_hour => 'hour';

  @override
  String get listing_unit_hours => 'hours';

  @override
  String get listing_unit_min => 'min';

  @override
  String get listing_saved_venues => 'Saved venues';

  @override
  String get listing_add_venue => 'Add venue';

  @override
  String get listing_venues_none_title => 'No venues found';

  @override
  String get listing_venues_none_text => 'Try selecting a different sport.';

  @override
  String listing_venues_radius_text(int km) {
    return 'No venues within $km km — try widening your search radius.';
  }

  @override
  String get listing_starting_from => 'Starting from';

  @override
  String get listing_view_venue => 'View venue';

  @override
  String get listing_save_venue => 'Save venue';

  @override
  String get listing_remove_saved => 'Remove from saved';

  @override
  String get listing_indoor => 'Indoor';

  @override
  String get listing_outdoor => 'Outdoor';

  @override
  String get listing_distance_unavailable => 'Distance unavailable';

  @override
  String listing_km_away(String distance) {
    return '$distance away';
  }

  @override
  String get listing_free => 'Free';

  @override
  String listing_price_per_hour(String amount) {
    return 'AED $amount / hour';
  }

  @override
  String get location_change_title => 'Change location';

  @override
  String get location_search_areas => 'Search areas…';

  @override
  String get location_use_current => 'Use current location';

  @override
  String get location_detecting => 'Detecting…';

  @override
  String get location_saved => 'Saved';

  @override
  String get location_add => 'Add location';

  @override
  String location_no_areas(String query) {
    return 'No areas match \"$query\"';
  }

  @override
  String get location_access_required => 'Location access required';

  @override
  String get location_permission_denied_forever =>
      'Location permission is permanently denied. Open Settings to enable it.';

  @override
  String get location_open_settings => 'Open Settings';

  @override
  String get location_enable_services => 'Please enable location services';

  @override
  String get location_permission_denied => 'Location permission denied';

  @override
  String get location_timeout => 'Could not get location — try again';

  @override
  String location_error(String message) {
    return 'Error: $message';
  }

  @override
  String get listing_skill_any => 'Any skill';

  @override
  String get home_upcoming_title => 'Upcoming';

  @override
  String home_upcoming_title_count(int count) {
    return 'Upcoming · $count';
  }

  @override
  String home_upcoming_strip_count(int count) {
    return '$count upcoming';
  }

  @override
  String home_upcoming_more(int count) {
    return '$count more this week';
  }

  @override
  String get home_upcoming_show_less => 'Show less';

  @override
  String get home_upcoming_hide => 'Hide';

  @override
  String home_upcoming_see_all(int count) {
    return 'See all $count upcoming';
  }

  @override
  String get home_upcoming_day => 'day';

  @override
  String get home_upcoming_days => 'days';

  @override
  String get home_upcoming_hour => 'hour';

  @override
  String get home_upcoming_hours => 'hours';

  @override
  String get home_upcoming_min => 'min';

  @override
  String home_upcoming_in_days(int days) {
    return 'in ${days}d';
  }

  @override
  String home_upcoming_in_hours(int hours, int minutes) {
    return 'in ${hours}h ${minutes}m';
  }

  @override
  String home_upcoming_in_minutes(int minutes) {
    return 'in ${minutes}m';
  }

  @override
  String get home_post_options_title => 'Post options';

  @override
  String home_post_options_by(String name) {
    return 'Posted by $name';
  }

  @override
  String get home_post_report => 'Report post';

  @override
  String get home_post_report_note => 'Tell us what is wrong with this post';

  @override
  String get home_post_block => 'Block user';

  @override
  String get home_vibe_title => 'What\'s the vibe?';

  @override
  String get home_location_title => 'Change location';

  @override
  String get home_location_done => 'Done';

  @override
  String get home_location_search => 'Search area, street or city';

  @override
  String get home_location_use_current => 'Use current location';

  @override
  String get home_location_add => 'Add location';

  @override
  String get home_location_cancel => 'Cancel';

  @override
  String get home_location_search_venues => 'Search venues and areas';

  @override
  String get home_location_recent => 'Recent';

  @override
  String home_location_no_match(String query) {
    return 'No areas match \"$query\"';
  }

  @override
  String get blocked_accounts_note =>
      'Manage users you\'ve blocked from contacting you.';

  @override
  String get blocked_accounts_empty => 'You haven\'t blocked anyone.';

  @override
  String get blocked_accounts_load_failed =>
      'Could not load your blocked accounts.';

  @override
  String get blocked_accounts_unknown => 'Unknown';

  @override
  String get blocked_accounts_unblock => 'Unblock';

  @override
  String get blocked_accounts_unblocked => 'Unblocked';

  @override
  String blocked_accounts_unblock_failed(String message) {
    return 'Could not unblock: $message';
  }

  @override
  String get notif_settings_push => 'Push notifications';

  @override
  String get notif_settings_push_sub =>
      'Receive push notifications on your device';

  @override
  String get notif_settings_email => 'Email notifications';

  @override
  String get notif_settings_email_sub => 'Receive notifications via email';

  @override
  String get notif_settings_sms => 'SMS notifications';

  @override
  String get notif_settings_sms_sub => 'Receive important updates via SMS';

  @override
  String get notif_settings_quiet_header => 'Quiet hours';

  @override
  String get notif_settings_quiet_mute => 'Mute during quiet hours';

  @override
  String get notif_settings_quiet_mute_off =>
      'Pause push notifications overnight';

  @override
  String notif_settings_quiet_mute_on(String start, String end) {
    return 'No push between $start and $end';
  }

  @override
  String get notif_settings_quiet_start => 'Start';

  @override
  String get notif_settings_quiet_end => 'End';

  @override
  String get notif_settings_quiet_urgent => 'Allow urgent notifications';

  @override
  String get notif_settings_quiet_urgent_sub =>
      'High-priority alerts still come through during quiet hours';

  @override
  String get notif_settings_quiet_all => 'Allow all notifications';

  @override
  String get notif_settings_quiet_all_sub =>
      'Every push still comes through during quiet hours';

  @override
  String get notif_settings_group_game => 'Game notifications';

  @override
  String get notif_settings_group_social => 'Social notifications';

  @override
  String get notif_settings_group_connections => 'Connections';

  @override
  String get notif_settings_kind_game_invites => 'Game invites & requests';

  @override
  String get notif_settings_kind_game_invites_sub =>
      'Invites, join requests, approvals';

  @override
  String get notif_settings_kind_game_reminders => 'Game reminders';

  @override
  String get notif_settings_kind_game_reminders_sub =>
      'Reminders for upcoming games';

  @override
  String get notif_settings_kind_game_updates => 'Game updates';

  @override
  String get notif_settings_kind_game_updates_sub =>
      'Changes, waitlist promotions, players joining';

  @override
  String get notif_settings_kind_booking => 'Booking payments';

  @override
  String get notif_settings_kind_booking_sub => 'When a booking needs payment';

  @override
  String get notif_settings_kind_likes => 'Likes & reactions';

  @override
  String get notif_settings_kind_likes_sub =>
      'Likes and reactions on your content';

  @override
  String get notif_settings_kind_comments => 'Comments';

  @override
  String get notif_settings_kind_comments_sub => 'Comments on your posts';

  @override
  String get notif_settings_kind_mentions => 'Mentions';

  @override
  String get notif_settings_kind_mentions_sub => 'When someone mentions you';

  @override
  String get notif_settings_kind_followers => 'New followers';

  @override
  String get notif_settings_kind_followers_sub => 'When someone follows you';

  @override
  String get notif_settings_kind_friends => 'Friend requests';

  @override
  String get notif_settings_kind_friends_sub =>
      'New and accepted friend requests';

  @override
  String get notif_settings_kind_squads => 'Squad invites';

  @override
  String get notif_settings_kind_squads_sub => 'Invites to join a squad';

  @override
  String get notif_settings_kind_meetups => 'Meetup invites';

  @override
  String get notif_settings_kind_meetups_sub =>
      'Invites and players joining meetups';

  @override
  String get notif_settings_kind_meetup_rsvps => 'Meetup RSVPs';

  @override
  String get notif_settings_kind_meetup_rsvps_sub =>
      'When someone RSVPs to a meetup you host';

  @override
  String get notif_settings_kind_meetup_requests => 'Meetup join requests';

  @override
  String get notif_settings_kind_meetup_requests_sub =>
      'When someone asks to join a meetup you host';

  @override
  String get notif_settings_kind_meetup_approved => 'Meetup request approved';

  @override
  String get notif_settings_kind_meetup_approved_sub =>
      'When a host approves your request to join';

  @override
  String get notif_settings_kind_meetup_declined => 'Meetup request declined';

  @override
  String get notif_settings_kind_meetup_declined_sub =>
      'When a host declines your request to join';

  @override
  String get notif_settings_kind_meetup_cancelled => 'Meetup cancelled';

  @override
  String get notif_settings_kind_meetup_cancelled_sub =>
      'When a meetup you joined is cancelled';

  @override
  String notif_settings_update_failed(String error) {
    return 'Could not update settings: $error';
  }

  @override
  String get game_prefs_title => 'Game preferences';

  @override
  String get game_prefs_save => 'Save';

  @override
  String get game_prefs_saved => 'Game preferences saved';

  @override
  String get game_prefs_types_header => 'Preferred game types';

  @override
  String get game_prefs_types_note =>
      'Select the types of games you enjoy most';

  @override
  String get game_prefs_type_pickup => 'Pickup games';

  @override
  String get game_prefs_type_pickup_sub => 'Casual games with other players';

  @override
  String get game_prefs_type_tournaments => 'Tournaments';

  @override
  String get game_prefs_type_tournaments_sub => 'Competitive organized events';

  @override
  String get game_prefs_type_practice => 'Practice sessions';

  @override
  String get game_prefs_type_practice_sub => 'Skill development and training';

  @override
  String get game_prefs_type_leagues => 'Leagues';

  @override
  String get game_prefs_type_leagues_sub => 'Season-long competitions';

  @override
  String get game_prefs_type_friendly => 'Friendly matches';

  @override
  String get game_prefs_type_friendly_sub => 'Non-competitive social games';

  @override
  String get game_prefs_type_camps => 'Training camps';

  @override
  String get game_prefs_type_camps_sub => 'Intensive skill workshops';

  @override
  String get game_prefs_duration_header => 'Game duration';

  @override
  String get game_prefs_duration_note =>
      'How long do you prefer games to last?';

  @override
  String get game_prefs_duration_short => 'Short games';

  @override
  String get game_prefs_duration_short_sub => '30-60 minutes';

  @override
  String get game_prefs_duration_medium => 'Medium games';

  @override
  String get game_prefs_duration_medium_sub => '60-90 minutes';

  @override
  String get game_prefs_duration_long => 'Long games';

  @override
  String get game_prefs_duration_long_sub => '90+ minutes';

  @override
  String get game_prefs_duration_flexible => 'Flexible duration';

  @override
  String get game_prefs_duration_flexible_sub => 'Any duration';

  @override
  String get game_prefs_duration_custom => 'Custom duration range';

  @override
  String get game_prefs_duration_min => 'Min duration';

  @override
  String get game_prefs_duration_max => 'Max duration';

  @override
  String game_prefs_minutes_hint(String value) {
    return '$value min';
  }

  @override
  String get game_prefs_minutes_suffix => 'min';

  @override
  String get game_prefs_team_header => 'Team size';

  @override
  String get game_prefs_team_note => 'What team sizes do you prefer?';

  @override
  String get game_prefs_team_flexible => 'Flexible team size';

  @override
  String get game_prefs_team_flexible_sub => 'Open to various team sizes';

  @override
  String game_prefs_team_preferred(String low, String high) {
    return 'Preferred team size: $low - $high players';
  }

  @override
  String get game_prefs_team_min_label => '2 players';

  @override
  String get game_prefs_team_max_label => '22 players';

  @override
  String get game_prefs_level_header => 'Competition level';

  @override
  String get game_prefs_level_note =>
      'What level of competition do you prefer?';

  @override
  String get game_prefs_level_casual => 'Casual';

  @override
  String get game_prefs_level_casual_sub => 'Just for fun, relaxed atmosphere';

  @override
  String get game_prefs_level_recreational => 'Recreational';

  @override
  String get game_prefs_level_recreational_sub =>
      'Friendly competition, moderate intensity';

  @override
  String get game_prefs_level_competitive => 'Competitive';

  @override
  String get game_prefs_level_competitive_sub =>
      'Serious competition, high intensity';

  @override
  String get game_prefs_level_professional => 'Professional';

  @override
  String get game_prefs_level_professional_sub => 'Elite level competition';

  @override
  String get game_prefs_equipment_header => 'Equipment';

  @override
  String get game_prefs_equipment_note => 'What are your equipment needs?';

  @override
  String get game_prefs_equipment_own => 'I have my own equipment';

  @override
  String get game_prefs_equipment_own_sub => 'You can bring your own gear';

  @override
  String get game_prefs_equipment_provide =>
      'I can provide equipment for others';

  @override
  String get game_prefs_equipment_provide_sub =>
      'You can share equipment with teammates';

  @override
  String get game_prefs_equipment_need => 'I need equipment provided';

  @override
  String get game_prefs_equipment_need_sub =>
      'Equipment should be available at the venue';

  @override
  String get game_prefs_equipment_types => 'Equipment types';

  @override
  String get game_prefs_equipment_ball => 'Ball';

  @override
  String get game_prefs_equipment_gear => 'Protective gear';

  @override
  String get game_prefs_equipment_uniforms => 'Uniforms';

  @override
  String get game_prefs_equipment_goals => 'Goals';

  @override
  String get game_prefs_equipment_nets => 'Nets';

  @override
  String get game_prefs_equipment_markers => 'Markers';

  @override
  String get game_prefs_referee_header => 'Referee';

  @override
  String get game_prefs_referee_note =>
      'How do you prefer games to be officiated?';

  @override
  String get game_prefs_referee_prefer => 'Prefer games with a referee';

  @override
  String get game_prefs_referee_prefer_sub => 'Official referee for fair play';

  @override
  String get game_prefs_referee_can => 'I can referee games';

  @override
  String get game_prefs_referee_can_sub => 'You\'re qualified to officiate';

  @override
  String get game_prefs_referee_strict => 'Strict rule enforcement';

  @override
  String get game_prefs_referee_strict_sub =>
      'Games should follow official rules closely';

  @override
  String get composer_cancel => 'Cancel';

  @override
  String get composer_confirm => 'Confirm';

  @override
  String get composer_clear => 'Clear';

  @override
  String get composer_none => 'None';

  @override
  String get composer_select => 'Select';

  @override
  String get composer_tap_to_change => 'Tap to change.';

  @override
  String get composer_create_post => 'Create post';

  @override
  String get composer_post_cta => 'Post';

  @override
  String get composer_you => 'You';

  @override
  String get composer_post_as => 'Post As';

  @override
  String get composer_switch_failed => 'Failed to switch profile';

  @override
  String get composer_body_hint => 'What\'s on your mind? Use #hashtags';

  @override
  String get composer_add_media => 'Add media';

  @override
  String get composer_add_vibe => 'Add vibe';

  @override
  String get composer_add_sport => 'Add sport';

  @override
  String get composer_add_location => 'Add location';

  @override
  String get composer_link_game => 'Link a game';

  @override
  String get composer_add_more_media => 'Add more media';

  @override
  String get composer_remove_media => 'Remove media';

  @override
  String get composer_allow_reposts => 'Allow reposts';

  @override
  String get composer_allow_reposts_sub => 'Others can share this post';

  @override
  String get composer_pin => 'Pin to profile';

  @override
  String get composer_pin_sub => 'Keep at the top of your profile';

  @override
  String get composer_expiry => 'Set expiry';

  @override
  String get composer_expiry_sub => 'Auto-hides after date';

  @override
  String get composer_who_can_see => 'Who can see this?';

  @override
  String get composer_which_sport => 'Which sport?';

  @override
  String get composer_kind_of_post => 'What kind of post?';

  @override
  String get composer_link_a_game => 'Link a game';

  @override
  String get composer_location => 'Location';

  @override
  String get composer_add_media_title => 'Add media';

  @override
  String get composer_take_photo => 'Take photo';

  @override
  String get composer_choose_gallery => 'Choose from gallery';

  @override
  String get composer_search_gifs => 'Search GIFs';

  @override
  String get composer_powered_giphy => 'Powered by GIPHY';

  @override
  String get composer_vis_public => 'Public';

  @override
  String get composer_vis_followers => 'Followers';

  @override
  String get composer_vis_circle => 'Circle';

  @override
  String get composer_vis_squad => 'Squad';

  @override
  String get composer_vis_private => 'Private';

  @override
  String get composer_vis_link => 'Link Only';

  @override
  String get composer_vis_public_sub => 'Anyone can see this post';

  @override
  String get composer_vis_followers_sub => 'Only your followers can see this';

  @override
  String get composer_vis_circle_sub => 'Shared with a specific circle';

  @override
  String get composer_vis_squad_sub => 'Shared with your squad';

  @override
  String get composer_vis_private_sub => 'Only you can see this';

  @override
  String get composer_vis_link_sub => 'Only people with the link can see this';

  @override
  String get composer_type_moment => 'Moment';

  @override
  String get composer_type_dab => 'Dab';

  @override
  String get composer_type_kickin => 'Kick-in';

  @override
  String get composer_type_moment_sub => 'A quick snapshot of right now';

  @override
  String get composer_type_dab_sub => 'Share what you\'re vibing with';

  @override
  String get composer_type_kickin_sub => 'Invite others to join in';

  @override
  String get composer_vibe_search => 'Search vibes';

  @override
  String get composer_vibe_failed => 'Failed to load vibes';

  @override
  String get composer_vibe_none => 'No vibes match that search';

  @override
  String get composer_sports_failed => 'Failed to load sports';

  @override
  String get composer_sports_none => 'No sports available';

  @override
  String get composer_venue_search => 'Search venues...';

  @override
  String get composer_type_location => 'Type a location';

  @override
  String get composer_use_location => 'Use this location';

  @override
  String get composer_search_failed => 'Search failed';

  @override
  String get composer_no_venues => 'No venues found';

  @override
  String get composer_venue => 'Venue';

  @override
  String get composer_venue_hint => 'Search for a venue or type a location';

  @override
  String get composer_games_search => 'Search games by title...';

  @override
  String get composer_no_games => 'No games found';

  @override
  String get composer_untitled_game => 'Untitled Game';

  @override
  String get composer_games_hint => 'Search for a game to link to your post';

  @override
  String get game_create => 'Create game';

  @override
  String get game_edit => 'Edit Game';

  @override
  String get game_save_changes => 'Save changes';

  @override
  String get game_sport => 'Sport';

  @override
  String get game_format => 'Format';

  @override
  String get game_format_sub => 'Game format';

  @override
  String get game_select_sport_first => 'Pick a sport first';

  @override
  String get game_select_format => 'Select format';

  @override
  String get game_venue_sub => 'Where to play';

  @override
  String get game_date_time => 'Date & time';

  @override
  String get game_date_time_sub => 'When is the game';

  @override
  String get game_duration => 'Duration';

  @override
  String get game_duration_sub => 'How long it runs';

  @override
  String get game_join_policy => 'Join policy';

  @override
  String get game_join_open => 'Open';

  @override
  String get game_join_request => 'Request';

  @override
  String get game_join_invite => 'Invite';

  @override
  String get game_join_link => 'Link';

  @override
  String get game_visibility => 'Visibility';

  @override
  String get game_skill_level => 'Skill level';

  @override
  String get game_skill_sub => 'Player experience';

  @override
  String get game_any_level => 'Any level';

  @override
  String get game_players => 'Players';

  @override
  String get game_players_sub => 'Min and max players';

  @override
  String get game_fewer_min => 'Fewer minimum players';

  @override
  String get game_more_min => 'More minimum players';

  @override
  String get game_fewer_max => 'Fewer maximum players';

  @override
  String get game_more_max => 'More maximum players';

  @override
  String get game_waitlist => 'Waitlist';

  @override
  String get game_waitlist_sub => 'Let players queue when full';

  @override
  String get game_spectators => 'Spectators';

  @override
  String get game_spectators_sub => 'Allow spectators to watch';

  @override
  String get game_details => 'Details (optional)';

  @override
  String get game_title_hint => 'Game title';

  @override
  String get game_note_hint => 'Add a note for players...';

  @override
  String get game_date => 'Date';

  @override
  String get game_time => 'Time';

  @override
  String get game_today => 'Today';

  @override
  String get game_tomorrow => 'Tomorrow';

  @override
  String get game_select_venue => 'Select Venue';

  @override
  String get game_select_format_title => 'Select Format';

  @override
  String get game_no_formats => 'No formats available';

  @override
  String get game_no_matches => 'No matches';

  @override
  String get game_skill_beginner => 'Beginner';

  @override
  String get game_skill_intermediate => 'Intermediate';

  @override
  String get game_skill_advanced => 'Advanced';

  @override
  String get game_skill_pro => 'Pro';

  @override
  String get game_skill_beginner_sub => 'Just getting started';

  @override
  String get game_skill_intermediate_sub => 'Plays regularly';

  @override
  String get game_skill_advanced_sub => 'Competitive level';

  @override
  String get game_skill_pro_sub => 'Elite / professional';

  @override
  String get post_detail_title => 'Post';

  @override
  String get post_detail_more => 'More options';

  @override
  String get post_detail_follow => 'Follow';

  @override
  String get post_detail_following => 'Following';

  @override
  String get post_detail_anonymous => 'Anonymous';

  @override
  String get post_detail_no_replies => 'No replies yet';

  @override
  String get post_detail_first_reply => 'Be the first to reply.';

  @override
  String get post_detail_reply_hint => 'Post your reply…';

  @override
  String get post_detail_reply_to_hint => 'Reply…';

  @override
  String get post_detail_add_image => 'Add image';

  @override
  String get post_detail_add_location => 'Add location';

  @override
  String get post_detail_send_reply => 'Send reply';

  @override
  String get post_detail_reply => 'Reply';

  @override
  String get post_detail_add => 'Add';

  @override
  String get post_detail_hide_replies => 'Hide replies';

  @override
  String get post_detail_view_replies => 'View replies';

  @override
  String get post_detail_copy_link => 'Copy link';

  @override
  String get post_detail_link_copied => 'Link copied';

  @override
  String get post_detail_delete_post => 'Delete post';

  @override
  String get post_detail_delete_reply => 'Delete reply';

  @override
  String get post_detail_report => 'Report';

  @override
  String get post_detail_edited => 'Edited';

  @override
  String get post_detail_failed => 'Could not load post';

  @override
  String get post_detail_replies_failed => 'Could not load replies';

  @override
  String get post_detail_retry => 'Retry';

  @override
  String get post_detail_remove_image => 'Remove image';

  @override
  String get post_detail_remove_location => 'Remove location';

  @override
  String get post_detail_image => 'Image';

  @override
  String get post_detail_org => 'Org';

  @override
  String get post_detail_player => 'Player';

  @override
  String post_detail_replies_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String post_detail_views(String count) {
    return '$count views';
  }

  @override
  String get post_detail_replying_to => 'Replying to';

  @override
  String get post_detail_cancel_reply => 'Cancel reply';

  @override
  String get help_center_title => 'Help center';

  @override
  String get help_center_empty_title => 'Help center';

  @override
  String get help_center_empty_text => 'This screen is under development';

  @override
  String get contact_title => 'Contact support';

  @override
  String get contact_intro_title => 'How can we help?';

  @override
  String get contact_intro_message =>
      'Send us a message and we\'ll get back to you as soon as possible.';

  @override
  String get contact_section => 'Contact information';

  @override
  String get contact_email => 'Your email';

  @override
  String get contact_category => 'Category';

  @override
  String get contact_subject => 'Subject';

  @override
  String get contact_message => 'Message';

  @override
  String get contact_send => 'Send message';

  @override
  String get contact_cat_general => 'General';

  @override
  String get contact_cat_account => 'Account issues';

  @override
  String get contact_cat_technical => 'Technical problem';

  @override
  String get contact_cat_billing => 'Payment & billing';

  @override
  String get contact_cat_feature => 'Feature request';

  @override
  String get contact_cat_abuse => 'Report abuse';

  @override
  String get contact_cat_privacy => 'Privacy concern';

  @override
  String get contact_cat_other => 'Other';

  @override
  String get contact_err_email_required => 'Please enter your email';

  @override
  String get contact_err_email_invalid => 'Please enter a valid email';

  @override
  String get contact_err_subject_required => 'Please enter a subject';

  @override
  String get contact_err_message_required => 'Please enter your message';

  @override
  String get contact_err_message_short =>
      'Message must be at least 10 characters long';

  @override
  String get contact_sent => 'Message sent. We\'ll get back to you soon.';

  @override
  String contact_send_failed(String error) {
    return 'Failed to send message: $error';
  }

  @override
  String get bug_title => 'Report a bug';

  @override
  String get bug_intro_title => 'Found a bug?';

  @override
  String get bug_intro_message =>
      'Help us improve by reporting any issues you encounter. The more details you provide, the faster we can fix it.';

  @override
  String get bug_details => 'Bug details';

  @override
  String get bug_category => 'Bug category';

  @override
  String get bug_severity => 'Severity level';

  @override
  String get bug_field_title => 'Bug title';

  @override
  String get bug_field_title_hint => 'Brief description of the issue';

  @override
  String get bug_field_description => 'Detailed description';

  @override
  String get bug_field_description_hint =>
      'Describe what happened and what you expected to happen';

  @override
  String get bug_field_steps => 'Steps to reproduce';

  @override
  String get bug_field_steps_hint =>
      '1. Go to...\n2. Tap on...\n3. See the error';

  @override
  String get bug_cat_general => 'General bug';

  @override
  String get bug_cat_ui => 'UI / visual issue';

  @override
  String get bug_cat_performance => 'Performance issue';

  @override
  String get bug_cat_crash => 'Crash / freeze';

  @override
  String get bug_cat_login => 'Login / authentication';

  @override
  String get bug_cat_profile => 'Profile / settings';

  @override
  String get bug_cat_games => 'Games / activities';

  @override
  String get bug_cat_notifications => 'Notifications';

  @override
  String get bug_cat_social => 'Social features';

  @override
  String get bug_cat_other => 'Other';

  @override
  String get bug_sev_low => 'Low';

  @override
  String get bug_sev_medium => 'Medium';

  @override
  String get bug_sev_high => 'High';

  @override
  String get bug_sev_critical => 'Critical';

  @override
  String get bug_additional => 'Additional information';

  @override
  String get bug_include_device => 'Include device information';

  @override
  String get bug_include_device_sub => 'OS version, device model, screen size';

  @override
  String get bug_include_logs => 'Include app logs';

  @override
  String get bug_include_logs_sub => 'Recent app activity and error logs';

  @override
  String get bug_device_heading => 'Device information to include:';

  @override
  String bug_device_platform(String value) {
    return 'Platform: $value';
  }

  @override
  String bug_device_app_version(String value) {
    return 'App version: $value';
  }

  @override
  String bug_device_resolution(String value) {
    return 'Screen resolution: $value';
  }

  @override
  String get bug_platform_unknown => 'Unknown';

  @override
  String get bug_platform_web => 'Web';

  @override
  String get bug_err_email_required => 'Please enter your email';

  @override
  String get bug_err_title_required => 'Please enter a bug title';

  @override
  String get bug_err_description_required => 'Please describe the bug';

  @override
  String get bug_err_description_short =>
      'Please provide more details (at least 20 characters)';

  @override
  String get bug_err_steps_required =>
      'Please provide steps to reproduce the bug';

  @override
  String get bug_submit => 'Submit bug report';

  @override
  String get bug_submitted =>
      'Bug report submitted. Thank you for helping us improve.';

  @override
  String bug_submit_failed(String error) {
    return 'Failed to submit bug report: $error';
  }

  @override
  String get sports_prefs_title => 'Sports preferences';

  @override
  String get sports_prefs_save => 'Save';

  @override
  String get sports_prefs_create_game => 'Create game';

  @override
  String get sports_prefs_my_sports => 'My sports';

  @override
  String get sports_prefs_my_sports_note =>
      'Enable sports you want to play and set your skill level';

  @override
  String get sports_prefs_general => 'General preferences';

  @override
  String get sports_prefs_auto_join => 'Auto-join compatible games';

  @override
  String get sports_prefs_auto_join_sub =>
      'Automatically join games that match your preferences';

  @override
  String get sports_prefs_location => 'Use location for recommendations';

  @override
  String get sports_prefs_location_sub =>
      'Find games near your current location';

  @override
  String get sports_prefs_flexible => 'Flexible timing';

  @override
  String get sports_prefs_flexible_sub =>
      'Show games with flexible start times';

  @override
  String get sports_prefs_disabled => 'Disabled';

  @override
  String get sports_prefs_skill_level => 'Skill level';

  @override
  String get sports_prefs_position => 'Preferred position';

  @override
  String get sports_prefs_level_beginner => 'Beginner';

  @override
  String get sports_prefs_level_intermediate => 'Intermediate';

  @override
  String get sports_prefs_level_advanced => 'Advanced';

  @override
  String sports_prefs_load_failed(String error) {
    return 'Failed to load sports preferences: $error';
  }

  @override
  String get sports_prefs_saved => 'Sports preferences saved';

  @override
  String sports_prefs_save_failed(String error) {
    return 'Failed to save preferences: $error';
  }

  @override
  String sports_prefs_enable_failed(String error) {
    return 'Failed to enable sport: $error';
  }

  @override
  String sports_prefs_remove_failed(String error) {
    return 'Failed to remove sport: $error';
  }

  @override
  String get sports_prefs_need_one =>
      'You must have at least one sport enabled';

  @override
  String sports_prefs_remove_title(String sport) {
    return 'Remove $sport?';
  }

  @override
  String sports_prefs_remove_body(String sport) {
    return 'Are you sure you want to remove $sport from your profile?';
  }

  @override
  String get sports_prefs_cancel => 'Cancel';

  @override
  String get sports_prefs_remove => 'Remove';

  @override
  String get sports_pos_goalkeeper => 'Goalkeeper';

  @override
  String get sports_pos_defender => 'Defender';

  @override
  String get sports_pos_midfielder => 'Midfielder';

  @override
  String get sports_pos_forward => 'Forward';

  @override
  String get sports_pos_point_guard => 'Point Guard';

  @override
  String get sports_pos_shooting_guard => 'Shooting Guard';

  @override
  String get sports_pos_small_forward => 'Small Forward';

  @override
  String get sports_pos_power_forward => 'Power Forward';

  @override
  String get sports_pos_center => 'Center';

  @override
  String get sports_pos_setter => 'Setter';

  @override
  String get sports_pos_outside_hitter => 'Outside Hitter';

  @override
  String get sports_pos_middle_blocker => 'Middle Blocker';

  @override
  String get sports_pos_opposite_hitter => 'Opposite Hitter';

  @override
  String get sports_pos_libero => 'Libero';

  @override
  String get about_terms_intro =>
      'Please read these terms carefully before using our service.';

  @override
  String get about_privacy_intro =>
      'Your privacy is important to us. This policy explains how we collect, use, and protect your information.';

  @override
  String about_last_updated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get about_privacy_settings_tooltip => 'Privacy settings';

  @override
  String get licenses_title => 'Open source licenses';

  @override
  String get licenses_about_tooltip => 'About licenses';

  @override
  String get licenses_intro =>
      'This app is built with amazing open source libraries. We thank all contributors for their work.';

  @override
  String licenses_count(String count) {
    return '$count open source packages';
  }

  @override
  String get licenses_search_hint => 'Search licenses...';

  @override
  String get licenses_empty_title => 'No licenses found';

  @override
  String get licenses_empty_text => 'Try adjusting your search query';

  @override
  String get licenses_info_title => 'About open source licenses';

  @override
  String get licenses_info_body =>
      'This app uses various open source libraries and packages. Each license defines the terms under which the code can be used, modified, and distributed.\n\nWe are grateful to all the developers and contributors who make their work available under open source licenses.';

  @override
  String get licenses_got_it => 'Got it';

  @override
  String get licenses_detail_version => 'Version';

  @override
  String get licenses_detail_license => 'License';

  @override
  String get licenses_detail_copyright => 'Copyright';

  @override
  String get licenses_detail_url => 'URL';

  @override
  String get licenses_detail_description => 'Description';

  @override
  String get licenses_view_web => 'View on web';

  @override
  String licenses_opening(String url) {
    return 'Opening $url';
  }

  @override
  String get sfx_search_placeholder => 'Search people, games, posts…';

  @override
  String get sfx_recent => 'Recent';

  @override
  String get sfx_clear => 'Clear';

  @override
  String sfx_remove_recent(String query) {
    return 'Remove $query';
  }

  @override
  String get sfx_quick_filters => 'Quick filters';

  @override
  String get sfx_near_me => 'Near me';

  @override
  String get sfx_today => 'Today';

  @override
  String get sfx_this_week => 'This week';

  @override
  String get sfx_friends_only => 'Friends only';

  @override
  String get sfx_popular => 'Popular';

  @override
  String get sfx_free_entry => 'Free entry';

  @override
  String get sfx_people_nearby => 'People nearby';

  @override
  String get sfx_people_nearby_sub => 'Find players near you';

  @override
  String get sfx_popular_games => 'Popular games';

  @override
  String get sfx_popular_games_sub => 'Open spots today';

  @override
  String get sfx_trending_posts => 'Trending posts';

  @override
  String get sfx_trending_posts_sub => 'What everyone’s on';

  @override
  String get sfx_showing_results_for => 'Showing results for';

  @override
  String get sfx_view_all => 'View all';

  @override
  String get sfx_people => 'People';

  @override
  String get sfx_hashtags => 'Hashtags';

  @override
  String get sfx_games => 'Games';

  @override
  String get sfx_venues => 'Venues';

  @override
  String get sfx_posts => 'Posts';

  @override
  String get sfx_comments => 'Comments';

  @override
  String get sfx_meetups => 'Meet-ups';

  @override
  String get sfx_follow => 'Follow';

  @override
  String get sfx_join => 'Join';

  @override
  String get sfx_kind_game => 'Game';

  @override
  String get sfx_kind_meetup => 'Meet-up';

  @override
  String get sfx_spots => 'spots';

  @override
  String sfx_spots_meta(int joined, int max) {
    return '$joined/$max spots';
  }

  @override
  String sfx_posts_count(int count) {
    return '$count posts';
  }

  @override
  String sfx_on_post(String title) {
    return 'on $title';
  }

  @override
  String sfx_no_results_for(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String sfx_none_found(String label) {
    return 'No $label found';
  }

  @override
  String sfx_list_header(int count, String label, String query) {
    return '$count $label for \"$query\"';
  }

  @override
  String sfx_hashtag_empty(String slug) {
    return 'No posts found for #$slug';
  }

  @override
  String get sfx_retry => 'Retry';

  @override
  String get sfx_news => 'News';

  @override
  String get sfx_add_comment => 'Add a comment';

  @override
  String get sfx_discuss => 'Discuss';

  @override
  String get sfx_be_first => 'Be the first to comment.';

  @override
  String get sfx_like => 'Like';

  @override
  String get sfx_send => 'Send';

  @override
  String get sfx_share => 'Share';

  @override
  String get sfx_share_article => 'Share article';

  @override
  String get sfx_copy_link => 'Copy link';

  @override
  String get sfx_share_to => 'Share to…';

  @override
  String get sfx_link_copied => 'Link copied';

  @override
  String get sfx_events => 'games and meet-ups';

  @override
  String get composer_place_search => 'Search venues and areas';

  @override
  String get composer_results => 'Results';

  @override
  String get composer_places_none => 'No places match that search';

  @override
  String get composer_pick_date => 'Pick a date';

  @override
  String get composer_pick_time => 'Pick a time';

  @override
  String get composer_step_1 => 'Step 1 of 2';

  @override
  String get composer_step_2 => 'Step 2 of 2';

  @override
  String get composer_kickoff_time => 'Kickoff time';

  @override
  String get composer_continue_time => 'Continue to time';

  @override
  String get composer_done => 'Done';

  @override
  String composer_use_typed(String query) {
    return 'Use “$query”';
  }

  @override
  String composer_format_title(String sport) {
    return '$sport format';
  }

  @override
  String composer_players_count(int count) {
    return '$count players';
  }

  @override
  String composer_vibe_count(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vibes for $kind',
      one: '1 vibe for $kind',
    );
    return '$_temp0';
  }

  @override
  String get home_location_saved_home => 'Home';

  @override
  String get home_location_saved_work => 'Work';

  @override
  String get home_location_custom => 'Custom location';

  @override
  String get home_location_nearby_areas => 'Nearby areas';

  @override
  String get composer_games_joined_hint => 'Games you have joined';

  @override
  String get composer_content_class_title => 'Content Class';

  @override
  String get composer_content_class_social => 'Social';

  @override
  String get composer_content_class_editorial => 'Editorial';

  @override
  String get composer_content_class_social_sub => 'Standard social post';

  @override
  String get composer_content_class_editorial_sub =>
      'Editorial or long-form content';

  @override
  String composer_posting_as(String name) {
    return 'Posting as $name';
  }

  @override
  String composer_posting_as_switch(String name) {
    return 'Posting as $name. Tap to switch profile.';
  }

  @override
  String get composer_tool_value_set => 'set';

  @override
  String composer_tool_vibe_set(String name) {
    return 'Vibe: $name. Tap to change.';
  }

  @override
  String composer_tool_sport_set(String name) {
    return 'Sport: $name. Tap to change.';
  }

  @override
  String composer_tool_location_set(String name) {
    return 'Location: $name. Tap to change.';
  }

  @override
  String composer_tool_game_set(String name) {
    return 'Game: $name. Tap to change.';
  }

  @override
  String get composer_media_gif => 'GIF';

  @override
  String get composer_media_image => 'Image';

  @override
  String get composer_place_current_location => 'Current location';

  @override
  String get composer_place_recent_empty => 'No recent places';

  @override
  String get composer_place_location_denied =>
      'Turn on location to use your current place';

  @override
  String game_format_choose_sub(String sport) {
    return 'Choose the $sport format';
  }

  @override
  String get game_players_min => 'min';

  @override
  String get game_players_max => 'max';

  @override
  String game_sport_tile_semantic(String name) {
    return 'Sport: $name, tap to select';
  }

  @override
  String get game_create_failed => 'Failed to create game';

  @override
  String get game_save_failed => 'Failed to save changes';

  @override
  String get game_load_failed => 'Failed to load game';

  @override
  String get game_venue_search_placeholder => 'Search venues, spaces or area…';

  @override
  String get game_venue_none => 'No venues available for this format';

  @override
  String get game_error_sport_unavailable => 'Sport not available for games.';

  @override
  String get game_error_invalid_format => 'Invalid format for this sport.';

  @override
  String get game_error_invalid_time_range =>
      'End time must be after start time.';

  @override
  String get game_error_profile_incomplete => 'Complete your profile first.';

  @override
  String get game_error_not_editable => 'This game can no longer be edited.';

  @override
  String get game_error_player_range =>
      'Min players cannot exceed max players.';

  @override
  String get game_error_player_count_min => 'Player counts must be at least 1.';

  @override
  String game_error_daily_limit(String reset) {
    return 'Daily limit reached. Try again at $reset.';
  }

  @override
  String get game_error_generic => 'Something went wrong. Try again.';

  @override
  String composer_counter_semantic(int used, int max) {
    return '$used of $max characters used';
  }

  @override
  String get game_format_locked => 'Locked';

  @override
  String get game_duration_30m => '30m';

  @override
  String get game_duration_1h => '1h';

  @override
  String get game_duration_2h => '2h';

  @override
  String sfx_comments_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String get profile_section_my_sports => 'My sports';

  @override
  String get profile_section_their_sports => 'Their sports';

  @override
  String get profile_btn_manage => 'Manage';

  @override
  String get profile_sport_picker_all => 'All sports';

  @override
  String get profile_stat_rated => 'Rated by players';

  @override
  String get profile_stat_primary_sports => 'Primary sports';

  @override
  String profile_stat_sport_matches(String sport) {
    return '$sport matches';
  }

  @override
  String get profile_create_another_profile => 'Create another profile';

  @override
  String profile_create_persona_profile(String persona) {
    return 'Create $persona profile';
  }

  @override
  String sport_profile_overall_level(String sport, String level) {
    return '$sport · overall level $level';
  }

  @override
  String get profile_sports_followed_note =>
      'Sports followed — feeds and results only';

  @override
  String get profile_stat_sports_followed => 'Sports followed';

  @override
  String get profile_stat_minutes_played => 'Minutes played';

  @override
  String get meetups_tab_all => 'All';

  @override
  String get meetups_none_title => 'No meetups available.';

  @override
  String get meetups_explore_another => 'Explore another activity';

  @override
  String get meetups_load_failed => 'Couldn\'t load meetups';

  @override
  String get meetups_join => 'Join meetup';

  @override
  String get meetups_request => 'Request to join';

  @override
  String meetups_going_count(int count) {
    return '$count going';
  }

  @override
  String meetups_max(int count) {
    return 'Max $count';
  }

  @override
  String get meetups_free_note => 'no charge';

  @override
  String meetups_distance_km(String km) {
    return '$km km';
  }

  @override
  String get meetups_cta_going => 'Joining';

  @override
  String get meetups_cta_interested => 'Maybe going';

  @override
  String get meetups_cta_full => 'Full - you\'re interested';

  @override
  String get meetups_cta_closed => 'Registration closed';

  @override
  String get meetups_cta_cancelled => 'Cancelled';

  @override
  String get meetups_cta_started => 'Already started';

  @override
  String get meetups_cta_unavailable => 'Not available';

  @override
  String get meetups_cta_not_allowed => 'Switch profile to join';

  @override
  String get meetups_sheet_title => 'Are you going to this meetup?';

  @override
  String get meetups_sheet_cancel => 'Cancel';

  @override
  String get meetups_sheet_yes => 'Yes, I am going';

  @override
  String get meetups_sheet_maybe => 'Maybe';

  @override
  String get meetups_sheet_no => 'No, not this time';

  @override
  String get meetups_sheet_confirm => 'Confirm';

  @override
  String get meetups_error_generic => 'Something went wrong. Try again.';

  @override
  String get meetups_error_cancelled => 'This meetup was cancelled.';

  @override
  String get meetups_host_caption => 'Community host';

  @override
  String get meetups_tile_meeting_point => 'Meeting point';

  @override
  String get meetups_tile_entry => 'Entry';

  @override
  String get meetups_load_detail_failed => 'Couldn\'t load this meetup';

  @override
  String get meetups_back => 'Back';

  @override
  String meetups_names_and_others(String names, int count) {
    return '$names and $count others';
  }

  @override
  String meetups_show_count(int count) {
    return 'Show $count meetups';
  }

  @override
  String meetups_km_away(String km) {
    return '$km km away';
  }

  @override
  String get meetups_create_title => 'Create meet-up';

  @override
  String get meetups_create_title_hint => 'Meet up title';

  @override
  String get meetups_create_note_hint =>
      'Add short description for participations...';

  @override
  String get meetups_create_name_section => 'CHOOSE NAME AND DESCRIPTION';

  @override
  String get meetups_when => 'When';

  @override
  String get meetups_when_sub => 'Date and time';

  @override
  String get meetups_end => 'End';

  @override
  String get meetups_location => 'Location';

  @override
  String get meetups_location_sub => 'Add a location or venue';

  @override
  String get meetups_capacity => 'Capacity';

  @override
  String get meetups_capacity_sub => 'Max participants';

  @override
  String get meetups_advanced => 'Advanced options';

  @override
  String get meetups_policy => 'How people join';

  @override
  String get meetups_policy_sub => 'Join settings';

  @override
  String get meetups_policy_closed => 'Closed';

  @override
  String get meetups_skill => 'Skill range';

  @override
  String get meetups_skill_sub => 'Experience level';

  @override
  String get meetups_skill_any => 'Any';

  @override
  String get meetups_vibe => 'Vibe';

  @override
  String get meetups_vibe_sub => 'Set the mood';

  @override
  String get meetups_vibe_choose => 'Choose';

  @override
  String get meetups_create_failed => 'Failed to create meet-up';

  @override
  String get meetups_visibility => 'Who can see it';

  @override
  String get meetups_visibility_sub => 'Visibility settings';

  @override
  String get meetups_cost => 'Cost';

  @override
  String get meetups_cost_sub => 'Entry fee';

  @override
  String get meetups_err_location_required => 'Add a location for the meet-up.';

  @override
  String get meetups_sports_failed =>
      'Sports could not be loaded. Try again later.';

  @override
  String get game_err_create_refused =>
      'You can\'t create a game right now. Try again later.';

  @override
  String get meetups_err_create_refused =>
      'You can\'t create this meet-up right now. Try again later.';

  @override
  String get meetups_err_title_invalid =>
      'The title must be 3 to 80 characters.';

  @override
  String get meetups_err_invalid_time_range =>
      'The end time must be after the start time.';

  @override
  String get meetups_err_invalid_capacity => 'The capacity must be at least 1.';

  @override
  String get meetups_err_auth_required => 'Sign in to continue.';

  @override
  String get meetups_err_unsupported => 'This option is not available yet.';

  @override
  String get meetups_manage => 'Manage meetup';

  @override
  String get meetups_manage_title => 'Manage meet-up';

  @override
  String get meetups_section_going => 'Going';

  @override
  String get meetups_section_interested => 'Interested';

  @override
  String get meetups_section_pending => 'Requests';

  @override
  String get meetups_manage_empty => 'Nobody has responded yet.';

  @override
  String get meetups_approve => 'Approve';

  @override
  String get meetups_decline => 'Decline';

  @override
  String get meetups_remove => 'Remove';

  @override
  String meetups_remove_title(String name) {
    return 'Remove $name?';
  }

  @override
  String get meetups_remove_body =>
      'They will lose their spot and be notified.';

  @override
  String get meetups_edit => 'Edit meet-up';

  @override
  String get meetups_save => 'Save changes';

  @override
  String get meetups_cancel_meetup => 'Cancel meetup';

  @override
  String get meetups_cancel_title => 'Cancel this meet-up?';

  @override
  String get meetups_cancel_body =>
      'Everyone who responded will be told. This cannot be undone.';

  @override
  String get meetups_cancel_confirm => 'Cancel meet-up';

  @override
  String get meetups_keep => 'Keep it';

  @override
  String get meetups_err_capacity_below_going =>
      'The capacity is lower than the number already going.';

  @override
  String get meetups_err_not_host => 'Only the host can do this.';

  @override
  String get meetups_err_attendee_not_found =>
      'That person is no longer on this meet-up.';

  @override
  String get meetups_err_no_pending => 'That request is no longer pending.';

  @override
  String get meetups_save_failed => 'Couldn\'t save the changes';

  @override
  String get meetups_action_failed => 'That didn\'t work. Try again.';

  @override
  String get meetups_share => 'Share';

  @override
  String meetups_share_headline(String title) {
    return 'Join me for $title on Dabbler!';
  }

  @override
  String get meetups_more => 'More';

  @override
  String get meetups_report => 'Report meetup';

  @override
  String get meetups_report_note => 'Tell us what is wrong with this meet-up';

  @override
  String get venue_amenity_outdoor => 'Outdoor';

  @override
  String get venue_amenity_indoor => 'Indoor';

  @override
  String get venue_amenity_parking => 'Parking';

  @override
  String get venue_amenity_washrooms => 'Washrooms';

  @override
  String get venue_amenity_changing_rooms => 'Changing rooms';

  @override
  String get venue_amenity_showers => 'Showers';

  @override
  String get venue_amenity_lighting => 'Lighting';

  @override
  String get venue_amenity_cafeteria => 'Cafeteria';

  @override
  String get venue_amenity_wifi => 'Wifi';

  @override
  String get venue_amenity_first_aid => 'First aid';

  @override
  String get venue_amenity_accessibility => 'Accessibility';

  @override
  String get venue_amenity_gym => 'Gym';

  @override
  String get venue_amenity_locker_room => 'Locker room';

  @override
  String get venue_amenity_equipment_rental => 'Equipment rental';

  @override
  String get venue_amenity_air_conditioning => 'Air conditioning';

  @override
  String get venue_amenity_spectator_seating => 'Spectator seating';

  @override
  String get venue_amenity_vending => 'Vending machines';

  @override
  String get feedback_dismiss => 'Dismiss';

  @override
  String get feedback_joining => 'Joining…';

  @override
  String get feedback_join_failed => 'Couldn\'t join the game.';

  @override
  String checkin_done_day(int day, int total) {
    return 'Checked in! Day $day of $total';
  }

  @override
  String get checkin_badge_earned =>
      'Congratulations! You earned the Early Bird badge!';

  @override
  String get checkin_already => 'Already checked in today!';

  @override
  String get listing_badge_top_rated => 'Top rated';

  @override
  String get listing_badge_verified => 'Verified';

  @override
  String get listing_badge_open_now => 'Open now';

  @override
  String get listing_group_setting => 'Indoor / outdoor';

  @override
  String get listing_group_price_hour => 'Price per hour';

  @override
  String get listing_group_rating => 'Rating';

  @override
  String listing_price_up_to(String amount) {
    return 'Up to AED $amount';
  }

  @override
  String get listing_any_price => 'Any price';

  @override
  String listing_rating_and_up(String rating) {
    return '$rating and up';
  }

  @override
  String get listing_venue_sort_distance => 'Distance';

  @override
  String get listing_venue_sort_rating => 'Rating';

  @override
  String get listing_venue_sort_price => 'Lowest price';

  @override
  String get listing_expand_search => 'Expand search area';

  @override
  String get listing_venues_none_filters_text =>
      'Try loosening a filter or widening the search area.';

  @override
  String listing_reviews_count(String count) {
    return '($count)';
  }

  @override
  String get listing_this_weekend => 'This weekend';

  @override
  String get listing_sort_popular => 'Most popular';

  @override
  String get meetups_favourite => 'Add to favourites';

  @override
  String get meetups_unfavourite => 'Remove from favourites';

  @override
  String meetups_empty_text(String activity, String others) {
    return '$activity has no meetups right now. Sessions are coming up in $others.';
  }

  @override
  String listing_share_venue_headline(String name) {
    return 'Check out $name on Dabbler!';
  }

  @override
  String get skill_sub_beginner => 'Just getting started';

  @override
  String get skill_sub_intermediate => 'Plays regularly';

  @override
  String get skill_sub_advanced => 'Competitive level';

  @override
  String get listing_price_ask => 'Ask';

  @override
  String listing_price_aed(String amount) {
    return 'AED $amount';
  }

  @override
  String get game_price => 'Price';

  @override
  String get game_price_hint => 'Price per player, in AED';

  @override
  String get game_price_sub => 'Enter 0 for a free game';

  @override
  String get game_price_required => 'Enter a price — 0 means free';

  @override
  String get game_price_unit => 'AED';

  @override
  String get listing_popular => 'Popular';

  @override
  String get meetup_setting => 'Setting';

  @override
  String get meetup_setting_sub =>
      'Where it takes place when there is no venue';

  @override
  String get meetup_setting_required => 'Choose Indoor or Outdoor';

  @override
  String get fav_toast_game_added => 'Game added to favourites';

  @override
  String get fav_toast_game_removed => 'Game removed from favourites';

  @override
  String get fav_toast_venue_added => 'Venue added to favourites';

  @override
  String get fav_toast_venue_removed => 'Venue removed from favourites';

  @override
  String get fav_toast_meetup_added => 'Meetup added to favourites';

  @override
  String get fav_toast_meetup_removed => 'Meetup removed from favourites';

  @override
  String get fav_toast_error => 'Couldn\'t update favourites. Try again.';

  @override
  String listing_following_joined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count following',
    );
    return '$_temp0';
  }

  @override
  String listing_note_join(String first, String second) {
    return '$first · $second';
  }

  @override
  String get fav_title => 'Favourites';

  @override
  String get fav_back => 'Back';

  @override
  String get fav_ended => 'Ended';

  @override
  String get fav_remove => 'Remove from favourites';

  @override
  String get fav_empty_venues_title => 'No favourite venues yet.';

  @override
  String get fav_empty_venues_body =>
      'Tap the heart on a venue to save it here.';

  @override
  String get fav_empty_games_title => 'No favourite games yet.';

  @override
  String get fav_empty_games_body => 'Tap the heart on a game to save it here.';

  @override
  String get fav_empty_meetups_title => 'No favourite meetups yet.';

  @override
  String get fav_empty_meetups_body =>
      'Tap the heart on a meetup to save it here.';

  @override
  String get fav_load_failed => 'Couldn\'t load your favourites.';

  @override
  String get fav_retry => 'Try again';

  @override
  String fav_meta_players(int n, int cap) {
    return '$n/$cap players';
  }

  @override
  String fav_meta_going(int n) {
    return '$n going';
  }

  @override
  String fav_meta_went(int n) {
    return '$n went';
  }
}
