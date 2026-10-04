import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';

enum CompetitionLevel { casual, recreational, competitive, professional }

enum GameDuration { short, medium, long, flexible }

enum _GameType { pickup, tournaments, practice, leagues, friendly, camps }

enum _Equipment { ball, gear, uniforms, goals, nets, markers }

/// Game preferences — a page of Settings-style [DabblerRowGroup]s: checkbox
/// rows for game types, radio rows for duration and competition level, toggle
/// rows for team size / equipment / referee, a range slider for team size and
/// chips for equipment types. State is local and "Save" only confirms with a
/// toast. No design frame exists for this screen; it takes the Settings inner
/// page pattern with design-system defaults.
class GamePreferencesScreen extends ConsumerStatefulWidget {
  const GamePreferencesScreen({super.key});

  @override
  ConsumerState<GamePreferencesScreen> createState() =>
      _GamePreferencesScreenState();
}

class _GamePreferencesScreenState extends ConsumerState<GamePreferencesScreen> {
  // Game type preferences
  final Set<_GameType> _preferredGameTypes = {
    _GameType.pickup,
    _GameType.tournaments,
    _GameType.practice,
  };

  // Duration preferences
  GameDuration _preferredDuration = GameDuration.medium;
  int _customMinDuration = 60; // minutes
  int _customMaxDuration = 120; // minutes

  // Team size preferences
  DabblerSliderRange _teamSizeRange = const DabblerSliderRange(5, 11);
  bool _flexibleTeamSize = true;

  // Competition level
  CompetitionLevel _preferredCompetitionLevel = CompetitionLevel.recreational;

  // Equipment preferences
  bool _hasOwnEquipment = true;
  bool _canProvideEquipment = false;
  bool _needsEquipmentProvided = false;
  final Set<_Equipment> _equipmentTypes = {_Equipment.ball, _Equipment.gear};

  // Referee preferences
  bool _preferReferee = false;
  bool _canReferee = false;
  bool _strictRules = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const gap = DabblerGap.v(DabblerSpacing.space6);
    return DabblerPage(
      topBar: settingsInnerTopBar(
        context,
        title: l10n.game_prefs_title,
        extraActions: [
          DabblerNavigationAction.text(
            label: l10n.game_prefs_save,
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space5,
          DabblerSpacing.space6,
          DabblerSpacing.space5,
          DabblerSpacing.space10,
        ),
        children: [
          _buildGameTypesSection(context),
          gap,
          _buildDurationSection(context),
          gap,
          _buildTeamSizeSection(context),
          gap,
          _buildCompetitionLevelSection(context),
          gap,
          _buildEquipmentSection(context),
          gap,
          _buildRefereeSection(context),
        ],
      ),
    );
  }

  Widget _icon(BuildContext context, String name) => DabblerIcon(
    name,
    size: DabblerSizing.iconMd,
    color: DabblerColors.of(context).textSecondary,
  );

