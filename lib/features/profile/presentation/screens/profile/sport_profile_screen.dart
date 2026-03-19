import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/design_system/widgets/ds_avatar.dart';
import 'package:dabbler/core/design_system/tokens/avatar_color_palette.dart';
import 'package:dabbler/core/design_system/tokens/avatar_tokens.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';

class SportProfileScreen extends ConsumerWidget {
  const SportProfileScreen({super.key, required this.args});

  final SportProfileRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final view = ref.watch(sportProfileViewProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(args.sportName)),
      body: view.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(args: args, data: data),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Scoreboard',
              child: data.metrics.isEmpty
                  ? _EmptySection(
                      icon: Icons.leaderboard_outlined,
                      message: 'No scoreboard data yet.',
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.metrics.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.5,
                          ),
                      itemBuilder: (context, index) {
                        final metric = data.metrics[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(metric.icon, color: colorScheme.primary),
                              Text(
                                metric.value,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                metric.label,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Per-sport preferences (own profile only)
            if (Supabase.instance.client.auth.currentUser?.id == args.userId)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _SportPreferencesSection(args: args, data: data),
              ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Achievements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.badges.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.badges
                          .map(
                            (badge) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge.name.isEmpty ? badge.key : badge.name,
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (data.badges.isNotEmpty && data.recentEvents.isNotEmpty)
                    const SizedBox(height: 16),
                  if (data.recentEvents.isNotEmpty)
                    ...data.recentEvents.map(
                      (event) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.workspace_premium_outlined,
                          color: colorScheme.primary,
                        ),
                        title: Text(
                          _formatEventType(event.eventType),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _formatEventData(event.eventData),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  if (data.badges.isEmpty && data.recentEvents.isEmpty)
                    const _EmptySection(
                      icon: Icons.emoji_events_outlined,
                      message: 'No sport achievements yet.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Sport Activity',
              child: data.activity.isEmpty
                  ? const _EmptySection(
                      icon: Icons.article_outlined,
                      message: 'No sport-related posts yet.',
                    )
                  : Column(
                      children: data.activity.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: item.sources
                                    .map(
                                      (source) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _sourceLabel(source),
                                          style: textTheme.labelMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSecondaryContainer,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              FeedPostCard(post: item.post),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load sport profile: $error',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static String _sourceLabel(SportActivitySource source) {
    switch (source) {
      case SportActivitySource.authored:
        return 'Authored';
      case SportActivitySource.commented:
        return 'Commented';
      case SportActivitySource.reacted:
        return 'Reacted';
    }
  }

  static String _formatEventType(String type) {
    if (type.isEmpty) {
      return 'Sport milestone';
    }
    return type
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _formatEventData(Map<String, dynamic> eventData) {
    if (eventData.isEmpty) {
      return 'Recent progress in this sport.';
    }
    final entries = eventData.entries
        .take(2)
        .map((entry) => '${entry.key}: ${entry.value}');
    return entries.join(' • ');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.args, required this.data});

  final SportProfileRouteArgs args;
  final SportProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final playerProfile = data.playerProfile;
    final organiserProfile = data.organiserProfile;

    final subtitle = args.isOrganiserPersona
        ? _organiserSubtitle(organiserProfile)
        : _playerSubtitle(playerProfile);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(
                size: AvatarSize.medium,
                customDimension: 56,
                imageUrl: args.avatarUrl,
                displayName: args.displayName,
                context: AvatarContext.sports,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.displayName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                label:
                    '${args.sportEmoji != null && args.sportEmoji!.isNotEmpty ? '${args.sportEmoji!} ' : ''}${args.sportName}',
              ),
              _HeaderChip(
                label: args.isOrganiserPersona
                    ? 'Organiser persona'
                    : 'Player persona',
              ),
              if (data.playerTier != null)
                _HeaderChip(label: data.playerTier!.key.toUpperCase()),
              if (organiserProfile?.isVerified == true)
                const _HeaderChip(label: 'Verified'),
            ],
          ),
        ],
      ),
    );
  }

  static String _playerSubtitle(dynamic playerProfile) {
    if (playerProfile == null) {
      return 'Read-only sport profile';
    }
    final primaryPosition = playerProfile.primaryPosition as String;
    final level = (playerProfile.overallLevel as double).toStringAsFixed(1);
    if (primaryPosition.isNotEmpty) {
      return 'Overall level $level • $primaryPosition';
    }
    return 'Overall level $level';
  }

  static String _organiserSubtitle(dynamic organiserProfile) {
    if (organiserProfile == null) {
      return 'Read-only organiser sport profile';
    }
    final level = organiserProfile.organiserLevel as int;
    final status = organiserProfile.isActive == true ? 'Active' : 'Inactive';
    return 'Organiser level $level • $status';
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
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

/// Editable per-sport preferences: skill level and preferred position.
class _SportPreferencesSection extends ConsumerStatefulWidget {
  const _SportPreferencesSection({required this.args, required this.data});

  final SportProfileRouteArgs args;
  final SportProfileViewData data;

  @override
  ConsumerState<_SportPreferencesSection> createState() =>
      _SportPreferencesSectionState();
}

class _SportPreferencesSectionState
    extends ConsumerState<_SportPreferencesSection> {
  int _skillLevel = 1;
  String? _position;
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadFromProfile();
      _loaded = true;
    }
  }

  void _loadFromProfile() {
    final player = widget.data.playerProfile;
    if (player != null && !widget.args.isOrganiserPersona) {
      _skillLevel = _skillFromProfile(player);
      _position = _positionFromProfile(player);
    }
    final organiser = widget.data.organiserProfile;
    if (organiser != null && widget.args.isOrganiserPersona) {
      _skillLevel = organiser.organiserLevel;
    }
  }

  int _skillFromProfile(dynamic player) {
    final raw = player.skillLevel;
    if (raw is int && raw >= 1 && raw <= 3) return raw;
    return 1;
  }

  String? _positionFromProfile(dynamic player) {
    final pos = player.primaryPosition as String?;
    if (pos != null && pos.isNotEmpty) return pos;
    return null;
  }

  List<String> get _availablePositions {
    switch (widget.args.sportKey.toLowerCase()) {
      case 'football':
        return ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
      case 'basketball':
        return [
          'Point Guard',
          'Shooting Guard',
          'Small Forward',
          'Power Forward',
          'Center',
        ];
      case 'volleyball':
        return [
          'Setter',
          'Outside Hitter',
          'Middle Blocker',
          'Opposite Hitter',
          'Libero',
        ];
      default:
        return [];
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;

      if (widget.args.isOrganiserPersona) {
        await supabase
            .from('organiser')
            .update({'organiser_level': _skillLevel})
            .eq('profile_id', widget.args.profileId)
            .eq('sport', widget.args.sportKey.toLowerCase());
      } else {
        final updates = <String, dynamic>{'skill_level': _skillLevel};
        if (_position != null) {
          updates['primary_position'] = _position;
        }
        await supabase
            .from('sport_profiles')
            .update(updates)
            .eq('profile_id', widget.args.profileId)
            .eq('sport', widget.args.sportKey.toLowerCase());
      }

      // Invalidate provider so the screen refreshes.
      ref.invalidate(sportProfileViewProvider(widget.args));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const _skillLabels = {1: 'Beginner', 2: 'Intermediate', 3: 'Advanced'};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final positions = _availablePositions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Skill level chips
          Text(
            widget.args.isOrganiserPersona ? 'Organiser Level' : 'Skill Level',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillLabels.entries.map((entry) {
              final isSelected = _skillLevel == entry.key;
              return FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _skillLevel = entry.key);
                },
              );
            }).toList(),
          ),
          // Position selector (player only, sports that have positions)
          if (!widget.args.isOrganiserPersona && positions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Preferred Position',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: positions.map((pos) {
                final isSelected = _position == pos;
                return FilterChip(
                  label: Text(pos),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _position = selected ? pos : null);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
