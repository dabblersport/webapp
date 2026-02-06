import 'dart:convert';

import 'package:http/http.dart' as http;

/// Simple utility service to fetch the user's public IP address.
///
/// This uses a lightweight external API and is designed to be called
/// on-demand rather than continuously.
class IpService {
  IpService._internal();
  static final IpService _instance = IpService._internal();
  factory IpService() => _instance;

  String? _cachedIp;

  /// Returns the last successfully fetched IP if available.
  String? get cachedIp => _cachedIp;

  /// Fetch the current public IP address.
  ///
  /// Returns `null` if the IP cannot be determined.
  Future<String?> fetchPublicIp() async {
    try {
      final uri = Uri.parse('https://api.ipify.org?format=json');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return _cachedIp;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final ip = data['ip'] as String?;
      if (ip != null && ip.isNotEmpty) {
        _cachedIp = ip;
      }
      return _cachedIp;
    } catch (_) {
      // On any failure, fall back to the last known IP (if any).
      return _cachedIp;
    }
  }
}
