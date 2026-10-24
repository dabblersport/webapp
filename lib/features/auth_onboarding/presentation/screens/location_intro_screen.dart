import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/service_region_labels.dart';
import 'package:dabbler/features/location/presentation/widgets/country_flag.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The full-screen location introduction that follows Welcome / Welcome Back,
/// drawn as the prompt frame of `Location.dc.html` (KAN-640): the Location
/// background, a country pill, a card ("Welcome, first name", "Where do you
/// play?", its line), a banner after a refusal or a missing GPS fix, and a
/// card of three buttons (Use my location, Enter location manually, Maybe
/// later). The
/// system permission prompt appears only when the user taps "Use my location";
/// "Select city" opens the manual drawer; "Maybe later" (and back) finishes the
/// intro at once (KAN-640): no GPS, no area, no city, nothing asked of the OS.
/// A city already chosen is kept; listings gate on a city at point of use.
class LocationIntroScreen extends ConsumerStatefulWidget {
  const LocationIntroScreen({
    super.key,
    this.userId,
    this.onFinish,
    this.displayNameLoader,
  });

  /// The Location background (`assets/location-intro-background.webp` in
  /// the design project is this same image).
  static const String artAsset = 'assets/images/location_intro.webp';

  /// Whose presentation to record (null: nothing is recorded).
  final String? userId;

  /// Where to go on; defaults to Home.
  final VoidCallback? onFinish;

  /// Test seam: how the greeting's name is read (default: the signed-in
  /// user's profile). A null or empty answer draws no greeting line.
  @visibleForTesting
  final Future<String?> Function()? displayNameLoader;

  @override
  ConsumerState<LocationIntroScreen> createState() =>
      _LocationIntroScreenState();
}

class _LocationIntroScreenState extends ConsumerState<LocationIntroScreen> {
  bool _finished = false;

  /// The user's first name for the greeting; null until known (no line).
  String? _firstName;

  Future<String?> _readDisplayName() async {
    final profile = await AuthService().getUserProfile(
      fields: const ['display_name'],
    );
    return (profile?['display_name'] as String?);
  }

