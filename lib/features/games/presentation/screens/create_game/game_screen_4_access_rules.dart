import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/games/domain/models/game_creation_state.dart';
import 'package:dabbler/features/games/presentation/controllers/game_creation_controller.dart';

class GameScreen4AccessRules extends ConsumerStatefulWidget {
  final GameCreationState initialState;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const GameScreen4AccessRules({
    super.key,
    required this.initialState,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<GameScreen4AccessRules> createState() =>
      _GameScreen4AccessRulesState();
}

class _GameScreen4AccessRulesState
    extends ConsumerState<GameScreen4AccessRules> {
  String _listingVisibility = 'public';
  String _joinPolicy = 'open';
  RangeValues _skillRange = const RangeValues(1, 10);
  bool _allowsWaitlist = false;

  static const _visibilityOptions = [
    ('public', 'Public', Icons.public_rounded,
        'Everyone can see this game'),
    ('followers', 'Followers only', Icons.people_rounded,
        'Only your followers can see it'),
    ('private', 'Private', Icons.lock_rounded, 'Hidden — invite only'),
    ('link', 'Link only', Icons.link_rounded, 'Shareable link required'),
  ];

  static const _joinOptions = [
    ('open', 'Open', Icons.lock_open_rounded, 'Anyone can join instantly'),
    ('request', 'Request', Icons.pending_rounded,
        'You approve each player'),
    ('invite', 'Invite only', Icons.mail_rounded, 'By invitation only'),
    ('link', 'Link', Icons.link_rounded, 'Requires the game link'),
  ];

  @override
  void initState() {
    super.initState();
    final state =
        ref.read(gameCreationControllerProvider(widget.initialState));
    _listingVisibility = state.listingVisibility ?? 'public';
    _joinPolicy = state.joinPolicy ?? 'open';
    _skillRange = RangeValues(
      (state.minSkill ?? 1).toDouble(),
      (state.maxSkill ?? 10).toDouble(),
    );
    _allowsWaitlist = state.allowsWaitlist;
  }

  void _onContinue() {
    ref
        .read(gameCreationControllerProvider(widget.initialState).notifier)
        .updateScreen4(
          listingVisibility: _listingVisibility,
          joinPolicy: _joinPolicy,
          minSkill: _skillRange.start.round(),
          maxSkill: _skillRange.end.round(),
          allowsWaitlist: _allowsWaitlist,
        );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visibility & Joining',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Control who can find and join your game.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // Listing visibility
          Text(
            'Listing visibility',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: _visibilityOptions.map((opt) {
              final selected = _listingVisibility == opt.$1;
              return _SelectionCard(
                icon: opt.$3,
                label: opt.$2,
                description: opt.$4,
                selected: selected,
                onTap: () =>
                    setState(() => _listingVisibility = opt.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Join policy
          Text(
            'Join policy',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: _joinOptions.map((opt) {
              final selected = _joinPolicy == opt.$1;
              return _SelectionCard(
                icon: opt.$3,
                label: opt.$2,
                description: opt.$4,
                selected: selected,
                onTap: () => setState(() => _joinPolicy = opt.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Skill range
          Text(
            'Skill level range (optional)',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Min: ${_skillRange.start.round()} — Max: ${_skillRange.end.round()}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          RangeSlider(
            values: _skillRange,
            min: 1,
            max: 10,
            divisions: 9,
            labels: RangeLabels(
              _skillRange.start.round().toString(),
              _skillRange.end.round().toString(),
            ),
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.primary.withValues(alpha: 0.2),
            onChanged: (v) => setState(() => _skillRange = v),
          ),
          const SizedBox(height: 20),

          // Waitlist toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable waitlist when full',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Players can queue when capacity is reached',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _allowsWaitlist,
                onChanged: (v) => setState(() => _allowsWaitlist = v),
                activeThumbColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: colorScheme.outline),
                    foregroundColor: colorScheme.onSurface,
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: textTheme.bodySmall?.copyWith(
                color: selected
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
