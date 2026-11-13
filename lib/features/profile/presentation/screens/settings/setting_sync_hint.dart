import 'package:dabbler/core/offline/sync/queueable_settings.dart';
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
        (edits) => {
          for (final k in settingKeys)
            if (edits.containsKey(k)) k: edits[k]!,
        },
      ),
    );
    final notice = ref.watch(
      settingNoticesProvider.select((n) {
        for (final k in settingKeys) {
          if (n.containsKey(k)) return MapEntry(k, n[k]!);
        }
        return null;
      }),
    );
    final l10n = AppLocalizations.of(context);
    if (queued.isEmpty && notice == null) return const SizedBox.shrink();

    final DabblerTextSpan span;
    if (queued.isNotEmpty) {
      final failed = queued.values.contains(SettingSyncState.failed);
      span = DabblerTextSpan(
        failed
            ? l10n.settings_not_synced_retry
            : l10n.settings_will_sync_online,
        tone: failed ? DabblerTextTone.warning : DabblerTextTone.secondary,
        onTap: () {
          final sync = ref.read(settingsSyncProvider.notifier);
          for (final key in queued.keys) {
            sync.retry(key);
          }
        },
      );
    } else {
      span = DabblerTextSpan(
        notice!.value == SettingNotice.updatedElsewhere
            ? l10n.settings_updated_elsewhere
            : l10n.settings_change_rejected,
        tone: DabblerTextTone.warning,
        onTap: () {
          final notices = ref.read(settingNoticesProvider.notifier);
          notices.state = Map.of(notices.state)..remove(notice.key);
        },
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
      child: DabblerText.rich([span], style: DabblerType.footnote),
    );
  }
}
