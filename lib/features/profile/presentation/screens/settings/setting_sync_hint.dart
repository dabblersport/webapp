import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The inline "not synced, tap to retry" line next to a setting that was
/// changed on this device and has not reached the server yet (KAN-608).
/// It shows only while one of [settingKeys] is queued; a tap sends the queued
/// edits again. Not a modal and not a toast: the setting itself already shows
/// the value the user chose.
class SettingSyncHint extends ConsumerWidget {
  const SettingSyncHint(this.settingKeys, {super.key});

  /// The queue keys this line speaks for (see `SettingKeys`).
  final List<String> settingKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref.watch(
      settingsSyncProvider.select(
        (edits) => settingKeys.where(edits.containsKey).toList(),
      ),
    );
    if (queued.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
      child: DabblerText.rich([
        DabblerTextSpan(
          l10n.settings_not_synced_retry,
          tone: DabblerTextTone.warning,
          onTap: () {
            final sync = ref.read(settingsSyncProvider.notifier);
            for (final key in queued) {
              sync.retry(key);
            }
          },
        ),
      ], style: DabblerType.footnote),
    );
  }
}
