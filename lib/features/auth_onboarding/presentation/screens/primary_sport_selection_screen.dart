import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
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

  bool get _isOnboarding => widget.mode == PrimarySportSelectionMode.onboarding;

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

  /// The title and subtitle the design writes for the chosen persona; the
  /// add-persona flow keeps its own copy.
  (String, String) _copy(AppLocalizations l10n) {
    if (!_isOnboarding) {
      return (l10n.primary_sport_title, l10n.primary_sport_subtitle);
    }
    return switch (ref.read(onboardingDataProvider)?.intention) {
      'organiser' => (
        l10n.onb_primary_title_organiser,
        l10n.onb_primary_subtitle_organiser,
      ),
      'host' => (l10n.onb_primary_title_host, l10n.onb_primary_subtitle_host),
      'socialiser' => (
        l10n.onb_primary_title_socialiser,
        l10n.onb_primary_subtitle_socialiser,
      ),
      _ => (l10n.onb_primary_title_player, l10n.onb_primary_subtitle_player),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);
    final l10n = AppLocalizations.of(context);
    final (title, subtitle) = _copy(l10n);

    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: _isOnboarding ? 5 : null,
      stepIndex: _isOnboarding ? 3 : null,
      stepLabel: _isOnboarding ? l10n.onb_step_label(4, 5) : null,
      title: title,
      subtitle: subtitle,
      titleStyle: DabblerType.displayStep,
      subtitleStyle: DabblerType.copy,
      bodyGap: DabblerSpacing.space3,
      content: sportsAsync.when<List<Widget>>(
        loading: () => [const Center(child: DabblerSpinner())],
        error: (err, _) => [
          DabblerText(
            l10n.primary_sport_failed_load,
            style: DabblerType.copy,
            tone: DabblerTextTone.secondary,
          ),
          DabblerButton(
            label: l10n.interests_retry,
            tone: DabblerButtonTone.text,
            onPressed: () => ref.invalidate(sportsForSelectedCountryProvider),
          ),
        ],
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
            return [
              DabblerText(
                l10n.primary_sport_no_sports,
                style: DabblerType.copy,
                tone: DabblerTextTone.secondary,
              ),
            ];
          }

          return [
            for (final sport in sports) _row(sport),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DabblerTextLink(
                label: l10n.onb_primary_more,
                style: authLinkStyle(context, DabblerType.small),
                underline: false,
                onPressed: () => context.pop(),
              ),
            ),
          ];
        },
      ),
      primaryLabel: l10n.onb_continue,
      primaryLoading: _isLoading,
      onPrimary: (_isLoading || _selectedSportId == null)
          ? null
          : _handleContinue,
    );
  }

  Widget _row(Sport sport) {
    final selected = _selectedSportId == sport.id;
    final tone = onboardingSportTone(sport);
    return DabblerSelectableCard(
      layout: DabblerSelectableCardLayout.listRow,
      leading: OnboardingSportGlyph(
        sport: sport,
        selected: selected,
        size: DabblerSizing.iconMd,
        color: tone.deep,
      ),
      title: sport.localizedName(context),
      selected: selected,
      tone: tone,
      onChanged: (_) => _selectSport(sport.id),
    );
  }
}
