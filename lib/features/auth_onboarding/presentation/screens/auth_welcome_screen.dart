import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';

class AuthWelcomeScreen extends ConsumerStatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  ConsumerState<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends ConsumerState<AuthWelcomeScreen> {
  bool _isLoading = false;

  List<Map<String, dynamic>> _countries = [];
  bool _countriesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    try {
      final response = await Supabase.instance.client
          .from('ref_countries')
          .select('name_en')
          .eq('coverage', true)
          .order('name_en');
      if (mounted) {
        setState(() {
          _countries = (response as List).cast<Map<String, dynamic>>();
          _countriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _countriesLoading = false);
    }
  }

  Future<void> _openLanguagePicker() async {
    final current = ref.read(localeProvider);
    await showAdaptiveSheet<void>(
      context: context,
      builder: (context) => _LanguagePickerSheet(currentLocale: current),
    );
  }

  Future<void> _openCountryPicker() async {
    final selected = ref.read(selectedCountryProvider).valueOrNull;

    final picked = await showAdaptiveSheet<String>(
      context: context,
      builder: (context) => _CountryPickerSheet(
        countries: _countries,
        loading: _countriesLoading,
        selectedCountryName: selected,
      ),
    );

    if (!mounted || picked == null) return;
    await ref.read(selectedCountryProvider.notifier).setCountry(picked);
  }

  Future<void> _handleGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);

      final launched = await authService.signInWithGoogle();
      if (!launched) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // On web, signInWithGoogle() triggers a full-page redirect to Google.
      // The browser navigates away immediately — nothing below runs until
      // the user returns, at which point Supabase restores the session and
      // onAuthStateChange fires, letting the router redirect to home.
      if (kIsWeb) return;

      // Check the result after OAuth completes (mobile only)
      final result = await authService.handleGoogleSignInFlow();

      if (!mounted) return;

      // Navigate based on result
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          // New Google user - go to onboarding
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;

        case GoogleSignInResultGoToSetUsername():
          // Legacy case
          context.go(
            RoutePaths.setUsername,
            extra: {
              'email': result.email,
              'suggestedUsername': result.suggestedUsername,
            },
          );
          break;

        case GoogleSignInResultGoToPhoneOtp():
          // New Google user (with phone) - go to OTP
          context.push(
            RoutePaths.otpVerification,
            extra: {
              'phone': result.phone,
              'email': result.email,
              'userExistsBeforeOtp': false,
            },
          );
          break;

        case GoogleSignInResultGoToHome():
          // Existing Google user - navigate to home (welcome screen will show first via router)
          context.go(RoutePaths.home);
          break;

        case GoogleSignInResultRequirePassword():
          // Existing user (non-Google) - require password
          context.push(
            RoutePaths.enterPassword,
            extra: {'email': result.email},
          );
          break;

