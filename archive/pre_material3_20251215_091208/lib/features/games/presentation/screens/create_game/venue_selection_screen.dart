import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/domain/repositories/venues_repository.dart';

class VenueSelectionScreen extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>?) onVenueSelected;
  final Map<String, dynamic>? selectedVenue;
  final String? sport;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const VenueSelectionScreen({
    super.key,
    required this.onVenueSelected,
    this.selectedVenue,
    this.sport,
    this.date,
    this.startTime,
    this.endTime,
  });

  @override
  ConsumerState<VenueSelectionScreen> createState() =>
      _VenueSelectionScreenState();
}

class _VenueSelectionScreenState extends ConsumerState<VenueSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedOption = 'find_venue'; // 'find_venue' or 'no_venue'
  Map<String, dynamic>? _selectedVenue;
  List<Map<String, dynamic>> _allVenues = [];
  bool _isLoadingVenues = true;
  String? _venuesError;

  List<Map<String, dynamic>> get _filteredVenues {
    var venues = _allVenues.where((venue) {
      // Filter by sport (case-insensitive)
      if (widget.sport != null) {
        final sports = venue['sports'] as List<dynamic>?;
        if (sports == null || sports.isEmpty) {
          return false; // No sports listed, filter out
        }
        // Check if any sport matches (case-insensitive)
        final sportLower = widget.sport!.toLowerCase();
        final hasMatchingSport = sports.any(
          (sport) => sport.toString().toLowerCase() == sportLower,
        );
        if (!hasMatchingSport) {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = venue['name']?.toString().toLowerCase() ?? '';
        final address = venue['address']?.toString().toLowerCase() ?? '';
        if (!name.contains(query) && !address.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by name
    venues.sort((a, b) {
      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });

    return venues;
  }

  @override
  void initState() {
    super.initState();
    _selectedVenue = widget.selectedVenue;
    if (_selectedVenue != null) {
      _selectedOption = 'find_venue';
    }
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() {
      _isLoadingVenues = true;
      _venuesError = null;
    });

    try {
      final repository = ref.read(venuesRepositoryProvider);

      // Build filters - pass sport filter to repository
      final filters = VenueFilters(
        sports: widget.sport != null ? [widget.sport!] : null,
      );

      final result = await repository.getVenues(
        filters: filters,
        limit: 100, // Get more venues for selection
      );

      result.fold(
        (failure) {
          setState(() {
            _venuesError = failure.message;
            _isLoadingVenues = false;
          });
        },
        (venues) {
          setState(() {
            _allVenues = venues.map((venue) {
              return {
                'id': venue.id,
                'name': venue.name,
                'address': venue.fullAddress,
                'distance': 0.0, // Distance not available in selection screen
                'price': venue.pricePerHour,
                'priceType': venue.pricePerHour > 0
                    ? '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}/hour'
                    : 'Free',
                'rating': venue.rating,
                'reviewCount': venue.totalRatings,
                'sports': venue.supportedSports,
                'amenities': venue.amenities,
                'availability': true, // TODO: Check actual availability
                'imageUrl': null, // TODO: Load photos
                'description': venue.description,
              };
            }).toList();
            _isLoadingVenues = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _venuesError = 'Failed to load venues: $e';
        _isLoadingVenues = false;
      });
    }
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
              'Where will you play?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Find a venue or play without a specific location.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildVenueOptions(),
            const SizedBox(height: 24),

            if (_selectedOption == 'find_venue') ...[
              _buildVenueSearch(),
              const SizedBox(height: 16),
              _buildVenueList(),
            ] else ...[
              _buildNoVenueInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVenueOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose an Option',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Find a Venue option
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOption = 'find_venue';
                });
                if (_selectedVenue == null) {
                  widget.onVenueSelected(null);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedOption == 'find_venue'
                        ? Colors.blue
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedOption == 'find_venue'
                      ? Colors.blue[50]
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'find_venue'
                            ? Colors.blue
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: _selectedOption == 'find_venue'
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find a Venue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedOption == 'find_venue'
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search for courts, fields, and facilities',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedOption == 'find_venue')
                      const Icon(Icons.check_circle, color: Colors.blue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // No Venue Needed option
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOption = 'no_venue';
                  _selectedVenue = null;
                });
                widget.onVenueSelected(null);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedOption == 'no_venue'
                        ? Colors.green
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedOption == 'no_venue'
                      ? Colors.green[50]
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'no_venue'
                            ? Colors.green
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.nature_people,
                        color: _selectedOption == 'no_venue'
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Venue Needed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedOption == 'no_venue'
                                  ? Colors.green
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Play at a park, beach, or outdoor space',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedOption == 'no_venue')
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Search Venues',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showFilters,
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filters'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or location...',
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

            if (widget.sport != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Showing venues for ${widget.sport}',
                      style: TextStyle(color: Colors.blue[600], fontSize: 12),
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

  Widget _buildVenueList() {
    if (_isLoadingVenues) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_venuesError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(
                'Failed to load venues',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _venuesError!,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadVenues,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final venues = _filteredVenues;

    if (venues.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'No venues found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Try adjusting your search or filters',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _suggestVenue,
                icon: const Icon(Icons.add_location),
                label: const Text('Suggest a Venue'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${venues.length} venues found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton(
              onPressed: _suggestVenue,
              child: const Text('Suggest Venue'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...venues.map((venue) => _buildVenueCard(venue)),
      ],
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    final isSelected = _selectedVenue?['id'] == venue['id'];
    final isAvailable = venue['availability'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: isAvailable ? () => _selectVenue(venue) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Venue image placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: venue['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              venue['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image, size: 24, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                venue['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                          ],
                        ),
                        const SizedBox(height: 4),

                        Text(
                          venue['address'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        venue['priceType'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: venue['price'] == 0
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber[600]),
                          const SizedBox(width: 2),
                          Text(
                            venue['rating'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Venue details
              Row(
                children: [
                  Icon(Icons.location_city, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${venue['distance']} km away',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.sports, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      (venue['sports'] as List).join(', '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Amenities
              Wrap(
                spacing: 4,
                children: (venue['amenities'] as List<String>)
                    .take(3)
                    .map(
                      (amenity) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

              if (!isAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Not available for selected time',
                        style: TextStyle(color: Colors.red[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _previewVenue(venue),
                      child: const Text('Preview'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isAvailable ? () => _selectVenue(venue) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.green
                            : Colors.blue,
                      ),
                      child: Text(
                        isSelected ? 'Selected' : 'Select',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoVenueInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.nature_people,
                size: 48,
                color: Colors.green[600],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Playing Without a Venue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              'Great choice for outdoor activities! Players will coordinate the exact location among themselves.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for Success',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    '• Suggest a specific location in your game description',
                  ),
                  const Text('• Consider accessibility and parking'),
                  const Text('• Have a backup plan in case of weather'),
                  const Text(
                    '• Share contact info for last-minute coordination',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectVenue(Map<String, dynamic> venue) {
    setState(() {
      _selectedVenue = venue;
    });
    widget.onVenueSelected(venue);
  }

  void _previewVenue(Map<String, dynamic> venue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Venue image
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Details
                      Text(
                        venue['description'],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // Amenities
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (venue['amenities'] as List<String>)
                            .map(
                              (amenity) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  amenity,
                                  style: TextStyle(color: Colors.blue[800]),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // Select button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _selectVenue(venue);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Select This Venue',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const ListTile(
              leading: Icon(Icons.monetization_on),
              title: Text('Price Range'),
              subtitle: Text('Free - \$50/hour'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            const ListTile(
              leading: Icon(Icons.location_city),
              title: Text('Distance'),
              subtitle: Text('Within 5 km'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            const ListTile(
              leading: Icon(Icons.star),
              title: Text('Rating'),
              subtitle: Text('4+ stars'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _suggestVenue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggest a Venue'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Know a great place to play? Let us know!'),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Venue name and address...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
                  content: Text('Thanks for the suggestion! We\'ll review it.'),
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
