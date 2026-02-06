import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dabbler/data/models/sport_profiles/sport_profile.dart'
    as advanced_profile;
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart'
    as advanced_badge;
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart'
    as advanced_tier;

class PlayerSportProfileHeader extends StatelessWidget {
  const PlayerSportProfileHeader({
    super.key,
    required this.profile,
    this.tier,
    this.badges = const <advanced_badge.SportProfileBadge>[],
  });

  final advanced_profile.SportProfile profile;
  final advanced_tier.SportProfileTier? tier;
  final List<advanced_badge.SportProfileBadge> badges;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = _buildGradient(colorScheme);
    final verificationStatus = profile.verificationStatus.trim().toLowerCase();
    final isVerified = verificationStatus == 'verified';
    final secondaryPositions = profile.secondaryPositions
        .map((dynamic value) => value.toString())
        .where((position) => position.isNotEmpty)
        .toList(growable: false);

    final xpCurrent = profile.xpTotal;
    final xpTarget = profile.xpNextLevel <= 0
        ? profile.xpTotal
        : math.max(profile.xpNextLevel, 0.0);
    final progress = xpTarget <= 0
        ? 0.0
        : (xpCurrent / xpTarget).clamp(0.0, 1.0);

    // return Container(
    //   padding: const EdgeInsets.all(20),
    //   decoration: BoxDecoration(
    //     gradient: backgroundGradient,
    //     borderRadius: BorderRadius.circular(20),
    //   ),
    //   child: Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       Row(
    //         children: [
    //           _buildSportKeyChip(context, isVerified),
    //           const SizedBox(width: 12),
    //           if (tier != null && tier!.key.isNotEmpty)
    //             _buildTierChip(context, tier!),
    //         ],
    //       ),
    //       const SizedBox(height: 16),
    //       Row(
    //         crossAxisAlignment: CrossAxisAlignment.end,
    //         children: [
    //           Expanded(
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Text(
    //                   'Overall ${profile.overallLevel.toStringAsFixed(1)}',
    //                   style: Theme.of(context).textTheme.headlineSmall
    //                       ?.copyWith(
    //                         color: colorScheme.onPrimary,
    //                         fontWeight: FontWeight.w700,
    //                       ),
    //                 ),
    //                 const SizedBox(height: 4),
    //                 Text(
    //                   _buildPositionLabel(secondaryPositions),
    //                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    //                     color: colorScheme.onPrimary.withOpacity(0.8),
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           ),
    //           if (tier?.iconUrl.isNotEmpty == true)
    //             CircleAvatar(
    //               radius: 24,
    //               backgroundColor: colorScheme.onPrimary.withOpacity(0.1),
    //               backgroundImage: NetworkImage(tier!.iconUrl),
    //             ),
    //         ],
    //       ),
    //       const SizedBox(height: 20),
    //       _buildXpSection(context, xpCurrent, xpTarget, progress),
    //       const SizedBox(height: 16),
    //       _buildFormAndReliability(context),
    //       if (badges.isNotEmpty) ...[
    //         const SizedBox(height: 16),
    //         _buildBadgeRow(context),
    //       ],
    //     ],
    //   ),
    // );
    return const SizedBox.shrink();
  }

  LinearGradient _buildGradient(ColorScheme colorScheme) {
    final primaryColor = _parseColor(
      tier?.colorPrimary,
      fallback: colorScheme.primary,
    );
    final secondaryColor = _parseColor(
      tier?.colorSecondary,
      fallback: colorScheme.primaryContainer,
    );

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, secondaryColor],
    );
  }

  Widget _buildSportKeyChip(BuildContext context, bool isVerified) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile.sportKey.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 6),
            Icon(Icons.verified, size: 18, color: colorScheme.onPrimary),
          ],
        ],
      ),
    );
  }

  Widget _buildTierChip(
    BuildContext context,
    advanced_tier.SportProfileTier tier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tier.key.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildXpSection(
    BuildContext context,
    double xpCurrent,
    double xpTarget,
    double progress,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP Level ${profile.xpLevel.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${xpCurrent.toStringAsFixed(0)} / ${xpTarget.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.isNaN ? 0.0 : progress,
            minHeight: 8,
            backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildFormAndReliability(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            icon: Icons.trending_up,
            label: 'Form',
            value: profile.formScore.toStringAsFixed(1),
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            context,
            // Replaced unavailable icon (Icons.shield_person) with a supported Material icon.
            icon: Icons.security,
            label: 'Reliability',
            value: profile.reliabilityScore.toStringAsFixed(1),
            color: colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(BuildContext context) {
    final theme = Theme.of(context);
    final color = Theme.of(context).colorScheme.onPrimary;
    final visibleBadges = badges.take(3).toList(growable: false);
    final remainingCount = badges.length - visibleBadges.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Badges',
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final badge in visibleBadges) ...[
              _BadgeChip(badge: badge, color: color),
              const SizedBox(width: 8),
            ],
            if (remainingCount > 0)
              Text(
                '+$remainingCount more',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _buildPositionLabel(List<String> secondaryPositions) {
    final primary = profile.primaryPosition.isNotEmpty
        ? profile.primaryPosition
        : 'Preferred position not set';

    if (secondaryPositions.isEmpty) {
      return primary;
    }

    final secondary = secondaryPositions.join(', ');
    return '$primary · $secondary';
  }

  Color _parseColor(String? value, {required Color fallback}) {
    final hex = value?.trim();
    if (hex == null || hex.isEmpty) {
      return fallback;
    }

    final sanitized = hex.replaceAll('#', '');
    if (sanitized.length == 6) {
      final color = int.tryParse(sanitized, radix: 16);
      if (color != null) {
        return Color(0xFF000000 | color);
      }
    }
    if (sanitized.length == 8) {
      final color = int.tryParse(sanitized, radix: 16);
      if (color != null) {
        return Color(color);
      }
    }
    return fallback;
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.color});

  final advanced_badge.SportProfileBadge badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (badge.iconUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.15),
        backgroundImage: NetworkImage(badge.iconUrl),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        badge.name.isNotEmpty ? badge.name : badge.key,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
