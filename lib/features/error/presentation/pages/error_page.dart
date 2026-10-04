import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/utils/constants/route_constants.dart';

/// Error route page. Built from the design system: a [DabblerPage] with a
/// titled top bar and a [DabblerEmptyState.error] whose retry action keeps the
/// previous behaviour (pop when possible, otherwise go home). No design frame
/// exists for it.
class ErrorPage extends StatelessWidget {
  final String? message;

  const ErrorPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: const DabblerNavigationTopBar.titled(title: 'Error'),
      body: Center(
        child: DabblerEmptyState.error(
          title: message ?? 'An error occurred',
          text: 'Please try again or contact support if the problem persists.',
          retryLabel: 'Retry',
          onRetry: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.home),
        ),
      ),
    );
  }
}
