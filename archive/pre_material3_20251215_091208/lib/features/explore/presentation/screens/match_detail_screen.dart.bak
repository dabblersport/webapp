import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/data/models/core/match_model.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/app_button.dart';
import 'package:dabbler/widgets/avatar_widget.dart';

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _isJoining = false;
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    // Check if user is already joined
    _isJoined = widget.match.participants.any((p) => p.id == 'current_user_id');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          _buildSliverAppBar(),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match Info Header
                  _buildMatchInfoHeader(),
                  const SizedBox(height: 24),

                  // Venue & Time Info
                  _buildVenueTimeInfo(),
                  const SizedBox(height: 24),

                  // Price & Payment Info
                  _buildPriceInfo(),
                  const SizedBox(height: 24),

                  // Roster Section
                  _buildRosterSection(),
                  const SizedBox(height: 24),

                  // Game Details
                  _buildGameDetails(),
                  const SizedBox(height: 24),

                  // Organizer Info
                  _buildOrganizerInfo(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: context.colors.surface,
      leading: IconButton(
        icon: Icon(LucideIcons.arrowLeft, color: context.colors.onSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.share2, color: context.colors.onSurface),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(
            _isJoined ? LucideIcons.heart : LucideIcons.heart,
            color: _isJoined ? Colors.red : context.colors.onSurface,
          ),
          onPressed: () {
            setState(() {
              _isJoined = !_isJoined;
            });
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero Image
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.primary.withValues(alpha: 0.8),
                    context.colors.primary.withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: widget.match.venue.imageUrl != null
                  ? Image.network(
                      widget.match.venue.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        LucideIcons.mapPin,
                        size: 64,
                        color: context.colors.primary,
                      ),
                    ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),

            // Match status badge
            Positioned(
              top: 80,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.match.title,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                widget.match.format.name,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.match.description ?? 'Join us for an exciting game!',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildVenueTimeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.violetWidgetBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.match.venue.name,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      widget.match.venue.location,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.navigation,
                  color: context.colors.primary,
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(widget.match.startTime),
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      '${widget.match.duration.inMinutes} minutes',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTimeUntilMatch(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo() {
    final isFree = widget.match.price == 0;
    final spotsLeft =
        widget.match.maxParticipants - widget.match.participants.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFree ? 'Free' : '${widget.match.price} EGP',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isFree ? Colors.green : context.colors.primary,
                  ),
                ),
                Text(
                  isFree ? 'No cost to join' : 'Per player',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: spotsLeft > 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: spotsLeft > 0
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              spotsLeft > 0 ? '$spotsLeft spots left' : 'Full',
              style: context.textTheme.bodySmall?.copyWith(
                color: spotsLeft > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterSection() {
    final participants = widget.match.participants;
    final maxParticipants = widget.match.maxParticipants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Roster',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${participants.length}/$maxParticipants',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Participants Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: maxParticipants,
          itemBuilder: (context, index) {
            if (index < participants.length) {
              // Filled spot
              final participant = participants[index];
              return _buildParticipantTile(participant, true);
            } else {
              // Empty spot
              return _buildEmptySpotTile();
            }
          },
        ),

        // Waitlist (if any)
        if (widget.match.waitlist.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Waitlist (${widget.match.waitlist.length})',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.match.waitlist.length,
              itemBuilder: (context, index) {
                final participant = widget.match.waitlist[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildParticipantTile(participant, false),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipantTile(Participant participant, bool isConfirmed) {
    return Container(
      decoration: BoxDecoration(
        color: isConfirmed
            ? context.colors.surface
            : context.colors.outline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed
              ? context.colors.outline.withValues(alpha: 0.1)
              : context.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget(
            imageUrl: participant.avatar,
            name: participant.name,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            participant.name.split(' ').first,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isConfirmed)
            Text(
              'Waitlist',
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySpotTile() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.outline.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.userPlus,
            size: 24,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Open',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.violetWidgetBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Details',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          _buildDetailRow(
            icon: LucideIcons.users,
            label: 'Format',
            value: widget.match.format.name,
          ),
          const SizedBox(height: 8),

          _buildDetailRow(
            icon: LucideIcons.target,
            label: 'Skill Level',
            value: widget.match.skillLevel,
          ),
          const SizedBox(height: 8),

          _buildDetailRow(
            icon: LucideIcons.clock,
            label: 'Duration',
            value: '${widget.match.duration.inMinutes} minutes',
          ),

          if (widget.match.amenities.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: LucideIcons.star,
              label: 'Amenities',
              value: widget.match.amenities.join(', '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizerInfo() {
    final organizer = widget.match.organizer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AvatarWidget(
            imageUrl: organizer.avatar,
            name: organizer.name,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizer.name,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),
                Text(
                  'Organizer',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.messageCircle,
              color: context.colors.primary,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final spotsLeft =
        widget.match.maxParticipants - widget.match.participants.length;
    final isFull = spotsLeft <= 0;
    final isPastDeadline = DateTime.now().isAfter(widget.match.startTime);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isFull && !isPastDeadline) ...[
            Expanded(
              child: AppButton(
                label: _isJoined ? 'Leave Game' : 'Join Game',
                onPressed: _isJoining ? null : _handleJoinLeave,
                variant: _isJoined
                    ? ButtonVariant.secondary
                    : ButtonVariant.primary,
                leadingIcon: _isJoined
                    ? LucideIcons.userMinus
                    : LucideIcons.userPlus,
                isLoading: _isJoining,
              ),
            ),
          ] else ...[
            Expanded(
              child: AppButton(
                label: isFull ? 'Game Full' : 'Game Ended',
                onPressed: null,
                variant: ButtonVariant.secondary,
                leadingIcon: isFull ? LucideIcons.users : LucideIcons.clock,
              ),
            ),
          ],
          const SizedBox(width: 12),
          AppButton(
            label: 'Share',
            onPressed: () {},
            variant: ButtonVariant.secondary,
            leadingIcon: LucideIcons.share2,
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoinLeave() async {
    setState(() {
      _isJoining = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isJoined = !_isJoined;
        _isJoining = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isJoined ? 'Successfully joined the game!' : 'Left the game',
            ),
            backgroundColor: _isJoined ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isJoined ? 'join' : 'leave'} game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor() {
    final now = DateTime.now();
    final timeUntilMatch = widget.match.startTime.difference(now);

    if (timeUntilMatch.isNegative) {
      return Colors.grey;
    } else if (timeUntilMatch.inHours < 1) {
      return Colors.red;
    } else if (timeUntilMatch.inHours < 24) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStatusText() {
    final now = DateTime.now();
    final timeUntilMatch = widget.match.startTime.difference(now);

    if (timeUntilMatch.isNegative) {
      return 'Ended';
    } else if (timeUntilMatch.inHours < 1) {
      return 'Starting Soon';
    } else if (timeUntilMatch.inHours < 24) {
      return 'Today';
    } else {
      return 'Upcoming';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateText;
    if (matchDate == today) {
      dateText = 'Today';
    } else if (matchDate == tomorrow) {
      dateText = 'Tomorrow';
    } else {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dateText = days[dateTime.weekday - 1];
    }

    final timeText =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateText at $timeText';
  }

  String _getTimeUntilMatch() {
    final now = DateTime.now();
    final timeUntilMatch = widget.match.startTime.difference(now);

    if (timeUntilMatch.isNegative) {
      return 'Ended';
    }

    final days = timeUntilMatch.inDays;
    final hours = timeUntilMatch.inHours % 24;
    final minutes = timeUntilMatch.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Now';
    }
  }
}
