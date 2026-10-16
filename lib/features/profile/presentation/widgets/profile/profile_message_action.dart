import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_message_action_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show currentUserProvider;
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The localized message of a failed start-DM (KAN-557): the daily cap, a
/// block, an account the Worker answers as not in the pilot (the under-age
/// case), a rate limit, or anything else.
String profileMessageFailureText(AppLocalizations l10n, Object failure) {
  if (failure is DmCapReachedFailure) {
    return l10n.messaging_dm_action_cap_reached;
  }
  if (failure is MessagingFailure) {
    return switch (failure.reason) {
      MessagingReason.blocked => l10n.messaging_dm_action_blocked,
      MessagingReason.notInPilot => l10n.messaging_dm_action_under_age,
      MessagingReason.rateLimited => l10n.messaging_dm_action_rate_limited,
      _ => l10n.messaging_dm_action_failed,
    };
  }
  return l10n.messaging_dm_action_failed;
}

/// The Message action on another user's profile (KAN-557): starts, or
/// reopens, the one-to-one chat with [targetUserId] and opens its thread.
///
/// It draws nothing unless both messaging flags are on, the viewer is signed
/// in and the profile is not the viewer's own. When the viewer and the profile
/// user have blocked each other (either direction, from the existing
/// `isUserBlockedProvider`) it is shown DISABLED, with the reason as its
/// accessibility label. While a start is in flight it shows a busy state and
/// ignores repeat taps. A failure shows a localized message and stays here.
class ProfileMessageAction extends ConsumerStatefulWidget {
  const ProfileMessageAction({super.key, required this.targetUserId});

  /// The profile user's genuine auth user id; null until the profile loads.
  final String? targetUserId;

  static const buttonKey = ValueKey<String>('profile-message-action');

  @override
  ConsumerState<ProfileMessageAction> createState() =>
      _ProfileMessageActionState();
}

class _ProfileMessageActionState extends ConsumerState<ProfileMessageAction> {
  bool _busy = false;

  Future<void> _start(String targetUserId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(dmRepositoryProvider).startDm(targetUserId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isSuccess) {
      context.pushNamed(
        dmThreadRouteName,
        pathParameters: {dmThreadRouteParam: result.requireValue},
      );
      return;
    }
    final text = profileMessageFailureText(
      AppLocalizations.of(context),
      result.requireError,
    );
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: text, tone: DabblerToastTone.error));
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetUserId;
    if (!profileMessageActionEnabled(ref.watch(profileMessageFlagsProvider))) {
      return const SizedBox.shrink();
    }
    final me = ref.watch(currentUserProvider);
    if (target == null || me == null || me.userId == target) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(isUserBlockedProvider(target)).valueOrNull;
    final isBlocked = blocked ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DabblerSpacing.space3),
      child: DabblerButton.icon(
        key: ProfileMessageAction.buttonKey,
        icon: 'sms',
        semanticLabel: _busy
            ? l10n.messaging_dm_action_opening
            : isBlocked
            ? l10n.messaging_dm_action_blocked
            : l10n.messaging_dm_action_label,
        tone: DabblerButtonTone.outlined,
        loading: _busy,
        disabled: isBlocked,
        onPressed: (_busy || isBlocked) ? null : () => _start(target),
      ),
    );
  }
}
