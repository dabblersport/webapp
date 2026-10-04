import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/social/sport.dart';

/// Shared helpers for the onboarding steps. The step page itself is the
/// design system's [DabblerFlowPage]; this file only holds what is not
/// visual: the toast helpers, the loading state, and the mapping from an app
/// [Sport] row to the design system's sport glyph.

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

/// The sport's tint family: the design's per-sport hue, or the fallback hue
/// for a sport the system does not know.
DabblerHueTone onboardingSportTone(Sport sport) =>
    DabblerHueTone.forSportKey(onboardingDsSport(sport)?.key);

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
