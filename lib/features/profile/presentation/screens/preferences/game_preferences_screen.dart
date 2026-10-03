import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum CompetitionLevel { casual, recreational, competitive, professional }

enum GameDuration { short, medium, long, flexible }

/// Game preferences — a design-system page of [DabblerSection] groups:
/// checkbox rows for game types, radio rows for duration and competition
/// level, toggle rows for team size / equipment / referee, a range slider for
/// team size and chips for equipment types. State is local (as before) and
/// "Save" only confirms with a toast. No design frame exists for this screen;
/// it is a DS-default render.
class GamePreferencesScreen extends ConsumerStatefulWidget {
  const GamePreferencesScreen({super.key});

  @override
  ConsumerState<GamePreferencesScreen> createState() =>
      _GamePreferencesScreenState();
}

class _GamePreferencesScreenState extends ConsumerState<GamePreferencesScreen> {
  // Game type preferences
  final Set<String> _preferredGameTypes = {
    'pickup_games',
    'tournaments',
    'practice_sessions',
  };

  static const Map<String, ({String title, String description, String icon})>
  _gameTypes = {
    'pickup_games': (
      title: 'Pickup Games',
      description: 'Casual games with other players',
      icon: 'game',
    ),
    'tournaments': (
      title: 'Tournaments',
      description: 'Competitive organized events',
      icon: 'cup',
    ),
    'practice_sessions': (
      title: 'Practice Sessions',
      description: 'Skill development and training',
      icon: 'weight',
    ),
    'leagues': (
      title: 'Leagues',
      description: 'Season-long competitions',
      icon: 'ranking',
    ),
    'friendly_matches': (
      title: 'Friendly Matches',
      description: 'Non-competitive social games',
      icon: 'people',
    ),
    'training_camps': (
      title: 'Training Camps',
      description: 'Intensive skill workshops',
      icon: 'teacher',
    ),
  };

  static const List<String> _equipmentOptions = [
    'ball',
    'protective_gear',
    'uniforms',
    'goals',
    'nets',
    'markers',
  ];

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
  final Set<String> _equipmentTypes = {'ball', 'protective_gear'};