  Widget _subheading(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: DabblerSpacing.space4,
    ),
    child: DabblerText(text, style: DabblerType.footnote),
  );

  Widget _row({
    required BuildContext context,
    required String icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) => DabblerInputRow(
    flat: true,
    showDivider: false,
    leading: _icon(context, icon),
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    trailing: trailing,
  );

  Widget _toggleRow(
    BuildContext context,
    String title,
    String subtitle,
    String icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) => _row(
    context: context,
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: DabblerToggle(
      checked: value,
      semanticLabel: title,
      onChanged: onChanged,
    ),
  );

  ({String title, String description, String icon}) _gameType(
    AppLocalizations l,
    _GameType t,
  ) => switch (t) {
    _GameType.pickup => (
      title: l.game_prefs_type_pickup,
      description: l.game_prefs_type_pickup_sub,
      icon: 'game',
    ),
    _GameType.tournaments => (
      title: l.game_prefs_type_tournaments,
      description: l.game_prefs_type_tournaments_sub,
      icon: 'cup',
    ),
    _GameType.practice => (
      title: l.game_prefs_type_practice,
      description: l.game_prefs_type_practice_sub,
      icon: 'weight',
    ),
    _GameType.leagues => (
      title: l.game_prefs_type_leagues,
      description: l.game_prefs_type_leagues_sub,
      icon: 'ranking',
    ),
    _GameType.friendly => (
      title: l.game_prefs_type_friendly,
      description: l.game_prefs_type_friendly_sub,
      icon: 'people',
    ),
    _GameType.camps => (
      title: l.game_prefs_type_camps,
      description: l.game_prefs_type_camps_sub,
      icon: 'teacher',
    ),
  };

  Widget _buildGameTypesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_types_header,
      note: l10n.game_prefs_types_note,
      children: [
        for (final type in _GameType.values)
          _row(
            context: context,
            icon: _gameType(l10n, type).icon,
            title: _gameType(l10n, type).title,
            subtitle: _gameType(l10n, type).description,
            onTap: () => _toggleGameType(type),
            trailing: DabblerCheckbox(
              checked: _preferredGameTypes.contains(type),
              semanticLabel: _gameType(l10n, type).title,
              onChanged: (_) => _toggleGameType(type),
            ),
          ),
      ],
    );
  }

  void _toggleGameType(_GameType type) {
    setState(() {
      if (!_preferredGameTypes.remove(type)) _preferredGameTypes.add(type);
    });
  }

  Widget _buildDurationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_duration_header,
      note: l10n.game_prefs_duration_note,
      children: [
        for (final duration in GameDuration.values)
          _row(
            context: context,
            icon: 'clock',
            title: _getDurationTitle(l10n, duration),
            subtitle: _getDurationDescription(l10n, duration),
            onTap: () => setState(() => _preferredDuration = duration),
            trailing: DabblerRadio(
              selected: _preferredDuration == duration,
              semanticLabel: _getDurationTitle(l10n, duration),
              onChanged: (_) => setState(() => _preferredDuration = duration),
            ),
          ),
        if (_preferredDuration == GameDuration.flexible)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _subheading(context, l10n.game_prefs_duration_custom),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDurationInput(
                      l10n.game_prefs_duration_min,
                      _customMinDuration,
                      (value) => setState(() => _customMinDuration = value),
                    ),
                  ),
                  const SizedBox(width: DabblerSpacing.space4),
                  Expanded(
                    child: _buildDurationInput(
                      l10n.game_prefs_duration_max,
                      _customMaxDuration,
                      (value) => setState(() => _customMaxDuration = value),
                    ),
                  ),
                ],
              ),
              const DabblerGap.v(DabblerSpacing.space4),
            ],
          ),
      ],
    );
  }

  Widget _buildDurationInput(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final l10n = AppLocalizations.of(context);
    return DabblerTextField(
      label: label,
      placeholder: l10n.game_prefs_minutes_hint('$value'),
      suffixText: l10n.game_prefs_minutes_suffix,
      keyboardType: TextInputType.number,
      onChanged: (text) {
        final newValue = int.tryParse(text);
        if (newValue != null && newValue > 0) {
          onChanged(newValue);
        }
      },
    );
  }

  Widget _buildTeamSizeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_team_header,
      note: l10n.game_prefs_team_note,
      children: [
        _toggleRow(
          context,
          l10n.game_prefs_team_flexible,
          l10n.game_prefs_team_flexible_sub,
          'people',
          _flexibleTeamSize,
          (value) => setState(() => _flexibleTeamSize = value),
        ),
        if (!_flexibleTeamSize)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _subheading(
                context,
                l10n.game_prefs_team_preferred(
                  DabblerType.toWesternDigits('${_teamSizeRange.low.round()}'),
                  DabblerType.toWesternDigits('${_teamSizeRange.high.round()}'),
                ),
              ),
              DabblerSlider.range(
                values: _teamSizeRange,
                min: 2,
                max: 22,
                step: 1,
                formatValue: (v) => v.round().toString(),
                minimumSemanticLabel: l10n.game_prefs_team_min_label,
                maximumSemanticLabel: l10n.game_prefs_team_max_label,
                onChanged: (values) => setState(() => _teamSizeRange = values),
              ),
              const DabblerGap.v(DabblerSpacing.space4),
            ],
          ),
      ],
    );
  }

  Widget _buildCompetitionLevelSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_level_header,
      note: l10n.game_prefs_level_note,
      children: [
        for (final level in CompetitionLevel.values)
          _row(
            context: context,
            icon: _getCompetitionLevelData(l10n, level).icon,
            title: _getCompetitionLevelData(l10n, level).title,
            subtitle: _getCompetitionLevelData(l10n, level).description,
            onTap: () => setState(() => _preferredCompetitionLevel = level),
            trailing: DabblerRadio(
              selected: _preferredCompetitionLevel == level,
              semanticLabel: _getCompetitionLevelData(l10n, level).title,
              onChanged: (_) =>
                  setState(() => _preferredCompetitionLevel = level),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_equipment_header,
      note: l10n.game_prefs_equipment_note,
      children: [
        _toggleRow(
          context,
          l10n.game_prefs_equipment_own,
          l10n.game_prefs_equipment_own_sub,
          'bag-2',
          _hasOwnEquipment,
          (value) => setState(() => _hasOwnEquipment = value),
        ),
        _toggleRow(
          context,
          l10n.game_prefs_equipment_provide,
          l10n.game_prefs_equipment_provide_sub,
          'share',
          _canProvideEquipment,
          (value) => setState(() => _canProvideEquipment = value),
        ),
        _toggleRow(
          context,
          l10n.game_prefs_equipment_need,
          l10n.game_prefs_equipment_need_sub,
          'shop',
          _needsEquipmentProvided,
          (value) => setState(() => _needsEquipmentProvided = value),
        ),
        if (_hasOwnEquipment || _canProvideEquipment)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _subheading(context, l10n.game_prefs_equipment_types),
              Wrap(
                spacing: DabblerSpacing.space2,
                runSpacing: DabblerSpacing.space2,
                children: [
                  for (final equipment in _Equipment.values)
                    DabblerChip(
                      label: _getEquipmentName(l10n, equipment),
                      selected: _equipmentTypes.contains(equipment),
                      onTap: () => setState(() {
                        if (!_equipmentTypes.remove(equipment)) {
                          _equipmentTypes.add(equipment);
                        }
                      }),
                    ),
                ],
              ),
              const DabblerGap.v(DabblerSpacing.space4),
            ],
          ),
      ],
    );
  }

  Widget _buildRefereeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.game_prefs_referee_header,
      note: l10n.game_prefs_referee_note,
      children: [
        _toggleRow(
          context,
          l10n.game_prefs_referee_prefer,
          l10n.game_prefs_referee_prefer_sub,
          'judge',
          _preferReferee,
          (value) => setState(() => _preferReferee = value),
        ),
        _toggleRow(
          context,
          l10n.game_prefs_referee_can,
          l10n.game_prefs_referee_can_sub,
          'verify',
          _canReferee,
          (value) => setState(() => _canReferee = value),
        ),
        _toggleRow(
          context,
          l10n.game_prefs_referee_strict,
          l10n.game_prefs_referee_strict_sub,
          'book',
          _strictRules,
          (value) => setState(() => _strictRules = value),
        ),
      ],
    );
  }

  String _getDurationTitle(AppLocalizations l, GameDuration duration) =>
      switch (duration) {
        GameDuration.short => l.game_prefs_duration_short,
        GameDuration.medium => l.game_prefs_duration_medium,
        GameDuration.long => l.game_prefs_duration_long,
        GameDuration.flexible => l.game_prefs_duration_flexible,
      };

  String _getDurationDescription(AppLocalizations l, GameDuration duration) =>
      switch (duration) {
        GameDuration.short => l.game_prefs_duration_short_sub,
        GameDuration.medium => l.game_prefs_duration_medium_sub,
        GameDuration.long => l.game_prefs_duration_long_sub,
        GameDuration.flexible => l.game_prefs_duration_flexible_sub,
      };

  ({String title, String description, String icon}) _getCompetitionLevelData(
    AppLocalizations l,
    CompetitionLevel level,
  ) => switch (level) {
    CompetitionLevel.casual => (
      title: l.game_prefs_level_casual,
      description: l.game_prefs_level_casual_sub,
      icon: 'emoji-happy',
    ),
    CompetitionLevel.recreational => (
      title: l.game_prefs_level_recreational,
      description: l.game_prefs_level_recreational_sub,
      icon: 'activity',
    ),
    CompetitionLevel.competitive => (
      title: l.game_prefs_level_competitive,
      description: l.game_prefs_level_competitive_sub,
      icon: 'trend-up',
    ),
    CompetitionLevel.professional => (
      title: l.game_prefs_level_professional,
      description: l.game_prefs_level_professional_sub,
      icon: 'cup',
    ),
  };

  String _getEquipmentName(AppLocalizations l, _Equipment e) => switch (e) {
    _Equipment.ball => l.game_prefs_equipment_ball,
    _Equipment.gear => l.game_prefs_equipment_gear,
    _Equipment.uniforms => l.game_prefs_equipment_uniforms,
    _Equipment.goals => l.game_prefs_equipment_goals,
    _Equipment.nets => l.game_prefs_equipment_nets,
    _Equipment.markers => l.game_prefs_equipment_markers,
  };

  void _saveSettings() {
    DabblerToastProvider.of(context).show(
      DabblerToastSpec(
        message: AppLocalizations.of(context).game_prefs_saved,
        tone: DabblerToastTone.success,
      ),
    );
  }
}
