import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LeaderboardFilters extends StatefulWidget {
  final Function(Map<String, dynamic>) onFiltersChanged;
  final VoidCallback onClose;
  final Map<String, dynamic>? initialFilters;

  const LeaderboardFilters({
    super.key,
    required this.onFiltersChanged,
    required this.onClose,
    this.initialFilters,
  });

  @override
  State<LeaderboardFilters> createState() => _LeaderboardFiltersState();
}

class _LeaderboardFiltersState extends State<LeaderboardFilters>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;

  // Filter state
  String? _selectedSport;
  String? _selectedRegion;
  String? _selectedAgeGroup;
  String? _selectedTier;
  String? _selectedTimeRange;
  bool _showOnlineOnly = false;
  bool _showFriendsOnly = false;
  String _sortBy = 'rank';
  bool _isAscending = true;

  // Available options
  final List<String> _sports = [
    'All Sports',
    'Basketball',
    'Football',
    'Soccer',
    'Tennis',
    'Baseball',
    'Hockey',
    'Golf',
    'Swimming',
    'Running',
    'Cycling',
  ];

  final List<String> _regions = [
    'Global',
    'North America',
    'Europe',
    'Asia',
    'Australia',
    'South America',
    'Africa',
  ];

  final List<String> _ageGroups = [
    'All Ages',
    'Under 18',
    '18-25',
    '26-35',
    '36-45',
    '46-55',
    '55+',
  ];

  final List<String> _tiers = [
    'All Tiers',
    'Fresh Player',
    'Rookie',
    'Novice',
    'Amateur',
    'Enthusiast',
    'Competitor',
    'Skilled',
    'Expert',
    'Veteran',
    'Elite',
    'Master',
    'Grandmaster',
    'Legend',
    'Champion',
    'Dabbler',
  ];

  final List<String> _timeRanges = [
    'All Time',
    'This Year',
    'This Month',
    'This Week',
    'Today',
  ];

  final Map<String, String> _sortOptions = {
    'rank': 'Rank',
    'points': 'Points',
    'name': 'Name',
    'recent': 'Recent Activity',
    'movement': 'Rank Movement',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();

    // Initialize from existing filters if provided
    if (widget.initialFilters != null) {
      _initializeFromFilters(widget.initialFilters!);
    }
  }

  void _initializeFromFilters(Map<String, dynamic> filters) {
    setState(() {
      _selectedSport = filters['sport'];
      _selectedRegion = filters['region'];
      _selectedAgeGroup = filters['age_group'];
      _selectedTier = filters['tier'];
      _selectedTimeRange = filters['time_range'];
      _showOnlineOnly = filters['online_only'] ?? false;
      _showFriendsOnly = filters['friends_only'] ?? false;
      _sortBy = filters['sort_by'] ?? 'rank';
      _isAscending = filters['ascending'] ?? true;
      _searchController.text = filters['search'] ?? '';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicFilters(),
                _buildAdvancedFilters(),
                _buildSortAndExport(),
              ],
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filter & Sort',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              TextButton(
                onPressed: _resetFilters,
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        tabs: const [
          Tab(text: 'Basic', icon: Icon(Icons.filter_list)),
          Tab(text: 'Advanced', icon: Icon(Icons.tune)),
          Tab(text: 'Sort', icon: Icon(Icons.sort)),
        ],
      ),
    );
  }

  Widget _buildBasicFilters() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          _buildSearchField(),
          const SizedBox(height: 24),

          // Sport Selection
          _buildDropdownFilter(
            title: 'Sport',
            value: _selectedSport,
            items: _sports,
            onChanged: (value) => setState(() => _selectedSport = value),
            icon: Icons.sports_basketball,
          ),
          const SizedBox(height: 16),

          // Region Selection
          _buildDropdownFilter(
            title: 'Region',
            value: _selectedRegion,
            items: _regions,
            onChanged: (value) => setState(() => _selectedRegion = value),
            icon: Icons.public,
          ),
          const SizedBox(height: 16),

          // Time Range
          _buildDropdownFilter(
            title: 'Time Period',
            value: _selectedTimeRange,
            items: _timeRanges,
            onChanged: (value) => setState(() => _selectedTimeRange = value),
            icon: Icons.schedule,
          ),
          const SizedBox(height: 24),

          // Quick toggles
          _buildToggleOptions(),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age Group
          _buildDropdownFilter(
            title: 'Age Group',
            value: _selectedAgeGroup,
            items: _ageGroups,
            onChanged: (value) => setState(() => _selectedAgeGroup = value),
            icon: Icons.people,
          ),
          const SizedBox(height: 16),

          // Tier Level
          _buildDropdownFilter(
            title: 'Tier Level',
            value: _selectedTier,
            items: _tiers,
            onChanged: (value) => setState(() => _selectedTier = value),
            icon: Icons.workspace_premium,
          ),
          const SizedBox(height: 24),

          // Activity filters
          _buildSectionHeader('Activity Filters'),
          const SizedBox(height: 12),

          SwitchListTile(
            title: const Text('Online Players Only'),
            subtitle: const Text('Show only currently active players'),
            value: _showOnlineOnly,
            onChanged: (value) => setState(() => _showOnlineOnly = value),
            activeThumbColor: Theme.of(context).primaryColor,
          ),

          SwitchListTile(
            title: const Text('Friends Only'),
            subtitle: const Text('Show only friends on leaderboard'),
            value: _showFriendsOnly,
            onChanged: (value) => setState(() => _showFriendsOnly = value),
            activeThumbColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndExport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort options
          _buildSectionHeader('Sort Options'),
          const SizedBox(height: 16),

          ..._sortOptions.entries.map(
            (entry) => RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _sortBy,
              onChanged: (value) => setState(() => _sortBy = value!),
              activeColor: Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Sort direction
          SwitchListTile(
            title: const Text('Sort Direction'),
            subtitle: Text(_isAscending ? 'Ascending' : 'Descending'),
            value: _isAscending,
            onChanged: (value) => setState(() => _isAscending = value),
            activeThumbColor: Theme.of(context).primaryColor,
          ),

          const SizedBox(height: 32),

          // Export options
          _buildSectionHeader('Export Options'),
          const SizedBox(height: 16),

          _buildExportButton(
            'Export to CSV',
            Icons.table_chart,
            () => _exportData('csv'),
          ),
          const SizedBox(height: 12),

          _buildExportButton(
            'Share Screenshot',
            Icons.share,
            () => _exportData('screenshot'),
          ),
          const SizedBox(height: 12),

          _buildExportButton(
            'Copy to Clipboard',
            Icons.content_copy,
            () => _exportData('clipboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search players',
        hintText: 'Enter username...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildDropdownFilter({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          hint: Text('Select $title'),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value:
                      item == 'All Sports' ||
                          item == 'Global' ||
                          item == 'All Ages' ||
                          item == 'All Tiers' ||
                          item == 'All Time'
                      ? null
                      : item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quick Filters'),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              'Online Only',
              _showOnlineOnly,
              Icons.circle,
              Colors.green,
              (selected) => setState(() => _showOnlineOnly = selected),
            ),
            _buildFilterChip(
              'Friends Only',
              _showFriendsOnly,
              Icons.people,
              Colors.blue,
              (selected) => setState(() => _showFriendsOnly = selected),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    IconData icon,
    Color color,
    Function(bool) onSelected,
  ) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildExportButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedSport = null;
      _selectedRegion = null;
      _selectedAgeGroup = null;
      _selectedTier = null;
      _selectedTimeRange = null;
      _showOnlineOnly = false;
      _showFriendsOnly = false;
      _sortBy = 'rank';
      _isAscending = true;
      _searchController.clear();
    });
  }

  void _applyFilters() {
    HapticFeedback.lightImpact();

    final filters = <String, dynamic>{
      'search': _searchController.text.trim(),
      'sport': _selectedSport,
      'region': _selectedRegion,
      'age_group': _selectedAgeGroup,
      'tier': _selectedTier,
      'time_range': _selectedTimeRange,
      'online_only': _showOnlineOnly,
      'friends_only': _showFriendsOnly,
      'sort_by': _sortBy,
      'ascending': _isAscending,
    };

    widget.onFiltersChanged(filters);
  }

  void _exportData(String format) {
    HapticFeedback.lightImpact();

    String message;
    switch (format) {
      case 'csv':
        message = 'Exporting leaderboard to CSV...';
        break;
      case 'screenshot':
        message = 'Capturing screenshot to share...';
        break;
      case 'clipboard':
        message = 'Copying leaderboard data to clipboard...';
        break;
      default:
        message = 'Export started...';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
