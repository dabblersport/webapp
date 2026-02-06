import 'dart:ui' as ui;
import 'package:dabbler/features/auth_onboarding/data/services/ip_country_detection_service.dart';

/// Result from location detection
class LocationDetectionResult {
  final String country;
  final String? city;

  LocationDetectionResult({required this.country, this.city});
}

/// Read-only utility for detecting user's country and city during onboarding.
///
/// This utility determines the location to suggest to the user based on:
/// 1. IP-derived country and city (via Supabase Edge Function)
/// 2. Device locale country code (country only)
/// 3. Fallback to "Global" if unavailable
///
/// Note: This does NOT write to database or persist data.
class LocationDetector {
  /// Detects the user's country and city for onboarding purposes.
  ///
  /// Priority order:
  /// 1. **IP-derived location**: Calls Supabase edge function to detect country
  ///    and city from the user's IP address using ipapi.co.
  ///
  /// 2. **Device locale country**: Reads the device's locale settings to extract
  ///    the country code (e.g., "US", "AE", "GB"). This is converted to a full
  ///    country name using a predefined mapping. (No city from this source)
  ///
  /// 3. **Fallback**: If both above methods fail, returns "Global" as a safe default.
  ///
  /// Returns:
  /// - LocationDetectionResult with country name and optional city
  ///
  /// This function is:
  /// - Pure (no side effects)
  /// - Deterministic (same input = same output)
  /// - Safe to call multiple times
  ///
  /// Example usage:
  /// ```dart
  /// final result = await LocationDetector.detectUserLocation();
  /// print(result.country); // "United Arab Emirates" or "Global"
  /// print(result.city);    // "Dubai" or null
  /// ```
  static Future<LocationDetectionResult> detectUserLocation() async {
    try {
      // Step 1: Try IP-based location detection first (most accurate, includes city)
      try {
        final ipService = IpCountryDetectionService();
        final ipResult = await ipService.detectLocationFromIp();

        if (ipResult.country != 'Global') {
          print(
            'Location detected from IP: ${ipResult.country}, ${ipResult.city}',
          );
          return LocationDetectionResult(
            country: ipResult.country,
            city: ipResult.city,
          );
        }
      } catch (e) {
        print('IP detection failed: $e');
      }

      // Step 2: Fallback to device locale country (no city available)
      final locale = ui.PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode;

      if (countryCode != null && countryCode.isNotEmpty) {
        final countryName = _countryCodeToName(countryCode);
        if (countryName != null) {
          print(
            'Country detected from device locale: $countryName ($countryCode)',
          );
          return LocationDetectionResult(country: countryName);
        }
      }

      // Step 3: Fallback to "Global"
      print('Falling back to Global');
      return LocationDetectionResult(country: 'Global');
    } catch (e) {
      print('Location detection error: $e');
      return LocationDetectionResult(country: 'Global');
    }
  }

  /// Legacy method for backwards compatibility - returns only country
  static Future<String> detectUserCountry() async {
    final result = await detectUserLocation();
    return result.country;
  }

  /// Maps ISO 3166-1 alpha-2 country codes to full country names.
  ///
  /// This mapping is limited to commonly used countries in the app's target market.
  /// If a country code is not found here, it will fall back to "Global".
  ///
  /// Note: These country names must match the format used in `profiles.country`
  /// column in the database. Update this list if country naming convention changes.
  static String? _countryCodeToName(String code) {
    final upperCode = code.toUpperCase();

    // Common countries mapping (extend as needed for target markets)
    const countryMap = {
      'AE': 'United Arab Emirates',
      'US': 'United States',
      'GB': 'United Kingdom',
      'SA': 'Saudi Arabia',
      'QA': 'Qatar',
      'KW': 'Kuwait',
      'BH': 'Bahrain',
      'OM': 'Oman',
      'IN': 'India',
      'PK': 'Pakistan',
      'EG': 'Egypt',
      'JO': 'Jordan',
      'LB': 'Lebanon',
      'CA': 'Canada',
      'AU': 'Australia',
      'DE': 'Germany',
      'FR': 'France',
      'ES': 'Spain',
      'IT': 'Italy',
      'NL': 'Netherlands',
      'SE': 'Sweden',
      'NO': 'Norway',
      'DK': 'Denmark',
      'FI': 'Finland',
      'SG': 'Singapore',
      'MY': 'Malaysia',
      'TH': 'Thailand',
      'PH': 'Philippines',
      'ID': 'Indonesia',
      'JP': 'Japan',
      'KR': 'South Korea',
      'CN': 'China',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'AR': 'Argentina',
      'ZA': 'South Africa',
      'NG': 'Nigeria',
      'KE': 'Kenya',
      'NZ': 'New Zealand',
    };

    return countryMap[upperCode];
  }
}
