import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Dabbler Player';
  static const String appVersion = '1.0.5';
  static const String appBuildNumber = '1';

  // API Constants
  static const String apiBaseUrl = 'https://api.dabbler.com';
  static const String apiVersion = '/v1';
  static const int apiTimeout = 30000; // 30 seconds

  // Storage Keys
  static const String userKey = 'user';
  static const String languageKey = 'language';
  static const String themeKey = 'theme';
  static const String authTokenKey = 'auth_token';
  static const String onboardingCompletedKey = 'onboarding_completed';

  // User Roles
  static const String roleGuest = 'guest';
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';

  // Languages
  static const String languageEnglish = 'en';
  static const String languageArabic = 'ar';

  // Themes
  static const String themeLight = 'light';
  static const String themeDark = 'dark';
  static const String themeSystem = 'system';

  // Match Status
  static const String matchStatusUpcoming = 'upcoming';
  static const String matchStatusOngoing = 'ongoing';
  static const String matchStatusCompleted = 'completed';
  static const String matchStatusCancelled = 'cancelled';

  // Booking Status
  static const String bookingStatusConfirmed = 'confirmed';
  static const String bookingStatusPending = 'pending';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusCompleted = 'completed';

  // Payment Status
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusRefunded = 'refunded';

  // Venue Status
  static const String venueStatusActive = 'active';
  static const String venueStatusInactive = 'inactive';
  static const String venueStatusMaintenance = 'maintenance';

  // Notification Types
  static const String notificationTypeMatch = 'match';
  static const String notificationTypeBooking = 'booking';
  static const String notificationTypeSystem = 'system';
  static const String notificationTypePromo = 'promo';

  // Notification Status
  static const String notificationStatusUnread = 'unread';
  static const String notificationStatusRead = 'read';

  // Sports
  static const List<String> availableSports = [
    'football',
    'cricket',
    'paddle',
    'basketball',
    'tennis',
    'volleyball',
    'badminton',
    'table_tennis',
    'baseball',
    'rugby',
    'hockey',
  ];

  // Intents
  static const List<String> availableIntents = [
    'competitive',
    'casual',
    'training',
    'social',
    'fitness',
  ];

  // Amenities
  static const List<String> availableAmenities = [
    'parking',
    'shower',
    'locker_room',
    'equipment_rental',
    'cafe',
    'wifi',
    'air_conditioning',
    'lighting',
    'spectator_seating',
    'first_aid',
  ];

  // Validation
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  static const int minNameLength =
      5; // Updated to require at least 5 characters
  static const int maxNameLength = 50;
  static const int minAge = 13;
  static const int maxAge = 100;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Debounce
  static const int searchDebounceMs = 500;
  static const int inputDebounceMs = 300;

  // Cache
  static const int cacheExpiryHours = 24;
  static const int maxCacheSize = 100; // MB

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File Upload
  static const int maxImageSize = 5; // MB
  static const int maxFileSize = 10; // MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedFileTypes = ['pdf', 'doc', 'docx'];

  // Location
  static const double defaultLatitude = 25.2048; // Dubai
  static const double defaultLongitude = 55.2708;
  static const double maxSearchRadius = 50.0; // km

  // Time
  static const int matchReminderHours = 1;
  static const int bookingCancellationHours = 24;
  static const int sessionTimeoutMinutes = 30;

  // Error Messages
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'Please check your internet connection.';
  static const String unauthorizedErrorMessage = 'Please sign in to continue.';
  static const String forbiddenErrorMessage =
      'You don\'t have permission to perform this action.';
  static const String notFoundErrorMessage =
      'The requested resource was not found.';
  static const String validationErrorMessage =
      'Please check your input and try again.';

  // Accessibility Constants
  static const double minTouchTargetSize =
      44.0; // iOS/Android accessibility guidelines
  static const double minFocusTargetSize = 48.0; // Material Design guidelines
  static const double minContrastRatio = 4.5; // WCAG AA standard
  static const double largeContrastRatio = 7.0; // WCAG AAA standard

  // Semantic Labels
  static const String profileAvatarLabel = 'Profile picture';
  static const String editProfileLabel = 'Edit profile';
  static const String settingsLabel = 'Settings';
  static const String refreshLabel = 'Refresh profile';
  static const String logoutLabel = 'Logout';
  static const String helpLabel = 'Help and support';
  static const String statsLabel = 'Game statistics';
  static const String sportsLabel = 'Preferred sports';
  static const String verificationLabel = 'Verified profile';
  static const String incompleteLabel = 'Profile incomplete';

  // Profile Module Specific Constants
  static const double profileAvatarSize = 80.0;
  static const double profileCardElevation = 4.0;
  static const double statsCardElevation = 2.0;
  static const double menuItemHeight = 56.0;
  static const double chipHeight = 32.0;
  static const double iconSize = 24.0;
  static const double smallIconSize = 20.0;
  static const double largeIconSize = 28.0;

  // Profile Module Spacing
  static const double profileHeaderPadding = 8.0;
  static const double profileCardPadding = 16.0;
  static const double statsSpacing = 20.0;
  static const double menuSpacing = 24.0;
  static const double chipSpacing = 8.0;
  static const double sectionSpacing = 16.0;

  // Profile Module Colors (Theme-aware)
  static const Color profileIncompleteColor = Color(0xFFFF9800); // Orange
  static const Color profileVerifiedColor = Color(0xFF2196F3); // Blue
  static const Color profileSuccessColor = Color(0xFF4CAF50); // Green
  static const Color profileWarningColor = Color(0xFFFFC107); // Amber
  static const Color profileErrorColor = Color(0xFFF44336); // Red

  // Profile Module Typography
  static const double profileTitleSize = 24.0;
  static const double profileSubtitleSize = 16.0;
  static const double profileBodySize = 14.0;
  static const double profileCaptionSize = 12.0;
  static const double statsValueSize = 20.0;
  static const double statsLabelSize = 12.0;

  // Profile Module Animation
  static const Duration profileRefreshDuration = Duration(milliseconds: 300);
  static const Duration profileCardAnimationDuration = Duration(
    milliseconds: 200,
  );
  static const Duration profileAvatarAnimationDuration = Duration(
    milliseconds: 150,
  );

  // Profile Module Loading States
  static const Duration profileLoadingTimeout = Duration(seconds: 10);
  static const Duration profileRefreshTimeout = Duration(seconds: 5);

  // Profile Module Error Messages
  static const String profileLoadError =
      'Failed to load profile. Please try again.';
  static const String profileUpdateError =
      'Failed to update profile. Please try again.';
  static const String avatarUploadError =
      'Failed to upload profile picture. Please try again.';
  static const String statsLoadError = 'Failed to load game statistics.';
  static const String logoutError = 'Failed to logout. Please try again.';

  // Profile Module Success Messages
  static const String profileUpdateSuccess = 'Profile updated successfully!';
  static const String avatarUploadSuccess =
      'Profile picture updated successfully!';
  static const String logoutSuccess = 'Logged out successfully!';

  // Profile Module Confirmation Messages
  static const String logoutConfirmationTitle = 'Confirm Logout';
  static const String logoutConfirmationMessage =
      'Are you sure you want to logout?';
  static const String logoutConfirmationCancel = 'Cancel';
  static const String logoutConfirmationConfirm = 'Logout';
}
