// KAN-1014: the organiser's "Banned people" list — avatar, name, scope (with
// the event or series title for an event ban), date, and Unban behind a
// confirm. Lives on the Privacy page of Settings, beside Blocked accounts.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/bans/data/bans_repository.dart';
import 'package:dabbler/features/bans/domain/ban_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The scope label a ban row shows; the event title only for an event ban.
String banScopeLabel(AppLocalizations l, OrganiserBan b) {
  if (b.scope == BanScope.organiser) return l.ban_scope_all;
  final title = b.eventTitle;
  if (title == null || title.isEmpty) return l.ban_scope_one_event;
  return b.seriesId != null
      ? l.ban_scope_series(title)
      : l.ban_scope_event(title);
}

class BannedPeopleGroup extends ConsumerWidget {
  const BannedPeopleGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref
        .watch(myBansProvider)
        .when(
          loading: () => const Center(child: DabblerSpinner()),
          error: (_, _) => DabblerRowHint(text: l.ban_list_load_failed),
          data: (bans) => bans.isEmpty
              ? DabblerRowHint(
                  key: const ValueKey<String>('bans-empty'),
                  text: l.ban_list_empty,
                )
              : DabblerRowGroup(
                  children: [for (final b in bans) _row(context, ref, l, b)],
                ),
        );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    OrganiserBan b,
  ) {
    final name = b.displayName ?? b.username ?? l.ban_unknown_person;
    final date = b.createdAt == null
        ? null
        : DabblerType.toWesternDigits(
            DateFormat.yMMMd(l.localeName).format(b.createdAt!.toLocal()),
          );
    final scope = banScopeLabel(l, b);
    return DabblerInputRow(
      key: ValueKey<String>('ban-row-${b.banId}'),
      flat: true,
      showDivider: false,
      dense: true,
      title: context.isolate(name),
      subtitle: date == null ? scope : '$scope · $date',
      leading: DabblerAvatar(
        seed: b.username ?? name,
        imageUrl: b.avatarUrl,
        size: DabblerAvatarSize.md,
      ),
      trailing: DabblerRowAction(
        key: ValueKey<String>('ban-unban-${b.banId}'),
        label: l.ban_unban,
        onPressed: () => _unban(context, ref, l, b, name),
      ),
    );
  }

  Future<void> _unban(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    OrganiserBan b,
    String name,
  ) async {
    final toasts = DabblerToastProvider.maybeOf(context);
    final ok = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: l.ban_unban_title(context.isolate(name)),
        description: l.ban_unban_body,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: l.composer_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: l.ban_unban,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (ok != true) return;
    final r = await ref.read(bansRepositoryProvider).liftBan(b.banId);
    r.fold(
      (_) => toasts?.show(
        DabblerToastSpec(
          message: l.ban_unban_failed,
          tone: DabblerToastTone.error,
        ),
      ),
      (_) {
        ref.invalidate(myBansProvider);
        toasts?.show(
          DabblerToastSpec(
            message: l.ban_unbanned,
            tone: DabblerToastTone.neutral,
          ),
        );
      },
    );
  }
}
