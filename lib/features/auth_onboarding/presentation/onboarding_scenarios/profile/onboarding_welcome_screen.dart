import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';

enum _StepStatus { pending, running, done, error }

class ProfileOnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingWelcomeScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingWelcomeScreen> createState() =>
      _ProfileOnboardingWelcomeScreenState();
}

class _ProfileOnboardingWelcomeScreenState
    extends ConsumerState<ProfileOnboardingWelcomeScreen> {
  _Step _step = const _Step();
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCreation());
  }

  void _setStep(_StepStatus status, {String? error}) {
    if (!mounted) return;
    setState(() => _step = _Step(status: status, errorMsg: error));
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('country_fkey') || raw.contains('profiles_country_fkey')) {
      return 'The selected country isn\'t supported yet. Please go back and choose a different country.';
    }
    if (raw.contains('username') && (raw.contains('unique') || raw.contains('23505'))) {
      return 'That username is already taken. Please go back and choose a different one.';
    }
    if (raw.contains('23503')) {
      return 'Some information couldn\'t be saved. Please go back and check your details.';
    }
    if (raw.contains('organiser persona requires p_preferred_sport')) {
      // Belt-and-suspenders: interests_selection_screen already requires a
      // sport before an organiser can reach this screen (T-037/KAN-48 —
      // the RPC rejects a null-sport organiser, so the client must never
      // let one arrive here). This message only fires if that guard is
      // ever bypassed.
      return 'Please go back and choose a sport before continuing as an organiser.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _runCreation() async {
    if (_didStart) return;
    _didStart = true;

    final data = ref.read(onboardingDataProvider);
    if (!mounted) return;
    if (data == null) {
      // No in-memory onboarding data to submit for this session — this
      // screen was reached without going through the onboarding flow (e.g.
      // browser back/forward on web after onboarding already completed, or
      // a stale/bookmarked route). The router deliberately never redirects
      // away from this progress screen (KAN-96), so without this branch an
      // already-onboarded user sees "Setting up your account" forever with
      // no error, no back, and no timeout. Route them out instead.
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      context.go(isAuthenticated ? RoutePaths.home : RoutePaths.landing);
      return;
    }

    final authService = AuthService();
    final locationState = ref.read(selectedLocationProvider);
    final country = locationState.maybeWhen(
      data: (loc) => loc.country,
      orElse: () => null,
    );
    final city = locationState.maybeWhen(
      data: (loc) => loc.city,
      orElse: () => null,
    );

    // One call: rpc_onboard_profile creates the profile, the persona
    // extension row, and (for players) the sport_profiles row, all in one
    // transaction (T-037/KAN-48). There is no longer a separate persona or
    // sport step to run — one step either fully succeeds or fully fails.
    _setStep(_StepStatus.running);
    try {
      await authService.createProfileStep(
        displayName: data.displayName ?? '',
        username: data.username ?? '',
        age: data.age ?? 18,
        gender: data.gender,
        intention: data.intention ?? 'player',
        preferredSport: data.preferredSport ?? '',
        interests: data.interests,
        country: country,
        city: city,
        password: null,
      );
      _setStep(_StepStatus.done);
    } catch (e) {
      _setStep(_StepStatus.error, error: _friendlyError(e));
      return;
    }

    // Navigate
    if (!mounted) return;
    final displayName = data.displayName ?? '';
    final intention = data.intention ?? 'player';
    ref.read(onboardingDataProvider.notifier).clear();
    await ref.read(simpleAuthProvider.notifier).refreshAuthState();
    // Ensure the post-login welcome screen is shown (not bypassed by the
    // welcome route's needsPostLoginWelcome guard).
    routerRefreshNotifier.requirePostLoginWelcome();
    if (mounted) {
      context.go(
        RoutePaths.welcome,
        extra: {
          'displayName': displayName,
          'personaType': intention,
          'isFirstTime': true,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboarding_welcome_title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboarding_welcome_subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              _StepRow(
                step: _step,
                label: l10n.onboarding_welcome_step_profile,
                colorScheme: colorScheme,
                theme: theme,
              ),
            ],
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step {
  final _StepStatus status;
  final String? errorMsg;

  const _Step({this.status = _StepStatus.pending, this.errorMsg});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _StepRow({required this.step, required this.label, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (step.status) {
      case _StepStatus.running:
        icon = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        );
        break;
      case _StepStatus.done:
        icon = Icon(Icons.check_circle, color: Colors.green.shade600, size: 24);
        break;
      case _StepStatus.error:
        icon = Icon(Icons.error, color: colorScheme.error, size: 24);
        break;
      case _StepStatus.pending:
        icon = Icon(Icons.radio_button_unchecked, color: colorScheme.outlineVariant, size: 24);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: step.status == _StepStatus.done
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: step.status == _StepStatus.pending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
                if (step.errorMsg != null)
                  Text(
                    step.errorMsg!,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
