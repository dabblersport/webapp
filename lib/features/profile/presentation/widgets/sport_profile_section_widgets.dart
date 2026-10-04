import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Resolves a DS type step against the ambient direction and tints it.
TextStyle sportProfileText(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) {
  return step
      .resolveForDirection(Directionality.of(context))
      .copyWith(color: color, fontWeight: weight);
}

/// Titled section shared by the sport profile sections — the design's
/// section header (15 semibold title) over its content, drawn by
/// [DabblerSection].
class SportSectionCard extends StatelessWidget {
  const SportSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DabblerSection(
    title: title,
    style: DabblerSectionStyle.label,
    children: [child],
  );
}

/// Icon + message placeholder for empty sport profile sections.
///
/// [icon] is a kebab-case DS icon name rendered through [DabblerIcon].
class SportEmptySection extends StatelessWidget {
  const SportEmptySection({
    super.key,
    required this.icon,
    required this.message,
  });

  final String icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DabblerEmptyState(icon: icon, title: message);
  }
}

/// Inline loading indicator for sections that fetch independently.
class SportSectionLoading extends StatelessWidget {
  const SportSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space7),
      child: Center(child: DabblerSpinner()),
    );
  }
}
