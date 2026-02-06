import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/games_providers.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import '../../controllers/game_detail_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/services/moderation_service.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  bool _shouldShowJoinButton() {
    final profileState = ref.read(profileControllerProvider);
    final profileType = profileState.profile?.profileType;

    if (profileType == 'player') {
      return FeatureFlags.enablePlayerGameJoining;
    } else if (profileType == 'organiser') {
      return FeatureFlags.enableOrganiserGameJoining;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Text(
              'Please log in to view game details',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final detailParams = GameDetailParams(
      gameId: widget.gameId,
      currentUserId: currentUserId,
    );
    final detailState = ref.watch(gameDetailStateProvider(detailParams));

    if (detailState.isLoading || !detailState.hasGame) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (detailState.error != null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${detailState.error}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final game = detailState.game!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _checkGameTakedown(game.id),
          builder: (context, takedownSnapshot) {
            if (takedownSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final isTakedown = takedownSnapshot.data ?? false;
            if (isTakedown) {
              return _buildTakedownPlaceholder(context, colorScheme, textTheme);
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeaderSection(game, colorScheme, textTheme),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeroSection(
                      game,
                      detailState,
                      colorScheme,
                      textTheme,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickInfoCards(
                          game,
                          detailState,
                          textTheme,
                          colorScheme,
                        ),
                        const SizedBox(height: 20),
                        _buildDescriptionSection(game, textTheme, colorScheme),
                        const SizedBox(height: 20),
                        _buildPlayersSection(game, textTheme, colorScheme),
                        const SizedBox(height: 20),
                        _buildVenueSection(detailState, textTheme, colorScheme),
                        const SizedBox(height: 20),
                        _buildOrganizerSection(textTheme, colorScheme),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<bool>(
        future: _checkGameTakedown(game.id),
        builder: (context, takedownSnapshot) {
          if (takedownSnapshot.data == true) {
            return const SizedBox.shrink();
          }
          return _buildBottomBar(
            game,
            detailState,
            colorScheme,
            textTheme,
            currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(
    dynamic game,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateLabel = DateFormat('EEE, MMM d').format(game.scheduledDate);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game details',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$dateLabel • ${game.startTime}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: _shareGame,
          icon: const Icon(Icons.share_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _showMoreOptions,
          icon: const Icon(Icons.more_horiz_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }

  // Hero Section - Material 3 minimal design
  Widget _buildHeroSection(
    dynamic game,
    dynamic detailState,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateFormat = DateFormat('EEEE, MMM dd');
    final formattedDate = dateFormat.format(game.scheduledDate);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sport badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              game.sport.toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Game title
          Text(
            game.title,
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Date and time
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: textColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: textTheme.bodyMedium?.copyWith(
                  color: textColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: textColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '${game.startTime} - ${game.endTime}',
                style: textTheme.bodyMedium?.copyWith(
                  color: textColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Info Cards - Material 3 style
  Widget _buildQuickInfoCards(
    dynamic game,
    dynamic detailState,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final venue = detailState.venue;

    return Column(
      children: [
        // Location Card
        AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue?.name ?? 'Venue',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue != null
                          ? '${venue.addressLine1}, ${venue.city}'
                          : 'Address not available',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showDirections,
                icon: Icon(Icons.directions, color: colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Price & Players Row
        Row(
          children: [
            // Price Card
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payments,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Price',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.pricePerPlayer > 0
                          ? '${game.currency} ${game.pricePerPlayer.toStringAsFixed(0)}'
                          : 'Free',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Players Card
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Players',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${game.currentPlayers}/${game.maxPlayers}',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Description Section
  Widget _buildDescriptionSection(
    dynamic game,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.description,
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Skill level badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      size: 16,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${game.skillLevel} level',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Players Section
  Widget _buildPlayersSection(
    dynamic game,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Players',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: _viewAllPlayers,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              ...List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: index < 2 ? 16 : 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          'P${index + 1}',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Player ${index + 1}',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${20 + index * 5} games played',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ORGANIZER',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (game.currentPlayers < game.maxPlayers)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.onTertiaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${game.maxPlayers - game.currentPlayers} ${game.maxPlayers - game.currentPlayers == 1 ? 'spot' : 'spots'} available',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Venue Section
  Widget _buildVenueSection(
    dynamic detailState,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final venue = detailState.venue;

    if (venue == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Venue',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(onPressed: _viewVenue, child: const Text('Details')),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue name and rating
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: venue.rating > 0
                                  ? Colors.amber[700]
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              venue.rating > 0 && venue.totalRatings > 0
                                  ? '${venue.rating.toStringAsFixed(1)} (${venue.totalRatings} reviews)'
                                  : venue.totalRatings > 0
                                  ? '${venue.rating.toStringAsFixed(1)} (${venue.totalRatings} reviews)'
                                  : 'No ratings yet',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      venue.fullAddress,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Operating hours
              if (venue.openingTime.isNotEmpty &&
                  venue.closingTime.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${venue.openingTime} - ${venue.closingTime}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              // Price
              if (venue.pricePerHour > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      venue.priceDisplay,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              // Sports supported
              if (venue.supportedSports.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List<Widget>.from(
                    (venue.supportedSports as List).map(
                      (sport) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sport.toString(),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Amenities
              const SizedBox(height: 16),
              Text(
                'Amenities',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (venue.amenities.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.from(
                    (venue.amenities as List)
                        .take(6)
                        .map(
                          (amenity) => _buildAmenityChip(
                            amenity.toString(),
                            _getAmenityIcon(amenity.toString()),
                            colorScheme,
                            textTheme,
                          ),
                        ),
                  ),
                )
              else
                Text(
                  'No amenities listed',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final amenityLower = amenity.toLowerCase();
    if (amenityLower.contains('parking')) {
      return Icons.local_parking;
    } else if (amenityLower.contains('restroom') ||
        amenityLower.contains('wc')) {
      return Icons.wc;
    } else if (amenityLower.contains('water')) {
      return Icons.water_drop;
    } else if (amenityLower.contains('wifi') ||
        amenityLower.contains('internet')) {
      return Icons.wifi;
    } else if (amenityLower.contains('shower')) {
      return Icons.shower;
    } else if (amenityLower.contains('locker')) {
      return Icons.lock;
    } else if (amenityLower.contains('cafe') ||
        amenityLower.contains('restaurant')) {
      return Icons.restaurant;
    } else {
      return Icons.check_circle;
    }
  }

  Widget _buildAmenityChip(
    String label,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Organizer Section
  Widget _buildOrganizerSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Organizer',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  'JD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'John Doe',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          '4.8',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• 24 reviews',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _messageOrganizer,
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Bottom Bar - Material 3 style
  Widget _buildBottomBar(
    dynamic game,
    dynamic detailState,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String currentUserId,
  ) {
    final bool isJoined =
        detailState.joinStatus == JoinGameStatus.alreadyJoined ||
        detailState.players.any((p) => p.playerId == currentUserId);
    final bool isRequested = detailState.joinStatus == JoinGameStatus.requested;
    // Check if game requires request based on joinability decision
    final bool needsRequest =
        detailState.joinabilityDecision?.canRequest == true;
    final dateFormat = DateFormat('MMM dd');
    final formattedDate = dateFormat.format(game.scheduledDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.pricePerPlayer > 0
                        ? '${game.currency} ${game.pricePerPlayer.toStringAsFixed(0)}'
                        : 'Free',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$formattedDate at ${game.startTime}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            if (_shouldShowJoinButton())
              FilledButton.icon(
                onPressed: detailState.isJoining
                    ? null
                    : (isJoined
                          ? _leaveGame
                          : isRequested
                          ? _cancelRequest
                          : _joinGame),
                style: FilledButton.styleFrom(
                  backgroundColor: isJoined
                      ? colorScheme.error
                      : isRequested
                      ? colorScheme.errorContainer
                      : colorScheme.primary,
                  foregroundColor: isJoined
                      ? colorScheme.onError
                      : isRequested
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: detailState.isJoining
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isJoined
                                ? colorScheme.onError
                                : isRequested
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        isJoined
                            ? Icons.close
                            : isRequested
                            ? Icons.cancel
                            : needsRequest
                            ? Icons.send
                            : Icons.check,
                      ),
                label: Text(
                  detailState.isJoining
                      ? (needsRequest ? 'Requesting...' : 'Joining...')
                      : isJoined
                      ? 'Leave'
                      : isRequested
                      ? 'Cancel Request'
                      : needsRequest
                      ? 'Request to Join'
                      : 'Join Game',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Action methods
  void _shareGame() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sharing game...')));
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Report Game'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Save Game'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Add to Calendar'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDirections() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening directions...')));
  }

  void _viewAllPlayers() {}

  void _viewVenue() {
    Navigator.pushNamed(context, '/venues/detail', arguments: 'venue-id');
  }

  void _messageOrganizer() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening message...')));
  }

  Future<void> _joinGame() async {
    final currentUserId = ref.read(currentUserIdProvider);

    if (currentUserId == null) return;

    final detailState = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ),
    );

    if (detailState.game == null) return;

    final game = detailState.game!;

    // Track join attempt
    AnalyticsService.trackEvent('join_attempt', {
      'gameId': game.id,
      'sport': game.sport,
      'startsAt': game.scheduledDate.toIso8601String(),
    });

    final controller = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ).notifier,
    );

    await controller.joinGame();

    // Get updated state after join
    final updatedState = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ),
    );

    if (mounted) {
      if (updatedState.error != null) {
        // Check if waitlisted based on error message or status
        final errorMsg = updatedState.error!.toLowerCase();
        if (errorMsg.contains('waitlist') || errorMsg.contains('full')) {
          AnalyticsService.trackEvent('waitlist', {
            'gameId': game.id,
            'sport': game.sport,
            'startsAt': game.scheduledDate.toIso8601String(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedState.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (updatedState.joinMessage != null) {
        // Show success message (includes waitlist info)
        final bool updatedWaitlisted =
            updatedState.joinStatus == JoinGameStatus.waitlisted;

        AnalyticsService.trackEvent(
          updatedWaitlisted ? 'waitlist' : 'join_success',
          {
            'gameId': game.id,
            'sport': game.sport,
            'startsAt': game.scheduledDate.toIso8601String(),
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedState.joinMessage!),
            backgroundColor: updatedWaitlisted
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Fallback success message
        AnalyticsService.trackEvent('join_success', {
          'gameId': game.id,
          'sport': game.sport,
          'startsAt': game.scheduledDate.toIso8601String(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the game!')),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    final currentUserId = ref.read(currentUserIdProvider);

    if (currentUserId == null) return;

    final controller = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ).notifier,
    );

    await controller.cancelJoinRequest();

    // Get updated state after cancel
    final updatedState = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ),
    );

    if (mounted) {
      if (updatedState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedState.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (updatedState.joinMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedState.joinMessage!),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _leaveGame() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game'),
        content: const Text('Are you sure you want to leave this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLeave != true) return;

    final currentUserId = ref.read(currentUserIdProvider);

    if (currentUserId == null) return;

    final detailState = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ),
    );

    if (detailState.game == null) return;

    final game = detailState.game!;

    final controller = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ).notifier,
    );

    await controller.leaveGame();

    // Get updated state
    final updatedState = ref.read(
      gameDetailControllerProvider(
        GameDetailParams(gameId: widget.gameId, currentUserId: currentUserId),
      ),
    );

    if (updatedState.error == null) {
      // Track successful leave
      AnalyticsService.trackEvent('leave_success', {
        'gameId': game.id,
        'sport': game.sport,
        'startsAt': game.scheduledDate.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You have left the game')));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(updatedState.error!)));
    }
  }

  Future<bool> _checkGameTakedown(String gameId) async {
    try {
      final moderationService = ModerationService();
      return await moderationService.isContentTakedown(ModTarget.game, gameId);
    } catch (e) {
      // If check fails, assume not takedown to avoid blocking content
      return false;
    }
  }

  Widget _buildTakedownPlaceholder(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Content Removed',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This content has been removed due to a violation of our community guidelines.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
