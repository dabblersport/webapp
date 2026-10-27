import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

class IntentSelectionScreen extends ConsumerStatefulWidget {
  const IntentSelectionScreen({super.key});

  @override
  ConsumerState<IntentSelectionScreen> createState() =>
      _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends ConsumerState<IntentSelectionScreen> {
  OnboardingIntention? _selected;
  bool _isLoadingData = true;

  /// KAN-648: the four intentions, in the design's order, on the existing
  /// four-card layout. Each keeps the icon its card already had.
  static const _options = [
    (intention: OnboardingIntention.connectPlay, icon: 'people'),
    (intention: OnboardingIntention.playOrganise, icon: 'game'),
    (intention: OnboardingIntention.organise, icon: 'calendar'),
    (intention: OnboardingIntention.hostGames, icon: 'location'),
  ];

  @override
  void initState() {
    super.initState();
    _restoreChoice();
  }

  /// Brings back a choice made before an interruption (app killed, sign-in
  /// round trip) so the card is already selected.
  Future<void> _restoreChoice() async {
    final notifier = ref.read(onboardingDataProvider.notifier);
    try {
      await notifier.restoreOnboardingIntention();
      _selected = notifier.onboardingIntention;
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  /// The old persona string the sports, primary and username steps still key
  /// their copy on. The first three intentions are the same Contributor and
  /// take the same path; only host_games takes the Host sequence.
  static String legacyPersonaFor(OnboardingIntention intention) =>
      switch (intention) {
        OnboardingIntention.hostGames => 'host',
        _ => 'player',
      };

  void _handleSubmit() {
    final chosen = _selected;
    if (chosen == null) {
      showOnboardingWarning(
        context,
        AppLocalizations.of(context).intent_select_role,
      );
      return;
    }
    final notifier = ref.read(onboardingDataProvider.notifier);
    notifier.setOnboardingIntention(chosen);
    notifier.setIntention(legacyPersonaFor(chosen));
    context.push(RoutePaths.interestsSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const OnboardingLoading();

    final l10n = AppLocalizations.of(context);
    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: 5,
      stepIndex: 1,
      stepLabel: l10n.onb_step_label(2, 5),
      title: l10n.onb_intention_title,
      subtitle: l10n.onb_intention_subtitle,
      titleStyle: DabblerType.displayStep,
      subtitleStyle: DabblerType.copy,
      bodyGap: DabblerSpacing.space4,
      content: [
        for (final opt in _options)
          DabblerSelectableCard(
            borderOutside: true,
            icon: opt.icon,
            title: opt.intention.label(l10n),
            selected: _selected == opt.intention,
            onChanged: (_) => setState(() => _selected = opt.intention),
          ),
        // `Auth and Onboarding.dc.html:393`.
        DabblerText(
          l10n.onb_persona_footnote,
          style: DabblerType.footnote,
          tone: DabblerTextTone.tertiary,
        ),
      ],
      primaryLabel: l10n.onb_continue,
      onPrimary: _selected == null ? null : _handleSubmit,
    );
  }
}
