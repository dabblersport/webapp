import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class SchemaGuard extends ConsumerWidget {
  final Widget child;
  const SchemaGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compatible = ref.watch(schemaCompatibleProvider);

    return compatible.when(
      loading: () => const _BootSplash(),
      error: (_, __) => const _SchemaMismatchScreen(),
      data: (ok) => ok ? child : const _SchemaMismatchScreen(),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SchemaMismatchScreen extends ConsumerWidget {
  const _SchemaMismatchScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbSchemaMetaProvider).valueOrNull;
    final app = ref.watch(appSchemaHashProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Update required')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your app is out of sync with the server schema.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('App schema: ${app ?? 'unknown'}'),
              Text('Server schema: ${db?.schemaHash ?? 'unknown'}'),
              if (db?.notes != null) ...[
                const SizedBox(height: 8),
                Text('Notes: ${db!.notes}'),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () {
                  // You can take users to the store or a custom updater.
                  // For now, just pop any dialogs and let them restart.
                  Navigator.of(context).maybePop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
