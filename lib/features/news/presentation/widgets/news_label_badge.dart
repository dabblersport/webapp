import 'package:flutter/material.dart';

/// Colored chip badge for the `feed_label` field on a news article.
class NewsLabelBadge extends StatelessWidget {
  const NewsLabelBadge(this.label, {super.key});

  final String label;

  static Color _colorFor(String label) => switch (label.toLowerCase()) {
        'breaking' => Colors.red,
        'important' => Colors.orange,
        'new feature' => Colors.blue.shade700,
        'match recap' => Colors.purple,
        'trending' => Colors.green,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
