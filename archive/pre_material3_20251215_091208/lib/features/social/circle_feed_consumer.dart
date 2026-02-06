import 'package:dabbler/core/fp/result.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'circles_providers.dart';

class CircleFeedConsumer extends ConsumerWidget {
  const CircleFeedConsumer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(circleFeedStreamProvider((limit: 30, offset: 0)));
    return stream.when(
      data: (res) => res.match(
        (l) => Center(child: Text('Feed error: ${l.message}')),
        (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) =>
              ListTile(dense: true, title: Text(rows[i].toString())),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Stream error: $e')),
    );
  }
}
