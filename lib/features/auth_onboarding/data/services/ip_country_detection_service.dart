import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';

/// Result from IP-based location detection
class IpLocationResult {
  final String country;
  final String? city;

  IpLocationResult({required this.country, this.city});
}

/// Service to detect user's country and city from IP address via Supabase Edge Function.
///
/// This service calls the `detect-country` edge function which uses
/// Cloudflare's IP geolocation headers and ipapi.co to determine the user's location.
class IpCountryDetectionService {
  /// Detects the user's country and city from their IP address.
  ///
  /// Returns:
  /// - IpLocationResult with detected country name and city
  /// - country: The detected country name (e.g., "United Arab Emirates")
  /// - city: The detected city name (e.g., "Dubai") or null if unknown
  ///
  /// This method is safe to call and will never throw - always returns a fallback.
  Future<IpLocationResult> detectLocationFromIp() async {
    try {
      // Use direct HTTP call instead of Supabase Functions client
      // to avoid automatic JWT authorization header.
      // Note: The function currently requires JWT verification, so we send
      // the anon key as the Authorization bearer token.
      // TODO: Disable JWT verification in Supabase dashboard for this function
      // since it needs to work for unauthenticated users during signup.
      final url = Uri.parse(
        '${Environment.supabaseUrl}/functions/v1/detect-country',
      );

      final response = await http.get(
        url,
        headers: {
          'apikey': Environment.supabaseAnonKey,
          'Authorization': 'Bearer ${Environment.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      // Debug logging (suppressed in release so the IP-derived response body
      // is never written to production logs).
      if (kDebugMode) {
        debugPrint('IP Location Detection Response:');
        debugPrint('  Status: ${response.statusCode}');
        debugPrint('  Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final country = data['country'] as String?;
        final city = data['city'] as String?;
        final countryCode = data['countryCode'] as String?;
        final debug = data['debug'] as Map<String, dynamic>?;

        // Log debug info if available
        if (debug != null) {
          debugPrint('  Debug Info: $debug');
        }

        debugPrint('  Detected Country: $country ($countryCode), City: $city');

        return IpLocationResult(
          country:
              (country != null && country.isNotEmpty && country != 'Global')
              ? country
              : 'Global',
          city: city,
        );
      }

      // Fallback if response is invalid
      debugPrint('  Falling back to Global');
      return IpLocationResult(country: 'Global');
    } catch (e) {
      // Log the error for debugging
      debugPrint('IP Location Detection Error: $e');

      // Silently fail and return Global
      // This ensures the app continues working even if:
      // - Edge function is not deployed
      // - Network issues occur
      // - Cloudflare headers are missing
      return IpLocationResult(country: 'Global');
    }
  }

  /// Legacy method for backwards compatibility - returns only country
  Future<String> detectCountryFromIp() async {
    final result = await detectLocationFromIp();
    return result.country;
  }
}
