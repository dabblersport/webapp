import 'dart:async';
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
import 'package:dabbler/themes/app_theme.dart';

// ─── Sport palette ────────────────────────────────────────────────────────────

class _SportMeta {
  final Color color;
  final String emoji;
  final String label;
  const _SportMeta({required this.color, required this.emoji, required this.label});
}

const _sportMeta = <String, _SportMeta>{
  'football':   _SportMeta(color: Color(0xFF00C853), emoji: '⚽', label: 'Football'),
  'soccer':     _SportMeta(color: Color(0xFF00C853), emoji: '⚽', label: 'Football'),
  'basketball': _SportMeta(color: Color(0xFFFF6D00), emoji: '🏀', label: 'Basketball'),
  'tennis':     _SportMeta(color: Color(0xFFF4C430), emoji: '🎾', label: 'Tennis'),
  'padel':      _SportMeta(color: Color(0xFF7328CE), emoji: '🏓', label: 'Padel'),
  'cricket':    _SportMeta(color: Color(0xFF8BC34A), emoji: '🏏', label: 'Cricket'),
  'swimming':   _SportMeta(color: Color(0xFF00BCD4), emoji: '🏊', label: 'Swimming'),
  'running':    _SportMeta(color: Color(0xFF00B0FF), emoji: '🏃', label: 'Running'),
  'gym':        _SportMeta(color: Color(0xFFE040FB), emoji: '🏋', label: 'Gym'),
  'yoga':       _SportMeta(color: Color(0xFFFF3376), emoji: '🧘', label: 'Yoga'),
};

const _green = Color(0xFF00C853);

_SportMeta _metaFor(String sport) =>
    _sportMeta[sport.trim().toLowerCase()] ??
    const _SportMeta(color: Color(0xFF7328CE), emoji: '🏟', label: 'Sport');

