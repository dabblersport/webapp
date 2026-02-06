import 'package:flutter/material.dart';

class GameTypeSelectionScreen extends StatefulWidget {
  final Function(String) onSportSelected;
  final String? selectedSport;

  const GameTypeSelectionScreen({
    super.key,
    required this.onSportSelected,
    this.selectedSport,
  });

  @override
  State<GameTypeSelectionScreen> createState() =>
      _GameTypeSelectionScreenState();
}

class _GameTypeSelectionScreenState extends State<GameTypeSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _popularSports = [
    {
      'name': 'Basketball',
      'icon': Icons.sports_basketball,
      'minPlayers': 6,
      'maxPlayers': 10,
      'duration': '60-90 min',
      'type': 'Team',
      'color': Colors.orange,
    },
    {
      'name': 'Soccer',
      'icon': Icons.sports_soccer,
      'minPlayers': 10,
      'maxPlayers': 22,
      'duration': '90 min',
      'type': 'Team',
      'color': Colors.green,
    },
    {
      'name': 'Tennis',
      'icon': Icons.sports_tennis,
      'minPlayers': 2,
      'maxPlayers': 4,
      'duration': '60-120 min',
      'type': 'Individual',
      'color': Colors.blue,
    },
    {
      'name': 'Volleyball',
      'icon': Icons.sports_volleyball,
      'minPlayers': 6,
      'maxPlayers': 12,
      'duration': '45-60 min',
      'type': 'Team',
      'color': Colors.purple,
    },
    {
      'name': 'Football',
      'icon': Icons.sports_football,
      'minPlayers': 14,
      'maxPlayers': 22,
      'duration': '120 min',
      'type': 'Team',
      'color': Colors.brown,
    },
    {
      'name': 'Baseball',
      'icon': Icons.sports_baseball,
      'minPlayers': 10,
      'maxPlayers': 18,
      'duration': '180 min',
      'type': 'Team',
      'color': Colors.red,
    },
  ];

  final List<Map<String, dynamic>> _otherSports = [
    {
      'name': 'Table Tennis',
      'icon': Icons.sports_tennis,
      'minPlayers': 2,
      'maxPlayers': 4,
      'duration': '30-60 min',
      'type': 'Individual',
      'color': Colors.teal,
    },
    {
      'name': 'Badminton',
      'icon': Icons.sports_tennis,
      'minPlayers': 2,
      'maxPlayers': 4,
      'duration': '45-60 min',
      'type': 'Individual',
      'color': Colors.indigo,
    },
    {
      'name': 'Cricket',
      'icon': Icons.sports,
      'minPlayers': 11,
      'maxPlayers': 22,
      'duration': '180+ min',
      'type': 'Team',
      'color': Colors.amber,
    },
    {
      'name': 'Hockey',
      'icon': Icons.sports_hockey,
      'minPlayers': 12,
      'maxPlayers': 22,
      'duration': '60 min',
      'type': 'Team',
      'color': Colors.cyan,
    },
    {
      'name': 'Golf',
      'icon': Icons.sports_golf,
      'minPlayers': 1,
      'maxPlayers': 4,
      'duration': '240+ min',
      'type': 'Individual',
      'color': Colors.lightGreen,
    },
    {
      'name': 'Swimming',
      'icon': Icons.pool,
      'minPlayers': 1,
      'maxPlayers': 8,
      'duration': '30-60 min',
      'type': 'Individual',
      'color': Colors.lightBlue,
    },
  ];

  List<Map<String, dynamic>> get _filteredOtherSports {
    if (_searchQuery.isEmpty) return _otherSports;
    return _otherSports
        .where(
          (sport) => sport['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              'What sport would you like to play?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the sport for your game. We\'ll suggest appropriate settings.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Popular Sports Section
            const Text(
              'Popular Sports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _popularSports.length,
              itemBuilder: (context, index) {
                final sport = _popularSports[index];
                final isSelected = widget.selectedSport == sport['name'];

                return _buildSportCard(sport, isSelected, isPopular: true);
              },
            ),
            const SizedBox(height: 32),

            // Search Section
            const Text(
              'More Sports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a sport...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Other Sports Grid
            if (_filteredOtherSports.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredOtherSports.length,
                itemBuilder: (context, index) {
                  final sport = _filteredOtherSports[index];
                  final isSelected = widget.selectedSport == sport['name'];

                  return _buildSportCard(sport, isSelected);
                },
              )
            else if (_searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No sports found for "$_searchQuery"',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _suggestCustomSport,
                      icon: const Icon(Icons.add),
                      label: const Text('Suggest This Sport'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Custom Sport Option (Future Feature)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 32,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Don\'t see your sport?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We\'ll add more sports soon!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _requestNewSport,
                    child: const Text('Request New Sport'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(
    Map<String, dynamic> sport,
    bool isSelected, {
    bool isPopular = false,
  }) {
    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => widget.onSportSelected(sport['name']),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sport['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(sport['icon'], size: 24, color: sport['color']),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  if (isPopular && !isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'POPULAR',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                sport['name'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Players info
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${sport['minPlayers']}-${sport['maxPlayers']} players',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Duration info
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    sport['duration'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Team/Individual badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sport['type'] == 'Team'
                      ? Colors.green[100]
                      : Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sport['type'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: sport['type'] == 'Team'
                        ? Colors.green[800]
                        : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _suggestCustomSport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Thanks for suggesting "$_searchQuery"! We\'ll consider adding it.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _requestNewSport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request New Sport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What sport would you like to see added?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter sport name...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.pop(context);
                if (value.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Thanks for requesting "$value"! We\'ll review it.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request submitted! We\'ll review it.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
