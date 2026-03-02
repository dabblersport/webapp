import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:flutter/material.dart';
import 'package:dabbler/utils/ui_constants.dart';

/// Shared adaptive wrapper for all auth / onboarding screens.
///
/// **Mobile (<800 px):** The card fills the screen — identical to the current
/// Scaffold → Padding → ClipRRect → DecoratedBox → SafeArea structure.
///
/// **Desktop (≥800 px):** Landing-style two-column layout.
///   - Scaffold background is unified with [containerColor] (no outer background
///     peeking behind the content).
///   - Left panel: [leftPanelContent] if provided, otherwise the default
///     Dabbler brand panel.
///   - Right panel: the [child] form content, centered and width-constrained.
class AdaptiveAuthShell extends StatelessWidget {
  const AdaptiveAuthShell({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.containerColor,
    this.resizeToAvoidBottomInset,
    this.maxCardWidth = 520,
    this.leftPanelContent,
    this.splitWideLayout = true,
  });

  /// The content rendered inside the card / right panel.
  final Widget child;

  /// Background colour for the left branding panel on wide screens, and the
  /// outer scaffold on mobile – typically `tokens.main.background`.
  final Color backgroundColor;

  /// Card / right-panel surface – typically `tokens.main.secondaryContainer`.
  final Color containerColor;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  /// Maximum width of the right-panel form content on wide screens.
  final double maxCardWidth;

  /// Optional custom widget for the left branding panel (wide screens only).
  /// When omitted, [_DefaultBrandPanel] is shown.
  final Widget? leftPanelContent;

  /// When true (default), wide screens use the two-column brand + form split.
  /// Set to false for screens that manage their own wide layout (e.g. WelcomeScreen).
  final bool splitWideLayout;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (!isWide) {
      // ── Mobile: full-screen rounded card ─────────────────────────────
      return Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: ClipRRect(
            borderRadius: AppRadius.extraExtraLarge,
            child: DecoratedBox(
              decoration: BoxDecoration(color: containerColor),
              child: SafeArea(child: child),
            ),
          ),
        ),
      );
    }

    // ── Wide screen: unified landing layout ───────────────────────────
    if (!splitWideLayout) {
      // Screen manages its own wide layout — use legacy centred-card behaviour.
      return Scaffold(
        backgroundColor: containerColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: SafeArea(child: child),
          ),
        ),
      );
    }

    return Scaffold(
      // Unified: scaffold bg == containerColor so no outer colour peeking.
      backgroundColor: containerColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: branding panel
            Expanded(
              flex: 5,
              child:
                  leftPanelContent ??
                  _DefaultBrandPanel(panelColor: containerColor),
            ),

            // Subtle divider
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: containerColor.withValues(alpha: 0.3),
            ),

            // Right: form content
            Expanded(
              flex: 5,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Default brand panel ──────────────────────────────────────────────────────

class _DefaultBrandPanel extends StatelessWidget {
  const _DefaultBrandPanel({required this.panelColor});

  final Color panelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    return ColoredBox(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl * 1.5,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App wordmark
            Text(
              'Dabbler',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: tokens.main.onSecondaryContainer,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Join the local sports community',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: tokens.main.onSecondaryContainer.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl * 2),
            Text(
              'Built for trust',
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.main.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _BulletRow(
              icon: Icons.check_circle,
              text: 'Reviewed players, verified memberships and rated venues',
              tokens: tokens,
            ),
            const SizedBox(height: AppSpacing.lg),
            _BulletRow(
              icon: Icons.check_circle,
              text:
                  'Connections and recommendations personalised to your sports',
              tokens: tokens,
            ),
            const SizedBox(height: AppSpacing.lg),
            _BulletRow(
              icon: Icons.check_circle,
              text: 'We do not sell your data — privacy-first by design',
              tokens: tokens,
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.text,
    required this.tokens,
  });

  final IconData icon;
  final String text;
  final dynamic tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.sm, color: tokens.main.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.main.onSecondaryContainer.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
