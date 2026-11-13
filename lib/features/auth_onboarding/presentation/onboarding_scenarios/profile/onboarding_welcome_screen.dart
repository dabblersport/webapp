import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/data/unified_onboarding_client.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/services/onboarding_completion_path.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

enum _StepStatus { pending, running, done, error }

class ProfileOnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingWelcomeScreen({
    super.key,
    @visibleForTesting this.holdRunning = false,
  });

  /// Stops at the running stage, before the request (render tests: the
  /// frame shows the stage in progress).
  final bool holdRunning;

  @override
  ConsumerState<ProfileOnboardingWelcomeScreen> createState() =>
      _ProfileOnboardingWelcomeScreenState();
}

class _ProfileOnboardingWelcomeScreenState
    extends ConsumerState<ProfileOnboardingWelcomeScreen> {
  _Step _step = const _Step();

  /// KAN-648: true while a request is in flight; a second tap does nothing.
  bool _pending = false;

  /// The id the unified RPC returned. A retry after a failed avatar step
  /// reuses it instead of calling the RPC again.
  String? _profileId;

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

  /// A second submit while one is pending must do nothing (tests drive it).
  @visibleForTesting
  Future<void> submit() => _runCreation();

  Future<void> _runCreation() async {
    if (_pending) return;

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

    final gateway = ref.read(onboardingCompletionGatewayProvider);
    final locationState = ref.read(selectedLocationProvider);
    final country = locationState.maybeWhen(
      data: (loc) => loc.country,
      orElse: () => null,
    );
    final city = locationState.maybeWhen(
      data: (loc) => loc.city,
      orElse: () => null,
    );

    final path = onboardingCompletionPath(
      data,
      resumingLegacyProfile:
          ref.read(onboardingControllerProvider).hasIncompleteOnboarding ??
          false,
    );

    _pending = true;
    _setStep(_StepStatus.running);
    if (widget.holdRunning) {
      _pending = false;
      return;
    }
    final String persona;
    try {
      persona = switch (path) {
        OnboardingCompletionPath.unified => await _createUnified(
          gateway,
          data,
          country: country,
          city: city,
        ),
        OnboardingCompletionPath.legacyContinuation => await _createLegacy(
          gateway,
          data,
          country: country,
          city: city,
        ),
      };
    } on UnifiedOnboardingFailure catch (f) {
      _pending = false;
      _setStep(
        _StepStatus.error,
        error: f.error.message(AppLocalizations.of(context)),
      );
      return;
    } catch (e) {
      _pending = false;
      _setStep(_StepStatus.error, error: _friendlyError(e));
      return;
    }
    _setStep(_StepStatus.done);

    // Navigate
    if (!mounted) return;
    final displayName = data.displayName ?? '';
    final onboardingIntention = data.onboardingIntention?.key;
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
          'personaType': persona,
          'isFirstTime': true,
          'primarySportKey': primarySportKey,
          // KAN-681: the provider is cleared above, so the welcome variant
          // travels with the route (read only by the welcome screen).
          'onboardingIntention': onboardingIntention,
        },
      );
    }
  }

  /// KAN-648: new account. Completion waits for the UUID the unified RPC
  /// returns; nothing here sets `onboard` or writes extension or tier rows.
  /// Returns the legacy persona string the welcome screen keys its copy on.
  Future<String> _createUnified(
    OnboardingCompletionGateway gateway,
    RegistrationOnboardingData data, {
    String? country,
    String? city,
  }) async {
    final input = unifiedInputFor(data, country: country, city: city);
    if (input == null) {
      throw const UnifiedOnboardingFailure(UnifiedOnboardingError.unknown);
    }
    var profileId = _profileId;
    if (profileId == null) {
      try {
        await gateway.syncAuthMetadata(
          displayName: input.displayName,
          username: input.username,
        );
      } catch (e) {
        throw UnifiedOnboardingFailure(
          UnifiedOnboardingError.unknown,
          cause: e,
        );
      }
      final result = await gateway.onboardUnified(input);
      profileId = result.fold<String>((failure) => throw failure, (id) => id);
      _profileId = profileId;
    }
    try {
      await gateway.ensureAvatar(profileId);
    } catch (e) {
      throw UnifiedOnboardingFailure(UnifiedOnboardingError.unknown, cause: e);
    }
    return input.intention == OnboardingIntention.hostGames ? 'host' : 'player';
  }

  /// An explicitly existing legacy profile resuming its old flow. The
  /// persona is the one already on the profile; none is guessed.
  Future<String> _createLegacy(
    OnboardingCompletionGateway gateway,
    RegistrationOnboardingData data, {
    String? country,
    String? city,
  }) async {
    await gateway.createLegacy(data: data, country: country, city: city);
    return data.intention ?? 'player';
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
      titleStyle: DabblerType.displayStep,
      subtitleStyle: DabblerType.copy,
      primaryLabel: _step.status == _StepStatus.error
          ? l10n.interests_retry
          : null,
      onPrimary: _step.status == _StepStatus.error && !_pending
          ? _runCreation
          : null,
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
