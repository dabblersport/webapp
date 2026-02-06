/// Configuration for sport-specific filters
/// Each sport has its own set of filters that are displayed in the filter drawer
class SportFiltersConfig {
  // ==================== FOOTBALL ====================

  static const List<String> footballGameTypes = [
    'All',
    'Futsal',
    '5-a-side',
    '7-a-side',
    '11-a-side',
    'Competitive',
    'Casual',
  ];

  static const List<String> footballSurfaceTypes = [
    'Grass',
    'Artificial Turf',
    'Indoor Court',
    'Concrete',
  ];

  // ==================== CRICKET ====================

  static const List<String> cricketGameTypes = [
    'All',
    'T20',
    'ODI',
    'Test Match',
    'Box Cricket',
  ];

  static const List<String> cricketBallTypes = [
    'Tennis Ball',
    'Leather Ball',
    'Season Ball',
    'Soft Ball',
  ];

  static const List<String> cricketOverFormats = [
    '6 Overs',
    '8 Overs',
    '10 Overs',
    '12 Overs',
    '20 Overs',
    '50 Overs',
  ];

  static const List<String> cricketPitchTypes = [
    'Turf',
    'Concrete',
    'Matting',
    'Astro Turf',
  ];

  // ==================== PADEL ====================

  static const List<String> padelGameTypes = [
    'All',
    'Singles',
    'Doubles',
    'Mixed Doubles',
  ];

  static const List<String> padelCourtTypes = ['Indoor', 'Outdoor', 'Covered'];

  static const List<String> padelSurfaceTypes = [
    'Artificial Grass',
    'Cement',
    'Porcelain',
  ];

  // ==================== HELPER METHODS ====================

  /// Get all game types for a specific sport
  static List<String> getGameTypesForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return footballGameTypes;
      case 'cricket':
        return cricketGameTypes;
      case 'padel':
        return padelGameTypes;
      default:
        return ['All'];
    }
  }

  /// Check if a sport has specific filters
  static bool hasSportSpecificFilters(String sport) {
    return ['football', 'cricket', 'padel'].contains(sport.toLowerCase());
  }

  /// Get filter display name
  static String getFilterDisplayName(String filterKey) {
    switch (filterKey) {
      case 'gameType':
        return 'Game Type';
      case 'ballType':
        return 'Ball Type';
      case 'overFormat':
        return 'Over Format';
      case 'pitchType':
        return 'Pitch Type';
      case 'surfaceType':
        return 'Surface Type';
      case 'courtType':
        return 'Court Type';
      default:
        return filterKey;
    }
  }
}
