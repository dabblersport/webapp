import 'package:flutter/material.dart';

class SportsSkillIndicator extends StatelessWidget {
  final String sportName;
  final int skillLevel; // 1-5 scale
  final String skillLabel;
  final Color? primaryColor;
  final bool showLabel;
  final bool isInteractive;
  final ValueChanged<int>? onSkillChanged;

  const SportsSkillIndicator({
    super.key,
    required this.sportName,
    required this.skillLevel,
    required this.skillLabel,
    this.primaryColor,
    this.showLabel = true,
    this.isInteractive = false,
    this.onSkillChanged,
  }) : assert(skillLevel >= 1 && skillLevel <= 5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = primaryColor ?? theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getSportIcon(sportName), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sportName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showLabel)
                      Text(
                        skillLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Skill level indicator
          if (isInteractive)
            _buildInteractiveSkillLevel(context, color)
          else
            _buildStaticSkillLevel(context, color),
        ],
      ),
    );
  }

  Widget _buildStaticSkillLevel(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skill Level',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final isActive = index < skillLevel;
            return Padding(
              padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? color : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Beginner',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
            ),
            Text(
              'Expert',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveSkillLevel(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skill Level',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final isActive = index < skillLevel;
            return Padding(
              padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onSkillChanged?.call(index + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Beginner',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
            ),
            Text(
              'Expert',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'baseball':
        return Icons.sports_baseball;
      case 'golf':
        return Icons.sports_golf;
      case 'running':
      case 'track':
        return Icons.directions_run;
      case 'swimming':
        return Icons.pool;
      case 'cycling':
        return Icons.directions_bike;
      case 'martial arts':
      case 'karate':
        return Icons.sports_martial_arts;
      case 'hockey':
        return Icons.sports_hockey;
      case 'cricket':
        return Icons.sports_cricket;
      case 'rugby':
        return Icons.sports_rugby;
      case 'badminton':
        return Icons.sports_tennis; // Using tennis as closest match
      case 'table tennis':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  static String getSkillLevelLabel(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Novice';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      case 5:
        return 'Expert';
      default:
        return 'Unknown';
    }
  }
}

// Grid layout for multiple sports
class SportsSkillGrid extends StatelessWidget {
  final List<SportSkill> skills;
  final bool isEditable;
  final Function(String sport, int level)? onSkillChanged;

  const SportsSkillGrid({
    super.key,
    required this.skills,
    this.isEditable = false,
    this.onSkillChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        return SportsSkillIndicator(
          sportName: skill.sportName,
          skillLevel: skill.level,
          skillLabel: SportsSkillIndicator.getSkillLevelLabel(skill.level),
          isInteractive: isEditable,
          onSkillChanged: (level) =>
              onSkillChanged?.call(skill.sportName, level),
        );
      },
    );
  }
}

class SportSkill {
  final String sportName;
  final int level;
  final Color? color;

  const SportSkill({required this.sportName, required this.level, this.color});
}
