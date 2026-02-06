import 'package:dabbler/data/models/squad.dart';
import 'package:dabbler/features/social/providers.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialConsumer extends ConsumerWidget {
  const SocialConsumer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(mySquadsStreamProvider);
    return asyncValue.when(
      data: (result) => result.match(
        (failure) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${failure.message}'),
          ),
        ),
        (squads) => _SquadList(squads: squads),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Stream error: $error'),
        ),
      ),
    );
  }
}

class _SquadList extends StatelessWidget {
  const _SquadList({required this.squads});

  final List<Squad> squads;

  @override
  Widget build(BuildContext context) {
    if (squads.isEmpty) {
      return const Center(child: Text('No squads yet'));
    }
    return ListView.builder(
      itemCount: squads.length,
      itemBuilder: (context, index) {
        final squad = squads[index];
        return ListTile(title: Text(squad.name), subtitle: Text(squad.sport));
      },
    );
  }
}
