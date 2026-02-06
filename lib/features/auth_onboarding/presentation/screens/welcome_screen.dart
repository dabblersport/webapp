import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/ui_constants.dart';

class WelcomeScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    // Get persona-specific content
    final personaContent = _getPersonaContent(personaType);

    return Scaffold(
      backgroundColor: tokens.main.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: ClipRRect(
          borderRadius: AppRadius.extraExtraLarge,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.main.secondaryContainer),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.xxxl),

                              // 2. Title
                              Text(
                                _getWelcomeTitle(),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                                textAlign: TextAlign.left,
                              ),

                              const SizedBox(height: AppSpacing.xxxl),

                              Row(
                                children: [
                                  // 1. Avatar with initials
                                  Center(
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundColor: tokens.main.primary,
                                      child: Text(
                                        _getInitials(displayName),
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: tokens.main.onPrimary,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 3. Display name
                                      Text(
                                        displayName,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: tokens
                                                  .main
                                                  .onSecondaryContainer,
                                            ),
                                        textAlign: TextAlign.left,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),

                                      // 4. Persona chip
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.lg,
                                            vertical: AppSpacing.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.main.secondary,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: tokens.main.outline
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            personaContent.chipLabel,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color:
                                                      tokens.main.onSecondary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppSpacing.xxxl),

                              // 5. Primary guidance text
                              Text(
                                personaContent.guidanceText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  height: 1.25,
                                ),
                                textAlign: TextAlign.left,
                              ),

                              const SizedBox(height: AppSpacing.xxl),

                              // 5. Core philosophy statement
                              Text(
                                personaContent.philosophyStatement,
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: tokens.main.primary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.left,
                              ),

                              const SizedBox(height: AppSpacing.xxxl),
                              const SizedBox(height: AppSpacing.xl),

                              // 6. Reminder section
                              Container(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Don\'t forget',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: tokens
                                                .main
                                                .onSecondaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      personaContent.reminderText,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tokens
                                                .main
                                                .onSecondaryContainer,
                                            height: 1.7,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // 7. Final emphasis line
                              Text(
                                personaContent.finalEmphasis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: AppSpacing.xl),
                              // 8. Primary CTA
                              FilledButton(
                                onPressed: () {
                                  routerRefreshNotifier.clearPostLoginWelcome();
                                  context.go(RoutePaths.home);
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  shape: const StadiumBorder(),
                                  backgroundColor: tokens.main.primary,
                                  foregroundColor: tokens.main.onPrimary,
                                  textStyle: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                child: const Text('Continue'),
                              ),

                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getWelcomeTitle() {
    if (isConversion) {
      return 'Conversion Complete! 🎉';
    } else if (isFirstTime) {
      return 'Welcome to Dabbler 😉';
    } else {
      return 'Welcome Back! 👋';
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';

    if (parts.length == 1) {
      // Single name: take first two characters
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    } else {
      // Multiple names: take first character of first and last name
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
              'Confirm only when you’re sure you can play.\nRespect the rules, timing, and other players.',
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
