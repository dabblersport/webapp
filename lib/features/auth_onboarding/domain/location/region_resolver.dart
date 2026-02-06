/// Pure utility for resolving geographic regions from country names.
///
/// This utility maps country names to their corresponding geographic regions.
/// It is used for:
/// - Country selector UI grouping
/// - Sports popularity grouping
/// - Regional content customization
///
/// Note: This does NOT query databases, use external APIs, or persist data.
/// It is a pure, side-effect-free function.
class RegionResolver {
  /// Resolves the geographic region for a given country.
  ///
  /// Behavior:
  /// 1. If country is null, empty, or "Global" → returns "Global"
  /// 2. If country matches a known mapping → returns its region
  /// 3. If country is unknown → returns "Global" (safe fallback)
  ///
  /// Returns one of these fixed region values:
  /// - Middle East
  /// - Africa
  /// - Europe
  /// - East Asia
  /// - South Asia
  /// - Central Asia
  /// - North America
  /// - South America
  /// - Central America
  /// - Caribbean
  /// - Oceania
  /// - Global (fallback)
  ///
  /// This function is:
  /// - Pure (no side effects)
  /// - Deterministic (same input = same output)
  /// - Safe to call multiple times
  ///
  /// Example usage:
  /// ```dart
  /// final region = RegionResolver.resolveRegionFromCountry('United Arab Emirates');
  /// print(region); // "Middle East"
  ///
  /// final unknownRegion = RegionResolver.resolveRegionFromCountry('Unknown Country');
  /// print(unknownRegion); // "Global"
  /// ```
  static String resolveRegionFromCountry(String? country) {
    // Step 1: Handle null, empty, or "Global" input
    if (country == null || country.isEmpty || country == 'Global') {
      return 'Global';
    }

    // Step 2: Lookup country in hardcoded mapping
    final region = _countryToRegionMap[country];

    // Step 3: Return region if found, otherwise fallback to "Global"
    return region ?? 'Global';
  }

  /// Hardcoded mapping of country names to geographic regions.
  ///
  /// This mapping matches country names as they appear in the LocationDetector
  /// and in the profiles.country database column.
  ///
  /// Fallback behavior: If a country is not in this map, the resolver returns
  /// "Global" to ensure the function never fails.
  ///
  /// Note: Country names must be exact matches (case-sensitive).
  static const Map<String, String> _countryToRegionMap = {
    // Middle East
    'United Arab Emirates': 'Middle East',
    'Saudi Arabia': 'Middle East',
    'Qatar': 'Middle East',
    'Kuwait': 'Middle East',
    'Bahrain': 'Middle East',
    'Oman': 'Middle East',
    'Jordan': 'Middle East',
    'Egypt': 'Middle East',
    'Lebanon': 'Middle East',

    // Africa
    'Morocco': 'Africa',
    'Algeria': 'Africa',
    'Tunisia': 'Africa',
    'Nigeria': 'Africa',
    'Kenya': 'Africa',
    'South Africa': 'Africa',

    // Europe
    'United Kingdom': 'Europe',
    'France': 'Europe',
    'Germany': 'Europe',
    'Italy': 'Europe',
    'Spain': 'Europe',
    'Netherlands': 'Europe',
    'Sweden': 'Europe',
    'Norway': 'Europe',
    'Denmark': 'Europe',
    'Finland': 'Europe',

    // South Asia
    'India': 'South Asia',
    'Pakistan': 'South Asia',
    'Sri Lanka': 'South Asia',
    'Bangladesh': 'South Asia',

    // East Asia
    'China': 'East Asia',
    'Japan': 'East Asia',
    'South Korea': 'East Asia',

    // Southeast Asia (commonly grouped separately from East Asia)
    'Singapore': 'East Asia',
    'Malaysia': 'East Asia',
    'Thailand': 'East Asia',
    'Philippines': 'East Asia',
    'Indonesia': 'East Asia',

    // North America
    'United States': 'North America',
    'Canada': 'North America',

    // South America
    'Brazil': 'South America',
    'Argentina': 'South America',

    // Central America
    'Mexico': 'Central America',

    // Oceania
    'Australia': 'Oceania',
    'New Zealand': 'Oceania',
  };

  /// Returns all supported region names.
  ///
  /// This can be used for validation or UI purposes (e.g., dropdown lists).
  static const List<String> supportedRegions = [
    'Middle East',
    'Africa',
    'Europe',
    'East Asia',
    'South Asia',
    'Central Asia',
    'North America',
    'South America',
    'Central America',
    'Caribbean',
    'Oceania',
    'Global',
  ];
}
