import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum CompetitionLevel { casual, recreational, competitive, professional }

enum GameDuration { short, medium, long, flexible }

class GamePreferencesScreen extends ConsumerStatefulWidget {
  const GamePreferencesScreen({super.key});

  @override
  ConsumerState<GamePreferencesScreen> createState() =>
      _GamePreferencesScreenState();
}

class _GamePreferencesScreenState extends ConsumerState<GamePreferencesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Game type preferences
  final Set<String> _preferredGameTypes = {
    'pickup_games',
    'tournaments',
    'practice_sessions',
  };

  final Map<String, Map<String, dynamic>> _gameTypes = {
    'pickup_games': {
      'title': 'Pickup Games',
      'description': 'Casual games with other players',
      'icon': Icons.sports_basketball,
      'color': Colors.blue,
    },
    'tournaments': {
      'title': 'Tournaments',
      'description': 'Competitive organized events',
      'icon': Icons.emoji_events,
      'color': Colors.orange,
    },
    'practice_sessions': {
      'title': 'Practice Sessions',
      'description': 'Skill development and training',
      'icon': Icons.fitness_center,
      'color': Colors.green,
    },
    'leagues': {
      'title': 'Leagues',
      'description': 'Season-long competitions',
      'icon': Icons.leaderboard,
      'color': Colors.purple,
    },
    'friendly_matches': {
      'title': 'Friendly Matches',
      'description': 'Non-competitive social games',
      'icon': Icons.handshake,
      'color': Colors.teal,
    },
    'training_camps': {
      'title': 'Training Camps',
      'description': 'Intensive skill workshops',
      'icon': Icons.school,
      'color': Colors.indigo,
    },
  };

  // Duration preferences
  GameDuration _preferredDuration = GameDuration.medium;
  int _customMinDuration = 60; // minutes
  int _customMaxDuration = 120; // minutes

  // Team size preferences
  RangeValues _teamSizeRange = const RangeValues(5, 11);
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
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(child: _buildGameTypesSection(context)),
              SliverToBoxAdapter(child: _buildDurationSection(context)),
              SliverToBoxAdapter(child: _buildTeamSizeSection(context)),
              SliverToBoxAdapter(child: _buildCompetitionLevelSection(context)),
              SliverToBoxAdapter(child: _buildEquipmentSection(context)),
              SliverToBoxAdapter(child: _buildRefereeSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Game Preferences',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
      actions: [
        TextButton(onPressed: _saveSettings, child: const Text('Save')),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGameTypesSection(BuildContext context) {
    return _buildSection(
      context,
      'Preferred Game Types',
      'Select the types of games you enjoy most',
      [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _gameTypes.length,
          itemBuilder: (context, index) {
            final entry = _gameTypes.entries.elementAt(index);
            final key = entry.key;
            final data = entry.value;
            final isSelected = _preferredGameTypes.contains(key);

            return _buildGameTypeCard(context, key, data, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildGameTypeCard(
    BuildContext context,
    String key,
    Map<String, dynamic> data,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _preferredGameTypes.remove(key);
            } else {
              _preferredGameTypes.add(key);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.05)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (data['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data['icon'],
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : data['color'],
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['title'],
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                data['description'],
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSection(BuildContext context) {
    return _buildSection(
      context,
      'Game Duration',
      'How long do you prefer games to last?',
      [
        ...GameDuration.values.map((duration) {
          final isSelected = _preferredDuration == duration;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _preferredDuration = duration),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.05)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getDurationTitle(duration),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getDurationDescription(duration),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_preferredDuration == GameDuration.flexible) ...[
          const SizedBox(height: 16),
          Text(
            'Custom Duration Range',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDurationInput(
                  'Min Duration',
                  _customMinDuration,
                  (value) => setState(() => _customMinDuration = value),
                ),
              ),
              const SizedBox(width: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: '$value min',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          keyboardType: TextInputType.number,
          onChanged: (text) {
            final newValue = int.tryParse(text);
            if (newValue != null && newValue > 0) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTeamSizeSection(BuildContext context) {
    return _buildSection(
      context,
      'Team Size Preferences',
      'What team sizes do you prefer?',
      [
        SwitchListTile(
          title: const Text('Flexible Team Size'),
          subtitle: const Text('Open to various team sizes'),
          value: _flexibleTeamSize,
          onChanged: (value) => setState(() => _flexibleTeamSize = value),
          contentPadding: EdgeInsets.zero,
        ),
        if (!_flexibleTeamSize) ...[
          const SizedBox(height: 16),
          Text(
            'Preferred Team Size: ${_teamSizeRange.start.round()} - ${_teamSizeRange.end.round()} players',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          RangeSlider(
            values: _teamSizeRange,
            min: 2,
            max: 22,
            divisions: 20,
            labels: RangeLabels(
              _teamSizeRange.start.round().toString(),
              _teamSizeRange.end.round().toString(),
            ),
            onChanged: (values) => setState(() => _teamSizeRange = values),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2 players',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                '22 players',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompetitionLevelSection(BuildContext context) {
    return _buildSection(
      context,
      'Competition Level',
      'What level of competition do you prefer?',
      [
        ...CompetitionLevel.values.map((level) {
          final isSelected = _preferredCompetitionLevel == level;
          final levelData = _getCompetitionLevelData(level);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _preferredCompetitionLevel = level),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.05)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (levelData['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          levelData['icon'],
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : levelData['color'],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              levelData['title'],
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              levelData['description'],
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEquipmentSection(BuildContext context) {
    return _buildSection(
      context,
      'Equipment Preferences',
      'What are your equipment needs?',
      [
        _buildEquipmentToggle(
          'I have my own equipment',
          'You can bring your own gear',
          Icons.sports_outlined,
          _hasOwnEquipment,
          (value) => setState(() => _hasOwnEquipment = value),
        ),
        _buildEquipmentToggle(
          'I can provide equipment for others',
          'You can share equipment with teammates',
          Icons.handshake_outlined,
          _canProvideEquipment,
          (value) => setState(() => _canProvideEquipment = value),
        ),
        _buildEquipmentToggle(
          'I need equipment provided',
          'Equipment should be available at the venue',
          Icons.help_outline,
          _needsEquipmentProvided,
          (value) => setState(() => _needsEquipmentProvided = value),
        ),
        if (_hasOwnEquipment || _canProvideEquipment) ...[
          const SizedBox(height: 16),
          Text(
            'Equipment Types',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'ball',
                  'protective_gear',
                  'uniforms',
                  'goals',
                  'nets',
                  'markers',
                ].map((equipment) {
                  final isSelected = _equipmentTypes.contains(equipment);
                  return FilterChip(
                    label: Text(_getEquipmentName(equipment)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _equipmentTypes.add(equipment);
                        } else {
                          _equipmentTypes.remove(equipment);
                        }
                      });
                    },
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRefereeSection(BuildContext context) {
    return _buildSection(
      context,
      'Referee Preferences',
      'How do you prefer games to be officiated?',
      [
        _buildEquipmentToggle(
          'Prefer games with referee',
          'Official referee for fair play',
          Icons.sports_outlined,
          _preferReferee,
          (value) => setState(() => _preferReferee = value),
        ),
        _buildEquipmentToggle(
          'I can referee games',
          'You\'re qualified to officiate',
          Icons.sports_soccer_outlined,
          _canReferee,
          (value) => setState(() => _canReferee = value),
        ),
        _buildEquipmentToggle(
          'Strict rule enforcement',
          'Games should follow official rules closely',
          Icons.gavel_outlined,
          _strictRules,
          (value) => setState(() => _strictRules = value),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: value
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Theme.of(context).primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
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

  Map<String, dynamic> _getCompetitionLevelData(CompetitionLevel level) {
    switch (level) {
      case CompetitionLevel.casual:
        return {
          'title': 'Casual',
          'description': 'Just for fun, relaxed atmosphere',
          'icon': Icons.sentiment_satisfied,
          'color': Colors.green,
        };
      case CompetitionLevel.recreational:
        return {
          'title': 'Recreational',
          'description': 'Friendly competition, moderate intensity',
          'icon': Icons.sports_outlined,
          'color': Colors.blue,
        };
      case CompetitionLevel.competitive:
        return {
          'title': 'Competitive',
          'description': 'Serious competition, high intensity',
          'icon': Icons.trending_up,
          'color': Colors.orange,
        };
      case CompetitionLevel.professional:
        return {
          'title': 'Professional',
          'description': 'Elite level competition',
          'icon': Icons.emoji_events,
          'color': Colors.red,
        };
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Game preferences saved!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
