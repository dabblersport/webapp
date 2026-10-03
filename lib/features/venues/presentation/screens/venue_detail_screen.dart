import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dabbler/data/models/games/venue.dart' as games_venue;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/venues/providers.dart';

/// Venue details (D03) on the design system only.
///
/// Same providers, favourite toggle, directions / call / website actions and
/// space sheet as before. The booking action stays unbuilt (see the note in
/// [_VenueDetailScreenState._showSpaceSheet]); only the widget tree changed.

TextStyle _t(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

/// The design's section header: 15 / 600 ink.
TextStyle _section(BuildContext context, DabblerColors colors) => _t(
  context,
  DabblerType.subheadline,
  colors.textPrimary,
  weight: DabblerType.semibold,
);

// ─── Sport labels ─────────────────────────────────────────────────────────────

/// The sport's display label. The sport's identity is drawn by
/// [DabblerSportIcon]; the colour is the design system's, not a per-sport hue.
const _sportLabels = <String, String>{
  'football': 'Football',
  'soccer': 'Football',
  'basketball': 'Basketball',
  'tennis': 'Tennis',
  'padel': 'Padel',
  'cricket': 'Cricket',
  'swimming': 'Swimming',
  'running': 'Running',
  'gym': 'Gym',
  'yoga': 'Yoga',
};

String _labelFor(String sport) =>
    _sportLabels[sport.trim().toLowerCase()] ?? 'Sport';

String _sportKey(String sport) {
  final key = sport.trim().toLowerCase();
  return key == 'soccer' ? 'football' : key;
}

String _backIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? 'arrow-circle-right'
    : 'arrow-circle-left';

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
    final safeTop = MediaQuery.paddingOf(context).top;

    return DabblerPage(
      // The hero bleeds under the status bar, so the page must not inset the
      // top itself: an empty top bar turns that inset off and the hero pads
      // the safe area on its own.
      topBar: const SizedBox.shrink(),
      body: venueAsync.when(
        data: (venue) => _buildContent(venue, isFavorited, safeTop),
        loading: () => _buildLoading(safeTop),
        error: (_, __) => _buildError(safeTop),
      ),
    );
  }

  // ─── Content ─────────────────────────────────────────────────────────────────

  Widget _buildContent(
    games_venue.Venue venue,
    bool isFavorited,
    double safeTop,
  ) {
    final sports = venue.supportedSports.isNotEmpty
        ? venue.supportedSports
        : ['sport'];
    final isOpen = venue.isOpenAt(DateTime.now());
    const gutter = DabblerSpacing.space6;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: CustomScrollView(
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
                onBack: () => Navigator.of(context).maybePop(),
                onFavorite: () => _toggleFavorite(isFavorited),
              ),
            ),

            // Title + status pills
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  gutter,
                  gutter,
                  DabblerSpacing.space5,
                ),
                child: _buildTitle(venue, isOpen),
              ),
            ),

            // Rating + Spaces tiles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  0,
                  gutter,
                  DabblerSpacing.space5,
                ),
                child: _buildRatingSpacesTiles(venue),
              ),
            ),

            // Spaces section header
            if (venue.supportedSports.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    0,
                    gutter,
                    DabblerSpacing.space3,
                  ),
                  child: _sectionHeader('Spaces', sub: 'tap for details'),
                ),
              ),
              // Full-bleed horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 232,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      gutter,
                      0,
                      gutter,
                      DabblerSpacing.space6,
                    ),
                    itemCount: venue.supportedSports.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: DabblerSpacing.space4),
                    itemBuilder: (ctx, i) => _SpaceCard(
                      sport: venue.supportedSports[i],
                      pricePerHour: venue.pricePerHour,
                      currency: venue.currency,
                      onTap: () =>
                          _showSpaceSheet(ctx, venue.supportedSports[i], venue),
                    ),
                  ),
                ),
              ),
            ],

            // Location card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  DabblerSpacing.space1,
                  gutter,
                  DabblerSpacing.space5,
                ),
                child: _buildLocationCard(venue),
              ),
            ),

            // Contact card
            if (_hasContact(venue))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    0,
                    gutter,
                    DabblerSpacing.space5,
                  ),
                  child: _buildContactCard(venue),
                ),
              ),

            // Amenities
            if (venue.amenities.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    0,
                    gutter,
                    DabblerSpacing.space5,
                  ),
                  child: _buildAmenities(venue),
                ),
              ),

            // About
            if (venue.description.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    0,
                    gutter,
                    DabblerSpacing.space5,
                  ),
                  child: _buildAbout(venue),
                ),
              ),

            // Ratings
            if (venue.totalRatings > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    0,
                    gutter,
                    DabblerSpacing.space10,
                  ),
                  child: _buildRatings(venue),
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MediaQuery.paddingOf(context).bottom +
                    DabblerSpacing.space8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Title ────────────────────────────────────────────────────────────────────

  Widget _buildTitle(games_venue.Venue venue, bool isOpen) {
    final colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          venue.name,
          style: _t(context, DabblerType.title1, colors.textPrimary),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space2,
          runSpacing: DabblerSpacing.space2,
          children: [
            DabblerBadge(
              label: isOpen ? 'Open Now' : 'Closed',
              status: isOpen ? colors.success : colors.error,
            ),
            if (venue.city.isNotEmpty)
              DabblerBadge(
                label: venue.city,
                tone: DabblerBadgeTone.withIcon,
                icon: const DabblerIcon('location', size: 12),
              ),
            if (venue.openingTime.isNotEmpty && venue.closingTime.isNotEmpty)
              DabblerBadge(
                label: '${venue.openingTime} – ${venue.closingTime}',
                tone: DabblerBadgeTone.withIcon,
                icon: const DabblerIcon('clock', size: 12),
              ),
          ],
        ),
      ],
    );
  }

  // ─── Rating + Spaces tiles ────────────────────────────────────────────────────

  Widget _buildRatingSpacesTiles(games_venue.Venue venue) {
    return DabblerStatGrid(
      children: [
        DabblerStatTile(
          value: venue.totalRatings == 0
              ? '—'
              : venue.rating.toStringAsFixed(1),
          label: venue.totalRatings == 0
              ? 'No ratings yet'
              : '${venue.totalRatings} reviews',
          tone: DabblerStatTileTone.amber,
          span: 3,
        ),
        DabblerStatTile(
          value: venue.supportedSports.isNotEmpty
              ? '${venue.supportedSports.length}'
              : '—',
          label: 'Bookable areas',
          tone: DabblerStatTileTone.info,
          span: 3,
        ),
      ],
    );
  }

  // ─── Location card ────────────────────────────────────────────────────────────

  Widget _buildLocationCard(games_venue.Venue venue) {
    final colors = DabblerColors.of(context);
    final parts = <String>[
      if (venue.addressLine1.isNotEmpty) venue.addressLine1,
      if (venue.city.isNotEmpty) venue.city,
      if (venue.state.isNotEmpty) venue.state,
      if (venue.country.isNotEmpty) venue.country,
    ];
    final address = parts.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: _section(context, colors)),
        const SizedBox(height: DabblerSpacing.space3),
        DabblerSurface.sunken(
          radius: DabblerRadius.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Map slot: the design's "Map of the venue" frame. Tapping it
              // opens directions, as before.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _getDirections,
                child: SizedBox(
                  height: 120,
                  child: ColoredBox(
                    color: colors.bgTertiary,
                    child: Stack(
                      children: [
                        Center(
                          child: DabblerIcon(
                            'location',
                            weight: DabblerIconWeight.bold,
                            size: 28,
                            color: colors.brandPrimary,
                          ),
                        ),
                        PositionedDirectional(
                          top: DabblerSpacing.space3,
                          end: DabblerSpacing.space4,
                          child: const DabblerBadge(
                            label: 'Open Map',
                            tone: DabblerBadgeTone.withIcon,
                            icon: DabblerIcon('map', size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DabblerIconTile.named('location', size: 36),
                    const SizedBox(width: DabblerSpacing.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCATION',
                            style: _t(
                              context,
                              DabblerType.caption2,
                              colors.textTertiary,
                            ),
                          ),
                          Text(
                            address.isEmpty ? 'Address unavailable' : address,
                            style: _t(
                              context,
                              DabblerType.subheadline,
                              colors.textPrimary,
                              weight: DabblerType.semibold,
                            ),
                          ),
                        ],
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

  // ─── Contact card ─────────────────────────────────────────────────────────────

  bool _hasContact(games_venue.Venue v) =>
      (v.phone?.isNotEmpty ?? false) ||
      (v.email?.isNotEmpty ?? false) ||
      (v.website?.isNotEmpty ?? false);

  Widget _buildContactCard(games_venue.Venue venue) {
    final colors = DabblerColors.of(context);
    final rows = <({String icon, String label, VoidCallback? onTap})>[
      if (venue.phone?.isNotEmpty ?? false)
        (
          icon: 'call',
          label: venue.phone!,
          onTap: () => _callVenue(venue.phone!),
        ),
      if (venue.email?.isNotEmpty ?? false)
        (icon: 'sms', label: venue.email!, onTap: null),
      if (venue.website?.isNotEmpty ?? false)
        (
          icon: 'global',
          label: venue.website!,
          onTap: () => _openWebsite(venue.website!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTACT',
          style: _t(context, DabblerType.caption2, colors.textTertiary),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        DabblerSurface(
          fill: DabblerColors.tileInfo.surface,
          borderColor: DabblerColors.tileInfo.surface,
          radius: DabblerRadius.xl,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const DabblerDivider(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: rows[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DabblerSpacing.space5,
                      vertical: DabblerSpacing.space4,
                    ),
                    child: Row(
                      children: [
                        DabblerIcon(
                          rows[i].icon,
                          size: 20,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: DabblerSpacing.space4),
                        Expanded(
                          child: Text(
                            rows[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              context,
                              DabblerType.subheadline,
                              colors.textPrimary,
                              weight: DabblerType.semibold,
                            ),
                          ),
                        ),
                        if (rows[i].onTap != null)
                          DabblerIcon(
                            'arrow-circle-right',
                            mirrorInRtl: true,
                            size: 18,
                            color: colors.textPrimary,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Amenities ────────────────────────────────────────────────────────────────

  Widget _buildAmenities(games_venue.Venue venue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Amenities'),
        const SizedBox(height: DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: [
            for (final a in venue.amenities)
              DabblerBadge(
                label: a,
                tone: DabblerBadgeTone.withIcon,
                icon: DabblerIcon(_amenityIcon(a), size: 14),
              ),
          ],
        ),
      ],
    );
  }

  String _amenityIcon(String a) {
    switch (a.trim().toLowerCase()) {
      case 'parking':
      case 'free parking':
        return 'car';
      case 'wifi':
        return 'wifi-square';
      case 'lighting':
        return 'lamp-on';
      case 'gym':
        return 'activity';
      case 'restaurant':
      case 'cafe':
      case 'cafeteria':
      case 'snack bar':
        return 'coffee';
      case 'locker rooms':
      case 'changing rooms':
      case 'changing':
        return 'lock';
      case 'showers':
        return 'drop';
      default:
        return 'tick-circle';
    }
  }

  // ─── About ────────────────────────────────────────────────────────────────────

  Widget _buildAbout(games_venue.Venue venue) {
    final colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('About'),
        const SizedBox(height: DabblerSpacing.space3),
        Text(
          venue.description,
          style: _t(context, DabblerType.footnote, colors.textSecondary),
        ),
      ],
    );
  }

  // ─── Ratings ─────────────────────────────────────────────────────────────────

  Widget _buildRatings(games_venue.Venue venue) {
    final colors = DabblerColors.of(context);
    final avg = venue.rating;
    final filled = avg.round().clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Ratings & Reviews'),
        const SizedBox(height: DabblerSpacing.space3),
        DabblerSurface.sunken(
          radius: DabblerRadius.xl,
          padding: const EdgeInsets.all(DabblerSpacing.space5),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: _t(
                      context,
                      DabblerType.largeTitle,
                      colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: DabblerSpacing.space1),
                  DabblerRating(
                    value: filled.toDouble(),
                    size: DabblerRatingSize.sm,
                  ),
                  const SizedBox(height: DabblerSpacing.space1),
                  Text(
                    '${venue.totalRatings} reviews',
                    style: _t(
                      context,
                      DabblerType.caption2,
                      colors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: DabblerSpacing.space6),
              Expanded(
                child: Column(
                  children: [
                    for (final n in const [5, 4, 3, 2, 1])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DabblerSpacing.space1,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$n',
                              style: _t(
                                context,
                                DabblerType.caption2,
                                colors.textTertiary,
                                weight: DabblerType.bold,
                              ),
                            ),
                            const SizedBox(width: DabblerSpacing.space1),
                            DabblerIcon(
                              'star',
                              weight: DabblerIconWeight.bold,
                              size: 10,
                              color: colors.warning.base,
                            ),
                            const SizedBox(width: DabblerSpacing.space2),
                            Expanded(
                              child: DabblerProgressBar(
                                value: n == filled
                                    ? 0.6
                                    : (n == filled + 1 || n == filled - 1)
                                    ? 0.3
                                    : 0.1,
                                size: DabblerProgressBarSize.sm,
                                tone: n >= 4
                                    ? DabblerProgressBarTone.brand
                                    : n == 3
                                    ? DabblerProgressBarTone.warning
                                    : DabblerProgressBarTone.info,
                              ),
                            ),
                          ],
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

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? sub}) {
    final colors = DabblerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: _section(context, colors)),
        if (sub != null) ...[
          const SizedBox(width: DabblerSpacing.space2),
          Text(
            '· $sub',
            style: _t(context, DabblerType.caption1, colors.textTertiary),
          ),
        ],
      ],
    );
  }

  // ─── Space detail bottom sheet ───────────────────────────────────────────────

  void _showSpaceSheet(
    BuildContext ctx,
    String sport,
    games_venue.Venue venue,
  ) {
    showDabblerSheet<void>(
      context: ctx,
      detent: DabblerSheetDetent.content,
      builder: (sheetCtx) {
        final colors = DabblerColors.of(sheetCtx);
        final free = venue.pricePerHour == 0;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            DabblerSpacing.space2,
            DabblerSpacing.space6,
            DabblerSpacing.space8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DabblerIconTile(
                    DabblerSportIcon.fromKey(_sportKey(sport), size: 22),
                    size: 44,
                  ),
                  const SizedBox(width: DabblerSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labelFor(sport),
                          style: _t(
                            context,
                            DabblerType.headline,
                            colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Sport Space',
                          style: _t(
                            context,
                            DabblerType.caption1,
                            colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    free
                        ? 'Free'
                        : '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}/hr',
                    style: _t(
                      context,
                      DabblerType.headline,
                      free ? colors.success.strong : colors.brandPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DabblerSpacing.space7),
              Row(
                children: [
                  _statTile(
                    'Hours',
                    '${venue.openingTime}–${venue.closingTime}',
                    'clock',
                  ),
                  const SizedBox(width: DabblerSpacing.space3),
                  _statTile('Lighting', 'Yes', 'lamp-on'),
                  const SizedBox(width: DabblerSpacing.space3),
                  _statTile('Type', 'Outdoor', 'sun-1'),
                ],
              ),
              // Booking is not an app feature (and was already commented out):
              // the design's "Book a space" action stays unbuilt. The original
              // full-width primary action, kept here as a note:
              // DabblerButton(
              //   label: 'Book Space',
              //   fullWidth: true,
              //   onPressed: () => Navigator.pop(sheetCtx),
              // ),
            ],
          ),
        );
      },
    );
  }

  Widget _statTile(String label, String value, String icon) {
    final colors = DabblerColors.of(context);
    return Expanded(
      child: DabblerSurface.sunken(
        radius: DabblerRadius.lg,
        padding: const EdgeInsets.all(DabblerSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerIcon(icon, size: 18, color: colors.brandPrimary),
            const SizedBox(height: DabblerSpacing.space1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(
                context,
                DabblerType.caption1,
                colors.textPrimary,
                weight: DabblerType.bold,
              ),
            ),
            Text(
              label,
              style: _t(context, DabblerType.caption2, colors.textTertiary),
            ),
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
        SliverToBoxAdapter(
          child: DabblerSkeleton.rect(
            width: double.infinity,
            height: 240 + safeTop,
            radius: 0,
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space6,
              DabblerSpacing.space6,
              DabblerSpacing.space6,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerSkeleton.rect(width: 220, height: 28),
                SizedBox(height: DabblerSpacing.space3),
                DabblerSkeleton.rect(width: 160, height: 20),
                SizedBox(height: DabblerSpacing.space6),
                DabblerSkeleton.rect(width: double.infinity, height: 80),
                SizedBox(height: DabblerSpacing.space4),
                DabblerSkeleton.rect(width: double.infinity, height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────────

  Widget _buildError(double safeTop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space5,
            safeTop + DabblerSpacing.space3,
            DabblerSpacing.space5,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DabblerButton.icon(
              icon: _backIcon(context),
              semanticLabel: 'Back',
              tone: DabblerButtonTone.neutral,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Expanded(
          child: DabblerEmptyState.error(
            title: 'Failed to load venue',
            text: 'Please check your connection and try again.',
            retryLabel: 'Retry',
            onRetry: () => ref.refresh(venueDetailProvider(widget.venueId)),
          ),
        ),
      ],
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

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
    async.whenData(
      (venue) => _launchUrl(
        'https://www.google.com/maps?q=${venue.latitude},${venue.longitude}',
      ),
    );
  }

  void _callVenue(String phone) => _launchPhoneDialer(phone);

  void _openWebsite(String url) =>
      _launchUrl(url.startsWith('http') ? url : 'https://$url');

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Could not open link');
    }
  }

  Future<void> _launchPhoneDialer(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      _snack('Phone number not available');
      return;
    }
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: normalized),
        mode: LaunchMode.externalApplication,
      );
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
      if (code >= 48 && code <= 57) {
        buf.write(ch);
        continue;
      }
      if (ch == '+' && buf.isEmpty) buf.write(ch);
    }
    return buf.toString();
  }

  void _snack(String message) {
    final toasts = DabblerToastProvider.maybeOf(context);
    if (toasts == null) return;
    toasts
      ..clear()
      ..show(DabblerToastSpec(message: message));
  }
}

// ─── Hero carousel ────────────────────────────────────────────────────────────

/// The venue's sports, cycling every three seconds (or on tap / dot).
///
/// The venue record carries no photographs, so each slide is the design's
/// photo slot in its empty state: the sunken ground with the sport's glyph and
/// a label pill.
class _HeroCarousel extends StatefulWidget {
  final List<String> sports;
  final String venueName;
  final double safeTop;
  final bool isFavorited;
  final bool favoriteBusy;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  const _HeroCarousel({
    required this.sports,
    required this.venueName,
    required this.safeTop,
    required this.isFavorited,
    required this.favoriteBusy,
    required this.onBack,
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
    final colors = DabblerColors.of(context);
    final sport = widget.sports[_idx];

    return GestureDetector(
      onTap: () => setState(() => _idx = (_idx + 1) % widget.sports.length),
      child: SizedBox(
        height: 240 + widget.safeTop,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.surfaceSunken)),
            // Sport glyph — large, centred
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 60,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: DabblerSportIcon.fromKey(
                    _sportKey(sport),
                    key: ValueKey(_idx),
                    size: 80,
                    color: colors.brandPrimary,
                  ),
                ),
              ),
            ),
            // Label pill
            PositionedDirectional(
              start: DabblerSpacing.space6,
              bottom: 42,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: DabblerBadge(
                  key: ValueKey(_idx),
                  label: _labelFor(sport),
                  tone: DabblerBadgeTone.success,
                ),
              ),
            ),
            // Carousel dots
            if (widget.sports.length > 1)
              Positioned(
                bottom: DabblerSpacing.space4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.sports.length,
                    (i) => GestureDetector(
                      onTap: () {
                        _timer?.cancel();
                        setState(() => _idx = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == _idx ? 16 : 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _idx
                              ? colors.textPrimary
                              : colors.textPrimary.withValues(alpha: 0.25),
                          borderRadius: DabblerRadius.pillAll,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Back / save overlay (the share button stays hidden until
            // sharing is implemented).
            PositionedDirectional(
              top: widget.safeTop + DabblerSpacing.space4,
              start: DabblerSpacing.space6,
              end: DabblerSpacing.space6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DabblerButton.icon(
                    icon: _backIcon(context),
                    semanticLabel: 'Back',
                    tone: DabblerButtonTone.neutral,
                    onPressed: widget.onBack,
                  ),
                  DabblerButton.icon(
                    icon: widget.isFavorited ? 'bookmark-2' : 'bookmark',
                    semanticLabel: widget.isFavorited
                        ? 'Unsave venue'
                        : 'Save venue',
                    tone: widget.isFavorited
                        ? DabblerButtonTone.primary
                        : DabblerButtonTone.neutral,
                    onPressed: widget.favoriteBusy ? null : widget.onFavorite,
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
    final colors = DabblerColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 180,
        child: DabblerSurface.sunken(
          radius: DabblerRadius.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Illustration header
              SizedBox(
                height: 96,
                child: ColoredBox(
                  color: colors.bgTertiary,
                  child: Stack(
                    children: [
                      Center(
                        child: DabblerSportIcon.fromKey(
                          _sportKey(sport),
                          size: 44,
                          color: colors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelFor(sport),
                      style: _t(
                        context,
                        DabblerType.footnote,
                        colors.textPrimary,
                        weight: DabblerType.semibold,
                      ),
                    ),
                    Text(
                      'Court / Field',
                      style: _t(
                        context,
                        DabblerType.caption2,
                        colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: DabblerSpacing.space2),
                    Wrap(
                      spacing: DabblerSpacing.space2,
                      runSpacing: DabblerSpacing.space1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const DabblerBadge(
                          label: 'Outdoor',
                          tone: DabblerBadgeTone.withIcon,
                        ),
                        const DabblerBadge(
                          label: 'Lights',
                          tone: DabblerBadgeTone.withIcon,
                          icon: DabblerIcon('flash', size: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: DabblerSpacing.space2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            DabblerIcon(
                              'people',
                              size: 13,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: DabblerSpacing.space1),
                            Text(
                              '10',
                              style: _t(
                                context,
                                DabblerType.caption2,
                                colors.textTertiary,
                                weight: DabblerType.semibold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          pricePerHour == 0
                              ? 'Free'
                              : '$currency ${pricePerHour.toStringAsFixed(0)}',
                          style: _t(
                            context,
                            DabblerType.footnote,
                            pricePerHour == 0
                                ? colors.success.strong
                                : colors.textPrimary,
                            weight: DabblerType.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
