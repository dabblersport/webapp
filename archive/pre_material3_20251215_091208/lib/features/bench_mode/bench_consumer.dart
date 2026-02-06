import 'package:dabbler/core/fp/result.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class BenchConsumer extends ConsumerWidget {
  final String profileType; // 'player' | 'organiser'
  const BenchConsumer({super.key, required this.profileType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRes = ref.watch(myProfileActiveProvider(profileType));
    return activeRes.when(
      data: (res) => res.match(
        (l) => Text('Error: ${l.message}'),
        (isActive) => Row(
          children: [
            Text(isActive ? 'Active' : 'Benched'),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (isActive) {
                  ref.refresh(benchMyProfileProvider(profileType));
                } else {
                  ref.refresh(unbenchMyProfileProvider(profileType));
                }
                ref.invalidate(myProfileActiveProvider(profileType));
              },
              child: Text(isActive ? 'Bench me' : 'Unbench me'),
            ),
          ],
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Err: $e'),
    );
  }
}
