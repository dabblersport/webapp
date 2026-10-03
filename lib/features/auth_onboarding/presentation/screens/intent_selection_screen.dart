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

  static const _personaOptions = [
    _PersonaOption(
      value: 'compete',
      title: 'Compete',
      description: 'Join games, track your level, play regularly',
      icon: 'game',
    ),
    _PersonaOption(
      value: 'organise',
      title: 'Organise',
      description: 'Create games, set rules, manage players',
      icon: 'calendar',
    ),
    _PersonaOption(
      value: 'host',
      title: 'Host',
      description: 'Manage venues, availability, and bookings',
      icon: 'location',
    ),
    _PersonaOption(
      value: 'socialise',
      title: 'Socialise',
      description: 'Follow sports, people, and communities',
      icon: 'people',
    ),
  ];

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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const OnboardingLoading();

    final colors = DabblerColors.of(context);
    return OnboardingStepFrame(
      onBack: () => context.pop(),
      step: 2,
      stepLabel: 'Step 2 of 5',
      title: 'What brings you here?',
      subtitle:
          'Help us tailor Dabbler. You can pick more than one later in settings.',
      ctaLabel: AppLocalizations.of(context).intent_continue,
      ctaLoading: _isLoading,
      onCta: (_isLoading || _selectedPersona == null) ? null : _handleSubmit,
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
        ),
        children: [
          ..._personaOptions
              // Temporarily hidden: 'organise' and 'host'.
              // Keep entries in _personaOptions so re-enabling
              // is a one-line revert.
              .where((o) => o.value != 'organise' && o.value != 'host')
              .map((opt) {
                final on = _selectedPersona == opt.value;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: DabblerSpacing.space4,
                  ),
                  child: _IntentCard(
                    option: opt,
                    selected: on,
                    onTap: () => setState(() => _selectedPersona = opt.value),
                  ),
                );
              }),
          Text(
            'You can add another way to use Dabbler later in settings.',
            style: onboardingType(
              context,
              DabblerType.footnote,
              colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaOption {
  final String value;
  final String title;
  final String description;

  /// The DS icon name (Iconsax vocabulary).
  final String icon;

  const _PersonaOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PersonaOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return OnboardingOptionCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: option.title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerIcon(
            option.icon,
            size: DabblerSizing.iconMd,
            weight: selected
                ? DabblerIconWeight.bold
                : DabblerIconWeight.linear,
            color: colors.brandPrimary,
          ),
          const SizedBox(width: DabblerSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: onboardingType(
                    context,
                    DabblerType.callout,
                    colors.textPrimary,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space1),
                Text(
                  option.description,
                  style: onboardingType(
                    context,
                    DabblerType.subheadline,
                    colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DabblerSpacing.space4),
          OnboardingRadioGlyph(selected: selected),
        ],
      ),
    );
  }
}
