import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/invitation_list.dart';

class PlayerInvitationStep extends StatefulWidget {
  final GameCreationViewModel viewModel;

  const PlayerInvitationStep({super.key, required this.viewModel});

  @override
  State<PlayerInvitationStep> createState() => _PlayerInvitationStepState();
}

class _PlayerInvitationStepState extends State<PlayerInvitationStep>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();

  bool _isLoadingContacts = false;
  List<InvitePlayer> _selectedPlayers = [];
  List<InvitePlayer> _contacts = [];
  List<InvitePlayer> _recentTeammates = [];
  List<InvitePlayer> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _messageController.text =
        widget.viewModel.state.invitationMessage ?? _getSimpleDefaultMessage();
    _loadMockData();
    _restoreSelectedPlayers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    _contacts = [
      InvitePlayer(
        id: 'c1',
        name: 'John Smith',
        email: 'john@example.com',
        phone: '+1234567890',
        source: PlayerSource.contact,
      ),
      InvitePlayer(
        id: 'c2',
        name: 'Sarah Johnson',
        email: 'sarah@example.com',
        phone: '+1234567891',
        source: PlayerSource.contact,
      ),
      InvitePlayer(
        id: 'c3',
        name: 'Mike Davis',
        email: 'mike@example.com',
        phone: '+1234567892',
        source: PlayerSource.contact,
      ),
      InvitePlayer(
        id: 'c4',
        name: 'Emily Brown',
        email: 'emily@example.com',
        phone: '+1234567893',
        source: PlayerSource.contact,
      ),
      InvitePlayer(
        id: 'c5',
        name: 'David Wilson',
        email: 'david@example.com',
        phone: '+1234567894',
        source: PlayerSource.contact,
      ),
    ];

    _recentTeammates = [
      InvitePlayer(
        id: 't1',
        name: 'Alex Rodriguez',
        email: 'alex@example.com',
        source: PlayerSource.teammate,
        lastPlayedDate: '2 days ago',
      ),
      InvitePlayer(
        id: 't2',
        name: 'Lisa Chen',
        email: 'lisa@example.com',
        source: PlayerSource.teammate,
        lastPlayedDate: '1 week ago',
      ),
      InvitePlayer(
        id: 't3',
        name: 'Ryan Murphy',
        email: 'ryan@example.com',
        source: PlayerSource.teammate,
        lastPlayedDate: '2 weeks ago',
      ),
      InvitePlayer(
        id: 't4',
        name: 'Jessica Taylor',
        email: 'jessica@example.com',
        source: PlayerSource.teammate,
        lastPlayedDate: '3 weeks ago',
      ),
    ];
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoadingContacts = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final results =
        [
              InvitePlayer(
                id: 's1',
                name: 'Tom Anderson',
                email: 'tom@example.com',
                source: PlayerSource.search,
              ),
              InvitePlayer(
                id: 's2',
                name: 'Maria Garcia',
                email: 'maria@example.com',
                source: PlayerSource.search,
              ),
              InvitePlayer(
                id: 's3',
                name: 'James Wilson',
                email: 'james@example.com',
                source: PlayerSource.search,
              ),
            ]
            .where(
              (player) =>
                  player.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoadingContacts = false;
      });
    }
  }

  void _togglePlayerSelection(InvitePlayer player) {
    setState(() {
      final index = _selectedPlayers.indexWhere((p) => p.id == player.id);
      if (index >= 0) {
        _selectedPlayers.removeAt(index);
      } else {
        _selectedPlayers.add(player);
      }
    });

    final playerIds = _selectedPlayers.map((p) => p.id).toList();
    widget.viewModel.updateSelectedPlayers(playerIds);
  }

  String _getSimpleDefaultMessage() {
    final sport = widget.viewModel.state.selectedSport ?? 'game';
    return 'Hey! I\'m organizing a $sport match. Would you like to join us? It\'s going to be fun!';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Game settings',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure who can join your game',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Participation Mode
          _buildParticipationMode(context),
          const SizedBox(height: 24),

          // Invite Players Button (only show if Private or Hybrid)
          if (widget.viewModel.state.participationMode ==
                  ParticipationMode.private ||
              widget.viewModel.state.participationMode ==
                  ParticipationMode.hybrid) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite Players'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.colors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                        left: 16,
                        right: 16,
                        top: 24,
                      ),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.75,
                        child: InvitationList(
                          contacts: _contacts,
                          recentTeammates: _recentTeammates,
                          searchResults: _searchResults,
                          selectedPlayers: _selectedPlayers,
                          isLoadingContacts: _isLoadingContacts,
                          onPlayerToggle: _togglePlayerSelection,
                          onSearch: _performSearch,
                          onClearAll: () {
                            setState(() {
                              _selectedPlayers.clear();
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Selected Players (show as chips)
          if (_selectedPlayers.isNotEmpty) ...[
            Text(
              'Selected Players',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPlayers
                  .map(
                    (player) => Chip(
                      label: Text(
                        player.displayName.split(' ').first,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      avatar: _buildPlayerAvatar(context, player, size: 20),
                      onDeleted: () => _togglePlayerSelection(player),
                    ),
                  )
                  .toList(),
            ),
          ],

          // Invitation Message
          const SizedBox(height: 32),
          _buildInvitationMessage(context),
        ],
      ),
    );
  }

  Widget _buildParticipationMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who can join?',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...ParticipationMode.values.map((mode) {
          final isSelected = widget.viewModel.state.participationMode == mode;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParticipationOption(
              context,
              mode: mode,
              isSelected: isSelected,
              onTap: () => widget.viewModel.selectParticipationMode(mode),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildParticipationOption(
    BuildContext context, {
    required ParticipationMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final modeData = _getParticipationModeData(mode);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withOpacity(0.1)
              : context.violetWidgetBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outline.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withOpacity(0.1)
                    : context.colors.outline.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                modeData['icon'] as IconData,
                size: 20,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeData['title'] as String,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modeData['description'] as String,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.check, size: 20, color: context.colors.primary),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getParticipationModeData(ParticipationMode mode) {
    switch (mode) {
      case ParticipationMode.public:
        return {
          'title': 'Public',
          'description': 'Anyone can join your game',
          'icon': LucideIcons.globe,
        };
      case ParticipationMode.private:
        return {
          'title': 'Private',
          'description': 'Only invited players can join',
          'icon': LucideIcons.lock,
        };
      case ParticipationMode.hybrid:
        return {
          'title': 'Hybrid',
          'description': 'Mix of invited players and open spots',
          'icon': LucideIcons.userPlus,
        };
    }
  }

  void _restoreSelectedPlayers() {
    final savedPlayerIds = widget.viewModel.state.selectedPlayers ?? [];
    if (savedPlayerIds.isNotEmpty) {
      final allPlayers = [..._contacts, ..._recentTeammates, ..._searchResults];
      _selectedPlayers = allPlayers
          .where((player) => savedPlayerIds.contains(player.id))
          .toList();
    }
  }

  Widget _buildPlayerAvatar(
    BuildContext context,
    InvitePlayer player, {
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.primary.withOpacity(0.1),
        border: Border.all(
          color: context.colors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: player.avatar != null && player.avatar!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                player.avatar!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(context, player, size),
              ),
            )
          : _buildAvatarFallback(context, player, size),
    );
  }

  Widget _buildAvatarFallback(
    BuildContext context,
    InvitePlayer player,
    double size,
  ) {
    final initials = player.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join('')
        .toUpperCase();
    return Center(
      child: Text(
        initials,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.primary,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildInvitationMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Invitation message',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customize the message sent to invited players',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Enter your invitation message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: context.colors.outline.withOpacity(0.1),
              ),
            ),
            filled: true,
            fillColor: context.violetWidgetBg,
          ),
          maxLines: 3,
          onChanged: (value) => widget.viewModel.updateInvitationMessage(value),
        ),
      ],
    );
  }
}
