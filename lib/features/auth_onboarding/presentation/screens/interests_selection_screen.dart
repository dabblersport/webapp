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

  /// Tiles per row of the sport grid.
  static const int _columns = 4;

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

  /// The persona the copy is written for: `player`, `organiser`, `host` or
  /// `socialiser`.
  String _personaKey() {
    if (widget.mode == InterestsSelectionMode.addPersona) {
      final targetPersona = ref.read(addPersonaDataProvider)?.targetPersona;
      return switch (targetPersona) {
        PersonaType.organiser => 'organiser',
        PersonaType.host => 'host',
        PersonaType.socialiser => 'socialiser',
        _ => 'player',
      };
    }
    final intention = ref.read(onboardingDataProvider)?.intention;
    return switch (intention) {
      'organiser' => 'organiser',
      'host' => 'host',
      'socialiser' => 'socialiser',
      _ => 'player',
    };
  }

  (String, String) _copy(AppLocalizations l10n) => switch (_personaKey()) {
    'organiser' => (
      l10n.onb_sports_title_organiser,
      l10n.onb_sports_subtitle_organiser,
    ),
    'host' => (l10n.onb_sports_title_host, l10n.onb_sports_subtitle_host),
    'socialiser' => (
      l10n.onb_sports_title_socialiser,
      l10n.onb_sports_subtitle_socialiser,
    ),
    _ => (l10n.onb_sports_title_player, l10n.onb_sports_subtitle_player),
  };

  void _handleBack() {
    if (widget.mode == InterestsSelectionMode.addPersona) {
      ref.read(addPersonaDataProvider.notifier).clear();
    }
    context.pop();
  }

  String _countLabel(AppLocalizations l10n) {
    final n = _selectedSportIds.length;
    if (n == 0) return l10n.onb_sports_count_zero;
    if (n == 1) return l10n.onb_sports_count_one;
    return l10n.onb_sports_count_many(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, subtitle) = _copy(l10n);
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);

    return DabblerFlowPage(
      onBack: _handleBack,
      backLabel: l10n.onb_back,
      stepCount: 5,
      stepIndex: 2,
      stepLabel: l10n.onb_step_label(3, 5),
      title: title,
      subtitle: subtitle,
      content: [
        DabblerSearchField(
          initialValue: _query,
          placeholder: l10n.onb_sports_search,
          onChanged: (v) => setState(() => _query = v),
          onCleared: () => setState(() => _query = ''),
        ),
        ...sportsAsync.when(
          loading: () => [const Center(child: DabblerSpinner())],
          error: (err, _) => [
            DabblerText(
              l10n.interests_failed_load,
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
            DabblerButton(
              label: l10n.interests_retry,
              tone: DabblerButtonTone.text,
              onPressed: () => ref.invalidate(sportsForSelectedCountryProvider),
            ),
          ],
          data: (sports) {
            _loadedSports = sports;
            final needle = _query.trim().toLowerCase();
            final filtered = needle.isEmpty
                ? sports
                : sports
                      .where((s) => s.nameEn.toLowerCase().contains(needle))
                      .toList();
            return [
              if (filtered.isEmpty)
                DabblerText(
                  l10n.onb_sports_none,
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.tertiary,
                ),
              DabblerTileGrid(
                columns: _columns,
                children: [for (final sport in filtered) _tile(sport)],
              ),
              DabblerText(
                _countLabel(l10n),
                style: DabblerType.footnote,
                tone: DabblerTextTone.tertiary,
              ),
            ];
          },
        ),
      ],
      primaryLabel: l10n.onb_continue,
      primaryLoading: _isLoading,
      onPrimary: (_isLoading || _selectedSportIds.isEmpty)
          ? null
          : _handleContinue,
    );
  }

  Widget _tile(Sport sport) {
    final selected = _selectedSportIds.contains(sport.id);
    final tone = onboardingSportTone(sport);
    return DabblerSelectableCard(
      layout: DabblerSelectableCardLayout.tile,
      leading: OnboardingSportGlyph(
        sport: sport,
        selected: selected,
        size: DabblerSizing.iconLg,
        color: tone.deep,
      ),
      title: sport.localizedName(context),
      selected: selected,
      tone: tone,
      onChanged: (_) => _toggleSport(sport.id),
    );
  }
}
