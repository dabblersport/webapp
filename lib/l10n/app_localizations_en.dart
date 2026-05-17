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
  String get create_info_gender => 'Gender';

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
  String get interests_title_hoster => 'Which sports do you host?';

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
  String get welcome_screen_chip_hoster => 'Venue host';

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
  String get welcome_screen_hoster_guidance =>
      'Help players feel welcome by keeping information accurate and spaces ready.';

  @override
  String get welcome_screen_hoster_philosophy =>
      'Clear availability and smooth coordination make everyone\'s experience better.';

  @override
  String get welcome_screen_hoster_reminder =>
      'Keep availability and details accurate.\nUpdate information as soon as things change.';

  @override
  String get welcome_screen_hoster_emphasis =>
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
  String get onboarding_welcome_step_persona => 'Setting up your persona';

  @override
  String get onboarding_welcome_step_sport => 'Adding sport profile';

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
  String get nav_create_post => 'Create Post';

  @override
  String get nav_create_game => 'Create Game';

  @override
  String get nav_create_meetup => 'Create Meetup';

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
  String get persona_label_hoster => 'Host';

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
  String get profile_btn_edit => 'Edit profile';

  @override
  String get profile_btn_share => 'Share profile';

  @override
  String get profile_btn_manage_profiles_tooltip => 'Manage profiles';

  @override
  String get profile_manage_profiles_title => 'Manage Profiles';

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
  String get user_profile_stat_games => 'Games';

  @override
  String get user_profile_stat_win_rate => 'Win rate';

  @override
  String get user_profile_stat_sports => 'Sports';

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
}
