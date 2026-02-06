import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'package:dabbler/core/fp/result.dart';

class SquadMembersConsumer extends ConsumerWidget {
  const SquadMembersConsumer({super.key, required this.squadId});

  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(squadMembersStreamProvider(squadId));
    return stream.when(
      data: (res) => res.match(
        (failure) => Center(child: Text('Members error: ${failure.message}')),
        (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, index) {
            final member = rows[index];
            return ListTile(
              title: Text('${member.profileId} — ${member.role}'),
              subtitle: Text(member.status),
            );
          },
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Stream error: $error')),
    );
  }
}
