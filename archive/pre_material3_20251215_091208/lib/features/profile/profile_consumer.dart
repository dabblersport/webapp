import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/profile.dart';
import 'providers.dart';

class ProfileConsumer extends ConsumerWidget {
  const ProfileConsumer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(myProfileStreamProvider);

    return myProfile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Error: ${error.toString()}')),
      data: (result) => result.fold(
        (failure) => _FailureView(failure: failure),
        (profile) => _ProfileView(profile: profile),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        failure.message,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Center(
        child: Text(
          'Profile not available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final username = '@${profile!.username}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          profile!.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(username, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
