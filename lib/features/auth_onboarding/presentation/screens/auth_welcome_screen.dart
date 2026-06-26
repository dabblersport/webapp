import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
          .from(SupabaseConfig.refCountriesTable)
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
      if (kIsWeb) return;
      final result = await authService.handleGoogleSignInFlow();
      if (!mounted) return;
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;
        case GoogleSignInResultGoToSetUsername():
          context.go(
            RoutePaths.setUsername,
            extra: {
              'email': result.email,
              'suggestedUsername': result.suggestedUsername,
            },
          );
          break;
        case GoogleSignInResultGoToPhoneOtp():
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
          context.go(RoutePaths.home);
          break;
        case GoogleSignInResultRequirePassword():
          context.push(
            RoutePaths.enterPassword,
            extra: {'email': result.email},
          );
          break;
        case GoogleSignInResultError():
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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).auth_welcome_google_error(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleApple() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).auth_welcome_apple_soon),
      ),
    );
  }

  void _handleEmail() => context.go(RoutePaths.emailInput);
  void _handleLogin() => context.go(RoutePaths.enterPassword);

  @override
  Widget build(BuildContext context) {
    final countryState = ref.watch(selectedCountryProvider);
    final countryName = countryState.maybeWhen(
      data: (c) => c,
      orElse: () => 'Global',
    );
    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: GradientBlob(color: colorScheme.primary, size: 320, opacity: 0.25),
            ),
            Positioned(
              bottom: 200,
              left: -100,
              child: GradientBlob(color: kObPink, size: 280, opacity: 0.18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.6,
                              color: colorScheme.onSurface,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('👋', style: TextStyle(fontSize: 36)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "We're stoked to have you. Create an account and start dabbling in local sports.",
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Glassmorphic trust card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: colorScheme.primaryContainer,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.verify, size: 13, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'BUILT FOR TRUST',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._kTrustItems.asMap().entries.map((e) {
                          return Column(
                            children: [
                              if (e.key > 0)
                                Divider(height: 1, color: colorScheme.outlineVariant),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [colorScheme.primary, colorScheme.onPrimaryContainer],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        e.value.icon,
                                        size: 17,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          e.value.text,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.4,
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // CTAs
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    children: [
                      _OutlineButton(
                        onPressed: _isLoading ? null : _handleGoogle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.google_1,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OnboardingCTAButton(
                        label: AppLocalizations.of(
                          context,
                        ).auth_welcome_btn_email,
                        onPressed: _isLoading ? null : _handleEmail,
                        isLoading: _isLoading,
                        icon: Icon(
                          Iconsax.sms,
                          size: 20,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS) ...[
                        const SizedBox(height: 12),
                        _OutlineButton(
                          onPressed: _handleApple,
                          bgColor: const Color(0xFF2C2A33),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/apple.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).auth_welcome_btn_apple,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Country / Language pills
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassPill(
                        icon: Iconsax.global,
                        label: countryName ?? 'Global',
                        onTap: _isLoading ? () {} : _openCountryPicker,
                      ),
                      const SizedBox(width: 8),
                      GlassPill(
                        icon: Iconsax.language_square,
                        label: langLabel,
                        onTap: _isLoading ? () {} : _openLanguagePicker,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem {
  final IconData icon;
  final String text;
  const _TrustItem(this.icon, this.text);
}

const _kTrustItems = [
  _TrustItem(
    Iconsax.medal_star,
    'Reviewed players, verified memberships, rated venues',
  ),
  _TrustItem(
    Iconsax.setting_3,
    'Connections and recommendations personalised to your sports',
  ),
  _TrustItem(Iconsax.lock, "We don't sell your data — privacy-first by design"),
];

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.child, this.onPressed, this.bgColor});
  final Widget child;
  final VoidCallback? onPressed;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bgColor ?? colorScheme.surfaceContainerLowest,
          border: bgColor == null
              ? Border.all(color: colorScheme.outlineVariant, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

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
                final name = countries[index]['name_en'] as String;
                final isSelected = name == selectedCountryName;
                return ListTile(
                  title: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : null,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Iconsax.tick_circle, color: colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(name),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

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
                ? Icon(Iconsax.tick_circle, color: colorScheme.primary)
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
