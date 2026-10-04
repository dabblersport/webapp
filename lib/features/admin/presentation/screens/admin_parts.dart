import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Shared design-system pieces for the admin screens (moderation queue and
/// safety overview). No design frame exists for either screen: DS defaults.

/// The "not an administrator" page body.
class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: DabblerEmptyState(
      icon: 'lock',
      size: DabblerEmptyStateSize.page,
      title: 'Access Denied',
      text: 'You must be an administrator to access this page.',
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
    child: DabblerEmptyState.error(
      title: title,
      text: text,
      onRetry: onRetry,
      retryLabel: 'Retry',
    ),
  );
}

/// The admin pages' loading body.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: DabblerSpinner());
}
