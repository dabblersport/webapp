import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/ui_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Landing screen shown after the native splash.
/// This is the first Flutter screen the user sees.
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 800;

    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: ClipRRect(
          borderRadius: AppRadius.extraExtraLarge,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colorScheme.secondaryContainer),
            child: SafeArea(
              child: isWide
                  ? _buildDesktopLayout(
                      context,
                      ref,
                      theme,
                      colorScheme,
                      langLabel,
                    )
                  : _buildMobileLayout(
                      context,
                      ref,
                      theme,
                      colorScheme,
                      langLabel,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Desktop: two-column hero layout ──────────────────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    String langLabel,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.xxl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left column: text + CTA ──
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: AppSpacing.xxxl,
                        child: SvgPicture.asset(
                          'assets/logos/logoTypo.svg',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          colorFilter: ColorFilter.mode(
                            colorScheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl * 2),
                      Text(
                        AppLocalizations.of(context).landing_quote1,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        AppLocalizations.of(context).landing_quote2,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Text(
                        AppLocalizations.of(context).landing_tagline,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      SizedBox(
                        width: 320,
                        child: _buildCTAButton(context, theme, colorScheme),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildLanguageButton(
                        context,
                        ref,
                        theme,
                        colorScheme,
                        langLabel,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right column: avatar visual ──
              Expanded(
                flex: 4,
                child: Center(child: _buildAvatarVisual(theme, colorScheme)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile: original single-column layout ────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    String langLabel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildAvatarVisual(theme, colorScheme),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      AppLocalizations.of(context).landing_quote1,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      AppLocalizations.of(context).landing_quote2,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context).landing_tagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: _buildCTAButton(context, theme, colorScheme),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: _buildLanguageButton(
                        context,
                        ref,
                        theme,
                        colorScheme,
                        langLabel,
                      ),
                    ),
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

  Widget _buildAvatarVisual(ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        CircleAvatar(
          radius: AppSpacing.xxxl + AppSpacing.xs,
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundImage: const AssetImage('assets/Avatar/female-3.png'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.secondary,
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
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Determined',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Noor',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
      onPressed: () => context.go(RoutePaths.authWelcome),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
        padding: AppButtonSize.extraLargePadding,
        shape: const StadiumBorder(),
      ),
      child: Text(
        AppLocalizations.of(context).landing_continue,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLanguageButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    String langLabel,
  ) {
    return ActionChip(
      avatar: Icon(
        Icons.language_rounded,
        size: AppIconSize.sm,
        color: colorScheme.onSurfaceVariant,
      ),
      label: Text(langLabel),
      onPressed: () => showAdaptiveSheet<void>(
        context: context,
        builder: (ctx) => _LandingLanguagePickerSheet(ref: ref),
      ),
    );
  }
}

// ── Language picker bottom sheet ────────────────────────────────────────────

class _LandingLanguagePickerSheet extends StatelessWidget {
  const _LandingLanguagePickerSheet({required this.ref});

  final WidgetRef ref;

  static const _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'العربية'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = ref.watch(localeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).landing_choose_language,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        ..._languages.map((lang) {
          final isSelected = current.languageCode == lang['code'];
          return ListTile(
            title: Text(
              lang['name']!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : null,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check, color: colorScheme.primary)
                : null,
            onTap: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(Locale(lang['code']!));
              Navigator.of(context).pop();
            },
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
