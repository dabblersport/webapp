import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The full-screen location introduction that follows Welcome / Welcome Back
/// (KAN-489): the illustrated map, the approved copy, and two actions. The
/// system permission prompt appears only when the user taps "Use my location";
/// "Maybe later" (and back) continue to Home without asking the OS anything.
class LocationIntroScreen extends ConsumerStatefulWidget {
  const LocationIntroScreen({super.key, this.userId, this.onFinish});

  /// Whose presentation to record (null: nothing is recorded).
  final String? userId;

  /// Where to go on; defaults to Home.
  final VoidCallback? onFinish;

  /// The bundled PNG copy of the supplied `Location.md` artwork.
  static const String artAsset = 'assets/images/location_intro.webp';

  @override
  ConsumerState<LocationIntroScreen> createState() =>
      _LocationIntroScreenState();
}

class _LocationIntroScreenState extends ConsumerState<LocationIntroScreen>
    with WidgetsBindingObserver {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Presented: never show it to this user on this device again.
    final id = widget.userId;
    if (id != null) {
      ref.read(locationIntroStoreProvider).markSeen(id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the settings app: re-check without asking again.
    if (state == AppLifecycleState.resumed) {
      ref.read(locationIntroControllerProvider.notifier).recheckAfterSettings();
    }
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
    final state = ref.watch(locationIntroControllerProvider);
    ref.listen<LocationIntroState>(locationIntroControllerProvider, (_, next) {
      if (next.phase == LocationIntroPhase.done) _finish();
    });

    final phase = state.phase;
    final guidance = switch (phase) {
      LocationIntroPhase.denied => l.location_intro_denied,
      LocationIntroPhase.deniedForever => l.location_intro_denied_forever,
      LocationIntroPhase.serviceOff => l.location_intro_service_off,
      LocationIntroPhase.lookupFailed => l.location_intro_lookup_failed,
      _ => null,
    };
    final settingsAction =
        state.canOpenSettings &&
        (phase == LocationIntroPhase.deniedForever ||
            phase == LocationIntroPhase.serviceOff);
    final controller = ref.read(locationIntroControllerProvider.notifier);

    return PopScope(
      // Back never traps the user: it continues like "Maybe later".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: DabblerFlowPage(
        background: Semantics(
          image: true,
          label: l.location_intro_art,
          child: Image.asset(
            LocationIntroScreen.artAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        spreadChildren: true,
        bodyTopPadding: DabblerSpacing.space8,
        bodyBottomPadding: DabblerSpacing.space4,
        footerBottomPadding: DabblerSpacing.space6,
        content: <Widget>[
          const DabblerGap.v(DabblerSpacing.space1),
          DabblerCard(
            variant: DabblerCardVariant.white,
            borderOutside: true,
            radius: DabblerRadius.xl,
            padding: DabblerInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DabblerText(
                  l.location_intro_headline,
                  style: DabblerType.displaySection,
                ),
                const DabblerGap.v(DabblerSpacing.space3),
                DabblerText(
                  l.location_intro_body,
                  style: DabblerType.lead,
                  tone: DabblerTextTone.secondary,
                ),
                if (guidance != null) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space4),
                  DabblerBanner(
                    tone: DabblerBannerTone.warning,
                    message: guidance,
                  ),
                ],
              ],
            ),
          ),
        ],
        primaryLabel: settingsAction
            ? l.location_intro_open_settings
            : l.location_intro_cta,
        primaryLoading: phase == LocationIntroPhase.working,
        onPrimary: phase == LocationIntroPhase.working
            ? null
            : settingsAction
            ? controller.openSettings
            : controller.useMyLocation,
        // On a white pill so it stays readable over the artwork.
        secondary: Center(
          child: DabblerCard(
            variant: DabblerCardVariant.white,
            borderOutside: true,
            radius: DabblerRadius.xl,
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
              vertical: DabblerSpacing.space2,
            ),
            child: DabblerTextLink(
              label: l.location_intro_later,
              style: DabblerType.copy
                  .resolveForDirection(Directionality.of(context))
                  .copyWith(fontWeight: DabblerType.medium),
              inline: true,
              underline: false,
              onPressed: phase == LocationIntroPhase.working ? null : _finish,
            ),
          ),
        ),
      ),
    );
  }
}
