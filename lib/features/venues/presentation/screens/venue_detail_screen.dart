import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/venues/providers.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/widgets/dynamic_background.dart';
import 'package:dabbler/data/models/games/venue.dart' as games_venue;

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool? _favoriteOptimistic;
  bool _favoriteBusy = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailProvider(widget.venueId));
    final favoriteIdsAsync = ref.watch(favoriteVenueIdsForCurrentUserProvider);
    final isFavoritedFromProvider = favoriteIdsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.venueId),
      orElse: () => false,
    );
    final isFavorited = _favoriteOptimistic ?? isFavoritedFromProvider;
    final cs = Theme.of(context).colorScheme;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(scrollController: _scrollController),
          venueAsync.when(
            data: (venue) => _buildContent(venue, isFavorited, safeTop, cs),
            loading: () => _buildLoading(safeTop, cs),
            error: (error, _) => _buildError(safeTop, cs),
          ),
        ],
      ),
    );
  }

  // ─── Main content ────────────────────────────────────────────────────────────

  Widget _buildContent(
    games_venue.Venue venue,
    bool isFavorited,
    double safeTop,
    ColorScheme cs,
  ) {
    final tt = Theme.of(context).textTheme;
    final isOpen = venue.isOpenAt(DateTime.now());

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Safe area top
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 8)),

        // Header: back + share + bookmark
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _buildHeader(isFavorited, cs),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Hero: name + status chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildHero(venue, isOpen, tt, cs),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Location card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildLocationCard(venue, tt, cs),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Rating + Price row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRatingPriceRow(venue, tt, cs),
          ),
        ),

        // Contact card (only if any contact info exists)
        if (_hasContact(venue)) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildContactCard(venue, tt, cs),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Operating hours
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildHoursCard(venue, isOpen, tt, cs),
          ),
        ),

        // Sports section
        if (venue.supportedSports.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSportsSection(venue, tt, cs),
            ),
          ),
        ],

        // Amenities section
        if (venue.amenities.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildAmenitiesSection(venue, tt, cs),
            ),
          ),
        ],

        // About / description
        if (venue.description.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildAboutSection(venue, tt, cs),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Actions bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionsBar(venue, cs),
          ),
        ),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
        ),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isFavorited, ColorScheme cs) {
    return Row(
      children: [
        _circleButton(
          icon: Iconsax.arrow_left_copy,
          cs: cs,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        _circleButton(
          icon: Iconsax.share_copy,
          cs: cs,
          onTap: _shareVenue,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: isFavorited ? Iconsax.bookmark_2_copy : Iconsax.bookmark_copy,
          cs: cs,
          onTap: _favoriteBusy ? null : () => _toggleFavorite(isFavorited),
          iconColor: isFavorited ? cs.primary : null,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required ColorScheme cs,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? cs.onSurface,
        ),
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────────────────────────────

  Widget _buildHero(
    games_venue.Venue venue,
    bool isOpen,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          venue.name,
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusChip(isOpen, cs, tt),
            _pillChip(
              label: venue.city.isNotEmpty ? venue.city : 'Unknown location',
              icon: Iconsax.location_copy,
              cs: cs,
              tt: tt,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(bool isOpen, ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen
            ? cs.secondaryContainer
            : cs.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Iconsax.tick_circle_copy : Iconsax.close_circle_copy,
            size: 14,
            color: isOpen ? cs.onSecondaryContainer : cs.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Open Now' : 'Closed',
            style: tt.labelSmall?.copyWith(
              color: isOpen ? cs.onSecondaryContainer : cs.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillChip({
    required String label,
    required IconData icon,
    required ColorScheme cs,
    required TextTheme tt,
    Color? color,
  }) {
    final textColor = color ?? cs.onSurface.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location ─────────────────────────────────────────────────────────────────

  Widget _buildLocationCard(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final parts = <String>[
      if (venue.addressLine1.isNotEmpty) venue.addressLine1,
      if (venue.city.isNotEmpty) venue.city,
      if (venue.state.isNotEmpty) venue.state,
      if (venue.country.isNotEmpty) venue.country,
    ];
    final address = parts.join(', ');

    return GestureDetector(
      onTap: _getDirections,
      child: Card.filled(
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Iconsax.location_copy, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.isEmpty ? 'Address unavailable' : address,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.routing_copy,
                size: 18,
                color: cs.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Rating + Price ───────────────────────────────────────────────────────────

  Widget _buildRatingPriceRow(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Expanded(child: _infoCard(
          icon: Iconsax.star_copy,
          label: 'Rating',
          value: venue.totalRatings == 0
              ? 'No ratings'
              : venue.rating.toStringAsFixed(1),
          subValue: venue.totalRatings == 0
              ? null
              : '${venue.totalRatings} reviews',
          iconColor: cs.tertiary,
          cs: cs,
          tt: tt,
        )),
        const SizedBox(width: 12),
        Expanded(child: _infoCard(
          icon: Iconsax.card_copy,
          label: 'Price',
          value: venue.pricePerHour == 0
              ? 'Free'
              : '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}',
          subValue: venue.pricePerHour == 0 ? null : 'per hour',
          iconColor: cs.primary,
          cs: cs,
          tt: tt,
        )),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    required Color iconColor,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Card.filled(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            if (subValue != null)
              Text(
                subValue,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Contact ──────────────────────────────────────────────────────────────────

  bool _hasContact(games_venue.Venue v) =>
      (v.phone?.isNotEmpty ?? false) ||
      (v.email?.isNotEmpty ?? false) ||
      (v.website?.isNotEmpty ?? false);

  Widget _buildContactCard(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Card.filled(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (venue.phone?.isNotEmpty ?? false)
              _contactRow(
                icon: Iconsax.call_copy,
                text: venue.phone!,
                cs: cs,
                tt: tt,
                onTap: () => _callVenue(venue.phone!),
              ),
            if (venue.email?.isNotEmpty ?? false)
              _contactRow(
                icon: Iconsax.sms_copy,
                text: venue.email!,
                cs: cs,
                tt: tt,
              ),
            if (venue.website?.isNotEmpty ?? false)
              _contactRow(
                icon: Iconsax.global_copy,
                text: venue.website!,
                cs: cs,
                tt: tt,
                onTap: () => _openWebsite(venue.website!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String text,
    required ColorScheme cs,
    required TextTheme tt,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: tt.bodyMedium?.copyWith(
                  color: onTap != null ? cs.primary : cs.onSurface,
                  fontWeight: FontWeight.w500,
                  decoration: onTap != null ? TextDecoration.underline : null,
                  decorationColor: cs.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ─── Hours ────────────────────────────────────────────────────────────────────

  Widget _buildHoursCard(
    games_venue.Venue venue,
    bool isOpen,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final hours = '${venue.openingTime} – ${venue.closingTime}';

    return Card.filled(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Iconsax.clock_copy, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operating Hours',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hours,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOpen
                    ? cs.secondaryContainer
                    : cs.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isOpen ? 'Open' : 'Closed',
                style: tt.labelSmall?.copyWith(
                  color: isOpen ? cs.onSecondaryContainer : cs.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sports ───────────────────────────────────────────────────────────────────

  Widget _buildSportsSection(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: venue.supportedSports.map((sport) {
            final isFootball = _isFootball(sport);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFootball)
                    const Text('⚽', style: TextStyle(fontSize: 14))
                  else
                    Icon(Iconsax.activity_copy, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    sport,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _isFootball(String sport) {
    final v = sport.trim().toLowerCase();
    return v == 'football' || v == 'soccer';
  }

  // ─── Amenities ────────────────────────────────────────────────────────────────

  Widget _buildAmenitiesSection(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amenities',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: venue.amenities.map((amenity) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getAmenityIcon(amenity),
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    amenity,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.trim().toLowerCase()) {
      case 'parking':
      case 'free parking':
        return Iconsax.car_copy;
      case 'wifi':
        return Iconsax.wifi_square_copy;
      case 'locker rooms':
      case 'changing rooms':
        return Iconsax.lock_copy;
      case 'lighting':
        return Iconsax.lamp_on_copy;
      case 'gym':
        return Iconsax.activity_copy;
      case 'restaurant':
      case 'snack bar':
        return Iconsax.coffee_copy;
      default:
        return Iconsax.tick_circle_copy;
    }
  }

  // ─── About ────────────────────────────────────────────────────────────────────

  Widget _buildAboutSection(
    games_venue.Venue venue,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          venue.description,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ─── Actions bar ──────────────────────────────────────────────────────────────

  Widget _buildActionsBar(games_venue.Venue venue, ColorScheme cs) {
    final hasPhone = venue.phone?.isNotEmpty ?? false;
    final hasWebsite = venue.website?.isNotEmpty ?? false;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _getDirections,
            icon: const Icon(Iconsax.routing_copy, size: 18),
            label: const Text('Directions'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (hasPhone) ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _callVenue(venue.phone!),
              icon: const Icon(Iconsax.call_copy, size: 18),
              label: const Text('Call'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
        if (hasWebsite) ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _openWebsite(venue.website!),
              icon: const Icon(Iconsax.global_copy, size: 18),
              label: const Text('Website'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Loading state ────────────────────────────────────────────────────────────

  Widget _buildLoading(double safeTop, ColorScheme cs) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                _shimmerBox(40, 40, cs, circle: true),
                const Spacer(),
                _shimmerBox(40, 40, cs, circle: true),
                const SizedBox(width: 8),
                _shimmerBox(40, 40, cs, circle: true),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _shimmerBox(double.infinity, 32, cs),
                const SizedBox(height: 10),
                _shimmerBox(180, 20, cs),
                const SizedBox(height: 20),
                _shimmerBox(double.infinity, 80, cs),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _shimmerBox(double.infinity, 90, cs)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(double.infinity, 90, cs)),
                ]),
                const SizedBox(height: 12),
                _shimmerBox(double.infinity, 100, cs),
                const SizedBox(height: 12),
                _shimmerBox(double.infinity, 80, cs),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(
    double width,
    double height,
    ColorScheme cs, {
    bool circle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: circle
            ? BorderRadius.circular(999)
            : BorderRadius.circular(12),
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────────

  Widget _buildError(double safeTop, ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                _circleButton(
                  icon: Iconsax.arrow_left_copy,
                  cs: cs,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.danger_copy, size: 56, color: cs.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load venue',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────────

  void _shareVenue() => _snack('Sharing coming soon');

  Future<void> _toggleFavorite(bool currentlyFavorited) async {
    if (_favoriteBusy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      _snack('Sign in to save venues');
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
        _snack(failure.message);
      },
      (_) {
        ref.invalidate(favoriteVenuesForCurrentUserProvider);
        ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        setState(() {
          _favoriteBusy = false;
          _favoriteOptimistic = null;
        });
        _snack(currentlyFavorited ? 'Removed from saved' : 'Saved');
      },
    );
  }

  void _getDirections() {
    final async = ref.read(venueDetailProvider(widget.venueId));
    async.whenData((venue) {
      _launchUrl(
        'https://www.google.com/maps?q=${venue.latitude},${venue.longitude}',
      );
    });
  }

  void _callVenue(String phone) => _launchPhoneDialer(phone);

  void _openWebsite(String url) {
    final uri = url.startsWith('http') ? url : 'https://$url';
    _launchUrl(uri);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Could not open link');
    }
  }

  Future<void> _launchPhoneDialer(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) { _snack('Phone number not available'); return; }
    final uri = Uri(scheme: 'tel', path: normalized);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) _snack('Calling not supported on this device');
    } catch (_) {
      if (mounted) _snack('Could not open phone dialer');
    }
  }

  String _normalizePhone(String input) {
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) { buf.write(ch); continue; }
      if (ch == '+' && buf.isEmpty) buf.write(ch);
    }
    return buf.toString();
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
