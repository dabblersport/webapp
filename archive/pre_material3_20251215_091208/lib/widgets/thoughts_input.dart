import 'package:flutter/material.dart';

/// Thoughts Input Widget - Clickable card that opens create post screen
class ThoughtsInput extends StatelessWidget {
  const ThoughtsInput({
    super.key,
    this.onTap,
    this.controller,
    this.minLines = 1,
    this.maxLines = 6,
    this.readOnly = false,
  });

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final int minLines;
  final int? maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
