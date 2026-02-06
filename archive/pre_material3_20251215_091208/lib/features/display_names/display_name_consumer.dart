import 'package:dabbler/core/fp/result.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class DisplayNameConsumer extends ConsumerWidget {
  final String profileType; // 'player' | 'organiser'
  const DisplayNameConsumer({super.key, required this.profileType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(myProfileDisplayStreamProvider(profileType));
    return stream.when(
      data: (res) => res.match(
        (l) => Center(child: Text('Error: ${l.message}')),
        (p) => ListTile(
          title: Text(p.displayName),
          subtitle: Text('type: ${p.profileType}'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Stream error: $e')),
    );
  }
}
