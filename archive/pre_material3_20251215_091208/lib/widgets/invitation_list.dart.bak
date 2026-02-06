import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/themes/app_theme.dart';

// Player model for invitations
class InvitePlayer {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final PlayerSource source;
  final String? lastPlayedDate;

  InvitePlayer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    required this.source,
    this.lastPlayedDate,
  });

  // Getter for display name (uses name field for compatibility)
  String get displayName => name;
}

enum PlayerSource { contact, teammate, search }

// --- Ant Design Button Helper ---
enum AntdButtonType { primary, defaultType, ghost }

enum AntdButtonSize { small, medium, large }

class AntdButton extends StatelessWidget {
  final AntdButtonType type;
  final AntdButtonSize size;
  final VoidCallback? onPressed;
  final Widget child;
  final bool fullWidth;

  const AntdButton({
    super.key,
    required this.type,
    required this.onPressed,
    required this.child,
    this.size = AntdButtonSize.medium,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = () {
      switch (size) {
        case AntdButtonSize.small:
          return const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
        case AntdButtonSize.large:
          return const EdgeInsets.symmetric(vertical: 18, horizontal: 32);
        case AntdButtonSize.medium:
          return const EdgeInsets.symmetric(vertical: 12, horizontal: 24);
      }
    }();
    final minWidth = fullWidth ? double.infinity : null;
    switch (type) {
      case AntdButtonType.primary:
        return SizedBox(
          width: minWidth,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onPressed,
            child: child,
          ),
        );
      case AntdButtonType.defaultType:
        return SizedBox(
          width: minWidth,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onPressed,
            child: child,
          ),
        );
      case AntdButtonType.ghost:
        return SizedBox(
          width: minWidth,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onPressed,
            child: child,
          ),
        );
    }
  }
}

class InvitationList extends StatefulWidget {
  final List<InvitePlayer> contacts;
  final List<InvitePlayer> recentTeammates;
  final List<InvitePlayer> searchResults;
  final List<InvitePlayer> selectedPlayers;
  final bool isLoadingContacts;
  final Function(InvitePlayer) onPlayerToggle;
  final Function(String) onSearch;
  final VoidCallback? onClearAll;

  const InvitationList({
    super.key,
    required this.contacts,
    required this.recentTeammates,
    required this.searchResults,
    required this.selectedPlayers,
    required this.isLoadingContacts,
    required this.onPlayerToggle,
    required this.onSearch,
    this.onClearAll,
  });

  @override
  State<InvitationList> createState() => _InvitationListState();
}

class _InvitationListState extends State<InvitationList>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildAntdTabBar(context),
              Divider(
                height: 1,
                color: context.colors.outline.withValues(alpha: 0.08),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Main Tab Content
        SizedBox(
          height: 400, // Fixed height for demo, can be made dynamic
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContactsTab(context),
              _buildTeammatesTab(context),
              _buildSearchTab(context),
            ],
          ),
        ),

        // Selected Players
        if (widget.selectedPlayers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Selected Players',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedPlayers
                .map((player) => _buildAntdPlayerTag(context, player))
                .toList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AntdButton(
              type: AntdButtonType.ghost,
              size: AntdButtonSize.small,
              onPressed: widget.onClearAll,
              child: const Text('Clear All'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAntdTabBar(BuildContext context) {
    return TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      labelColor: context.colors.onPrimary,
      unselectedLabelColor: context.colors.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'Contacts'),
        Tab(text: 'Teammates'),
        Tab(text: 'Search'),
      ],
    );
  }

  Widget _buildAntdPlayerTag(BuildContext context, InvitePlayer player) {
    return Chip(
      label: Text(
        player.displayName.split(' ').first,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      avatar: _buildPlayerAvatar(context, player, size: 20),
      onDeleted: () => widget.onPlayerToggle(player),
      backgroundColor: context.colors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      labelStyle: context.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.colors.primary,
      ),
      deleteIcon: Icon(LucideIcons.x, size: 16, color: context.colors.primary),
    );
  }

  Widget _buildContactsTab(BuildContext context) {
    final filteredContacts = widget.contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(
                LucideIcons.search,
                color: context.colors.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.1),
                ),
              ),
              filled: true,
              fillColor: context.violetWidgetBg,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredContacts.isEmpty
              ? _buildAntdEmptyState(
                  context,
                  'No contacts found',
                  LucideIcons.phone,
                )
              : ListView.separated(
                  itemCount: filteredContacts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.colors.outline.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    return _buildAntdPlayerTile(context, contact);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeammatesTab(BuildContext context) {
    final filteredTeammates = widget.recentTeammates
        .where(
          (teammate) =>
              teammate.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search recent teammates...',
              prefixIcon: Icon(
                LucideIcons.search,
                color: context.colors.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.1),
                ),
              ),
              filled: true,
              fillColor: context.violetWidgetBg,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredTeammates.isEmpty
              ? _buildAntdEmptyState(
                  context,
                  'No recent teammates found',
                  LucideIcons.users,
                )
              : ListView.separated(
                  itemCount: filteredTeammates.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.colors.outline.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final teammate = filteredTeammates[index];
                    return _buildAntdPlayerTile(context, teammate);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search players by name or email...',
              prefixIcon: Icon(
                LucideIcons.search,
                color: context.colors.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.1),
                ),
              ),
              filled: true,
              fillColor: context.violetWidgetBg,
            ),
            onChanged: widget.onSearch,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.isLoadingContacts
              ? const Center(child: CircularProgressIndicator())
              : _searchController.text.isEmpty
              ? _buildAntdEmptyState(
                  context,
                  'Enter a name or email to search',
                  LucideIcons.search,
                )
              : widget.searchResults.isEmpty
              ? _buildAntdEmptyState(
                  context,
                  'No players found',
                  LucideIcons.userPlus,
                )
              : ListView.separated(
                  itemCount: widget.searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.colors.outline.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final player = widget.searchResults[index];
                    return _buildAntdPlayerTile(context, player);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAntdPlayerTile(BuildContext context, InvitePlayer player) {
    final isSelected = widget.selectedPlayers.any((p) => p.id == player.id);
    return ListTile(
      leading: _buildPlayerAvatar(context, player, size: 36),
      title: Text(
        player.displayName,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: player.email != null
          ? Text(player.email!, style: context.textTheme.bodySmall)
          : null,
      trailing: AntdButton(
        type: isSelected ? AntdButtonType.primary : AntdButtonType.defaultType,
        size: AntdButtonSize.small,
        onPressed: () => widget.onPlayerToggle(player),
        child: isSelected
            ? const Icon(LucideIcons.check, size: 16)
            : const Icon(LucideIcons.userPlus, size: 16),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? context.colors.primary : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      tileColor: isSelected
          ? context.colors.primary.withValues(alpha: 0.06)
          : context.colors.surface,
      onTap: () => widget.onPlayerToggle(player),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  Widget _buildAntdEmptyState(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 40, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
        color: context.colors.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.2),
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
}
