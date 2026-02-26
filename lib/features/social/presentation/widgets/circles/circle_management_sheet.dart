import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/data/models/user_circle.dart';
import 'package:dabbler/features/social/providers/user_circles_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen-ish bottom sheet for creating or editing a [UserCircle].
///
/// Pass [circle] to edit an existing one, or null to create a new one.
class CircleManagementSheet extends ConsumerStatefulWidget {
  const CircleManagementSheet({super.key, this.circle});

  final UserCircle? circle;

  @override
  ConsumerState<CircleManagementSheet> createState() =>
      _CircleManagementSheetState();
}

class _CircleManagementSheetState extends ConsumerState<CircleManagementSheet> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;

  // For new circles: a temp list of members that will be added after creation.
  // For existing circles: managed via circleMembersProvider.
  final List<CircleMember> _pendingNewMembers = [];

  bool get _isNew => widget.circle == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.circle?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _title => _isNew ? 'New Circle' : (widget.circle?.name ?? '');

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Circle name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final notifier = ref.read(userCirclesProvider.notifier);

    if (_isNew) {
      final result = await notifier.createCircle(name);

      await result.fold(
        (failure) async => setState(() => _error = failure.message),
        (newCircle) async {
          // Add any pending members.
          if (_pendingNewMembers.isNotEmpty) {
            final membersNotifier = ref.read(
              circleMembersProvider(newCircle.id).notifier,
            );
            for (final m in _pendingNewMembers) {
              await membersNotifier.addMember(m.profileId, userId: m.userId);
            }
          }
          if (mounted) Navigator.of(context).pop();
        },
      );
    } else {
      final result = await notifier.updateCircle(widget.circle!.id, name);
      result.fold(
        (f) => setState(() => _error = f.message),
        (_) => Navigator.of(context).pop(),
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete circle?'),
        content: Text(
          'This will permanently delete '
          '"${widget.circle!.name}" and remove all its members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    await ref
        .read(userCirclesProvider.notifier)
        .deleteCircle(widget.circle!.id);
    if (mounted) {
      setState(() => _isDeleting = false);
      Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── App bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _title,
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isNew)
                  _isDeleting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          tooltip: 'Delete circle',
                          onPressed: _deleteCircle,
                        ),
                const SizedBox(width: 4),
                _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 36),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Save'),
                      ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Scrollable body ─────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ── Name field ─────────────────────────────────────────────
                _buildNameField(cs, tt),
                const SizedBox(height: 24),

                // ── Error ─────────────────────────────────────────────────
                if (_error != null) ...[
                  _ErrorBanner(message: _error!, cs: cs),
                  const SizedBox(height: 16),
                ],

                // ── Members section ────────────────────────────────────────
                _buildMembersSection(cs, tt),
                const SizedBox(height: 24),

                // ── Followers section ──────────────────────────────────────
                _buildFollowersSection(cs, tt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Name field
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNameField(ColorScheme cs, TextTheme tt) {
    return TextField(
      controller: _nameController,
      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: 'Circle name (e.g. Close Friends)',
        hintStyle: tt.bodyLarge?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() => _error = null),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Members in circle
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMembersSection(ColorScheme cs, TextTheme tt) {
    if (_isNew) {
      return _PendingMembersSection(
        pendingMembers: _pendingNewMembers,
        cs: cs,
        tt: tt,
        onRemove: (m) => setState(() => _pendingNewMembers.remove(m)),
      );
    }

    final membersAsync = ref.watch(circleMembersProvider(widget.circle!.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        membersAsync.when(
          loading: () =>
              _SectionHeader(title: 'IN CIRCLE', count: null, cs: cs, tt: tt),
          error: (_, __) =>
              _SectionHeader(title: 'IN CIRCLE', count: 0, cs: cs, tt: tt),
          data: (members) => _SectionHeader(
            title: 'IN CIRCLE',
            count: members.length,
            cs: cs,
            tt: tt,
          ),
        ),
        const SizedBox(height: 8),
        membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('Error loading members', style: TextStyle(color: cs.error)),
          data: (members) => members.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No one in this circle yet. Add followers below.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: members
                      .map(
                        (m) => _MemberTile(
                          member: m,
                          cs: cs,
                          tt: tt,
                          trailingWidget: _RemoveButton(
                            cs: cs,
                            onTap: () => ref
                                .read(
                                  circleMembersProvider(
                                    widget.circle!.id,
                                  ).notifier,
                                )
                                .removeMember(m.profileId),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Followers to add
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFollowersSection(ColorScheme cs, TextTheme tt) {
    final followersAsync = ref.watch(circleFollowersProvider);
    final currentMemberIds = _isNew
        ? _pendingNewMembers.map((m) => m.profileId).toSet()
        : ref
                  .watch(circleMembersProvider(widget.circle!.id))
                  .valueOrNull
                  ?.map((m) => m.profileId)
                  .toSet() ??
              {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'ADD FOLLOWERS',
          count: null,
          cs: cs,
          tt: tt,
          subtitle: 'Ordered by most recent',
        ),
        const SizedBox(height: 8),
        followersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Could not load followers: $e',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          data: (followers) {
            // Filter out already-added members.
            final available = followers
                .where((f) => !currentMemberIds.contains(_extractProfileId(f)))
                .toList();

            if (available.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'All your followers are already in this circle.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            }

            return Column(
              children: available
                  .map(
                    (f) => _FollowerTile(
                      follower: f,
                      cs: cs,
                      tt: tt,
                      onAdd: () => _addFollower(f),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _addFollower(Map<String, dynamic> follower) {
    final profileId = _extractProfileId(follower);
    final userId = _extractUserId(follower);

    if (_isNew) {
      final member = CircleMember(
        profileId: profileId,
        userId: userId,
        displayName: _extractDisplayName(follower),
        username: _extractUsername(follower),
        avatarUrl: _extractAvatarUrl(follower),
      );
      setState(() => _pendingNewMembers.add(member));
    } else {
      ref
          .read(circleMembersProvider(widget.circle!.id).notifier)
          .addMember(profileId, userId: userId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending members section (new circles before first save)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingMembersSection extends StatelessWidget {
  const _PendingMembersSection({
    required this.pendingMembers,
    required this.cs,
    required this.tt,
    required this.onRemove,
  });

  final List<CircleMember> pendingMembers;
  final ColorScheme cs;
  final TextTheme tt;
  final ValueChanged<CircleMember> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        title: 'IN CIRCLE',
        count: pendingMembers.length,
        cs: cs,
        tt: tt,
      ),
      const SizedBox(height: 8),
      if (pendingMembers.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Add followers from the list below.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        )
      else
        ...pendingMembers.map(
          (m) => _MemberTile(
            member: m,
            cs: cs,
            tt: tt,
            trailingWidget: _RemoveButton(cs: cs, onTap: () => onRemove(m)),
          ),
        ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared tile widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.cs,
    required this.tt,
    this.subtitle,
  });

  final String title;
  final int? count;
  final ColorScheme cs;
  final TextTheme tt;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            count != null ? '$title ($count)' : title,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
    ],
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.cs,
    required this.tt,
    required this.trailingWidget,
  });

  final CircleMember member;
  final ColorScheme cs;
  final TextTheme tt;
  final Widget trailingWidget;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        DSAvatar.small(
          imageUrl: resolveAvatarUrl(member.avatarUrl),
          displayName: member.displayName,
          context: AvatarContext.social,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.displayName ?? member.username ?? 'Unknown',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (member.username != null)
                Text(
                  '@${member.username}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        trailingWidget,
      ],
    ),
  );
}

class _FollowerTile extends StatelessWidget {
  const _FollowerTile({
    required this.follower,
    required this.cs,
    required this.tt,
    required this.onAdd,
  });

  final Map<String, dynamic> follower;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final displayName = _extractDisplayName(follower);
    final username = _extractUsername(follower);
    final avatarUrl = _extractAvatarUrl(follower);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          DSAvatar.small(
            imageUrl: resolveAvatarUrl(avatarUrl),
            displayName: displayName,
            context: AvatarContext.social,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? username ?? 'Unknown',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (username != null)
                  Text(
                    '@$username',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _AddButton(cs: cs, onTap: onAdd),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.cs, required this.onTap});
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: cs.error,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    child: const Text('Remove'),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.cs, required this.onTap});
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(60, 36),
      shape: const StadiumBorder(),
    ),
    child: const Text('+ Add'),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.cs});
  final String message;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers to extract fields from various follower map shapes
// ─────────────────────────────────────────────────────────────────────────────

String _extractProfileId(Map<String, dynamic> f) {
  // Shapes: v_circle row, profiles join, or direct profiles row.
  final profile = f['profiles'];
  if (profile is Map<String, dynamic>) {
    return (profile['id'] ?? profile['profile_id'] ?? '') as String;
  }
  return (f['friend_profile_id'] ??
          f['peer_profile_id'] ??
          f['profile_id'] ??
          f['id'] ??
          '')
      as String;
}

String? _extractUserId(Map<String, dynamic> f) {
  final profile = f['profiles'];
  if (profile is Map<String, dynamic>) {
    return profile['user_id'] as String?;
  }
  return (f['friend_user_id'] ?? f['peer_user_id'] ?? f['user_id']) as String?;
}

String? _extractDisplayName(Map<String, dynamic> f) {
  final profile = f['profiles'];
  if (profile is Map<String, dynamic>) {
    return profile['display_name'] as String?;
  }
  return f['display_name'] as String?;
}

String? _extractUsername(Map<String, dynamic> f) {
  final profile = f['profiles'];
  if (profile is Map<String, dynamic>) {
    return profile['username'] as String?;
  }
  return f['username'] as String?;
}

String? _extractAvatarUrl(Map<String, dynamic> f) {
  final profile = f['profiles'];
  if (profile is Map<String, dynamic>) {
    return profile['avatar_url'] as String?;
  }
  return f['avatar_url'] as String?;
}
