import 'package:flutter/material.dart';
import '../../../../../../utils/enums/social_enums.dart';

class VisibilitySelector extends StatelessWidget {
  final PostVisibility visibility;
  final Function(PostVisibility) onVisibilityChanged;

  const VisibilitySelector({
    super.key,
    required this.visibility,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Visibility',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Column(
              children: [
                RadioListTile<PostVisibility>(
                  title: const Text('Public'),
                  subtitle: const Text('Anyone can see this post'),
                  value: PostVisibility.public,
                  groupValue: visibility,
                  onChanged: (value) {
                    if (value != null) onVisibilityChanged(value);
                  },
                ),
                RadioListTile<PostVisibility>(
                  title: const Text('Friends'),
                  subtitle: const Text('Only your friends can see this post'),
                  value: PostVisibility.friends,
                  groupValue: visibility,
                  onChanged: (value) {
                    if (value != null) onVisibilityChanged(value);
                  },
                ),
                RadioListTile<PostVisibility>(
                  title: const Text('Private'),
                  subtitle: const Text('Only you can see this post'),
                  value: PostVisibility.private,
                  groupValue: visibility,
                  onChanged: (value) {
                    if (value != null) onVisibilityChanged(value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
