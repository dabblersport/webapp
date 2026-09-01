import 'dart:ui';

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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/dynamic_background.dart';
import 'package:dabbler/widgets/legal_doc_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

// ── Design tokens from Pencil node fRSW7 (Welcome — Dark) ────────────────────
const _kText = Color(0xFFE6E0E9);
const _kTextMuted = Color(0xFFCAC4CF);
const _kLavender = Color(0xFFC18FFF);

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
          .select('name_en, name_ar')
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
    final darkScheme = AppTheme.darkTheme.colorScheme;
    await showAdaptiveSheet<void>(
      context: context,
      colorSchemeOverride: darkScheme,
      backgroundColor: darkScheme.surfaceContainerHigh,
      builder: (context) => _LanguagePickerSheet(currentLocale: current),
    );
  }

  Future<void> _openCountryPicker() async {
    final selected = ref.read(selectedCountryProvider).valueOrNull;
    final darkScheme = AppTheme.darkTheme.colorScheme;
    final picked = await showAdaptiveSheet<String>(
      context: context,
      colorSchemeOverride: darkScheme,
      backgroundColor: darkScheme.surfaceContainerHigh,
      builder: (context) => _CountryPickerSheet(
        countries: _countries,
        loading: _countriesLoading,
        selectedCountryName: selected,
        languageCode: ref.read(localeProvider).languageCode,
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

  Future<void> _handleApple() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final signedIn = await authService.signInWithApple();
      if (!signedIn) return; // User cancelled the Apple sheet.
      final result = await authService.handleAppleSignInFlow();
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apple sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEmail() => context.go(RoutePaths.emailInput);
  void _handleLogin() => context.go(RoutePaths.enterPassword);

  /// Countries are persisted/selected by their English name (canonical id),
  /// but displayed in the active locale when a translation is available.
  String _localizedCountryName(String englishName, String languageCode) {
    if (languageCode != 'ar') return englishName;
    for (final country in _countries) {
      if (country['name_en'] == englishName) {
        final ar = country['name_ar'] as String?;
        if (ar != null && ar.isNotEmpty) return ar;
      }
    }
    return englishName;
  }

  Widget _buildTermsText(BuildContext context) {
    // Terms Notice — node Cqdmf: 13px, #CAC4CF, line-height 1.45, centered.
    const linkStyle = TextStyle(color: _kLavender);

    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: _kTextMuted, height: 1.45),
        children: [
          TextSpan(text: AppLocalizations.of(context).email_input_terms_prefix),
          TextSpan(
            text: AppLocalizations.of(context).email_input_terms_link,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => showTermsSheet(context),
          ),
          TextSpan(text: AppLocalizations.of(context).email_input_terms_and),
          TextSpan(
            text: AppLocalizations.of(context).email_input_privacy_link,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => showPrivacySheet(context),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryState = ref.watch(selectedCountryProvider);
    final locale = ref.watch(localeProvider);
    final countryName = countryState.maybeWhen(
      data: (c) => _localizedCountryName(c, locale.languageCode),
      orElse: () => 'Global',
    );
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';

    // Always dark, matching Pencil node fRSW7 (Welcome — Dark).
    final darkTheme = AppTheme.darkTheme;
    return Theme(
      data: darkTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: darkTheme.colorScheme.surface,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: DynamicBackground()),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  // Welcome Header — node V0fBC
                                  Text(
                                    '${AppLocalizations.of(context).auth_welcome_title} 👋',
                                    style: const TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w700,
                                      color: _kText,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).auth_welcome_subtitle,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: _kTextMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _TrustBenefitsCard(
                                    heading: AppLocalizations.of(
                                      context,
                                    ).auth_welcome_trust_heading.toUpperCase(),
                                    benefits: [
                                      AppLocalizations.of(
                                        context,
                                      ).auth_welcome_trust_verified,
                                      AppLocalizations.of(
                                        context,
                                      ).auth_welcome_trust_personalised,
                                      AppLocalizations.of(
                                        context,
                                      ).auth_welcome_trust_privacy,
                                    ],
                                  ),
                                  const Spacer(),

                                  // Continue Actions — node cI24o (gap 12)
                                  _GlassButton(
                                    // Glass Button / Dark — node Pnlba
                                    fill: const Color(0xA8241631),
                                    blur: 18,
                                    borderGradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x80FFFFFF),
                                        Color(0x8CC18FFF),
                                        Color(0x1FFFFFFF),
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 24,
                                        offset: Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: Color(0x33C18FFF),
                                        blurRadius: 5,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                    onTap: _isLoading ? null : _handleGoogle,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Iconsax.google_1,
                                          size: 20,
                                          color: _kText,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).auth_welcome_btn_google,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: _kText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassButton(
                                    // Continue with Email — Glass, node MYbIU
                                    fill: const Color(0x66C18FFF),
                                    blur: 20,
                                    borderGradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xB3FFFFFF),
                                        Color(0xCCC18FFF),
                                        Color(0x26FFFFFF),
                                      ],
                                      stops: [0.0, 0.48, 1.0],
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x52C18FFF),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: Color(0x55000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    onTap: _isLoading ? null : _handleEmail,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFFFBF6FF),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Iconsax.sms,
                                                size: 19,
                                                color: Color(0xFFFBF6FF),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).auth_welcome_btn_email,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFFBF6FF),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  if (!kIsWeb &&
                                      defaultTargetPlatform ==
                                          TargetPlatform.iOS) ...[
                                    const SizedBox(height: 12),
                                    _GlassButton(
                                      // Continue with Apple — Black, node LQcOo
                                      fill: const Color(0xFF09090B),
                                      blur: 16,
                                      borderColor: const Color(0x54FFFFFF),
                                      shadows: const [
                                        BoxShadow(
                                          color: Color(0x99000000),
                                          blurRadius: 18,
                                          offset: Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: Color(0x12FFFFFF),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                      onTap: _isLoading ? null : _handleApple,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Iconsax.apple,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).auth_welcome_btn_apple,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: _kText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Existing Account — node tXd9H
                                  SizedBox(
                                    width: double.infinity,
                                    height: 47,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleLogin,
                                      style: TextButton.styleFrom(
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).auth_welcome_btn_login,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: _kLavender,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTermsText(context),
                                  const SizedBox(height: 16),

                                  // Locale Controls — node ll0Ws
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LocalePill(
                                        icon: Iconsax.global,
                                        label: countryName,
                                        onTap: _isLoading
                                            ? () {}
                                            : _openCountryPicker,
                                      ),
                                      const SizedBox(width: 8),
                                      _LocalePill(
                                        icon: Iconsax.language_square,
                                        label: langLabel,
                                        onTap: _isLoading
                                            ? () {}
                                            : _openLanguagePicker,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trust Benefits card — node jOETk ─────────────────────────────────────────

class _TrustBenefitsCard extends StatelessWidget {
  const _TrustBenefitsCard({required this.heading, required this.benefits});

  final String heading;
  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xEE15101E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trust Badge — node KmmCd
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B48E8),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEADDFF),
                  ),
                ),
              ),
              for (var i = 0; i < benefits.length; i++) ...[
                if (i > 0) Container(height: 1, color: const Color(0x24FFFFFF)),
                Container(
                  constraints: BoxConstraints(minHeight: i == 0 ? 50 : 48),
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    benefits[i],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass CTA button — nodes Pnlba / MYbIU / LQcOo ───────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.fill,
    required this.blur,
    required this.shadows,
    required this.onTap,
    required this.child,
    this.borderGradient,
    this.borderColor,
  });

  final Color fill;
  final double blur;
  final List<BoxShadow> shadows;
  final VoidCallback? onTap;
  final Widget child;
  final Gradient? borderGradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: CustomPaint(
              foregroundPainter: _GradientBorderPainter(
                gradient: borderGradient,
                color: borderColor,
                radius: 22,
              ),
              child: Material(
                color: fill,
                child: InkWell(
                  onTap: onTap,
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a 1px inner-aligned rounded-rect stroke with a gradient (Flutter's
/// [Border] can't do gradient strokes).
class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.radius,
    this.gradient,
    this.color,
  });

  final double radius;
  final Gradient? gradient;
  final Color? color;

  static const double width = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color ?? const Color(0x00000000);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(width / 2),
        Radius.circular(radius - width / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) =>
      oldDelegate.gradient != gradient ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;
}

// ── Locale pill — nodes FJ3ef / ZMZ1P ────────────────────────────────────────

class _LocalePill extends StatelessWidget {
  const _LocalePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xE617121E),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _kText),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> countries;
  final bool loading;
  final String? selectedCountryName;
  final String languageCode;

  const _CountryPickerSheet({
    required this.countries,
    required this.loading,
    required this.selectedCountryName,
    required this.languageCode,
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
                final arName = countries[index]['name_ar'] as String?;
                final displayName = (languageCode == 'ar' && arName != null && arName.isNotEmpty)
                    ? arName
                    : name;
                final isSelected = name == selectedCountryName;
                return ListTile(
                  title: Text(
                    displayName,
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