        case GoogleSignInResultError():
          // Error occurred
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.message)));
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).auth_welcome_google_error(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleApple() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).auth_welcome_apple_soon)),
    );
  }

  void _handleEmail() {
    context.go(RoutePaths.emailInput);
  }

  void _handleLogin() {
    context.go(RoutePaths.enterPassword);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final countryState = ref.watch(selectedCountryProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    final countryName = countryState.maybeWhen(
      data: (country) => country,
      orElse: () => 'Global',
    );

    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';

    return AdaptiveAuthShell(
      backgroundColor: colorScheme.surface,
      containerColor: colorScheme.secondaryContainer,
      leftPanelContent: isWide
          ? _WelcomeLeftPanel(colorScheme: colorScheme, theme: theme)
          : null,
      child: isWide
          ? _buildWideCTAs(context, theme, colorScheme, isDark, countryName, langLabel)
          : _buildMobileContent(context, theme, colorScheme, isDark, countryName, langLabel),
    );
  }

  // ── Wide: right-panel CTAs only ──────────────────────────────────────

  Widget _buildWideCTAs(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
    String countryName,
    String langLabel,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppLocalizations.of(context).auth_welcome_get_started,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).auth_welcome_get_started_subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            ..._buildCTAButtons(context, theme, colorScheme, isDark),
            const SizedBox(height: AppSpacing.xxxl),
            _buildLocaleSwitchers(context, theme, colorScheme, countryName, langLabel),
          ],
        ),
      ),
    );
  }

  // ── Mobile: original full-column layout ─────────────────────────────

  Widget _buildMobileContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
    String countryName,
    String langLabel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),

                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context).auth_welcome_title,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '👋',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppLocalizations.of(context).auth_welcome_subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      AppLocalizations.of(context).auth_welcome_trust_heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TrustBullet(
                      text: AppLocalizations.of(context).auth_welcome_trust_verified,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TrustBullet(
                      text: AppLocalizations.of(context).auth_welcome_trust_personalised,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TrustBullet(
                      text: AppLocalizations.of(context).auth_welcome_trust_privacy,
                      colorScheme: colorScheme,
                    ),
                    const Spacer(),
                    ..._buildCTAButtons(context, theme, colorScheme, isDark),
                    const Spacer(),
                    _buildLocaleSwitchers(context, theme, colorScheme, countryName, langLabel),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Locale switchers row ────────────────────────────────────────────

  Widget _buildLocaleSwitchers(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String countryName,
    String langLabel,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionChip(
              avatar: Icon(
                Icons.public_rounded,
                size: AppIconSize.sm,
                color: colorScheme.onSurfaceVariant,
              ),
              label: Text(countryName),
              onPressed: _isLoading ? null : _openCountryPicker,
            ),
            const SizedBox(width: AppSpacing.sm),
            ActionChip(
              avatar: Icon(
                Icons.language_rounded,
                size: AppIconSize.sm,
                color: colorScheme.onSurfaceVariant,
              ),
              label: Text(langLabel),
              onPressed: _isLoading ? null : _openLanguagePicker,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared CTA buttons list ──────────────────────────────────────────

  List<Widget> _buildCTAButtons(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final googleBg = isDark
        ? colorScheme.inverseSurface
        : colorScheme.surfaceContainerLowest;
    final googleFg = isDark ? colorScheme.onInverseSurface : colorScheme.onSurface;

    return [
      FilledButton(
        onPressed: _isLoading ? null : _handleGoogle,
        style: FilledButton.styleFrom(
          backgroundColor: googleBg,
          foregroundColor: googleFg,
          minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
          padding: AppButtonSize.extraLargePadding,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/google.svg',
              width: AppIconSize.sm,
              height: AppIconSize.sm,
              colorFilter: ColorFilter.mode(googleFg, BlendMode.srcIn),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).auth_welcome_btn_google,
              style: theme.textTheme.titleMedium?.copyWith(
                color: googleFg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
        FilledButton(
          onPressed: _isLoading ? null : _handleApple,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.scrim,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
            padding: AppButtonSize.extraLargePadding,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/apple.svg',
                width: AppIconSize.sm,
                height: AppIconSize.sm,
                colorFilter: ColorFilter.mode(
                  colorScheme.onPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppLocalizations.of(context).auth_welcome_btn_apple,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      FilledButton(
        onPressed: _isLoading ? null : _handleEmail,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
          padding: AppButtonSize.extraLargePadding,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: AppIconSize.sm,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).auth_welcome_btn_email,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: TextButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: Text(
            AppLocalizations.of(context).auth_welcome_btn_login,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ];
  }
}

// ── Country picker bottom sheet ──────────────────────────────────────────────

class _CountryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> countries;
  final bool loading;
  final String? selectedCountryName;

  const _CountryPickerSheet({
    required this.countries,
    required this.loading,
    required this.selectedCountryName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).auth_welcome_country_picker_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: CircularProgressIndicator(color: colorScheme.primary),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: countries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final countryName = countries[index]['name_en'] as String;
                final isSelected = countryName == selectedCountryName;
                return ListTile(
                  title: Text(
                    countryName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : null,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(countryName),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Wide-screen left branding panel ─────────────────────────────────────────

class _WelcomeLeftPanel extends StatelessWidget {
  const _WelcomeLeftPanel({
    required this.colorScheme,
    required this.theme,
  });

  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl * 1.5,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppLocalizations.of(context).auth_welcome_title,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '👋',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.of(context).auth_welcome_subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl * 1.5),
            Text(
              AppLocalizations.of(context).auth_welcome_trust_heading,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _TrustBullet(
              text: AppLocalizations.of(context).auth_welcome_trust_verified,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: AppSpacing.lg),
            _TrustBullet(
              text: AppLocalizations.of(context).auth_welcome_trust_personalised,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: AppSpacing.lg),
            _TrustBullet(
              text: AppLocalizations.of(context).auth_welcome_trust_privacy,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language picker bottom sheet ────────────────────────────────────────────

class _LanguagePickerSheet extends ConsumerWidget {
  const _LanguagePickerSheet({required this.currentLocale});

  final Locale currentLocale;

  static const _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'العربية'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              AppLocalizations.of(context).auth_welcome_language_picker_title,
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

// ── Shared trust bullet widget ───────────────────────────────────────────────

class _TrustBullet extends StatelessWidget {
  const _TrustBullet({required this.text, required this.colorScheme});

  final String text;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          size: AppIconSize.sm,
          color: colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
