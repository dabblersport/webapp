import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Shared design-system pieces for the admin screens (moderation queue and
/// safety overview). No design frame exists for either screen: DS defaults.

/// The "not an administrator" page body.
class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(DabblerSpacing.space7),
      child: DabblerEmptyState(
        icon: 'lock',
        size: DabblerEmptyStateSize.page,
        title: 'Access Denied',
        text: 'You must be an administrator to access this page.',
      ),
    ),
  );
}

/// A centred error page with a retry button.
class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.title,
    this.text,
    this.onRetry,
  });

  final String title;
  final String? text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space7),
      child: DabblerEmptyState.error(
        title: title,
        text: text,
        onRetry: onRetry,
        retryLabel: 'Retry',
      ),
    ),
  );
}

/// A label / value line used in the detail sheet and the overview card.
class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth,
  });

  final String label;
  final String value;

  /// Fixed label column width; null spreads label and value to both ends.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final labelText = Text(
      label,
      style: DabblerType.subheadline
          .resolveForDirection(Directionality.of(context))
          .copyWith(
            color: colors.textSecondary,
            fontWeight: labelWidth != null ? DabblerType.semibold : null,
          ),
    );
    final valueStyle = DabblerType.subheadline
        .resolveForDirection(Directionality.of(context))
        .copyWith(
          color: colors.textPrimary,
          fontWeight: labelWidth == null ? DabblerType.semibold : null,
        );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: labelWidth != null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: labelWidth, child: labelText),
                Expanded(child: Text(value, style: valueStyle)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                labelText,
                Flexible(
                  child: Text(
                    value,
                    style: valueStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The admin pages' loading body.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: DabblerSpinner());
}
