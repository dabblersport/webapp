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

/// Titled card container shared by the sport profile sections.
class SportSectionCard extends StatelessWidget {
  const SportSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);

    return DabblerSurface.card(
      padding: const EdgeInsets.all(DabblerSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: sportProfileText(
              context,
              DabblerType.title3,
              colors.textPrimary,
            ),
          ),
          const SizedBox(height: DabblerSpacing.space4),
          child,
        ],
      ),
    );
  }
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