  Future<void> _loadName() async {
    try {
      final raw = await (widget.displayNameLoader ?? _readDisplayName)();
      final name = raw?.trim() ?? '';
      if (name.isEmpty || !mounted) return;
      final space = name.indexOf(RegExp(r'\s'));
      setState(() => _firstName = space < 0 ? name : name.substring(0, space));
    } catch (_) {
      // No name: the greeting line is simply not drawn.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadName();
    // Presented: never show it to this user on this device again.
    final id = widget.userId;
    if (id != null) {
      ref.read(locationIntroStoreProvider).markSeen(id);
    }
  }

  /// What the permission answer left on screen (`Location.dc.html` frames
  /// 03 and 04): the banner above the buttons and the primary's role.
  _Notice? _notice;

  void _onAnswer(LocationIntroOutcome? outcome) {
    switch (outcome) {
      case LocationIntroOutcome.granted:
        _finish();
      case LocationIntroOutcome.denied:
      case LocationIntroOutcome.deniedForever:
        setState(() => _notice = _Notice.denied);
      case LocationIntroOutcome.serviceOff:
      case LocationIntroOutcome.unavailable:
      case null:
        setState(() => _notice = _Notice.noGps);
    }
  }

  /// The primary: ask once; after a refusal it opens Settings (never asks
  /// again); with no GPS fix it tries again.
  void _primary() {
    if (_notice == _Notice.denied) {
      ref.read(locationPermissionGatewayProvider).openAppSettings();
      return;
    }
    setState(() => _notice = null);
    ref.read(locationIntroControllerProvider.notifier).useMyLocation();
  }

  Future<void> _openCountry() {
    return showAppSheet<void>(
      context: context,
      title: AppLocalizations.of(context).location_intro_country_title,
      detent: DabblerSheetDetent.content,
      showCloseButton: false,
      builder: (BuildContext ctx) {
        return Consumer(
          builder: (BuildContext ctx, WidgetRef ref, Widget? _) {
            final String current = normalizeServiceRegion(
              ref.watch(selectedCountryProvider).valueOrNull,
            );
            final String lang = ref.watch(localeProvider).languageCode;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (String c, String label) in serviceRegionOptions(
                  AppLocalizations.of(ctx),
                  lang,
                ))
                  DabblerInputRow.option(
                    title: label,
                    selected: c == current,
                    onTap: () {
                      ref.read(selectedCountryProvider.notifier).setCountry(c);
                      Navigator.of(ctx).maybePop();
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// KAN-640: Maybe later finishes with whatever is set (possibly nothing).
  void _maybeLater() => _finish();

  /// Manual entry: finish once the drawer left a usable location behind.
  Future<void> _setManually() async {
    await showSetLocationDrawer(context);
    if (!mounted) return;
    final s = ref.read(activeLocationProvider).valueOrNull;
    if (s is ActiveLocationReady || s is ActiveLocationCityOnly) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final go = widget.onFinish;
    if (go != null) {
      go();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen<LocationIntroState>(locationIntroControllerProvider, (_, next) {
      if (next.phase == LocationIntroPhase.done) _onAnswer(next.outcome);
    });
    final detecting =
        ref.watch(locationIntroControllerProvider).phase ==
        LocationIntroPhase.requesting;
    final region = normalizeServiceRegion(
      ref.watch(selectedCountryProvider).valueOrNull,
    );
    final notice = _notice;

    return PopScope(
      // Back behaves like "Maybe later": it finishes the intro.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLater();
      },
      child: DabblerFlowPage(
        // `Location.dc.html` prompt frame: the Location background behind a
        // country pill, a text card, the banner and a button card.
        background: Semantics(
          image: true,
          label: l.location_intro_art,
          child: Image.asset(
            LocationIntroScreen.artAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.1),
          ),
        ),
        spreadChildren: true,
        bodyTopPadding: DabblerSpacing.space4,
        bodyGap: DabblerSpacing.space4,
        bodyBottomPadding: DabblerSpacing.space9,
        footerBottomPadding: 0,
        content: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CountryPill(
                region: region,
                name: serviceRegionLabel(l, region),
                changeLabel: l.location_intro_country_change,
                onTap: _openCountry,
              ),
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerCard(
                variant: DabblerCardVariant.white,
                borderOutside: true,
                radius: DabblerRadius.xxl,
                padding: const EdgeInsets.symmetric(
                  horizontal: DabblerSpacing.space7,
                  vertical: DabblerSpacing.space6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_firstName != null) ...<Widget>[
                      DabblerText(
                        l.location_intro_kicker(_firstName!),
                        style: DabblerType.subheadline,
                        weight: DabblerTextWeight.semibold,
                        tone: DabblerTextTone.brand,
                      ),
                      const DabblerGap.v(DabblerSpacing.space2),
                    ],
                    DabblerText(
                      l.location_intro_title,
                      style: DabblerType.displayScreen,
                    ),
                    const DabblerGap.v(DabblerSpacing.space2),
                    DabblerText(
                      l.location_intro_subtitle,
                      style: DabblerType.lead,
                      tone: DabblerTextTone.secondary,
                    ),
                  ],
                ),
              ),
              if (notice != null) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerBanner(
                  tone: notice == _Notice.denied
                      ? DabblerBannerTone.error
                      : DabblerBannerTone.warning,
                  title: notice == _Notice.denied
                      ? l.location_intro_denied_title
                      : l.location_intro_no_gps_title,
                  message: notice == _Notice.denied
                      ? l.location_intro_denied_message
                      : l.location_intro_no_gps_message,
                ),
              ],
            ],
          ),
          DabblerCard(
            variant: DabblerCardVariant.white,
            borderOutside: true,
            radius: DabblerRadius.xxl,
            padding: const EdgeInsets.all(DabblerSpacing.space7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DabblerButton(
                  label: detecting
                      ? l.location_intro_detecting
                      : switch (notice) {
                          _Notice.denied => l.location_intro_open_settings,
                          _Notice.noGps => l.location_intro_try_again,
                          null => l.location_intro_cta,
                        },
                  fullWidth: true,
                  loading: detecting,
                  onPressed: _primary,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerButton(
                  label: l.location_intro_manual,
                  tone: DabblerButtonTone.outlined,
                  fullWidth: true,
                  onPressed: _setManually,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerButton(
                  label: l.location_intro_later,
                  tone: DabblerButtonTone.neutral,
                  fullWidth: true,
                  onPressed: _maybeLater,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The two notices the permission answer can leave on screen.
enum _Notice { denied, noGps }

/// The country pill (`Location.dc.html`): flag circle, country, and a tinted
/// circle with the down arrow. Opens the country sheet.
class _CountryPill extends StatelessWidget {
  const _CountryPill({
    required this.region,
    required this.name,
    required this.changeLabel,
    required this.onTap,
  });

  final String region;
  final String name;
  final String changeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerCard(
      variant: DabblerCardVariant.white,
      borderOutside: true,
      radius: DabblerRadius.pill,
      padding: const EdgeInsets.all(DabblerSpacing.space3),
      onTap: onTap,
      semanticLabel: changeLabel,
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: DabblerSurface(
              radius: DabblerRadius.pill,
              fill: colors.surfaceSunken,
              borderColor: colors.borderDefault,
              borderWidth: DabblerSizing.borderDefault,
              width: DabblerSpacing.space10,
              height: DabblerSpacing.space10,
              center: true,
              child: CountryFlag(region: region, size: DabblerSpacing.space9),
            ),
          ),
          const DabblerGap.h(DabblerSpacing.space5),
          Expanded(
            child: DabblerText(
              name,
              style: DabblerType.body,
              weight: DabblerTextWeight.medium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ExcludeSemantics(
            child: DabblerSurface(
              radius: DabblerRadius.pill,
              fill: DabblerSurface.tintedFillOf(colors, colors.brandPrimary),
              width: DabblerSpacing.space10,
              height: DabblerSpacing.space10,
              center: true,
              child: DabblerIcon(
                'arrow-circle-down',
                size: DabblerSizing.iconSm,
                color: colors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
