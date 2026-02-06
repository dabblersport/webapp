import 'package:flutter/material.dart';

class GameConfigurationScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfigurationChanged;
  final Map<String, dynamic> gameData;

  const GameConfigurationScreen({
    super.key,
    required this.onConfigurationChanged,
    required this.gameData,
  });

  @override
  State<GameConfigurationScreen> createState() =>
      _GameConfigurationScreenState();
}

class _GameConfigurationScreenState extends State<GameConfigurationScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  int _minPlayers = 2;
  int _maxPlayers = 10;
  String _skillLevel = 'Mixed';
  bool _isPublic = true;
  bool _allowWaitlist = true;
  double _pricePerPlayer = 0.0;

  final List<String> _skillLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Mixed',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with existing data
    final data = widget.gameData;
    _titleController = TextEditingController(
      text: data['title'] ?? _generateTitle(),
    );
    _descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );
    _priceController = TextEditingController(
      text: data['pricePerPlayer']?.toString() ?? '0.0',
    );

    _minPlayers = data['minPlayers'] ?? 2;
    _maxPlayers = data['maxPlayers'] ?? 10;
    _skillLevel = data['skillLevel'] ?? 'Mixed';
    _isPublic = data['isPublic'] ?? true;
    _allowWaitlist = data['allowWaitlist'] ?? true;
    _pricePerPlayer = data['pricePerPlayer'] ?? 0.0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _generateTitle() {
    final sport = widget.gameData['sport'] ?? 'Game';
    final date = widget.gameData['date'];
    final venue = widget.gameData['venue'];

    if (date != null) {
      final dayOfWeek = _getDayOfWeek(date);
      if (venue != null) {
        return '$sport at ${venue['name']} - $dayOfWeek';
      } else {
        return '$dayOfWeek $sport Game';
      }
    }

    return '$sport Game';
  }

  String _getDayOfWeek(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your game details to attract the right players.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildGameTitle(),
            const SizedBox(height: 16),
            _buildGameDescription(),
            const SizedBox(height: 16),
            _buildPlayersSection(),
            const SizedBox(height: 16),
            _buildSkillLevel(),
            const SizedBox(height: 16),
            _buildPricing(),
            const SizedBox(height: 16),
            _buildGameSettings(),
            const SizedBox(height: 16),
            _buildGameTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTitle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.title, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Game Title',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _titleController.text = _generateTitle();
                    _updateConfiguration();
                  },
                  child: const Text('Auto-generate'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter a catchy title for your game...',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 60,
              onChanged: (_) => _updateConfiguration(),
            ),

            const SizedBox(height: 8),

            Text(
              'A good title helps players find and join your game',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Description (Optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText:
                    'Add details about your game, rules, or what to bring...',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 500,
              maxLines: 4,
              onChanged: (_) => _updateConfiguration(),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                _buildSuggestionChip('Bring water and towel'),
                _buildSuggestionChip('All skill levels welcome'),
                _buildSuggestionChip('Rain cancels'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        final currentText = _descriptionController.text;
        if (!currentText.contains(text)) {
          _descriptionController.text = currentText.isEmpty
              ? text
              : '$currentText\n• $text';
          _updateConfiguration();
        }
      },
    );
  }

  Widget _buildPlayersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Number of Players',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Minimum Players'),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _minPlayers > 1
                                  ? () {
                                      setState(() {
                                        _minPlayers--;
                                        if (_maxPlayers < _minPlayers) {
                                          _maxPlayers = _minPlayers;
                                        }
                                      });
                                      _updateConfiguration();
                                    }
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Text(
                                _minPlayers.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _minPlayers++;
                                  if (_maxPlayers < _minPlayers) {
                                    _maxPlayers = _minPlayers;
                                  }
                                });
                                _updateConfiguration();
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Maximum Players'),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _maxPlayers > _minPlayers
                                  ? () {
                                      setState(() {
                                        _maxPlayers--;
                                      });
                                      _updateConfiguration();
                                    }
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Text(
                                _maxPlayers.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _maxPlayers++;
                                });
                                _updateConfiguration();
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Game needs at least $_minPlayers players to start',
                      style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillLevel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Skill Level Requirement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Set the expected skill level for your game',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              children: _skillLevels
                  .map(
                    (level) => ChoiceChip(
                      label: Text(level),
                      selected: _skillLevel == level,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _skillLevel = level;
                          });
                          _updateConfiguration();
                        }
                      },
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSkillLevelDescription(_skillLevel),
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSkillLevelDescription(String level) {
    switch (level) {
      case 'Beginner':
        return 'Perfect for new players learning the basics';
      case 'Intermediate':
        return 'For players with some experience and basic skills';
      case 'Advanced':
        return 'For experienced players with strong skills';
      case 'Mixed':
        return 'All skill levels welcome - great for inclusive games';
      default:
        return '';
    }
  }

  Widget _buildPricing() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Pricing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Set the cost per player (leave as 0 for free games)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text(
                  '\$',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      suffixText: 'per player',
                    ),
                    onChanged: (value) {
                      _pricePerPlayer = double.tryParse(value) ?? 0.0;
                      _updateConfiguration();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              children: [
                _buildPriceChip('Free', 0.0),
                _buildPriceChip('\$5', 5.0),
                _buildPriceChip('\$10', 10.0),
                _buildPriceChip('\$15', 15.0),
                _buildPriceChip('\$20', 20.0),
              ],
            ),

            if (_pricePerPlayer > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calculate,
                          color: Colors.green[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total for $_maxPlayers players: \$${(_pricePerPlayer * _maxPlayers).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChip(String label, double price) {
    return FilterChip(
      label: Text(label),
      selected: _pricePerPlayer == price,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _pricePerPlayer = price;
            _priceController.text = price.toStringAsFixed(2);
          });
          _updateConfiguration();
        }
      },
    );
  }

  Widget _buildGameSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Game Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Public Game'),
              subtitle: const Text('Anyone can find and join this game'),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
                _updateConfiguration();
              },
              contentPadding: EdgeInsets.zero,
            ),

            SwitchListTile(
              title: const Text('Allow Waitlist'),
              subtitle: const Text('Let extra players join a waiting list'),
              value: _allowWaitlist,
              onChanged: (value) {
                setState(() {
                  _allowWaitlist = value;
                });
                _updateConfiguration();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[600]),
                const SizedBox(width: 8),
                const Text(
                  'Tips for Attractive Listings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('✓ Use a clear, descriptive title'),
            const SizedBox(height: 4),
            const Text('✓ Set realistic player limits'),
            const SizedBox(height: 4),
            const Text('✓ Be specific about skill level'),
            const SizedBox(height: 4),
            const Text('✓ Include important details in description'),
            const SizedBox(height: 4),
            const Text('✓ Consider making it free to attract more players'),
          ],
        ),
      ),
    );
  }

  void _updateConfiguration() {
    widget.onConfigurationChanged({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'minPlayers': _minPlayers,
      'maxPlayers': _maxPlayers,
      'skillLevel': _skillLevel,
      'pricePerPlayer': _pricePerPlayer,
      'isPublic': _isPublic,
      'allowWaitlist': _allowWaitlist,
    });
  }
}
