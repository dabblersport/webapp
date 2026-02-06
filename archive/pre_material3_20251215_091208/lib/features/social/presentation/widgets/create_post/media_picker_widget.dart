import 'package:flutter/material.dart';

class MediaPickerWidget extends StatelessWidget {
  final List<dynamic> selectedMedia;
  final Function(dynamic) onMediaSelected;
  final Function(int) onMediaRemoved;
  final Map<String, double> uploadProgress;

  const MediaPickerWidget({
    super.key,
    required this.selectedMedia,
    required this.onMediaSelected,
    required this.onMediaRemoved,
    required this.uploadProgress,
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
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Media',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    onMediaSelected({'type': 'image', 'url': 'placeholder'});
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                ),
              ],
            ),

            if (selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedMedia.asMap().entries.map((entry) {
                  final index = entry.key;

                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onMediaRemoved(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
