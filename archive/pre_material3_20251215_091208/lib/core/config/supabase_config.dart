class SupabaseConfig {
  // Storage bucket names
  static const String avatarsBucket = 'avatars';
  static const String venueImagesBucket = 'venue-images';

  // Table names
  static const String usersTable =
      'profiles'; // Changed from 'users' to 'profiles' to match actual database schema
  static const String venuesTable = 'venues';
  static const String matchesTable = 'matches';
  static const String matchParticipantsTable = 'match_participants';
  static const String matchWaitlistTable = 'match_waitlist';

  // RPC function names
  static const String searchMatchesFunction = 'search_matches';
  static const String getNearbyVenuesFunction = 'get_nearby_venues';

  // Real-time channels
  static const String matchesChannel = 'matches';
  static const String participantsChannel = 'match_participants';

  // Auth settings
  static const bool enableEmailConfirmations = false;
  static const bool enablePhoneConfirmations = true;
  static const int sessionTimeout = 3600; // 1 hour in seconds

  // API settings
  static const int maxRowsPerRequest = 1000;
  static const int defaultPageSize = 20;

  // Cache settings
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const int maxCacheSize = 100; // number of items

  // File upload settings
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];

  // Validation rules
  static const int minPasswordLength = 8;
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 500;
  static const int maxParticipants = 50;
  static const int minParticipants = 2;

  // Error messages
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String authErrorMessage =
      'Authentication failed. Please try again.';
  static const String permissionErrorMessage =
      'You don\'t have permission to perform this action.';
  static const String validationErrorMessage =
      'Please check your input and try again.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';

  // Success messages
  static const String matchCreatedMessage = 'Match created successfully!';
  static const String matchUpdatedMessage = 'Match updated successfully!';
  static const String matchJoinedMessage = 'Successfully joined the match!';
  static const String matchLeftMessage = 'Left the match successfully.';
  static const String profileUpdatedMessage = 'Profile updated successfully!';

  // Default values
  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150';
  static const String defaultVenueImageUrl =
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800';
  static const double defaultRating = 4.5;
  static const List<String> defaultAmenities = ['Parking', 'Equipment'];

  // Sports configuration
  static const Map<String, List<String>> sportFormats = {
    'football': ['Futsal', 'Competitive', 'Substitutional', 'Association'],
    'basketball': ['3 vs 3', '5 vs 5'],
    'tennis': ['Singles', 'Doubles'],
    'padel': ['Singles', 'Doubles'],
    'squash': ['Singles', 'Doubles'],
  };

  static const Map<String, int> sportDefaultDurations = {
    'football': 90,
    'basketball': 60,
    'tennis': 120,
    'padel': 90,
    'squash': 60,
  };

  static const Map<String, int> sportMaxParticipants = {
    'football': 22,
    'basketball': 10,
    'tennis': 4,
    'padel': 4,
    'squash': 4,
  };
}
