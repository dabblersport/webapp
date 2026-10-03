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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final body = DabblerType.body
        .resolveForDirection(direction)
        .copyWith(color: colors.textPrimary);

    return DabblerPage(
      topBar: const DabblerNavigationTopBar.titled(title: 'Update required'),
      body: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space5),
        child: DefaultTextStyle.merge(
          style: body,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your app is out of sync with the server schema.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: DabblerSpacing.space4),
              Text('App schema: ${app ?? 'unknown'}'),
              Text('Server schema: ${db?.schemaHash ?? 'unknown'}'),
              if (db?.notes != null) ...[
                const SizedBox(height: DabblerSpacing.space3),
                Text('Notes: ${db!.notes}'),
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
      ),
    );
  }
}
