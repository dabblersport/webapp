import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/venues/providers.dart';
import 'package:dabbler/core/design_system/design_system.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  // Mock data as fallback (will be replaced by real data from provider)
  final Map<String, dynamic> _venueData = {
    'id': '1',
    'name': 'Central Park Basketball Court',
    'description':
        'A beautiful outdoor basketball court located in the heart of Central Park. Features professional-grade surfaces and equipment with stunning city views.',
    'address': '123 Main Street, New York, NY 10001',
    'coordinates': {'lat': 40.7831, 'lng': -73.9712},
    'phone': '+1 (555) 123-4567',
    'email': 'info@centralparkcourt.com',
    'website': 'www.centralparkcourt.com',
    'rating': 4.5,
    'reviewCount': 128,
    'priceRange': 'Free',
    'images': [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/image3.jpg',
    ],
    'sports': ['Basketball', 'Tennis'],
    'amenities': [
      'Free Parking',
      'Restrooms',
      'Water Fountain',
      'Lighting',
      'Seating Area',
    ],
    'features': [
      'Outdoor Courts',
      '2 Basketball Courts',
      'Professional Grade Surface',
      'Spectator Seating',
    ],
    'hours': {
      'monday': '6:00 AM - 10:00 PM',
      'tuesday': '6:00 AM - 10:00 PM',
      'wednesday': '6:00 AM - 10:00 PM',
      'thursday': '6:00 AM - 10:00 PM',
      'friday': '6:00 AM - 11:00 PM',
      'saturday': '7:00 AM - 11:00 PM',
      'sunday': '7:00 AM - 10:00 PM',
    },
    'isOpen': true,
    'openUntil': '10:00 PM',
    'rules': [
      'No glass containers allowed',
      'Clean up after yourself',
      'Be respectful to other players',
      'No loud music after 8 PM',
      'Maximum 2 hours per session during peak hours',
    ],
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailProvider(widget.venueId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: venueAsync.when(
          data: (venue) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildHeaderSection(venue, colorScheme, textTheme),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildHeroSection(venue, colorScheme, textTheme),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickInfoCards(venue, textTheme, colorScheme),
                      const SizedBox(height: 20),
                      _buildAboutSection(venue, textTheme, colorScheme),
                      const SizedBox(height: 20),
                      _buildSportsSection(venue, textTheme, colorScheme),
                      const SizedBox(height: 20),
                      _buildAmenitiesSection(venue, textTheme, colorScheme),
                      const SizedBox(height: 20),
                      _buildHoursSection(venue, textTheme, colorScheme),
                      const SizedBox(height: 20),
                      _buildRulesSection(textTheme, colorScheme),
                    ],
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load venue',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.refresh(venueDetailProvider(widget.venueId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: venueAsync.maybeWhen(
        data: (venue) => _buildBottomBar(venue, colorScheme, textTheme),
        orElse: () => null,
      ),
    );
  }

  Widget _buildHeaderSection(
    dynamic venue,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Venue details',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                venue.city ?? 'Community venue',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: _shareVenue,
          icon: const Icon(Icons.share_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _toggleFavorite,
          icon: const Icon(Icons.favorite_border_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }

  // Hero Section - Material 3 minimal design
  Widget _buildHeroSection(
    dynamic venue,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final isOpen = _venueData['isOpen'] as bool;
    final statusColor = isOpen
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final statusTextColor = isOpen
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isOpen ? 'OPEN' : 'CLOSED',
              style: textTheme.labelMedium?.copyWith(
                color: statusTextColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Venue name
          Text(
            venue.name,
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Location
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: textColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${venue.city}, ${venue.country}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Info Cards - Material 3 style
  Widget _buildQuickInfoCards(
    dynamic venue,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Price Card
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payments,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Price',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${venue.pricePerHour.toStringAsFixed(0)}/${venue.currency}',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Rating Card
            if (FeatureFlags.venuesBooking)
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Rating',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_venueData['rating']}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Contact Card
        AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.phone,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _venueData['phone'] as String,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _callVenue,
                icon: Icon(Icons.call, color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // About Section
  Widget _buildAboutSection(
    dynamic venue,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Text(
            venue.description.isEmpty
                ? 'No description available'
                : venue.description,
            style: textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // Sports Section
  Widget _buildSportsSection(
    dynamic venue,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final sports = venue.supportedSports as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports Available',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sports.map((sport) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSportIcon(sport),
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sport,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Amenities Section
  Widget _buildAmenitiesSection(
    dynamic venue,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final amenities = venue.amenities as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amenities',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenities.map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getAmenityIcon(amenity),
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      amenity,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Hours Section
  Widget _buildHoursSection(
    dynamic venue,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final openingTime = venue.openingTime ?? '—';
    final closingTime = venue.closingTime ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operating Hours',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.schedule,
                  color: colorScheme.onTertiaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Hours',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$openingTime - $closingTime',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Rules Section
  Widget _buildRulesSection(TextTheme textTheme, ColorScheme colorScheme) {
    final rules = _venueData['rules'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Venue Rules',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rules.asMap().entries.map((entry) {
              final isLast = entry.key == rules.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Bottom Bar - Material 3 style
  Widget _buildBottomBar(
    dynamic venue,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final priceRange =
        '\$${venue.pricePerHour.toStringAsFixed(0)}/${venue.currency}';
    final addressFirstLine = venue.addressLine1.isNotEmpty
        ? venue.addressLine1
        : 'Address not available';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceRange,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    addressFirstLine,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            FilledButton.icon(
              onPressed: _getDirections,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.directions),
              label: const Text(
                'Directions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'soccer':
        return Icons.sports_soccer;
      case 'football':
        return Icons.sports_football;
      case 'volleyball':
        return Icons.sports_volleyball;
      default:
        return Icons.sports;
    }
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'free parking':
      case 'parking':
        return Icons.local_parking;
      case 'restrooms':
        return Icons.wc;
      case 'water fountain':
      case 'water':
        return Icons.water_drop;
      case 'lighting':
        return Icons.lightbulb;
      case 'seating area':
      case 'seating':
        return Icons.chair;
      case 'locker rooms':
        return Icons.lock;
      case 'snack bar':
        return Icons.restaurant;
      case 'wifi':
        return Icons.wifi;
      case 'pro shop':
        return Icons.store;
      case 'restaurant':
        return Icons.restaurant_menu;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.check_circle;
    }
  }

  void _shareVenue() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sharing venue...')));
  }

  void _toggleFavorite() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to favorites')));
  }

  void _getDirections() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening directions...')));
  }

  void _callVenue() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Calling ${_venueData['phone']}')));
  }
}
