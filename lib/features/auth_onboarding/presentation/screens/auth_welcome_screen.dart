import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  void _toastError(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
  }

  Future<void> _openLanguagePicker() async {
    final current = ref.read(localeProvider);
    await showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.4],
      builder: (context) => _LanguagePickerSheet(currentLocale: current),
    );
  }

  Future<void> _openCountryPicker() async {
    final selected = ref.read(selectedCountryProvider).valueOrNull;
    final picked = await showDabblerSheet<String>(
      context: context,
      detents: const <double>[0.6],
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
            _toastError(result.message);
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _toastError(
        AppLocalizations.of(context).auth_welcome_google_error(e.toString()),
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
          _toastError(result.message);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _toastError('Apple sign-in failed: $e');
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final countryState = ref.watch(selectedCountryProvider);
    final locale = ref.watch(localeProvider);
    final countryName = countryState.maybeWhen(
      data: (c) => _localizedCountryName(c, locale.languageCode),
      orElse: () => 'Global',
    );
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return DabblerPage(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: DabblerSpacing.space8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: DabblerSpacing.space6),
                        DabblerText(
                          l10n.auth_welcome_title,
                          style: DabblerType.largeTitle,
                        ),
                        const SizedBox(height: DabblerSpacing.space3),
                        DabblerText(
                          l10n.auth_welcome_subtitle,
                          tone: DabblerTextTone.secondary,
                        ),
                        const SizedBox(height: DabblerSpacing.space8),
                        _TrustBenefitsCard(
                          heading: l10n.auth_welcome_trust_heading
                              .toUpperCase(),
                          benefits: [
                            ('verify', l10n.auth_welcome_trust_verified),
                            ('activity', l10n.auth_welcome_trust_personalised),
                            ('lock', l10n.auth_welcome_trust_privacy),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: DabblerSpacing.space6),
                        authIdentify(
                          'auth-welcome-continue-email',
                          DabblerButton(
                            label: l10n.auth_welcome_btn_email,
                            icon: 'sms',
                            size: DabblerButtonSize.full,
                            fullWidth: true,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _handleEmail,
                          ),
                        ),
                        const SizedBox(height: DabblerSpacing.space4),
                        authIdentify(
                          'auth-welcome-continue-google',
                          _WithProviderMark(
                            mark: const DabblerProviderMark.google(
                              size: DabblerSizing.iconLg,
                              excludeFromSemantics: true,
                            ),
                            child: DabblerButton(
                              label: l10n.auth_welcome_btn_google,
                              tone: DabblerButtonTone.outlined,
                              size: DabblerButtonSize.full,
                              fullWidth: true,
                              disabled: _isLoading,
                              onPressed: _isLoading ? null : _handleGoogle,
                            ),
                          ),
                        ),
                        if (showApple) ...[
                          const SizedBox(height: DabblerSpacing.space4),
                          authIdentify(
                            'auth-welcome-continue-apple',
                            _WithProviderMark(
                              mark: const DabblerProviderMark.apple(
                                size: DabblerSizing.iconLg,
                                excludeFromSemantics: true,
                              ),
                              child: DabblerButton(
                                label: l10n.auth_welcome_btn_apple,
                                tone: DabblerButtonTone.outlined,
                                size: DabblerButtonSize.full,
                                fullWidth: true,
                                disabled: _isLoading,
                                onPressed: _isLoading ? null : _handleApple,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: DabblerSpacing.space2),
                        DabblerButton(
                          label: l10n.auth_welcome_btn_login,
                          tone: DabblerButtonTone.text,
                          fullWidth: true,
                          disabled: _isLoading,
                          onPressed: _isLoading ? null : _handleLogin,
                        ),
                        const SizedBox(height: DabblerSpacing.space4),
                        const AuthLegalNotice(),
                        const SizedBox(height: DabblerSpacing.space5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DabblerChip(
                              label: countryName,
                              leadingIcon: const DabblerIcon('global'),
                              onTap: _isLoading ? () {} : _openCountryPicker,
                            ),
                            const SizedBox(width: DabblerSpacing.space3),
                            DabblerChip(
                              label: langLabel,
                              leadingIcon: const DabblerIcon('language-square'),
                              onTap: _isLoading ? () {} : _openLanguagePicker,
                            ),
                          ],
                        ),
                        const SizedBox(height: DabblerSpacing.space6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Trust benefits card ──────────────────────────────────────────────────────

class _TrustBenefitsCard extends StatelessWidget {
  const _TrustBenefitsCard({required this.heading, required this.benefits});

  final String heading;
  final List<(String, String)> benefits;

  @override
  Widget build(BuildContext context) {
    return DabblerCard(
      variant: DabblerCardVariant.white,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.space2,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: DabblerBadge(label: heading),
            ),
          ),
          for (var i = 0; i < benefits.length; i++) ...[
            if (i > 0) const DabblerDivider(inset: DabblerSpacing.space5),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space5,
                vertical: DabblerSpacing.space4,
              ),
              child: Row(
                children: [
                  DabblerIconTile.named(benefits[i].$1),
                  const SizedBox(width: DabblerSpacing.space4),
                  Expanded(
                    child: DabblerText(
                      benefits[i].$2,
                      style: DabblerType.subheadline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space4,
        end: DabblerSpacing.space4,
        bottom: DabblerSpacing.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space4,
              DabblerSpacing.space2,
              DabblerSpacing.space4,
              DabblerSpacing.space2,
            ),
            child: DabblerText(
              AppLocalizations.of(context).auth_welcome_country_picker_title,
              style: DabblerType.title3,
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(DabblerSpacing.space8),
              child: Center(child: DabblerSpinner()),
            )
          else
            for (final c in countries)
              () {
                final name = c['name_en'] as String;
                final arName = c['name_ar'] as String?;
                final displayName =
                    (languageCode == 'ar' &&
                        arName != null &&
                        arName.isNotEmpty)
                    ? arName
                    : name;
                return AuthPickerRow(
                  title: displayName,
                  selected: name == selectedCountryName,
                  onTap: () => Navigator.of(context).pop(name),
                );
              }(),
        ],
      ),
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
    final current = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space4,
        end: DabblerSpacing.space4,
        bottom: DabblerSpacing.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space4,
              DabblerSpacing.space2,
              DabblerSpacing.space4,
              DabblerSpacing.space2,
            ),
            child: DabblerText(
              AppLocalizations.of(context).auth_welcome_language_picker_title,
              style: DabblerType.title3,
            ),
          ),
          ..._languages.map((lang) {
            final isSelected = current.languageCode == lang['code'];
            return AuthPickerRow(
              title: lang['name']!,
              selected: isSelected,
              onTap: () {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(lang['code']!));
                Navigator.of(context).pop();
              },
            );
          }),
        ],
      ),
    );
  }
}


/// A sign-in button with the vendor's official mark at its inline start. The
/// mark is decoration (the button's label carries the name), so it ignores
/// pointers and is hidden from semantics.
class _WithProviderMark extends StatelessWidget {
  const _WithProviderMark({required this.mark, required this.child});

  final Widget mark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        child,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: DabblerSpacing.space4),
          child: IgnorePointer(child: mark),
        ),
      ],
    );
  }
}
