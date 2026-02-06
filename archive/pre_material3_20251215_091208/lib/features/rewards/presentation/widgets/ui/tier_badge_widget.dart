import 'package:flutter/material.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

/// A simple tier badge widget for displaying user tiers
class TierBadgeWidget extends StatelessWidget {
  final BadgeTier tier;
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;

  const TierBadgeWidget({
    super.key,
    required this.tier,
    this.size = 48,
    this.showLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: _getTierGradient(tier),
          shape: BoxShape.circle,
          border: Border.all(color: _getTierBorderColor(tier), width: 2),
          boxShadow: [
            BoxShadow(
              color: _getTierColor(tier).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getTierIcon(tier), color: Colors.white, size: size * 0.5),
            if (showLabel) ...[
              const SizedBox(height: 4),
              Text(
                tier.displayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  LinearGradient _getTierGradient(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCD7F32), Color(0xFF8B5A2B)],
        );
      case BadgeTier.silver:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
        );
      case BadgeTier.gold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        );
      case BadgeTier.platinum:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5E4E2), Color(0xFFB8B8B8)],
        );
      case BadgeTier.diamond:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB9F2FF), Color(0xFF00CED1)],
        );
    }
  }

  Color _getTierColor(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }

  Color _getTierBorderColor(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFF8B5A2B);
      case BadgeTier.silver:
        return const Color(0xFF808080);
      case BadgeTier.gold:
        return const Color(0xFFDAA520);
      case BadgeTier.platinum:
        return const Color(0xFFB8B8B8);
      case BadgeTier.diamond:
        return const Color(0xFF00CED1);
    }
  }

  IconData _getTierIcon(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return Icons.stars;
      case BadgeTier.silver:
        return Icons.star_border;
      case BadgeTier.gold:
        return Icons.star;
      case BadgeTier.platinum:
        return Icons.star_purple500;
      case BadgeTier.diamond:
        return Icons.diamond;
    }
  }
}
