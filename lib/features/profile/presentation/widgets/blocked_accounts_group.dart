import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The blocked-accounts list of the Settings design (`Settings.dc.html`,
/// `blocked`): a card of rows — avatar, name, handle and a destructive
/// "Unblock" action — or the "no one blocked" hint when the list is empty.
class BlockedAccountsGroup extends ConsumerWidget {
  const BlockedAccountsGroup({super.key, this.header, this.note});

  /// Optional heading and note, for a host page that shows the list among
  /// other groups; the design's own page draws the card alone.
  final String? header;
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedUsersWithProfilesProvider);
    return blocked.when(
      loading: () => const Center(child: DabblerSpinner()),
      error: (e, _) => DabblerRowHint(text: l10n.blocked_accounts_load_failed),
      data: (users) {
        if (users.isEmpty) {
          return DabblerRowHint(text: l10n.blocked_accounts_empty);
        }
        return DabblerRowGroup(
          header: header,
          note: note,
          children: [for (final user in users) _row(context, ref, user)],
        );
      },
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final l10n = AppLocalizations.of(context);
    final displayName =
        user['display_name'] as String? ?? l10n.blocked_accounts_unknown;
    final username = user['username'] as String? ?? '';
    final userId = user['user_id'] as String;
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      dense: true,
      title: displayName,
      subtitle: username.isNotEmpty ? '\u2066@$username\u2069' : null,
      leading: DabblerAvatar(seed: displayName, size: DabblerAvatarSize.md),
      trailing: DabblerRowAction(
        label: l10n.blocked_accounts_unblock,
        onPressed: () => _unblock(context, ref, userId, l10n),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AppLocalizations l10n,
  ) async {
    final toasts = DabblerToastProvider.of(context);
    final result = await ref.read(blockRepositoryProvider).unblockUser(userId);
    result.fold(
      (err) => toasts.show(
        DabblerToastSpec(
          message: l10n.blocked_accounts_unblock_failed(err.message),
          tone: DabblerToastTone.neutral,
        ),
      ),
      (_) {
        ref.invalidate(blockedUserIdsProvider);
        ref.invalidate(blockedUsersWithProfilesProvider);
        ref.invalidate(isUserBlockedProvider(userId));
        toasts.show(
          DabblerToastSpec(
            message: l10n.blocked_accounts_unblocked,
            tone: DabblerToastTone.neutral,
          ),
        );
      },
    );
  }
}