// ─── Screen ───────────────────────────────────────────────────────────────────

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
  late final String _previousCategory;

  @override
  void initState() {
    super.initState();
    _previousCategory = AppTheme.activeCategory;
    AppTheme.setActiveCategory('sports');
  }

  @override
  void dispose() {
    AppTheme.setActiveCategory(_previousCategory);
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
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(scrollController: _scrollController),
          venueAsync.when(
            data: (venue) => _buildContent(venue, isFavorited, safeTop),
            loading: () => _buildLoading(safeTop),
            error: (_, __) => _buildError(safeTop),
          ),
        ],
      ),
    );
  }

  // ─── Content ─────────────────────────────────────────────────────────────────

  Widget _buildContent(games_venue.Venue venue, bool isFavorited, double safeTop) {
    final cs = Theme.of(context).colorScheme;
    final sports = venue.supportedSports.isNotEmpty ? venue.supportedSports : ['sport'];
    final isOpen = venue.isOpenAt(DateTime.now());

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero carousel — full width, no horizontal padding
        SliverToBoxAdapter(
          child: _HeroCarousel(
            sports: sports,
            venueName: venue.name,
            safeTop: safeTop,
            isFavorited: isFavorited,
            favoriteBusy: _favoriteBusy,
            bgColor: cs.surfaceContainerLowest,
            primaryColor: cs.primary,
            onBack: () => Navigator.of(context).maybePop(),
            onShare: _shareVenue,
            onFavorite: () => _toggleFavorite(isFavorited),
          ),
        ),

        // Title + status pills
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: _buildTitle(venue, isOpen),
          ),
        ),

        // Rating + Spaces card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _buildRatingSpacesCard(venue),
          ),
        ),

        // Spaces section header
        if (venue.supportedSports.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _sectionHeader('Spaces', sub: 'tap for details'),
            ),
          ),
          // Full-bleed horizontal scroll
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: venue.supportedSports.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _SpaceCard(
                  sport: venue.supportedSports[i],
                  pricePerHour: venue.pricePerHour,
                  currency: venue.currency,
                  onTap: () => _showSpaceSheet(ctx, venue.supportedSports[i], venue),
                ),
              ),
            ),
          ),
        ],

        // Location card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: _buildLocationCard(venue),
          ),
        ),

        // Contact card
        if (_hasContact(venue))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _buildContactCard(venue),
            ),
          ),

        // Amenities
        if (venue.amenities.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildAmenities(venue),
            ),
          ),

        // About
        if (venue.description.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildAbout(venue),
            ),
          ),

        // Ratings
        if (venue.totalRatings > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: _buildRatings(venue),
            ),
          ),

        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ),
      ],
    );
  }

  // ─── Title ────────────────────────────────────────────────────────────────────

  Widget _buildTitle(games_venue.Venue venue, bool isOpen) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          venue.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _openBadge(isOpen),
            if (venue.city.isNotEmpty)
              _infoPill(icon: Iconsax.location_copy, label: venue.city),
            if (venue.openingTime.isNotEmpty && venue.closingTime.isNotEmpty)
              _infoPill(
                icon: Iconsax.clock_copy,
                label: '${venue.openingTime} – ${venue.closingTime}',
              ),
          ],
        ),
      ],
    );
  }

  Widget _openBadge(bool isOpen) {
    final color = isOpen ? _green : const Color(0xFFFF3376);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'Open Now' : 'Closed',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoPill({required IconData icon, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ─── Rating + Spaces card ─────────────────────────────────────────────────────

  Widget _buildRatingSpacesCard(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.star_copy, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('RATING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  venue.totalRatings == 0 ? '—' : venue.rating.toStringAsFixed(1),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
                ),
                Text(
                  venue.totalRatings == 0 ? 'No ratings yet' : '${venue.totalRatings} reviews',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 44, color: cs.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.calendar_copy, size: 13, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('SPACES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.supportedSports.isNotEmpty ? '${venue.supportedSports.length}' : '—',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary),
                  ),
                  Text('Bookable areas', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location card ────────────────────────────────────────────────────────────

  Widget _buildLocationCard(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[
      if (venue.addressLine1.isNotEmpty) venue.addressLine1,
      if (venue.city.isNotEmpty) venue.city,
      if (venue.state.isNotEmpty) venue.state,
      if (venue.country.isNotEmpty) venue.country,
    ];
    final address = parts.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Mini map
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: GestureDetector(
              onTap: _getDirections,
              child: SizedBox(
                height: 90,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cs.primary.withValues(alpha: 0.2), cs.primary.withValues(alpha: 0.12)],
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(double.infinity, 90),
                      painter: _MapGridPainter(color: cs.primary),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Iconsax.location_copy, size: 14, color: Colors.white),
                          ),
                          Container(width: 2, height: 6, color: cs.primary),
                          Container(
                            width: 6, height: 3,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.map_copy, size: 12, color: cs.primary),
                            const SizedBox(width: 4),
                            Text('Open Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Address
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Iconsax.location_copy, size: 16, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(
                        address.isEmpty ? 'Address unavailable' : address,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Contact card ─────────────────────────────────────────────────────────────

  bool _hasContact(games_venue.Venue v) =>
      (v.phone?.isNotEmpty ?? false) ||
      (v.email?.isNotEmpty ?? false) ||
      (v.website?.isNotEmpty ?? false);

  Widget _buildContactCard(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    final rows = <({IconData icon, String label, Color color, VoidCallback? onTap})>[
      if (venue.phone?.isNotEmpty ?? false)
        (icon: Iconsax.call_copy, label: venue.phone!, color: _green, onTap: () => _callVenue(venue.phone!)),
      if (venue.email?.isNotEmpty ?? false)
        (icon: Iconsax.sms_copy, label: venue.email!, color: cs.primary, onTap: null),
      if (venue.website?.isNotEmpty ?? false)
        (icon: Iconsax.global_copy, label: venue.website!, color: cs.primary, onTap: () => _openWebsite(venue.website!)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONTACT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Column(
              children: [
                if (i > 0) Container(height: 1, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 10)),
                GestureDetector(
                  onTap: row.onTap,
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: row.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(row.icon, size: 16, color: row.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.label,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: row.onTap != null ? row.color : cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (row.onTap != null)
                        Icon(Icons.chevron_right_rounded, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Amenities ────────────────────────────────────────────────────────────────

  Widget _buildAmenities(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Amenities'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: venue.amenities.map((a) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_amenityIcon(a), size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(a, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: cs.onSurface)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _amenityIcon(String a) {
    switch (a.trim().toLowerCase()) {
      case 'parking':
      case 'free parking':  return Iconsax.car_copy;
      case 'wifi':          return Iconsax.wifi_square_copy;
      case 'lighting':      return Iconsax.lamp_on_copy;
      case 'gym':           return Iconsax.activity_copy;
      case 'restaurant':
      case 'cafe':
      case 'cafeteria':
      case 'snack bar':     return Iconsax.coffee_copy;
      case 'locker rooms':
      case 'changing rooms':
      case 'changing':      return Iconsax.lock_copy;
      case 'showers':       return Iconsax.drop;
      default:              return Iconsax.tick_circle_copy;
    }
  }

  // ─── About ────────────────────────────────────────────────────────────────────

  Widget _buildAbout(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('About'),
        const SizedBox(height: 10),
        _card(
          child: Text(
            venue.description,
            style: TextStyle(fontSize: 14, height: 1.7, color: cs.onSurfaceVariant, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }

  // ─── Ratings ─────────────────────────────────────────────────────────────────

  Widget _buildRatings(games_venue.Venue venue) {
    final cs = Theme.of(context).colorScheme;
    final avg = venue.rating;
    final filled = avg.round().clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Ratings & Reviews'),
        const SizedBox(height: 10),
        _card(
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: cs.onSurface, letterSpacing: -2, height: 1),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        i < filled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: const Color(0xFFF4C430),
                      ),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text('${venue.totalRatings} reviews', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((n) {
                    final fraction = n == filled ? 0.6 : (n == filled + 1 || n == filled - 1) ? 0.3 : 0.1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text('$n', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 10, color: Color(0xFFF4C430)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 6,
                                backgroundColor: cs.surfaceContainerLow,
                                color: n >= 4 ? cs.primary : n == 3 ? const Color(0xFFF4C430) : cs.outlineVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? sub}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.1)),
        if (sub != null) ...[
          const SizedBox(width: 6),
          Text('· $sub', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  // ─── Space detail bottom sheet ───────────────────────────────────────────────

  void _showSpaceSheet(BuildContext ctx, String sport, games_venue.Venue venue) {
    final meta = _metaFor(sport);
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.15),
                    border: Border.all(color: meta.color.withValues(alpha: 0.3), width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
                      Text('Sport Space', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  venue.pricePerHour == 0 ? 'Free' : '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}/hr',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: venue.pricePerHour == 0 ? _green : meta.color),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statTile('Hours', '${venue.openingTime}–${venue.closingTime}', Icons.schedule_rounded),
                const SizedBox(width: 8),
                _statTile('Lighting', 'Yes', Icons.lightbulb_outline_rounded),
                const SizedBox(width: 8),
                _statTile('Type', 'Outdoor', Icons.landscape_rounded),
              ],
            ),
            // const SizedBox(height: 16),
            // SizedBox(
            //   width: double.infinity, height: 48,
            //   child: FilledButton(
            //     onPressed: () => Navigator.pop(ctx),
            //     style: FilledButton.styleFrom(
            //       backgroundColor: cs.primary,
            //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            //     ),
            //     child: const Text('Book Space', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          border: Border.all(color: cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface)),
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────────

  Widget _buildLoading(double safeTop) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _shimmer(double.infinity, 240 + safeTop, radius: 0)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(220, 28),
                const SizedBox(height: 10),
                _shimmer(160, 20),
                const SizedBox(height: 16),
                _shimmer(double.infinity, 80),
                const SizedBox(height: 12),
                _shimmer(double.infinity, 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmer(double w, double h, {double radius = 12}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: w, height: h,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────────

  Widget _buildError(double safeTop) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Iconsax.arrow_left_copy, size: 18, color: Colors.white),
              ),
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
                  const Icon(Iconsax.danger_copy, size: 56, color: Color(0xFFFF3376)),
                  const SizedBox(height: 16),
                  Text('Failed to load venue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Please check your connection and try again.', style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => ref.refresh(venueDetailProvider(widget.venueId)),
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

  // ─── Actions ─────────────────────────────────────────────────────────────────

  void _shareVenue() => _snack('Sharing coming soon');

  Future<void> _toggleFavorite(bool currentlyFavorited) async {
    if (_favoriteBusy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) { _snack('Sign in to save venues'); return; }
    setState(() { _favoriteBusy = true; _favoriteOptimistic = !currentlyFavorited; });
    final repository = ref.read(games_providers.venuesRepositoryProvider);
    final result = await repository.toggleVenueFavorite(widget.venueId, userId);
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() { _favoriteBusy = false; _favoriteOptimistic = currentlyFavorited; });
        _snack(failure.message);
      },
      (_) {
        ref.invalidate(favoriteVenuesForCurrentUserProvider);
        ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        setState(() { _favoriteBusy = false; _favoriteOptimistic = null; });
        _snack(currentlyFavorited ? 'Removed from saved' : 'Saved');
      },
    );
  }

  void _getDirections() {
    final async = ref.read(venueDetailProvider(widget.venueId));
    async.whenData((venue) => _launchUrl('https://www.google.com/maps?q=${venue.latitude},${venue.longitude}'));
  }

  void _callVenue(String phone) => _launchPhoneDialer(phone);

  void _openWebsite(String url) => _launchUrl(url.startsWith('http') ? url : 'https://$url');

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Could not open link');
    }
  }

  Future<void> _launchPhoneDialer(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) { _snack('Phone number not available'); return; }
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: normalized), mode: LaunchMode.externalApplication);
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
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m..clearSnackBars()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

// ─── Hero carousel ────────────────────────────────────────────────────────────

class _HeroCarousel extends StatefulWidget {
  final List<String> sports;
  final String venueName;
  final double safeTop;
  final bool isFavorited;
  final bool favoriteBusy;
  final Color bgColor;
  final Color primaryColor;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _HeroCarousel({
    required this.sports,
    required this.venueName,
    required this.safeTop,
    required this.isFavorited,
    required this.favoriteBusy,
    required this.bgColor,
    required this.primaryColor,
    required this.onBack,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sports.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _idx = (_idx + 1) % widget.sports.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(widget.sports[_idx]);
    final primary = widget.primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _idx = (_idx + 1) % widget.sports.length),
      child: SizedBox(
        height: 240 + widget.safeTop,
        child: Stack(
          children: [
            // Animated gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HSLColor.fromColor(primary).withLightness(0.18).toColor(),
                    meta.color.withValues(alpha: 0.75),
                    meta.color.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            // Pink glow blob
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 160, height: 160,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x25FF3376)),
              ),
            ),
            // Grid overlay
            const Positioned.fill(child: CustomPaint(painter: _HeroGridPainter())),
            // Sport emoji — large, centred
            Positioned(
              left: 0, right: 0,
              top: 0, bottom: 60,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(meta.emoji, key: ValueKey(_idx), style: const TextStyle(fontSize: 80)),
                ),
              ),
            ),
            // Bottom info
            Positioned(
              left: 20, right: 20, bottom: 30,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Column(
                  key: ValueKey(_idx),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${meta.emoji}  ${meta.label}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.venueName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4),
                    ),
                  ],
                ),
              ),
            ),
            // Carousel dots
            if (widget.sports.length > 1)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.sports.length, (i) => GestureDetector(
                    onTap: () { _timer?.cancel(); setState(() => _idx = i); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _idx ? 16 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _idx ? Colors.white : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  )),
                ),
              ),
            // Bottom fade to bg
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, widget.bgColor],
                  ),
                ),
              ),
            ),
            // Back / share / save overlay
            Positioned(
              top: widget.safeTop + 10,
              left: 18, right: 18,
              child: Row(
                children: [
                  _glassBtn(icon: Iconsax.arrow_left_copy, onTap: widget.onBack, primary: primary),
                  const Spacer(),
                  _glassBtn(icon: Iconsax.share_copy, onTap: widget.onShare, primary: primary),
                  const SizedBox(width: 8),
                  _glassBtn(
                    icon: widget.isFavorited ? Iconsax.bookmark_2_copy : Iconsax.bookmark_copy,
                    onTap: widget.favoriteBusy ? null : widget.onFavorite,
                    active: widget.isFavorited,
                    primary: primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassBtn({required IconData icon, VoidCallback? onTap, bool active = false, required Color primary}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.8) : cs.onSurface.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: active ? primary : cs.onSurface.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 18, color: cs.onPrimary),
      ),
    );
  }
}

// ─── Space card ───────────────────────────────────────────────────────────────

class _SpaceCard extends StatelessWidget {
  final String sport;
  final double pricePerHour;
  final String currency;
  final VoidCallback onTap;

  const _SpaceCard({
    required this.sport,
    required this.pricePerHour,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = _metaFor(sport);
    final color = meta.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 44))),
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                        child: const Text('Outdoor', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xE5F4C430), borderRadius: BorderRadius.circular(999)),
                        child: const Text('⚡ Lights', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurface, height: 1.3)),
                  const SizedBox(height: 4),
                  Text('Court / Field', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text('10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      Text(
                        pricePerHour == 0 ? 'Free' : '$currency ${pricePerHour.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: pricePerHour == 0 ? _green : color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

class _HeroGridPainter extends CustomPainter {
  const _HeroGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07)..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HeroGridPainter _) => false;
}

class _MapGridPainter extends CustomPainter {
  final Color color;
  const _MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.color != color;
}
