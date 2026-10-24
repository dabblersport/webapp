import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The full-screen location introduction that follows Welcome / Welcome Back,
/// drawn as the prompt frame of `Location.dc.html` (KAN-640): the location
/// tile, "Welcome, <first name>", "Where do you play?", its line, and three
/// stacked buttons (Use my location, Enter location manually, Maybe later). The
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

  /// Tells the user, once and without holding them here, why nearby games may
  /// be missing. Never shown for an allowed permission.
  void _hint(LocationIntroOutcome? outcome) {
    final l = AppLocalizations.of(context);
    final gateway = ref.read(locationPermissionGatewayProvider);
    final (String message, bool serviceSettings)? hint = switch (outcome) {
      LocationIntroOutcome.denied => (l.location_intro_denied, false),
      LocationIntroOutcome.deniedForever => (
        l.location_intro_denied_forever,
        false,
      ),
      LocationIntroOutcome.serviceOff => (l.location_intro_service_off, true),
      _ => null,
    };
    if (hint == null) return;
    final canOpen =
        !kIsWeb &&
        (outcome == LocationIntroOutcome.deniedForever ||
            outcome == LocationIntroOutcome.serviceOff);
    DabblerToasts.show(
      DabblerToastSpec(
        message: hint.$1,
        tone: DabblerToastTone.info,
        action: canOpen
            ? DabblerToastAction(
                label: l.location_intro_open_settings,
                onPressed: () {
                  if (hint.$2) {
                    gateway.openLocationSettings();
                  } else {
                    gateway.openAppSettings();
                  }
                },
              )
            : null,
      ),
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

  void _finish([LocationIntroOutcome? outcome]) {
    if (_finished) return;
    _finished = true;
    _hint(outcome);
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
      // The OS answered (any answer): on to the destination at once.
      if (next.phase == LocationIntroPhase.done) _finish(next.outcome);
    });
    final controller = ref.read(locationIntroControllerProvider.notifier);
    final colors = DabblerColors.of(context);

    return PopScope(
      // Back behaves like "Maybe later": it finishes the intro.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLater();
      },
      child: DabblerFlowPage(
        // `Location.dc.html` prompt frame: 36 above, 24 between the tile, the
        // text block and the banner area.
        bodyTopPadding: DabblerSpacing.space10,
        bodyGap: DabblerSpacing.space8,
        content: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExcludeSemantics(
              child: DabblerSurface(
                radius: DabblerRadius.lg,
                fill: DabblerSurface.tintedFillOf(colors, colors.brandPrimary),
                borderColor: DabblerSurface.tintedBorderOf(
                  colors,
                  colors.brandPrimary,
                ),
                borderWidth: DabblerSizing.borderDefault,
                width: DabblerSpacing.space8 + DabblerSpacing.space10,
                height: DabblerSpacing.space8 + DabblerSpacing.space10,
                center: true,
                child: DabblerIcon(
                  'location',
                  weight: DabblerIconWeight.bold,
                  size: DabblerSizing.iconLg,
                  color: colors.brandPrimary,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_firstName != null) ...<Widget>[
                DabblerText(
                  l.location_intro_kicker(_firstName!),
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                  tone: DabblerTextTone.brand,
                ),
                const DabblerGap.v(DabblerSpacing.space3),
              ],
              DabblerText(
                l.location_intro_title,
                style: DabblerType.displayScreen,
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerText(
                l.location_intro_subtitle,
                style: DabblerType.lead,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ),
        ],
        primaryLabel: l.location_intro_cta,
        onPrimary: controller.useMyLocation,
        // Secondary buttons (KAN-583), not pills: Maybe later is a button too.
        secondary: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
    );
  }
}
