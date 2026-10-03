// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  const LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space2,
      ),
      child: Center(
        child: DabblerButton(
          label: AppLocalizations.of(context).notif_load_older,
          tone: DabblerButtonTone.outlined,
          size: DabblerButtonSize.small,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Initial-load skeleton: a short stack of row-shaped placeholders.
class NotifLoadingView extends StatelessWidget {
  const NotifLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space4,
      ),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: DabblerSpacing.space4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DabblerSkeleton.circle(),
                  SizedBox(width: DabblerSpacing.space4),
                  Expanded(child: DabblerSkeleton.text(lines: 2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: DabblerEmptyState.error(
        title: l10n.notif_error_prefix(message),
        onRetry: onRetry,
        retryLabel: l10n.notif_btn_retry,
      ),
    );
  }
}
