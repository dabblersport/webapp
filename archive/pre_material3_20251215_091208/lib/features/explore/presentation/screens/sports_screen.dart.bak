import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/core/design_system/layouts/two_section_layout.dart';
import 'package:dabbler/core/design_system/widgets/app_filter_chip.dart';
import 'package:dabbler/core/design_system/widgets/app_search_input.dart';
import 'package:dabbler/core/design_system/app_colors.dart';
import 'package:dabbler/core/design_system/ds.dart';
import 'match_list_screen.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/presentation/controllers/venues_controller.dart'
    as vc;

class VenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final VoidCallback? onTap;
  final bool isLoading;

  const VenueCard({
    super.key,
    required this.venue,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeletonCard();
    }

    final images = (venue['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final name = venue['name'] as String? ?? 'Unknown Venue';
    final area = venue['location'] as String? ?? 'Location not available';
    final sports = (venue['sports'] as List<dynamic>?)?.cast<String>() ?? [];
    final rating = (venue['rating'] as num?)?.toDouble() ?? 0.0;
    final isClosed = venue['isOpen'] == false;
    final reviews =
        (venue['reviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    final distance = venue['distance'] as String? ?? '';
    final showRating = reviews.length >= 3 && rating >= 3.0;
    final maxNameLength = 26;
    final displayName = name.length > maxNameLength
        ? '${name.substring(0, maxNameLength)}…'
        : name;
    final maxSports = 3;
    final visibleSports = sports.take(maxSports).toList();
    final overflowCount = sports.length - maxSports;
    final thumbnail = images.isNotEmpty ? images.first : null;

    return GestureDetector(
      onTap: onTap, // Changed: Always call onTap when provided
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                color: context.colors.primary.withValues(alpha: 0.08),
              ),
              child: Stack(
                children: [
                  if (thumbnail != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        thumbnail,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackImage(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildImagePlaceholder();
                        },
                      ),
                    )
                  else
                    _buildFallbackImage(),
                  // Status badge
                  if (isClosed)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Closed',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Rating badge
                  if (showRating)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Venue info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    displayName,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 16,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          area,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Sports chips and distance
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            ...visibleSports.map(
                              (sport) => _buildSportChip(sport),
                            ),
                            if (overflowCount > 0)
                              _buildOverflowChip(overflowCount),
                          ],
                        ),
                      ),
                      if (distance.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.navigation,
                                size: 12,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                distance,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // CTA Button
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton(
                  //     onPressed: ctaEnabled ? onTap : null,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: isClosed ? Colors.grey[400] : context.colors.primary,
                  //       foregroundColor: Colors.white,
                  //       disabledBackgroundColor: Colors.grey[300],
                  //       minimumSize: const Size(0, 32),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(horizontal: 0),
                  //       elevation: 0,
                  //     ),
                  //     child: Text(
                  //       ctaLabel,
                  //       style: context.textTheme.bodySmall?.copyWith(
                  //         fontWeight: FontWeight.w700,
                  //         color: Colors.white,
                  //         fontSize: 12,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportChip(String sport) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.gap6,
        vertical: DS.gap2,
      ),
      decoration: BoxDecoration(
        color: DS.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getSportEmoji(sport), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            sport,
            style: DS.caption.copyWith(
              color: DS.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.gap6,
        vertical: DS.gap2,
      ),
      decoration: BoxDecoration(
        color: DS.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '+$count',
        style: DS.caption.copyWith(
          color: DS.primary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _getSportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return '⚽️';
      case 'cricket':
        return '🏏';
      case 'padel':
        return '🎾';
      case 'tennis':
        return '🎾';
      case 'basketball':
        return '🏀';
      case 'volleyball':
        return '🏐';
      default:
        return '⚽️';
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.image, size: 24, color: Colors.grey[400]),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: DS.caption.copyWith(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: DS.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton thumbnail
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),

          // Skeleton content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(DS.gap16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skeleton title
                  DS.skeleton(height: 18, width: 150),
                  const SizedBox(height: DS.gap4),

                  // Skeleton location
                  DS.skeleton(height: 14, width: 100),
                  const SizedBox(height: DS.gap8),

                  // Skeleton chips
                  Row(
                    children: [
                      DS.skeleton(height: 20, width: 60),
                      const SizedBox(width: DS.gap4),
                      DS.skeleton(height: 20, width: 50),
                    ],
                  ),

                  const SizedBox(height: DS.gap8),

                  // Skeleton button
                  DS.skeleton(height: 32, width: double.infinity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreScreen extends StatefulWidget {
  final String? initialTab;
  final Map<String, dynamic>? initialFilters;

  const ExploreScreen({super.key, this.initialTab, this.initialFilters});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  int _selectedSportIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter state
  String? _selectedArea;
  RangeValues _selectedPriceRange = const RangeValues(0, 500);
  double _selectedRating = 0;
  final Set<String> _selectedAmenities = {};
  final Set<String> _selectedSecondarySports =
      {}; // For additional sports like Futsal, etc.

  // Primary sports shown in chips
  final List<Map<String, dynamic>> _sports = [
    {
      'name': 'Football',
      'emoji': '⚽️',
      'icon': LucideIcons.circle,
      'color': Colors.green,
      'description': 'Find football games near you',
      'count': 30,
    },
    {
      'name': 'Cricket',
      'emoji': '🏏',
      'icon': LucideIcons.circle,
      'color': Colors.orange,
      'description': 'Join cricket games and tournaments',
      'count': 15,
    },
    {
      'name': 'Padel',
      'emoji': '🎾',
      'icon': LucideIcons.square,
      'color': Colors.blue,
      'description': 'Discover padel courts and players',
      'count': 8,
    },
  ];

  // Secondary sports shown in filter drawer
  final List<String> _secondarySports = [
    'All Sports',
    'Futsal',
    'Tennis',
    'Basketball',
    'Volleyball',
    'Badminton',
    'Squash',
    'Table Tennis',
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (_mainTabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _showFilterModal() {
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Filter Results',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Additional Sports
                    Text(
                      'Additional Sports',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _secondarySports.map((sport) {
                        return FilterChip(
                          label: Text(sport),
                          selected: _selectedSecondarySports.contains(sport),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedSecondarySports.add(sport);
                              } else {
                                _selectedSecondarySports.remove(sport);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Area
                    Text(
                      'Area',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedArea,
                      hint: const Text('Select Area'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items:
                          [
                            'Downtown',
                            'Jumeirah',
                            'Marina',
                            'Business Bay',
                            'Other',
                          ].map((area) {
                            return DropdownMenuItem(
                              value: area,
                              child: Text(area),
                            );
                          }).toList(),
                      onChanged: (value) =>
                          setModalState(() => _selectedArea = value),
                    ),
                    const SizedBox(height: 20),
                    // Price Range
                    Text(
                      'Price Range (AED)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    RangeSlider(
                      values: _selectedPriceRange,
                      min: 0,
                      max: 500,
                      divisions: 10,
                      labels: RangeLabels(
                        _selectedPriceRange.start.round().toString(),
                        _selectedPriceRange.end.round().toString(),
                      ),
                      onChanged: (values) =>
                          setModalState(() => _selectedPriceRange = values),
                    ),
                    Text(
                      'AED ${_selectedPriceRange.start.round()} - AED ${_selectedPriceRange.end.round()}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    // Rating
                    Text(
                      'Minimum Rating',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: _selectedRating,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _selectedRating == 0
                          ? 'Any'
                          : _selectedRating.toStringAsFixed(1),
                      onChanged: (value) =>
                          setModalState(() => _selectedRating = value),
                    ),
                    Text(
                      _selectedRating == 0
                          ? 'Any rating'
                          : '${_selectedRating.toStringAsFixed(1)}+ stars',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    // Amenities
                    Text(
                      'Amenities',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            'Parking',
                            'Showers',
                            'Indoor',
                            'Outdoor',
                            'Cafeteria',
                          ].map((amenity) {
                            return FilterChip(
                              label: Text(amenity),
                              selected: _selectedAmenities.contains(amenity),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _selectedAmenities.add(amenity);
                                  } else {
                                    _selectedAmenities.remove(amenity);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedArea = null;
                                _selectedPriceRange = const RangeValues(0, 500);
                                _selectedRating = 0;
                                _selectedAmenities.clear();
                                _selectedSecondarySports.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // Apply filters
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TwoSectionLayout(
      category: 'sports',
      topPadding: EdgeInsets.zero,
      bottomPadding: EdgeInsets.zero,
      topSection: _buildTopSection(),
      bottomSection: _buildBottomSection(),
    );
  }

  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Home icon and Create game button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home icon button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Text(
                    '🏠',
                    style: TextStyle(fontSize: 24, fontFamily: 'Roboto'),
                  ),
                  onPressed: () => context.go('/home'),
                ),
              ),
              // Create game button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => context.push(RoutePaths.createGame),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Create game'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tab Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.stroke(context), width: 1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: TabBar(
                controller: _mainTabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🎮',
                          style: TextStyle(fontSize: 20, fontFamily: 'Roboto'),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Games',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🏟️',
                          style: TextStyle(fontSize: 20, fontFamily: 'Roboto'),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Venues',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ],
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: AppColors.mainTxt(
                  context,
                ).withValues(alpha: 0.7),
                indicatorColor: Theme.of(context).colorScheme.onSurface,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                dividerColor: Colors.transparent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Search bar and settings
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: AppSearchInput(
                  controller: _searchController,
                  hintText: 'Search',
                  lightStyle: true,
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Text(
                    '⚙️',
                    style: TextStyle(fontSize: 22, fontFamily: 'Roboto'),
                  ),
                  onPressed: () {
                    // Show filter modal
                    _showFilterModal();
                  },
                ),
              ),
            ],
          ),
        ),
        // Sports Chips (for filtering)
        _buildSportsChips(),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Main TabBarView
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: TabBarView(
            controller: _mainTabController,
            children: [
              // Games Tab: Filtered by selected sport
              MatchListScreen(
                sport: _sports[_selectedSportIndex]['name'],
                sportColor: _sports[_selectedSportIndex]['color'],
                searchQuery: _searchQuery,
              ),
              // Venues Tab: Filtered by selected sport
              _buildVenuesTab(
                _sports[_selectedSportIndex]['name'],
                _searchQuery,
                secondarySports: _selectedSecondarySports,
                filterArea: _selectedArea,
                priceRange: _selectedPriceRange,
                rating: _selectedRating,
                amenities: _selectedAmenities,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSportsChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
      child: Row(
        children: List.generate(_sports.length, (index) {
          final sport = _sports[index];
          final isSelected = _selectedSportIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppFilterChip(
              emoji: sport['emoji'] ?? '⚽️',
              label: sport['name'],
              isSelected: isSelected,
              count: isSelected ? sport['count'] : null,
              selectedColor: AppColors.secondarySportsBtn,
              selectedBorderColor: Colors.transparent,
              selectedTextColor: AppColors.secondarySportsBtn,
              onTap: () {
                setState(() {
                  _selectedSportIndex = index;
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVenuesTab(
    String selectedSport,
    String searchQuery, {
    Set<String>? secondarySports,
    String? filterArea,
    RangeValues? priceRange,
    double? rating,
    Set<String>? amenities,
  }) {
    return _VenuesTabContent(
      selectedSport: selectedSport,
      searchQuery: searchQuery,
      secondarySports: secondarySports,
      filterArea: filterArea,
      priceRange: priceRange,
      rating: rating,
      amenities: amenities,
    );
  }
}

class _VenuesTabContent extends ConsumerStatefulWidget {
  final String selectedSport;
  final String searchQuery;
  final Set<String>? secondarySports;
  final String? filterArea;
  final RangeValues? priceRange;
  final double? rating;
  final Set<String>? amenities;

  const _VenuesTabContent({
    required this.selectedSport,
    required this.searchQuery,
    this.secondarySports,
    this.filterArea,
    this.priceRange,
    this.rating,
    this.amenities,
  });

  @override
  ConsumerState<_VenuesTabContent> createState() => _VenuesTabContentState();
}

class _VenuesTabContentState extends ConsumerState<_VenuesTabContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load venues with sport filter on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilter();
    });
  }

  @override
  void didUpdateWidget(_VenuesTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSport != widget.selectedSport) {
      // Delay provider update to avoid modifying during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyFilter();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll can be implemented if needed
  }

  void _applyFilter() {
    // Update venues controller with sport filter
    final filters = vc.VenueFilters(
      sports: [widget.selectedSport],
      minRating: widget.rating != null && widget.rating! > 0
          ? widget.rating
          : null,
      minPricePerHour: widget.priceRange != null && widget.priceRange!.start > 0
          ? widget.priceRange!.start
          : null,
      maxPricePerHour: widget.priceRange != null && widget.priceRange!.end < 500
          ? widget.priceRange!.end
          : null,
    );

    ref.read(venuesControllerProvider.notifier).updateFilters(filters);
  }

  Future<void> _refreshVenues() async {
    await ref.read(venuesControllerProvider.notifier).refresh();
  }

  void _onVenueTap(String venueId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenueDetailScreen(venueId: venueId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venuesState = ref.watch(venuesControllerProvider);
    final venues = venuesState.venues;

    // Apply search query filter
    final query = widget.searchQuery.toLowerCase();
    final filteredVenues = query.isEmpty
        ? venues
        : venues.where((venueWithDistance) {
            final name = venueWithDistance.venue.name.toLowerCase();
            final city = venueWithDistance.venue.city.toLowerCase();
            return name.contains(query) || city.contains(query);
          }).toList();

    // Show error state
    if (venuesState.error != null &&
        filteredVenues.isEmpty &&
        !venuesState.isLoading) {
      return _buildErrorState();
    }

    // Show empty state
    if (filteredVenues.isEmpty && !venuesState.isLoading) {
      return _buildEmptyState();
    }

    // Show venues list
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(
              bottom: BorderSide(
                color: context.colors.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.mapPin,
                size: 16,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Near Dubai, UAE',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshVenues,
            child: venuesState.isLoading && filteredVenues.isEmpty
                ? _buildLoadingState()
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: filteredVenues.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final venueWithDistance = filteredVenues[index];
                      final venue = venueWithDistance.venue;

                      // Convert Venue entity to Map for VenueCard
                      final venueMap = {
                        'id': venue.id,
                        'name': venue.name,
                        'location': '${venue.city}, ${venue.country}',
                        'sports': venue.supportedSports,
                        'images': [],
                        'rating': venue.rating,
                        'isOpen': true,
                        'slots': [],
                        'reviews': List.generate(venue.totalRatings, (_) => {}),
                        'distance': venueWithDistance.formattedDistance,
                        'price': venue.pricePerHour.toString(),
                        'amenities': venue.amenities,
                      };

                      return VenueCard(
                        venue: venueMap,
                        onTap: () => _onVenueTap(venue.id),
                        isLoading: false,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          VenueCard(venue: const {}, isLoading: true),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DS.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(LucideIcons.wifiOff, size: 48, color: DS.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Couldn\'t load venues',
              style: DS.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: DS.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: DS.body.copyWith(color: DS.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshVenues,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Retry'),
              style: DS.primaryButton,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DS.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(LucideIcons.mapPin, size: 48, color: DS.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No ${widget.selectedSport} venues found',
              style: DS.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: DS.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try broadening your filters or check back later',
              style: DS.body.copyWith(color: DS.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshVenues,
              icon: const Icon(LucideIcons.filter),
              label: const Text('Adjust Filters'),
              style: DS.primaryButton,
            ),
          ],
        ),
      ),
    );
  }
}
