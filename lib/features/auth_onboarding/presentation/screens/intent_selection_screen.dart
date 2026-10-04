import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
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
  String? _selectedPersona;
  bool _isLoading = false;
  bool _isLoadingData = true;

  /// The personas offered, in the design's order.
  static const _personaOptions = [
    _PersonaOption(value: 'socialise', icon: 'people'),
    _PersonaOption(value: 'compete', icon: 'game'),
    _PersonaOption(value: 'organise', icon: 'calendar'),
    _PersonaOption(value: 'host', icon: 'location'),
  ];

  // Temporarily hidden: 'organise' and 'host'. Keep entries in
  // _personaOptions so re-enabling is a one-line revert.
  static const _hiddenPersonas = {'organise', 'host'};

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final onboardingData = ref.read(onboardingDataProvider);
      if (onboardingData?.intention != null &&
          onboardingData!.intention!.isNotEmpty) {
        if (onboardingData.intention == 'organise') {
          setState(() => _selectedPersona = 'organiser');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedPersona == null) {
      showOnboardingWarning(
        context,
        AppLocalizations.of(context).intent_select_role,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      String personaType;
      if (_selectedPersona == 'compete') {
        personaType = 'player';
      } else if (_selectedPersona == 'organise') {
        personaType = 'organiser';
      } else if (_selectedPersona == 'host') {
        personaType = 'host';
      } else {
        personaType = 'socialiser';
      }
      ref.read(onboardingDataProvider.notifier).setIntention(personaType);
      if (mounted) context.push(RoutePaths.interestsSelection);
    } catch (e) {
      if (mounted) {
        showOnboardingError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The design's caption, hook and body for a persona.
  (String, String, String) _copy(AppLocalizations l10n, String value) =>
      switch (value) {
        'compete' => (
          l10n.onb_persona_player_name,
          l10n.onb_persona_player_hook,
          l10n.onb_persona_player_body,
        ),
        'organise' => (
          l10n.onb_persona_organiser_name,
          l10n.onb_persona_organiser_hook,
          l10n.onb_persona_organiser_body,
        ),
        'host' => (
          l10n.onb_persona_host_name,
          l10n.onb_persona_host_hook,
          l10n.onb_persona_host_body,
        ),
        _ => (
          l10n.onb_persona_socialiser_name,
          l10n.onb_persona_socialiser_hook,
          l10n.onb_persona_socialiser_body,
        ),
      };

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
      title: l10n.onb_persona_title,
      subtitle: l10n.onb_persona_subtitle,
      titleStyle: DabblerType.displayStep,
      subtitleStyle: DabblerType.copy,
      bodyGap: DabblerSpacing.space4,
      content: [
        for (final opt in _personaOptions.where(
          (o) => !_hiddenPersonas.contains(o.value),
        ))
          _card(l10n, opt),
        // `Auth and Onboarding.dc.html:393`.
        DabblerText(
          l10n.onb_persona_footnote,
          style: DabblerType.footnote,
          tone: DabblerTextTone.tertiary,
        ),
      ],
      primaryLabel: l10n.onb_continue,
      primaryLoading: _isLoading,
      onPrimary: (_isLoading || _selectedPersona == null)
          ? null
          : _handleSubmit,
    );
  }

  Widget _card(AppLocalizations l10n, _PersonaOption opt) {
    final (name, hook, body) = _copy(l10n, opt.value);
    return DabblerSelectableCard(
      borderOutside: true,
      icon: opt.icon,
      caption: name,
      title: hook,
      subtitle: body,
      selected: _selectedPersona == opt.value,
      onChanged: (_) => setState(() => _selectedPersona = opt.value),
    );
  }
}

class _PersonaOption {
  final String value;

  /// The DS icon name (DS icon vocabulary).
  final String icon;

  const _PersonaOption({required this.value, required this.icon});
}
