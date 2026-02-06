import 'package:flutter/material.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/profile_statistics.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.profile,
    required this.statistics,
    required this.sportsProfiles,
  });

  final UserProfile? profile;
  final ProfileStatistics statistics;
  final List<SportProfile> sportsProfiles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(profile: profile),
              const SizedBox(width: 20),
              Expanded(
                child: _HeroDetails(
                  profile: profile,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _HeroStats(
            statistics: statistics,
            sportsCount: sportsProfiles.length,
          ),
          const SizedBox(height: 16),
          if (profile != null) _HeroDataPoints(statistics: statistics),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
          ? Image.network(profile!.avatarUrl!, fit: BoxFit.cover)
          : Container(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              child: Icon(
                Icons.person_outline,
                size: 42,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
    );
  }
}

class _HeroDetails extends StatelessWidget {
  const _HeroDetails({
    required this.profile,
    required this.textTheme,
    required this.colorScheme,
  });

  final UserProfile? profile;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final subtitle = profile?.bio?.isNotEmpty == true
        ? profile!.bio!
        : 'Add a short bio so teammates know what to expect.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.getDisplayName().isNotEmpty == true
              ? profile!.getDisplayName()
              : 'Complete your profile',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.statistics, required this.sportsCount});

  final ProfileStatistics statistics;
  final int sportsCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final statTiles = [
      _HeroStat(
        label: 'Games',
        value: statistics.totalGamesPlayed.toString(),
        icon: Icons.sports_soccer,
      ),
      _HeroStat(
        label: 'Win rate',
        value: statistics.winRateFormatted,
        icon: Icons.emoji_events_outlined,
      ),
      _HeroStat(
        label: 'Sports',
        value: sportsCount.toString(),
        icon: Icons.sports_handball,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: statTiles.map((stat) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stat.icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                stat.value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                stat.label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _HeroDataPoints extends StatelessWidget {
  const _HeroDataPoints({required this.statistics});

  final ProfileStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dataPoints = [
      _ProfileDataPoint(
        icon: Icons.verified_user_outlined,
        label: 'Reliability',
        value: '${statistics.getReliabilityScore().round()}%',
      ),
      _ProfileDataPoint(
        icon: Icons.flash_on_outlined,
        label: 'Activity',
        value: statistics.getActivityLevel(),
      ),
      _ProfileDataPoint(
        icon: Icons.schedule_outlined,
        label: 'Last play',
        value: statistics.lastActiveFormatted,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: dataPoints
          .map(
            (point) => _DataPointChip(
              point: point,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          )
          .toList(),
    );
  }
}

class _DataPointChip extends StatelessWidget {
  const _DataPointChip({
    required this.point,
    required this.colorScheme,
    required this.textTheme,
  });

  final _ProfileDataPoint point;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(point.icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                point.label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ProfileDataPoint {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDataPoint({
    required this.icon,
    required this.label,
    required this.value,
  });
}
