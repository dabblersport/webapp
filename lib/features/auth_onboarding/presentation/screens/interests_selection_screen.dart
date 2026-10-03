import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

enum InterestsSelectionMode { onboarding, addPersona }

class InterestsSelectionScreen extends ConsumerStatefulWidget {
  final InterestsSelectionMode mode;

  const InterestsSelectionScreen({
    super.key,
    this.mode = InterestsSelectionMode.onboarding,
  });

  @override
  ConsumerState<InterestsSelectionScreen> createState() =>
      _InterestsSelectionScreenState();
}

class _InterestsSelectionScreenState
    extends ConsumerState<InterestsSelectionScreen> {
  final Set<String> _selectedSportIds = {};
  bool _isLoading = false;
  List<Sport> _loadedSports = [];
  String _query = '';

  void _toggleSport(String sportId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSportIds.contains(sportId)) {
        _selectedSportIds.remove(sportId);
      } else {
        _selectedSportIds.add(sportId);
      }
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedSportIds.isEmpty) {
      showOnboardingWarning(
        context,
        AppLocalizations.of(context).interests_select_one,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sportIds = _selectedSportIds.toList();

      if (widget.mode == InterestsSelectionMode.addPersona) {
        ref.read(addPersonaDataProvider.notifier).setInterests(sportIds);
        if (mounted) context.push(RoutePaths.addPersonaPrimarySport);
      } else {
        final firstSport = _loadedSports.isNotEmpty
            ? _loadedSports.firstWhere(
                (s) => s.id == sportIds.first,
                orElse: () => _loadedSports.first,
              )
            : null;
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: sportIds.first,
              interests: sportIds,
              preferredSportName: firstSport?.nameEn,
            );
        if (mounted) context.push(RoutePaths.onboardingPrimarySport);
      }
    } catch (e) {
      if (mounted) {
        showOnboardingError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  (String, String) _getPersonaSpecificCopy() {
    if (widget.mode == InterestsSelectionMode.addPersona) {
      final addPersonaData = ref.read(addPersonaDataProvider);
      final targetPersona = addPersonaData?.targetPersona;

      return switch (targetPersona) {
        PersonaType.player => (
          'What do you regularly practice?',
          'You can change and add more sports later',
        ),
        PersonaType.organiser => (
          'What do you intend to organise?',
          'You can change and add more sports later',
        ),
        PersonaType.host => (
          'Which sports do you host?',
          'You can change and add more sports later',
        ),
        PersonaType.socialiser => (
          'Which sports are you interested in?',
          'You can change and add more sports later',
        ),
        _ => (
          'What do you regularly practice?',
          'You can change and add more sports later',
        ),
      };
    }

    final onboardingData = ref.read(onboardingDataProvider);
    final intention = onboardingData?.intention;

    return switch (intention) {
      'player' => (
        'What do you regularly practice?',
        'You can change and add more sports later',
      ),
      'organiser' => (
        'What do you intend to organise?',
        'You can change and add more sports later',
      ),
      'host' => (
        'Which sports do you host?',
        'You can change and add more sports later',
      ),
      'socialiser' => (
        'Which sports are you interested in?',
        'You can change and add more sports later',
      ),
      _ => (
        'What do you regularly practice?',
        'You can change and add more sports later',
      ),
    };
  }

  void _handleBack() {
    if (widget.mode == InterestsSelectionMode.addPersona) {
      ref.read(addPersonaDataProvider.notifier).clear();
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _getPersonaSpecificCopy();
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);
    final colors = DabblerColors.of(context);

    return OnboardingStepFrame(
      onBack: _handleBack,
      step: 3,
      stepLabel: 'Step 3 of 5',
      title: title,
      subtitle: subtitle,
      ctaLabel: AppLocalizations.of(context).interests_continue,
      ctaLoading: _isLoading,
      onCta: (_isLoading || _selectedSportIds.isEmpty) ? null : _handleContinue,
      body: sportsAsync.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load sports',
                style: onboardingType(
                  context,
                  DabblerType.subheadline,
                  colors.textSecondary,
                ),
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
        data: (sports) {
          _loadedSports = sports;
          final filtered = _query.isEmpty
              ? sports
              : sports
                    .where(
                      (s) =>
                          s.nameEn.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space8,
                  0,
                  DabblerSpacing.space8,
                  DabblerSpacing.space6,
                ),
                sliver: SliverToBoxAdapter(
                  child: DabblerSearchField(
                    initialValue: _query,
                    placeholder: 'Search sports…',
                    onChanged: (v) => setState(() => _query = v),
                    onCleared: () => setState(() => _query = ''),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space8,
                  0,
                  DabblerSpacing.space8,
                  DabblerSpacing.space8,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: DabblerSpacing.space3,
                    mainAxisSpacing: DabblerSpacing.space3,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final sport = filtered[index];
                    return _SportTile(
                      sport: sport,
                      isSelected: _selectedSportIds.contains(sport.id),
                      onTap: () => _toggleSport(sport.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  const _SportTile({
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
      radius: DabblerRadius.md,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space1,
        vertical: DabblerSpacing.space4,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OnboardingSportGlyph(
                  sport: sport,
                  selected: isSelected,
                  size: DabblerSizing.iconLg,
                  color: isSelected ? colors.brandPrimary : colors.textPrimary,
                ),
                const SizedBox(height: DabblerSpacing.space2),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: onboardingType(
                    context,
                    DabblerType.caption2,
                    colors.textPrimary,
                    weight: DabblerType.medium,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            PositionedDirectional(
              top: -DabblerSpacing.space2,
              end: 0,
              child: DabblerIcon(
                'tick-circle',
                weight: DabblerIconWeight.bold,
                size: 14,
                color: colors.brandPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
