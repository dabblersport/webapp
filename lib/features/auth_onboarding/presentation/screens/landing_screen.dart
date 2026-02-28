import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Landing screen shown after the native splash.
/// This is the first Flutter screen the user sees.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

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
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                height: AppSpacing.xxl,
                                child: SvgPicture.asset(
                                  'assets/logos/logoTypo.svg',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  colorFilter: ColorFilter.mode(
                                    tokens.main.primary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxxl),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.lg,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  CircleAvatar(
                                    radius: AppSpacing.xxxl + AppSpacing.xs,
                                    backgroundColor:
                                        tokens.main.surfaceContainerHigh,
                                    foregroundImage: const AssetImage(
                                      'assets/Avatar/female-3.png',
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: tokens.main.secondary,
                                          borderRadius: AppRadius.circular,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.sports_tennis,
                                                size: AppIconSize.sm,
                                                color: tokens.main.onPrimary,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Text(
                                                'Determined',
                                                style: theme
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color:
                                                          tokens.main.onPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Noor',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              color: tokens.main.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxxl),
                              Text(
                                'I promised myself I\'d play at least twice a week.',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              Text(
                                'Between work and life finding a game feels harder than a 90-minute run.',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Dabbler connects players, captains, and venues so you can stop searching and start playing',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () =>
                                      context.go(RoutePaths.authWelcome),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.main.primary,
                                    foregroundColor: tokens.main.onPrimary,
                                    minimumSize: const Size.fromHeight(
                                      AppButtonSize.extraLargeHeight,
                                    ),
                                    padding: AppButtonSize.extraLargePadding,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    'Continue',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: tokens.main.onPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
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
}
