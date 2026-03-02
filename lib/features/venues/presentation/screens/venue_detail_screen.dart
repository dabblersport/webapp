import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/venues/providers.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool? _favoriteOptimistic;
  bool _favoriteBusy = false;

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
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');
    final favoriteIdsAsync = ref.watch(favoriteVenueIdsForCurrentUserProvider);
    final isFavoritedFromProvider = favoriteIdsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.venueId),
      orElse: () => false,
    );
    final isFavorited = _favoriteOptimistic ?? isFavoritedFromProvider;
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: venueAsync.when(
        data: (venue) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(
                      venue,
                      sportsScheme,
                      textTheme,
                      isFavorited: isFavorited,
                    ),
                    const SizedBox(height: 24),
                    _buildHeroSection(venue, sportsScheme, textTheme),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickInfoCards(venue, textTheme, sportsScheme),
                    const SizedBox(height: 20),
                    _buildAboutSection(venue, textTheme, sportsScheme),
                    const SizedBox(height: 20),
                    _buildSportsSection(venue, textTheme, sportsScheme),
                    const SizedBox(height: 20),
                    _buildAmenitiesSection(venue, textTheme, sportsScheme),
                    const SizedBox(height: 20),
                    _buildHoursSection(venue, textTheme, sportsScheme),
                    const SizedBox(height: 20),
                    _buildBottomBar(venue, sportsScheme, textTheme),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(child: _buildLoadingTop(textTheme)),
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, stack) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(child: _buildLoadingTop(textTheme)),
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.danger_copy,
                          size: 48, color: sportsScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load venue',
                        style: textTheme.titleMedium?.copyWith(
                          color: sportsScheme.onSecondaryContainer,
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingTop(TextTheme textTheme) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Iconsax.arrow_left_copy),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Venue details',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(
    dynamic venue,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool isFavorited,
  }) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Iconsax.arrow_left_copy),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
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
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: _shareVenue,
          icon: const Icon(Iconsax.share_copy),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _favoriteBusy ? null : () => _toggleFavorite(isFavorited),
          icon: Icon(
            isFavorited ? Iconsax.bookmark_2_copy : Iconsax.bookmark_copy,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
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
    final isOpen = venue.isOpenAt(DateTime.now());
    final statusColor = isOpen
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final statusTextColor = isOpen
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    // Minimal hero that relies on TwoSectionLayout's top background.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Location
          Builder(
            builder: (context) {
              final city = (venue.city?.toString() ?? '').trim();
              final country = (venue.country?.toString() ?? '').trim();
              final locationText = <String>[
                city,
                country,
              ].where((value) => value.isNotEmpty).join(', ');

              // Conservative max width so it won't overflow even with long names.
              final maxChipLabelWidth = (MediaQuery.sizeOf(context).width - 220)
                  .clamp(120.0, double.infinity)
                  .toDouble();

              return Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOpen
                              ? Iconsax.tick_circle_copy
                              : Iconsax.close_circle_copy,
                          size: 16,
                          color: statusTextColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOpen ? 'OPEN' : 'CLOSED',
                          style: textTheme.labelMedium?.copyWith(
                            color: statusTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.location_copy,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxChipLabelWidth,
                          ),
                          child: Text(
                            locationText.isEmpty
                                ? 'Location unavailable'
                                : locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.9,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Venue name
          Text(
            venue.name,
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
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
    final priceText = venue.priceText;
    final phone = (venue.phone as String?)?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    final ratingText = venue.totalRatings == 0
        ? 'No ratings'
        : venue.rating.toStringAsFixed(1);

    return Card.filled(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Iconsax.card_copy, size: 20, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Price',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  priceText,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (FeatureFlags.venuesBooking) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Iconsax.star_copy,
                    size: 20,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rating',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    ratingText,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.call_copy,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPhone ? phone : 'Not available',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: hasPhone ? () => _callVenue(phone) : null,
                  icon: Icon(Iconsax.call_copy, color: colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
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
        Card.filled(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(0),
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
        Card.filled(
          color: colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFootballSport(sport))
                        Text(
                          '⚽️',
                          style: textTheme.bodyMedium?.copyWith(height: 1),
                        )
                      else
                        Icon(
                          _getSportIcon(sport),
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        sport,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  bool _isFootballSport(String sport) {
    final value = sport.trim().toLowerCase();
    return value == 'football' || value == 'soccer';
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
        Card.filled(
          color: colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    borderRadius: BorderRadius.circular(20),
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
    final openingTime = (venue.openingTime as String).trim();
    final closingTime = (venue.closingTime as String).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operating Hours',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card.filled(
          color: colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.clock_copy,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Hours',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${openingTime.isEmpty ? '—' : openingTime} - ${closingTime.isEmpty ? '—' : closingTime}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

    return Card.filled(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceRange,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addressFirstLine,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Iconsax.routing_copy),
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
        return Iconsax.game_copy;
      case 'tennis':
        return Iconsax.activity_copy;
      case 'soccer':
        return Iconsax.ticket_2_copy;
      case 'football':
        return Iconsax.ticket_2_copy;
      case 'volleyball':
        return Iconsax.activity_copy;
      default:
        return Iconsax.activity_copy;
    }
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'free parking':
      case 'parking':
        return Iconsax.building_copy;
      case 'restrooms':
        return Iconsax.building_copy;
      case 'water fountain':
      case 'water':
        return Iconsax.tick_circle_copy;
      case 'lighting':
        return Iconsax.tick_circle_copy;
      case 'seating area':
      case 'seating':
        return Iconsax.tick_circle_copy;
      case 'locker rooms':
        return Iconsax.lock_copy;
      case 'snack bar':
        return Iconsax.tick_circle_copy;
      case 'wifi':
        return Iconsax.wifi_square_copy;
      case 'pro shop':
        return Iconsax.building_copy;
      case 'restaurant':
        return Iconsax.building_copy;
      case 'gym':
        return Iconsax.activity_copy;
      default:
        return Iconsax.tick_circle_copy;
    }
  }

  void _showInfoSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.fixed),
      );
  }

  void _shareVenue() {
    _showInfoSnackBar('Sharing venue...');
  }

  Future<void> _toggleFavorite(bool currentlyFavorited) async {
    if (_favoriteBusy) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      _showInfoSnackBar('Sign in to save venues');
      return;
    }

    setState(() {
      _favoriteBusy = true;
      _favoriteOptimistic = !currentlyFavorited;
    });

    final repository = ref.read(games_providers.venuesRepositoryProvider);
    final result = await repository.toggleVenueFavorite(widget.venueId, userId);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _favoriteBusy = false;
          _favoriteOptimistic = currentlyFavorited;
        });
        _showInfoSnackBar(failure.message);
      },
      (_) {
        ref.invalidate(favoriteVenuesForCurrentUserProvider);
        ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        setState(() {
          _favoriteBusy = false;
          _favoriteOptimistic = null;
        });
        _showInfoSnackBar(currentlyFavorited ? 'Removed from saved' : 'Saved');
      },
    );
  }

  void _getDirections() {
    _showInfoSnackBar('Opening directions...');
  }

  void _callVenue(String phone) {
    _launchPhoneDialer(phone);
  }

  String _normalizePhoneForTelUri(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final ch = trimmed[i];
      final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
      if (isDigit) {
        buffer.write(ch);
        continue;
      }
      if (ch == '+' && buffer.isEmpty) {
        buffer.write(ch);
      }
    }

    return buffer.toString();
  }

  Future<void> _launchPhoneDialer(String phone) async {
    final normalized = _normalizePhoneForTelUri(phone);
    if (normalized.isEmpty) {
      if (!mounted) return;
      _showInfoSnackBar('Phone number not available');
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showInfoSnackBar('Calling is not supported on this device');
      }
    } catch (_) {
      if (!mounted) return;
      _showInfoSnackBar('Could not open the phone dialer');
    }
  }
}
