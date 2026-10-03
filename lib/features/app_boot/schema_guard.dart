import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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
    return ColoredBox(
      color: DabblerColors.of(context).brandPrimary,
      child: const SizedBox.expand(),
    );
  }
}

class _SchemaMismatchScreen extends ConsumerWidget {
  const _SchemaMismatchScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbSchemaMetaProvider).valueOrNull;
    final app = ref.watch(appSchemaHashProvider).valueOrNull;
    return DabblerPage(
      topBar: const DabblerNavigationTopBar.titled(title: 'Update required'),
      body: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DabblerText(
              'Your app is out of sync with the server schema.',
              weight: DabblerTextWeight.bold,
            ),
            const SizedBox(height: DabblerSpacing.space4),
            DabblerText('App schema: ${app ?? 'unknown'}'),
            DabblerText('Server schema: ${db?.schemaHash ?? 'unknown'}'),
            if (db?.notes != null) ...[
              const SizedBox(height: DabblerSpacing.space3),
              DabblerText('Notes: ${db!.notes}'),
            ],
            const Spacer(),
            DabblerButton(
              label: 'Close',
              onPressed: () {
                // You can take users to the store or a custom updater.
                // For now, just pop any dialogs and let them restart.
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
