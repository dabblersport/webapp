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
  late List<_Step> _steps;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _steps = [
      const _Step(),
      const _Step(),
      const _Step(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCreation());
  }

  void _setStep(int i, _StepStatus status, {String? error}) {
    if (!mounted) return;
    setState(() {
      _steps = [
        for (int j = 0; j < _steps.length; j++)
          j == i ? _Step(status: status, errorMsg: error) : _steps[j],
      ];
    });
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
    return 'Something went wrong. Please try again.';
  }

  Future<void> _runCreation() async {
    if (_didStart) return;
    _didStart = true;

    final data = ref.read(onboardingDataProvider);
    if (data == null || !mounted) return;

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

    // Step 0: create profile
    _setStep(0, _StepStatus.running);
    late String profileId;
    try {
      profileId = await authService.createProfileStep(
        displayName: data.displayName ?? '',
        username: data.username ?? '',
        age: data.age ?? 18,
        gender: data.gender ?? 'other',
        intention: data.intention ?? 'player',
        preferredSport: data.preferredSport ?? '',
        interests: data.interests,
        country: country,
        city: city,
        password: null,
      );
      _setStep(0, _StepStatus.done);
    } catch (e) {
      _setStep(0, _StepStatus.error, error: _friendlyError(e));
      return;
    }

    // Step 1: persona profile
    _setStep(1, _StepStatus.running);
    try {
      await authService.createPersonaProfileStep(
        profileId,
        data.intention ?? 'player',
      );
      _setStep(1, _StepStatus.done);
    } catch (e) {
      _setStep(1, _StepStatus.error, error: _friendlyError(e));
      return;
    }

    // Step 2: sport profile (players only)
    _setStep(2, _StepStatus.running);
    try {
      if (data.intention == 'player' && (data.preferredSport?.isNotEmpty ?? false)) {
        await authService.createSportProfileStep(profileId, data.preferredSport!);
      }
      _setStep(2, _StepStatus.done);
    } catch (e) {
      _setStep(2, _StepStatus.error, error: _friendlyError(e));
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
    final labels = [
      l10n.onboarding_welcome_step_profile,
      l10n.onboarding_welcome_step_persona,
      l10n.onboarding_welcome_step_sport,
    ];

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
              for (int i = 0; i < _steps.length; i++)
                _StepRow(step: _steps[i], label: labels[i], colorScheme: colorScheme, theme: theme),
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
