/// Core application constants
class AppConstants {
  // App Information
  static const String appName = 'Dabbler';
  static const String appVersion = '1.0.5';
  static const int buildNumber = 1;

  // Animation Durations
  static const Duration quickDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration quickAnimation = Duration(milliseconds: 150);
  static const Duration defaultAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 200);

  // Layout Constants
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double defaultPadding = 16.0;

  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;
  static const double defaultMargin = 16.0;

  // Border Radius
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircular = 999.0;
  static const double defaultRadius = 8.0;
  static const double defaultSpacing = 8.0;

  // Network and Cache
  static const int maxRetryAttempts = 3;
  static const Duration cacheDuration = Duration(days: 7);
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const Duration retryDelay = Duration(seconds: 1);
  static const Duration defaultCacheDuration = Duration(hours: 24);
  static const Duration shortCacheDuration = Duration(minutes: 30);
  static const Duration longCacheDuration = Duration(days: 7);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Image Quality
  static const int defaultImageQuality = 85;
  static const double defaultAspectRatio = 16 / 9;
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const double maxImageDimension = 1920.0;
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
  ];

  // Input Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 32;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  // File Size Limits (in bytes)
  static const int maxProfileImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxUploadFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxFileUploadSize = 10 * 1024 * 1024; // 10MB
  static const int maxAttachmentCount = 5;

  // Search
  static const Duration searchDebounceTime = Duration(milliseconds: 300);
  static const int minSearchLength = 2;

  // Error Messages
  static const String defaultErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'Please check your internet connection.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please login again.';

  // Date Formats
  static const String defaultDateFormat = 'dd MMM yyyy';
  static const String defaultTimeFormat = 'HH:mm';
  static const String defaultDateTimeFormat = 'dd MMM yyyy HH:mm';

  // Regular Expressions
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  static final RegExp phoneRegex = RegExp(r'^\+?[0-9]{10,}$');
  static final RegExp urlRegex = RegExp(
    r'^https?:\/\/([\w\d-]+\.)*[\w-]+\.[a-z]+',
  );
}
