import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/sport_profile.dart';

import 'providers.dart';

/// Minimal showcase widget for sport profile providers.
class SportProfilesConsumer extends StatelessWidget {
  const SportProfilesConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final initialLoad = ref.watch(mySportProfilesProvider);
        final realtime = ref.watch(mySportProfilesStreamProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Initial load',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ResultView(value: initialLoad),
            const SizedBox(height: 16),
            Text(
              'Realtime updates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ResultView(value: realtime),
          ],
        );
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.value});

  final AsyncValue<Result<List<SportProfile>, Failure>> value;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (result) => result.fold(
        (failure) => Text('Error: ${failure.message}'),
        (sports) => sports.isEmpty
            ? const Text('No sport preferences yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final sport in sports)
                    Text('${sport.sportKey} · skill ${sport.skillLevel}'),
                ],
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
    );
  }
}
