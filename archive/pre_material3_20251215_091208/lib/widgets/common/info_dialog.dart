import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Information dialog widget with different types (success, error, warning, info)
enum InfoType { success, error, warning, info }

class InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final InfoType type;
  final VoidCallback? onOk;
  final String? okText;

  const InfoDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = InfoType.info,
    this.onOk,
    this.okText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_getIconForType(type), color: _getColorForType(type)),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onOk ?? () => Navigator.pop(context),
          child: Text(okText ?? 'OK'),
        ),
      ],
    );
  }

  IconData _getIconForType(InfoType type) {
    switch (type) {
      case InfoType.success:
        return Iconsax.tick_circle_copy;
      case InfoType.error:
        return Iconsax.danger_copy;
      case InfoType.warning:
        return Iconsax.warning_2_copy;
      case InfoType.info:
        return Iconsax.info_circle_copy;
    }
  }

  Color _getColorForType(InfoType type) {
    switch (type) {
      case InfoType.success:
        return Colors.green;
      case InfoType.error:
        return Colors.red;
      case InfoType.warning:
        return Colors.orange;
      case InfoType.info:
        return Colors.blue;
    }
  }
}
