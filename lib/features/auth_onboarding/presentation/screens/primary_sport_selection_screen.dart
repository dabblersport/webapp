import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

enum PrimarySportSelectionMode { onboarding, addPersona }

class PrimarySportSelectionScreen extends ConsumerStatefulWidget {
  final PrimarySportSelectionMode mode;

  const PrimarySportSelectionScreen({
    super.key,
    this.mode = PrimarySportSelectionMode.onboarding,
  });

  @override
  ConsumerState<PrimarySportSelectionScreen> createState() =>
      _PrimarySportSelectionScreenState();
}

class _PrimarySportSelectionScreenState
    extends ConsumerState<PrimarySportSelectionScreen> {
  String? _selectedSportId;
  bool _isLoading = false;

  List<String> _getInterestIds() {
    if (widget.mode == PrimarySportSelectionMode.addPersona) {
      return ref.read(addPersonaDataProvider)?.interests ?? [];
    }
    return ref.read(onboardingDataProvider)?.interests ?? [];
  }

  List<Sport> _resolveInterestSports(List<Sport> allSports) {
    final interestIds = _getInterestIds();
    final sportMap = {for (final s in allSports) s.id: s};
    return interestIds
        .where((id) => sportMap.containsKey(id))
        .map((id) => sportMap[id]!)
        .toList();
  }

  void _selectSport(String sportId) {
    HapticFeedback.lightImpact();
    setState(() => _selectedSportId = sportId);
  }

  Future<void> _handleContinue() async {
    if (_selectedSportId == null) {
      showOnboardingWarning(
        context,
        AppLocalizations.of(context).primary_sport_select_error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.mode == PrimarySportSelectionMode.addPersona) {
        ref
            .read(addPersonaDataProvider.notifier)
            .setPrimarySport(_selectedSportId!);
        if (mounted) context.push(RoutePaths.addPersonaUsername);
      } else {
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: _selectedSportId!,
              interests: ref.read(onboardingDataProvider)?.interests,
            );
        if (mounted) context.push(RoutePaths.setUsername);
      }
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
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);
    final l10n = AppLocalizations.of(context);

    return OnboardingStepFrame(
      onBack: () => context.pop(),
      step: widget.mode == PrimarySportSelectionMode.addPersona ? null : 4,
      stepLabel: widget.mode == PrimarySportSelectionMode.addPersona
          ? 'Primary Sport'
          : 'Step 4 of 5',
      title: l10n.primary_sport_title,
      subtitle: l10n.primary_sport_subtitle,
      ctaLabel: l10n.primary_sport_continue,
      ctaLoading: _isLoading,
      onCta: (_isLoading || _selectedSportId == null) ? null : _handleContinue,
      body: sportsAsync.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerText(
                'Failed to load sports',
                style: DabblerType.subheadline,
                tone: DabblerTextTone.secondary,
              ),
              const SizedBox(height: DabblerSpacing.space5),
              DabblerButton(
                label: 'Retry',
                tone: DabblerButtonTone.text,
                onPressed: () =>
                    ref.invalidate(sportsForSelectedCountryProvider),
              ),
            ],
          ),
        ),
        data: (allSports) {
          final sports = _resolveInterestSports(allSports);

          if (sports.length == 1 && _selectedSportId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedSportId = sports.first.id);
              }
            });
          }

          if (sports.isEmpty) {
            return Center(
              child: DabblerText(
                'No sports selected. Please go back.',
                style: DabblerType.subheadline,
                tone: DabblerTextTone.secondary,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space8,
            ),
            itemCount: sports.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: DabblerSpacing.space3),
            itemBuilder: (context, index) {
              final sport = sports[index];
              return _SportRow(
                sport: sport,
                isSelected: _selectedSportId == sport.id,
                onTap: () => _selectSport(sport.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  const _SportRow({
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  final Sport sport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final name = sport.localizedName(context);
    return OnboardingOptionCard(
      selected: isSelected,
      onTap: onTap,
      semanticLabel: name,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space5,
        vertical: DabblerSpacing.space4,
      ),
      child: Row(
        children: [
          OnboardingSportGlyph(
            sport: sport,
            selected: isSelected,
            size: DabblerSizing.iconMd,
            color: isSelected ? colors.brandPrimary : colors.textPrimary,
          ),
          const SizedBox(width: DabblerSpacing.space4),
          Expanded(child: DabblerText(name, style: DabblerType.callout)),
          OnboardingRadioGlyph(selected: isSelected),
        ],
      ),
    );
  }
}
