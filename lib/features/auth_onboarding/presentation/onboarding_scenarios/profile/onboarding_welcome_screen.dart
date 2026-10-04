import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

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
    if (raw.contains('username') &&
        (raw.contains('unique') || raw.contains('23505'))) {
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
    final primarySportKey = await _primarySportKey(data.preferredSport);
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
          'primarySportKey': primarySportKey,
        },
      );
    }
  }

  /// The DS key of the primary sport, which the welcome draws behind it.
  Future<String?> _primarySportKey(String? sportId) async {
    if (sportId == null) return null;
    try {
      final sports = await ref.read(sportsForSelectedCountryProvider.future);
      for (final sport in sports) {
        if (sport.id == sportId) return onboardingDsSport(sport)?.key;
      }
    } catch (_) {
      // The artwork is decoration; the welcome works without it.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DabblerFlowPage(
      centered: true,
      bodyGap: DabblerSpacing.space9,
      title: l10n.onb_setup_title,
      subtitle: l10n.onb_setup_subtitle,
      content: [
        switch (_step.status) {
          _StepStatus.running => const DabblerProgressBar.indeterminate(),
          _StepStatus.done => const DabblerProgressBar(value: 1),
          _ => const DabblerProgressBar(value: 0),
        },
        DabblerProgressStages(
          stages: [
            DabblerProgressStage(
              label: l10n.onb_setup_stage_profile,
              status: switch (_step.status) {
                _StepStatus.pending => DabblerStageStatus.pending,
                _StepStatus.running => DabblerStageStatus.active,
                _StepStatus.done => DabblerStageStatus.done,
                _StepStatus.error => DabblerStageStatus.failed,
              },
            ),
          ],
        ),
        if (_step.errorMsg != null)
          DabblerBanner(
            tone: DabblerBannerTone.error,
            title: l10n.onb_setup_failed_title,
            message: _step.errorMsg,
          ),
      ],
    );
  }
}

class _Step {
  final _StepStatus status;
  final String? errorMsg;

  const _Step({this.status = _StepStatus.pending, this.errorMsg});
}
