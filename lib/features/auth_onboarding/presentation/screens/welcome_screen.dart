import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/design_system/widgets/ds_avatar.dart';
import 'package:dabbler/core/design_system/tokens/avatar_color_palette.dart';
import 'package:dabbler/core/design_system/tokens/avatar_tokens.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  final String displayName;
  final String personaType; // player, organiser, hoster, socialiser
  final bool
  isFirstTime; // true = onboarding, false = returning user or add persona
  final bool isConversion; // true = converting from one persona type to another

  const WelcomeScreen({
    super.key,
    required this.displayName,
    required this.personaType,
    this.isFirstTime = true,
    this.isConversion = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService().getUserProfile(
      fields: const ['avatar_url', 'display_name'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    // Get persona-specific content
    final personaContent = _getPersonaContent(widget.personaType);

    return AdaptiveAuthShell(
      backgroundColor: colorScheme.surface,
      containerColor: colorScheme.secondaryContainer,
      maxCardWidth: isWide ? 960 : 520,
      // WelcomeScreen manages its own two-column desktop layout internally.
      splitWideLayout: false,
      child: isWide
          ? _buildDesktopLayout(context, theme, colorScheme, personaContent)
          : _buildMobileLayout(context, theme, colorScheme, personaContent),
    );
  }

  // ── Desktop: two-column layout ───────────────────────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    _PersonaContent personaContent,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: text content + CTA ──
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getWelcomeTitle(),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    personaContent.guidanceText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    personaContent.philosophyStatement,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildReminderCard(theme, colorScheme, personaContent),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    personaContent.finalEmphasis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: _buildCTAButton(context, theme, colorScheme),
                  ),
                ],
              ),
            ),
          ),

          // ── Right: avatar card ──
          Expanded(
            flex: 3,
            child: Center(
              child: _buildAvatarCard(theme, colorScheme, personaContent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile: original single-column layout ────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    _PersonaContent personaContent,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      _getWelcomeTitle(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildAvatarCard(theme, colorScheme, personaContent),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      personaContent.guidanceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      personaContent.philosophyStatement,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildReminderCard(theme, colorScheme, personaContent),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      personaContent.finalEmphasis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildCTAButton(context, theme, colorScheme),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Shared widgets ───────────────────────────────────────────────────

  Widget _buildAvatarCard(
    ThemeData theme,
    ColorScheme colorScheme,
    _PersonaContent personaContent,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final avatarUrl = profile?['avatar_url'] as String?;
            final avatarDisplayName =
                (profile?['display_name'] as String?) ?? widget.displayName;

            return DSAvatar(
              size: AvatarSize.large,
              customDimension: 80,
              imageUrl: avatarUrl,
              displayName: avatarDisplayName,
              context: AvatarContext.main,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              hasBorder: false,
            );
          },
        ),
        const SizedBox(width: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                personaContent.chipLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReminderCard(
    ThemeData theme,
    ColorScheme colorScheme,
    _PersonaContent personaContent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Don\'t forget',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          personaContent.reminderText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildCTAButton(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return FilledButton(
      onPressed: () {
        routerRefreshNotifier.clearPostLoginWelcome();
        context.go(RoutePaths.home);
      },
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(AppLocalizations.of(context).welcome_screen_continue),
    );
  }

  String _getWelcomeTitle() {
    if (widget.isConversion) {
      return 'Conversion Complete! 🎉';
    } else if (widget.isFirstTime) {
      return 'Welcome to Dabbler 😉';
    } else {
      return 'Welcome Back! 👋';
    }
  }

  _PersonaContent _getPersonaContent(String persona) {
    switch (persona.toLowerCase()) {
      case 'player':
        return _PersonaContent(
          chipLabel: 'Sports player',
          guidanceText:
              'Join games that match your level, respect the rules set by the organiser, and confirm only when you\'re ready to play.',
          philosophyStatement: 'Your reliability builds your reputation.',
          reminderText:
              'Confirm only when you\'re sure you can play.\nRespect the rules, timing, and other players.',
          finalEmphasis: 'Confirm only when you\'re ready to play',
        );

      case 'organiser':
        return _PersonaContent(
          chipLabel: 'Games organiser',
          guidanceText:
              'Create games with clear rules, fair skill levels, and realistic timings.',
          philosophyStatement:
              'You set the tone — great games start with great organisation.',
          reminderText:
              'Set clear rules and realistic timings.\nCommunicate changes early and clearly.',
          finalEmphasis: 'Continue only when you\'re ready!',
        );

      case 'hoster':
        return _PersonaContent(
          chipLabel: 'Venue host',
          guidanceText:
              'Help players feel welcome by keeping information accurate and spaces ready.',
          philosophyStatement:
              'Clear availability and smooth coordination make everyone\'s experience better.',
          reminderText:
              'Keep availability and details accurate.\nUpdate information as soon as things change.',
          finalEmphasis: 'Continue only when you\'re ready!',
        );

      case 'socialiser':
        return _PersonaContent(
          chipLabel: 'Sports socialiser',
          guidanceText:
              'Connect with players, spark conversations, and help games feel more human.',
          philosophyStatement:
              'Your presence shapes the community — friendly, inclusive, and respectful.',
          reminderText:
              'Be respectful and inclusive.\nAdd value without disrupting the game.',
          finalEmphasis: 'Continue only when you\'re ready!',
        );

      default:
        // Fallback to player
        return _PersonaContent(
          chipLabel: 'Sports player',
          guidanceText:
              'Join games that match your level, respect the rules set by the organiser, and confirm only when you\'re ready to play.',
          philosophyStatement: 'Your reliability builds your reputation.',
          reminderText: 'Play fair, communicate clearly, and respect the game.',
          finalEmphasis: 'Confirm only when you\'re ready to play',
        );
    }
  }
}

/// Helper class to hold persona-specific content
class _PersonaContent {
  final String chipLabel;
  final String guidanceText;
  final String philosophyStatement;
  final String reminderText;
  final String finalEmphasis;

  _PersonaContent({
    required this.chipLabel,
    required this.guidanceText,
    required this.philosophyStatement,
    required this.reminderText,
    required this.finalEmphasis,
  });
}
