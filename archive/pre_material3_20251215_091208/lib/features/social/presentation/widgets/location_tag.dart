import 'package:flutter/material.dart';

/// Widget to display a location tag
class LocationTag extends StatelessWidget {
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onTap;
  final bool compact;

  const LocationTag({
    super.key,
    required this.name,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.onTap,
    this.compact = false,
  });

  factory LocationTag.fromJson(Map<String, dynamic> json) {
    return LocationTag(
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  String get _locationText {
    if (compact) return name;

    final parts = <String>[name];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);

    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _locationText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed location card with all information
class LocationCard extends StatelessWidget {
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onMapTap;
  final VoidCallback? onDirectionsTap;

  const LocationCard({
    super.key,
    required this.name,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.onMapTap,
    this.onDirectionsTap,
  });

  factory LocationCard.fromJson(Map<String, dynamic> json) {
    return LocationCard(
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  bool get _hasCoordinates => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (address != null && address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                address!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
            if (city != null || country != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  city,
                  country,
                ].where((e) => e != null && e.isNotEmpty).join(', '),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
            if (_hasCoordinates) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onMapTap != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMapTap,
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View Map'),
                      ),
                    ),
                  if (onMapTap != null && onDirectionsTap != null)
                    const SizedBox(width: 8),
                  if (onDirectionsTap != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDirectionsTap,
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Directions'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget to display location in a post header
class PostLocationTag extends StatelessWidget {
  final Map<String, dynamic>? locationTag;
  final VoidCallback? onTap;

  const PostLocationTag({super.key, this.locationTag, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (locationTag == null) return const SizedBox.shrink();

    final name = locationTag!['name'] ?? '';
    if (name.isEmpty) return const SizedBox.shrink();

    return LocationTag(
      name: name,
      address: locationTag!['address'],
      city: locationTag!['city'],
      country: locationTag!['country'],
      latitude: locationTag!['latitude']?.toDouble(),
      longitude: locationTag!['longitude']?.toDouble(),
      compact: true,
      onTap: onTap,
    );
  }
}
