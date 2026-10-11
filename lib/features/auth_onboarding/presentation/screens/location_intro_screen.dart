import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class _LocationIntroScreenState extends ConsumerState<LocationIntroScreen> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
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
              ],
            ),
          ),
        ],
        primaryLabel: l.location_intro_cta,
        onPrimary: controller.useMyLocation,
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
              onPressed: _finish,
            ),
          ),
        ),
      ),
    );
  }
}
