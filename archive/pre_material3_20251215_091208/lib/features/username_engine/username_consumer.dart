import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'package:dabbler/core/fp/result.dart';

class UsernameConsumer extends ConsumerWidget {
  const UsernameConsumer({super.key, required this.profileType});

  final String profileType; // 'player' | 'organiser'

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(myProfileTypeStreamProvider(profileType));
    return stream.when(
      data: (result) => result.match(
        (failure) => Center(child: Text('Error: ${failure.message}')),
        (profile) => ListTile(
          title: Text(profile.username ?? '(no username)'),
          subtitle: Text('${profile.displayName} • ${profile.profileType}'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Stream error: $error')),
    );
  }
}
