import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The offline / poor-connection notice (KAN-610).
///
/// Compact, in normal layout flow (never an overlay), no dismiss and no retry.
/// Online collapses it and removes its footprint. Height animates over 220ms
/// and opacity over 160ms, both ease-out and both zero under reduced motion;
/// while collapsing it keeps the last visible state's content. Hidden content
/// is excluded from semantics and focus; a visible change is announced
/// politely.
///
/// Pure of state: [ConnectionBanner] reads KAN-603's [connectivityProvider];
/// [ConnectionBanner.status] is for screens that already hold a status.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key, this.status});

  /// Overrides [connectivityProvider]. Null reads the provider.
  final ConnectionStatus? status;

  /// Layout from the KAN-604 design: horizontal inset 18, bottom space 12.
  static const EdgeInsetsDirectional margin = EdgeInsetsDirectional.only(
    start: DabblerSpacing.space6,
    end: DabblerSpacing.space6,
    bottom: DabblerSpacing.space4,
  );
  static const Duration heightDuration = Duration(milliseconds: 220);
  static const Duration fadeDuration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ConnectionStatus current = status ?? ref.watch(connectivityProvider);
    return ConnectionBannerView(status: current);
  }
}

/// Stateful half: remembers the last visible state so the content survives
/// the collapse animation.
class ConnectionBannerView extends StatefulWidget {
  const ConnectionBannerView({super.key, required this.status});

  final ConnectionStatus status;

  @override
  State<ConnectionBannerView> createState() => _ConnectionBannerViewState();
}

class _ConnectionBannerViewState extends State<ConnectionBannerView> {
  // Null until a notice has been shown, and again once it has collapsed, so a
  // connected screen holds no banner in its tree.
  ConnectionStatus? _lastVisible;

  @override
  void initState() {
    super.initState();
    _lastVisible = widget.status == ConnectionStatus.online
        ? null
        : widget.status;
  }

  @override
  void didUpdateWidget(ConnectionBannerView old) {
    super.didUpdateWidget(old);
    if (widget.status != ConnectionStatus.online) {
      _lastVisible = widget.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = widget.status != ConnectionStatus.online;
    final ConnectionStatus? shown = visible ? widget.status : _lastVisible;
    // AnimatedSize asserts on a zero duration (it marks itself for layout from
    // its own controller listener), so reduced motion gets one microsecond.
    final Duration heightMs = _atLeastTick(
      DabblerMotion.durationOf(context, ConnectionBanner.heightDuration),
    );
    final Duration fadeMs = DabblerMotion.durationOf(
      context,
      ConnectionBanner.fadeDuration,
    );
    final bool offline = shown == ConnectionStatus.offline;
    final AppLocalizations l = AppLocalizations.of(context);
    final String text = offline
        ? l.offline_banner_offline
        : l.offline_banner_poor;
    final DabblerBannerTone tone = offline
        ? DabblerBannerTone.error
        : DabblerBannerTone.warning;
    final Color ink = DabblerStatusToneColors.of(
      DabblerColors.of(context),
      tone.status,
    ).ink;

    return AnimatedSize(
      duration: heightMs,
      curve: DabblerMotion.easeOut,
      alignment: AlignmentDirectional.topStart,
      onEnd: () {
        if (mounted && widget.status == ConnectionStatus.online) {
          setState(() => _lastVisible = null);
        }
      },
      child: shown == null
          ? const SizedBox.shrink()
          : ExcludeSemantics(
              excluding: !visible,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  duration: fadeMs,
                  curve: DabblerMotion.easeOut,
                  opacity: visible ? 1 : 0,
                  child: _body(tone, text, offline, ink, visible),
                ),
              ),
            ),
    );
  }

  static const Duration _tick = Duration(microseconds: 1);

  static Duration _atLeastTick(Duration d) => d == Duration.zero ? _tick : d;

  Widget _body(
    DabblerBannerTone tone,
    String text,
    bool offline,
    Color ink,
    bool visible,
  ) {
    // Collapsed: no footprint (height 0) once the animation has run; the
    // banner is clipped to zero height by the surrounding AnimatedSize.
    return Align(
      heightFactor: visible ? 1 : 0,
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: ConnectionBanner.margin,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: text,
          child: ExcludeSemantics(
            child: DabblerBanner(
              tone: tone,
              message: text,
              icon: DabblerIcon(
                offline ? 'cloud-cross' : 'wifi',
                weight: DabblerIconWeight.bold,
                size: DabblerSizing.iconSm,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
