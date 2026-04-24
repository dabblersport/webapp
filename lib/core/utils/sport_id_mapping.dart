/// Sport ID mapping from sport names to UUIDs
/// This maps sport keys (like 'football', 'padel') to their database UUIDs
class SportIdMapping {
  static const Map<String, String> _sportNameToId = {
    'football': '4fd36109-12c2-4b17-a8a2-281be2b8649c',
    'cricket': '6cfa352f-ecad-4594-8e2a-dc868d155090',
    'padel': '2502490a-0339-436c-8b5e-5ac1514606c9',
    'basketball': 'aefa2f62-eef9-47d1-b5b7-fb255c0a4fcd',
    'tennis': '5a3bf560-70c2-4be9-ad35-6fc4cbf33b16',
    'badminton': '3013da22-b866-4dbd-9936-a9d677491247',
    'gym': '91554c52-47b4-40e2-bf45-5f3b1e67f64a',
    'running': '84651f8f-7089-475e-8e06-725bab0a3e26',
    'swimming': '91e83dd8-58f3-4cca-83eb-019dc368f4e7',
    'equestrianism': 'fd9ce8df-4b5c-468f-aea2-dc39d2e93fd7',
    'shooting': '077ac568-e659-4ccc-be8c-35bfec654467',
  };

  /// Get sport ID from sport name (case-insensitive)
  static String? getSportId(String sportName) {
    return _sportNameToId[sportName.toLowerCase()];
  }

  /// Check if a sport name has a valid ID mapping
  static bool hasSportId(String sportName) {
    return _sportNameToId.containsKey(sportName.toLowerCase());
  }

  /// Get all available sport names
  static List<String> get availableSportNames => _sportNameToId.keys.toList();
}
