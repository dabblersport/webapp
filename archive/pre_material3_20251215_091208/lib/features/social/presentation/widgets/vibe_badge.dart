import 'package:flutter/material.dart';

/// Widget to display a vibe badge with emoji, label, and color
class VibeBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final String? colorHex;
  final bool showLabel;
  final VoidCallback? onTap;

  const VibeBadge({
    super.key,
    required this.emoji,
    required this.label,
    this.colorHex,
    this.showLabel = true,
    this.onTap,
  });

  Color get _backgroundColor {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final hex = colorHex!.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return Colors.grey.shade200;
      }
    }
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _backgroundColor;
    final textColor = _getContrastColor(bgColor);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 12 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }

  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Widget to display multiple vibes in a horizontal list
class VibesList extends StatelessWidget {
  final List<Map<String, dynamic>> vibes;
  final Function(Map<String, dynamic>)? onVibeTap;
  final bool showLabels;

  const VibesList({
    super.key,
    required this.vibes,
    this.onVibeTap,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    if (vibes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: vibes.map((vibe) {
        final vibeData = vibe['vibes'] ?? vibe;
        return VibeBadge(
          emoji: vibeData['emoji'] ?? '🤝',
          label: vibeData['label_en'] ?? vibeData['key'] ?? 'Vibe',
          colorHex: vibeData['color_hex'],
          showLabel: showLabels,
          onTap: onVibeTap != null ? () => onVibeTap!(vibe) : null,
        );
      }).toList(),
    );
  }
}

/// Widget to display primary vibe prominently
class PrimaryVibeBadge extends StatelessWidget {
  final Map<String, dynamic>? vibe;
  final VoidCallback? onTap;

  const PrimaryVibeBadge({super.key, this.vibe, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (vibe == null) return const SizedBox.shrink();

    final emoji = vibe!['emoji'] ?? '🤝';
    final label = vibe!['label_en'] ?? vibe!['key'] ?? 'Vibe';
    final colorHex = vibe!['color_hex'];

    return VibeBadge(
      emoji: emoji,
      label: label,
      colorHex: colorHex,
      showLabel: true,
      onTap: onTap,
    );
  }
}