  // Referee preferences
  bool _preferReferee = false;
  bool _canReferee = false;
  bool _strictRules = false;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: DabblerSpacing.space7);
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Game Preferences',
        onBack: () => context.pop(),
        actions: [
          DabblerNavigationAction.text(label: 'Save', onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
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
    size: DabblerSizing.iconRow,
    color: DabblerColors.of(context).textSecondary,
  );

  Widget _subheading(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: DabblerSpacing.space5,
      bottom: DabblerSpacing.space3,
    ),
    child: DabblerText(text, style: DabblerType.headline),
  );

  Widget _toggleRow(
    BuildContext context,
    String title,
    String subtitle,
    String icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return DabblerInputRow(
      leading: _icon(context, icon),
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: DabblerToggle(
        checked: value,
        semanticLabel: title,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildGameTypesSection(BuildContext context) {
    return DabblerSection(
      title: 'Preferred Game Types',
      subtitle: 'Select the types of games you enjoy most',
      children: [
        for (final entry in _gameTypes.entries)
          DabblerInputRow(
            leading: _icon(context, entry.value.icon),
            title: entry.value.title,
            subtitle: entry.value.description,
            onTap: () => _toggleGameType(entry.key),
            trailing: DabblerCheckbox(
              checked: _preferredGameTypes.contains(entry.key),
              semanticLabel: entry.value.title,
              onChanged: (_) => _toggleGameType(entry.key),
            ),
          ),
      ],
    );
  }

  void _toggleGameType(String key) {
    setState(() {
      if (_preferredGameTypes.contains(key)) {
        _preferredGameTypes.remove(key);
      } else {
        _preferredGameTypes.add(key);
      }
    });
  }

  Widget _buildDurationSection(BuildContext context) {
    return DabblerSection(
      title: 'Game Duration',
      subtitle: 'How long do you prefer games to last?',
      children: [
        for (final duration in GameDuration.values)
          DabblerInputRow(
            leading: _icon(context, 'clock'),
            title: _getDurationTitle(duration),
            subtitle: _getDurationDescription(duration),
            onTap: () => setState(() => _preferredDuration = duration),
            trailing: DabblerRadio(
              selected: _preferredDuration == duration,
              semanticLabel: _getDurationTitle(duration),
              onChanged: (_) => setState(() => _preferredDuration = duration),
            ),
          ),
        if (_preferredDuration == GameDuration.flexible) ...[
          _subheading(context, 'Custom Duration Range'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDurationInput(
                  'Min Duration',
                  _customMinDuration,
                  (value) => setState(() => _customMinDuration = value),
                ),
              ),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: _buildDurationInput(
                  'Max Duration',
                  _customMaxDuration,
                  (value) => setState(() => _customMaxDuration = value),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDurationInput(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return DabblerTextField(
      label: label,
      placeholder: '$value min',
      suffixText: 'min',
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
    return DabblerSection(
      title: 'Team Size Preferences',
      subtitle: 'What team sizes do you prefer?',
      children: [
        _toggleRow(
          context,
          'Flexible Team Size',
          'Open to various team sizes',
          'people',
          _flexibleTeamSize,
          (value) => setState(() => _flexibleTeamSize = value),
        ),
        if (!_flexibleTeamSize) ...[
          _subheading(
            context,
            'Preferred Team Size: ${_teamSizeRange.low.round()} - ${_teamSizeRange.high.round()} players',
          ),
          DabblerSlider.range(
            values: _teamSizeRange,
            min: 2,
            max: 22,
            step: 1,
            formatValue: (v) => v.round().toString(),
            minimumSemanticLabel: '2 players',
            maximumSemanticLabel: '22 players',
            onChanged: (values) => setState(() => _teamSizeRange = values),
          ),
        ],
      ],
    );
  }

  Widget _buildCompetitionLevelSection(BuildContext context) {
    return DabblerSection(
      title: 'Competition Level',
      subtitle: 'What level of competition do you prefer?',
      children: [
        for (final level in CompetitionLevel.values)
          DabblerInputRow(
            leading: _icon(context, _getCompetitionLevelData(level).icon),
            title: _getCompetitionLevelData(level).title,
            subtitle: _getCompetitionLevelData(level).description,
            onTap: () => setState(() => _preferredCompetitionLevel = level),
            trailing: DabblerRadio(
              selected: _preferredCompetitionLevel == level,
              semanticLabel: _getCompetitionLevelData(level).title,
              onChanged: (_) =>
                  setState(() => _preferredCompetitionLevel = level),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentSection(BuildContext context) {
    return DabblerSection(
      title: 'Equipment Preferences',
      subtitle: 'What are your equipment needs?',
      children: [
        _toggleRow(
          context,
          'I have my own equipment',
          'You can bring your own gear',
          'bag-2',
          _hasOwnEquipment,
          (value) => setState(() => _hasOwnEquipment = value),
        ),
        _toggleRow(
          context,
          'I can provide equipment for others',
          'You can share equipment with teammates',
          'share',
          _canProvideEquipment,
          (value) => setState(() => _canProvideEquipment = value),
        ),
        _toggleRow(
          context,
          'I need equipment provided',
          'Equipment should be available at the venue',
          'shop',
          _needsEquipmentProvided,
          (value) => setState(() => _needsEquipmentProvided = value),
        ),
        if (_hasOwnEquipment || _canProvideEquipment) ...[
          _subheading(context, 'Equipment Types'),
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: [
              for (final equipment in _equipmentOptions)
                DabblerChip(
                  label: _getEquipmentName(equipment),
                  selected: _equipmentTypes.contains(equipment),
                  onTap: () => setState(() {
                    if (!_equipmentTypes.remove(equipment)) {
                      _equipmentTypes.add(equipment);
                    }
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRefereeSection(BuildContext context) {
    return DabblerSection(
      title: 'Referee Preferences',
      subtitle: 'How do you prefer games to be officiated?',
      children: [
        _toggleRow(
          context,
          'Prefer games with referee',
          'Official referee for fair play',
          'judge',
          _preferReferee,
          (value) => setState(() => _preferReferee = value),
        ),
        _toggleRow(
          context,
          'I can referee games',
          'You\'re qualified to officiate',
          'verify',
          _canReferee,
          (value) => setState(() => _canReferee = value),
        ),
        _toggleRow(
          context,
          'Strict rule enforcement',
          'Games should follow official rules closely',
          'book',
          _strictRules,
          (value) => setState(() => _strictRules = value),
        ),
      ],
    );
  }

  String _getDurationTitle(GameDuration duration) {
    switch (duration) {
      case GameDuration.short:
        return 'Short Games';
      case GameDuration.medium:
        return 'Medium Games';
      case GameDuration.long:
        return 'Long Games';
      case GameDuration.flexible:
        return 'Flexible Duration';
    }
  }

  String _getDurationDescription(GameDuration duration) {
    switch (duration) {
      case GameDuration.short:
        return '30-60 minutes';
      case GameDuration.medium:
        return '60-90 minutes';
      case GameDuration.long:
        return '90+ minutes';
      case GameDuration.flexible:
        return 'Any duration';
    }
  }

  ({String title, String description, String icon}) _getCompetitionLevelData(
    CompetitionLevel level,
  ) {
    switch (level) {
      case CompetitionLevel.casual:
        return (
          title: 'Casual',
          description: 'Just for fun, relaxed atmosphere',
          icon: 'emoji-happy',
        );
      case CompetitionLevel.recreational:
        return (
          title: 'Recreational',
          description: 'Friendly competition, moderate intensity',
          icon: 'activity',
        );
      case CompetitionLevel.competitive:
        return (
          title: 'Competitive',
          description: 'Serious competition, high intensity',
          icon: 'trend-up',
        );
      case CompetitionLevel.professional:
        return (
          title: 'Professional',
          description: 'Elite level competition',
          icon: 'cup',
        );
    }
  }

  String _getEquipmentName(String equipment) {
    switch (equipment) {
      case 'ball':
        return 'Ball';
      case 'protective_gear':
        return 'Protective Gear';
      case 'uniforms':
        return 'Uniforms';
      case 'goals':
        return 'Goals';
      case 'nets':
        return 'Nets';
      case 'markers':
        return 'Markers';
      default:
        return equipment;
    }
  }

  void _saveSettings() {
    DabblerToastProvider.of(context).show(
      const DabblerToastSpec(
        message: 'Game preferences saved!',
        tone: DabblerToastTone.success,
      ),
    );
  }
}
