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
import 'package:dabbler/features/venues/presentation/widgets/venue_amenity_chips.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Venue details (D03), drawn from `Details.dc.html` "Venue details".
///
/// A [DabblerDetailPage]: a [DabblerGalleryHero] (one slide per sport — the
/// venue record carries no photographs), the name, fact tiles, the spaces
/// rail, facilities, where, contact and about, over a [DabblerActionBar] with
/// the hourly price. Booking, rating and photo galleries are not app features
/// and are not built. Same providers, favourite toggle and directions / call /
/// website actions as before.

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
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailProvider(widget.venueId));
    final favoriteIdsAsync = ref.watch(favoriteVenueIdsForCurrentUserProvider);
    final fromProvider = favoriteIdsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.venueId),
      orElse: () => false,
    );
    final isFavorited = _favoriteOptimistic ?? fromProvider;
    return venueAsync.when(
      data: (venue) => _content(venue, isFavorited),
      loading: _loading,
      error: (_, __) => _error(),
    );
  }

  Widget _back() => DabblerOnColorIconButton(
    onSurface: true,
    icon: 'arrow-circle-left',
    mirrorInRtl: true,
    semanticLabel: AppLocalizations.of(context).auth_back,
    onPressed: () => Navigator.of(context).maybePop(),
  );

  Widget _content(games_venue.Venue venue, bool isFavorited) {
    final sports = venue.supportedSports;
    final isOpen = venue.isOpenAt(DateTime.now());
    final hasHours =
        venue.openingTime.isNotEmpty && venue.closingTime.isNotEmpty;
    final address = [
      venue.addressLine1,
      venue.city,
    ].where((p) => p.isNotEmpty).join(' · ');
    final fullAddress = [
      venue.addressLine1,
      venue.city,
      venue.state,
      venue.country,
    ].where((p) => p.isNotEmpty).join(', ');

    final contacts =
        <({String icon, String label, String value, VoidCallback? onTap})>[
          if (venue.phone?.isNotEmpty ?? false)
            (
              icon: 'call',
              label: 'Phone',
              value: venue.phone!,
              onTap: () => _callVenue(venue.phone!),
            ),
          if (venue.email?.isNotEmpty ?? false)
            (
              icon: 'sms',
              label: AppLocalizations.of(context).auth_email_label,
              value: venue.email!,
              onTap: null,
            ),
          if (venue.website?.isNotEmpty ?? false)
            (
              icon: 'global',
              label: 'Website',
              value: venue.website!,
              onTap: () => _openWebsite(venue.website!),
            ),
        ];

    return DabblerDetailPage(
      header: DabblerGalleryHero(
        slides: [
          if (sports.isEmpty)
            DabblerGallerySlide(label: venue.name)
          else
            for (final s in sports)
              DabblerGallerySlide(
                label: _labelFor(s),
                child: DabblerSportIcon.fromKey(
                  _sportKey(s),
                  size: DabblerSizing.illustrationMd,
                ),
              ),
        ],
        leading: _back(),
        actions: [
          DabblerOnColorIconButton(
            onSurface: true,
            icon: 'heart',
            weight: isFavorited
                ? DabblerIconWeight.bold
                : DabblerIconWeight.linear,
            color: isFavorited ? DabblerColors.of(context).error.base : null,
            selected: isFavorited,
            semanticLabel: isFavorited ? 'Unsave venue' : 'Save venue',
            onPressed: _favoriteBusy
                ? null
                : () => _toggleFavorite(isFavorited),
          ),
          DabblerOnColorIconButton(
            onSurface: true,
            icon: 'share',
            semanticLabel: 'Share venue',
            onPressed: _shareVenue,
          ),
        ],
      ),
      bottomBar: DabblerActionBar(
        price: venue.pricePerHour == 0
            ? 'Free'
            : '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}',
        caption: venue.pricePerHour == 0 ? null : 'per hour',
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerText(venue.name, style: DabblerType.title1),
            if (address.isNotEmpty) ...[
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerText(
                address,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ],
        ),
        DabblerStatGrid(
          rowExtent: DabblerStatGrid.detailsRowHeight,
          children: [
            DabblerStatTile(
              size: DabblerStatTileSize.detail,
              tone: DabblerStatTileTone.amber,
              icon: const DabblerIcon('star', size: DabblerSizing.iconSm),
              value: venue.totalRatings == 0
                  ? '—'
                  : venue.rating.toStringAsFixed(1),
              label: venue.totalRatings == 0
                  ? 'No ratings yet'
                  : '${venue.totalRatings} ratings',
            ),
            DabblerStatTile(
              size: DabblerStatTileSize.detail,
              tone: DabblerStatTileTone.brand,
              icon: const DabblerIcon('building', size: DabblerSizing.iconSm),
              value: sports.isNotEmpty ? '${sports.length} spaces' : '—',
              label: 'Bookable areas',
              fitValue: true,
            ),
            if (hasHours)
              DabblerStatTile(
                size: DabblerStatTileSize.detail,
                tone: isOpen
                    ? DabblerStatTileTone.success
                    : DabblerStatTileTone.danger,
                icon: const DabblerIcon('clock', size: DabblerSizing.iconSm),
                value: isOpen ? 'Open until ${venue.closingTime}' : 'Closed',
                label: 'Daily ${venue.openingTime} – ${venue.closingTime}',
                span: 6,
                fitValue: true,
              ),
          ],
        ),
        if (sports.isNotEmpty)
          DabblerSection(
            style: DabblerSectionStyle.label,
            title: 'Spaces',
            subtitle: '${sports.length} bookable areas',
            children: [
              SizedBox(
                height: DabblerSizing.heroCoverHeight - DabblerSpacing.space11,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sports.length,
                  separatorBuilder: (_, __) =>
                      const DabblerGap.h(DabblerSpacing.space4),
                  itemBuilder: (_, i) => DabblerCard(
                    width: DabblerSizing.railCardWidth,
                    media: DabblerImage(
                      height: DabblerSizing.railCardHeight,
                      radius: BorderRadius.zero,
                      overlay: DabblerSportIcon.fromKey(
                        _sportKey(sports[i]),
                        size: DabblerSizing.iconRow,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DabblerText(
                          _labelFor(sports[i]),
                          style: DabblerType.smallTight,
                          weight: DabblerTextWeight.semibold,
                        ),
                        const DabblerGap.v(DabblerSpacing.space2),
                        DabblerText(
                          venue.pricePerHour == 0
                              ? 'Free'
                              : '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)} / hour',
                          style: DabblerType.smallTight,
                          weight: DabblerTextWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (venue.amenities.isNotEmpty)
          DabblerSection(
            style: DabblerSectionStyle.label,
            title: 'Facilities',
            children: [VenueAmenityChips(amenities: venue.amenities)],
          ),
        DabblerSection(
          style: DabblerSectionStyle.label,
          title: 'Where',
          children: [
            DabblerCard(
              padding: EdgeInsets.zero,
              media: DabblerImage(
                height: DabblerSizing.illustrationMd + DabblerSpacing.space11,
                radius: BorderRadius.zero,
                semanticLabel: 'Map of the venue',
              ),
              child: Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DabblerText(
                            venue.name,
                            style: DabblerType.smallTight,
                            weight: DabblerTextWeight.semibold,
                          ),
                          DabblerText(
                            fullAddress.isEmpty
                                ? 'Address unavailable'
                                : fullAddress,
                            style: DabblerType.footnote,
                            tone: DabblerTextTone.secondary,
                          ),
                        ],
                      ),
                    ),
                    DabblerTextLink(
                      label: 'Open map',
                      onPressed: _getDirections,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (contacts.isNotEmpty)
          DabblerListGroup(
            tone: DabblerListGroupTone.info,
            children: [
              for (final c in contacts)
                DabblerListRow(
                  leading: DabblerIcon(c.icon, size: DabblerSizing.iconRow),
                  overline: c.label,
                  title: c.value,
                  showChevron: c.onTap != null,
                  onTap: c.onTap,
                ),
            ],
          ),
        if (venue.description.isNotEmpty)
          DabblerSection(
            style: DabblerSectionStyle.label,
            title: AppLocalizations.of(context).settings_section_about,
            children: [
              DabblerText(
                venue.description,
                style: DabblerType.footnoteRelaxed,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ),
      ],
    );
  }

  Widget _loading() {
    return DabblerDetailPage(
      header: DabblerImage(
        height: DabblerSizing.heroCoverHeight,
        radius: BorderRadius.zero,
      ),
      children: [
        DabblerSkeleton.rect(
          width: DabblerSizing.skeletonWidthLong,
          height: DabblerSizing.skeletonTitleHeight,
        ),
        DabblerSkeleton.rect(
          width: double.infinity,
          height: DabblerSizing.skeletonBlockHeight,
        ),
        DabblerSkeleton.rect(
          width: double.infinity,
          height: DabblerSizing.skeletonBlockHeight,
        ),
      ],
    );
  }

  Widget _error() {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: DabblerEmptyState.error(
        title: 'Failed to load venue',
        text: 'Please check your connection and try again.',
        retryLabel: 'Retry',
        onRetry: () => ref.refresh(venueDetailProvider(widget.venueId)),
      ),
    );
  }

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

  void _shareVenue() => _snack('Sharing coming soon');

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
