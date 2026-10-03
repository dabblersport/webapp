import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/social/sport.dart';

/// Shared chrome for the five onboarding steps (create user info, persona,
/// sports, primary sport, identity), built from the Dabbler design system
/// only. Mirrors the `isStep` frame of `Auth and Onboarding.dc.html`: a back
/// arrow, the five-step progress with its caption, a display title and a
/// subtitle, the scrolling step body, and a full-width primary action.

/// Resolves a DS type step for the current direction with a colour.
TextStyle onboardingType(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

/// Shows an error toast when a [DabblerToastProvider] is mounted.
void showOnboardingError(BuildContext context, String message) {
  DabblerToastProvider.maybeOf(
    context,
  )?.show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
}

/// Shows a warning toast when a [DabblerToastProvider] is mounted.
void showOnboardingWarning(BuildContext context, String message) {
  DabblerToastProvider.maybeOf(
    context,
  )?.show(DabblerToastSpec(message: message, tone: DabblerToastTone.warning));
}

/// The full-page loading state used while a step reads its data.
class OnboardingLoading extends StatelessWidget {
  const OnboardingLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const DabblerPage(body: Center(child: DabblerSpinner()));
  }
}

/// One onboarding step page.
class OnboardingStepFrame extends StatelessWidget {
  const OnboardingStepFrame({
    super.key,
    required this.onBack,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    this.subtitle,
    this.stepLabel,
    this.step,
    this.ctaLoading = false,
    this.secondary,
  });

  final VoidCallback onBack;

  /// The caption under the progress, e.g. `Step 1 of 5`. Null hides it.
  final String? stepLabel;

  /// The 1-based step, drawn as progress out of [totalSteps]. Null hides it.
  final int? step;

  final String title;
  final String? subtitle;

  /// The step body. It scrolls on its own when it is a sliver-free widget.
  final Widget body;

  final String ctaLabel;

  /// Null draws the CTA disabled.
  final VoidCallback? onCta;
  final bool ctaLoading;

  /// An optional widget under the CTA (e.g. a text Back action).
  final Widget? secondary;

  static const int totalSteps = 5;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DabblerPage(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space4,
                    DabblerSpacing.space2,
                    DabblerSpacing.space8,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    // `arrow-left` mirrored under RTL: `arrow-right`
                    // is a boxed glyph, not the counterpart of `arrow-left`.
                    child: Transform.flip(
                      flipX: rtl,
                      child: DabblerButton.icon(
                        icon: 'arrow-left',
                        tone: DabblerButtonTone.text,
                        semanticLabel: 'Back',
                        onPressed: onBack,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space8,
                    DabblerSpacing.space2,
                    DabblerSpacing.space8,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (step != null) ...[
                        DabblerStepProgress(
                          count: totalSteps,
                          current: (step! - 1).clamp(0, totalSteps - 1),
                          label: stepLabel,
                        ),
                        const SizedBox(height: DabblerSpacing.space5),
                      ] else if (stepLabel != null) ...[
                        Text(
                          stepLabel!.toUpperCase(),
                          style: onboardingType(
                            context,
                            DabblerType.caption1,
                            colors.textSecondary,
                            weight: DabblerType.semibold,
                          ),
                        ),
                        const SizedBox(height: DabblerSpacing.space5),
                      ],
                      Text(
                        title,
                        style: onboardingType(
                          context,
                          DabblerType.title1,
                          colors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: DabblerSpacing.space2),
                        Text(
                          subtitle!,
                          style: onboardingType(
                            context,
                            DabblerType.subheadline,
                            colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space6),
                Expanded(child: body),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space8,
                    DabblerSpacing.space6,
                    DabblerSpacing.space8,
                    DabblerSpacing.space8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DabblerButton(
                        label: ctaLabel,
                        size: DabblerButtonSize.full,
                        fullWidth: true,
                        loading: ctaLoading,
                        disabled: onCta == null && !ctaLoading,
                        onPressed: onCta,
                      ),
                      if (secondary != null) ...[
                        const SizedBox(height: DabblerSpacing.space3),
                        secondary!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable option card: the design's persona / gender / sport row shell.
///
/// Unselected is the card surface with the default border; selected is the
/// DS `brandTint` surface with a 2px brand border (the design's tinted
/// selected card; the DS `selected` variant is a solid brand fill).
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(DabblerSpacing.space5),
    this.radius = DabblerRadius.lg,
    this.semanticLabel,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: selected
            ? DabblerSurface.brandTint(
                radius: radius,
                borderColor: colors.brandPrimary,
                borderWidth: 2,
                padding: padding,
                child: child,
              )
            : DabblerSurface.card(
                radius: radius,
                borderColor: colors.borderDefault,
                borderWidth: 1,
                padding: padding,
                child: child,
              ),
      ),
    );
  }
}

/// Maps an app [Sport] row to the DS sport, or null when the system has no
/// glyph for it. Tries `sport_key`, then the English name, kebab-cased.
DabblerSport? onboardingDsSport(Sport sport) {
  String norm(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  const aliases = <String, DabblerSport>{
    'soccer': DabblerSport.football,
    'ping-pong': DabblerSport.tableTennis,
    'tabletennis': DabblerSport.tableTennis,
    'fitness': DabblerSport.gym,
    'field-hockey': DabblerSport.hockey,
    'ice-hockey': DabblerSport.hockey,
  };
  for (final raw in <String?>[sport.sportKey, sport.nameEn]) {
    if (raw == null || raw.trim().isEmpty) continue;
    final key = norm(raw);
    final found = DabblerSport.fromKey(key) ?? aliases[key];
    if (found != null) return found;
  }
  return null;
}

/// The sport glyph: [DabblerSportIcon] for a known sport, otherwise the
/// neutral `game` [DabblerIcon]. Never an emoji.
class OnboardingSportGlyph extends StatelessWidget {
  const OnboardingSportGlyph({
    super.key,
    required this.sport,
    required this.selected,
    required this.size,
    required this.color,
  });

  final Sport sport;
  final bool selected;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final weight = selected ? DabblerIconWeight.bold : DabblerIconWeight.linear;
    final ds = onboardingDsSport(sport);
    if (ds != null) {
      return DabblerSportIcon(ds, weight: weight, size: size, color: color);
    }
    return DabblerIcon('game', weight: weight, size: size, color: color);
  }
}

/// The selected / unselected radio glyph of the design's option rows.
class OnboardingRadioGlyph extends StatelessWidget {
  const OnboardingRadioGlyph({
    super.key,
    required this.selected,
    this.size = 22,
  });

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerIcon(
      selected ? 'tick-circle' : 'record',
      weight: selected ? DabblerIconWeight.bold : DabblerIconWeight.linear,
      size: size,
      color: selected ? colors.brandPrimary : colors.borderStrong,
    );
  }
}
