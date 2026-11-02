import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_reason_text.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The two flags the profile Message action reads. Defaults to the real
/// compile-time flags (both false); a test overrides the provider instead of
/// flipping a const.
typedef ProfileMessageActionFlags = ({bool messaging, bool direct});

final profileMessageActionFlagsProvider = Provider<ProfileMessageActionFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    direct: FeatureFlags.enableMessagingDirect,
  ),
);

/// The signed-in viewer's auth user id, or null when signed out. Read only
/// when the flags are on; tests override it.
final profileMessageViewerIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);

/// The "Message" action on another user's profile (KAN-557): starts or
/// reopens the 1:1 DM and opens its thread. Draws nothing unless both flags
/// are on, the viewer is signed in, and the target is someone else. When the
/// two users are blocked (either direction) the action is disabled and says
/// why.
class ProfileMessageAction extends ConsumerStatefulWidget {
  const ProfileMessageAction({super.key, required this.targetAuthUserId});

  /// The genuine `auth.users` id of the profile on screen (never the route's
  /// `userId`, which may be a profile id). Null while the profile loads.
  final String? targetAuthUserId;

  static const buttonKey = ValueKey<String>('profile-message-action');

  @override
  ConsumerState<ProfileMessageAction> createState() =>
      _ProfileMessageActionState();
}

class _ProfileMessageActionState extends ConsumerState<ProfileMessageAction> {
  bool _busy = false;

  Future<void> _start(String targetId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(dmRepositoryProvider).startDm(targetId);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) {
        final l10n = AppLocalizations.of(context);
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message:
                dmReasonText(l10n, failure) ?? l10n.messaging_reason_unknown,
            tone: DabblerToastTone.error,
          ),
        );
      },
      (id) => context.pushNamed(
        dmThreadRouteName,
        pathParameters: {dmThreadRouteParam: id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(profileMessageActionFlagsProvider);
    if (!(flags.messaging && flags.direct)) return const SizedBox.shrink();
    final viewerId = ref.watch(profileMessageViewerIdProvider);
    final targetId = widget.targetAuthUserId;
    if (viewerId == null ||
        targetId == null ||
        targetId.isEmpty ||
        targetId == viewerId) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final blockedAsync = ref.watch(isUserBlockedProvider(targetId));
    final blocked = blockedAsync.maybeWhen(data: (v) => v, orElse: () => false);

    final button = DabblerButton(
      key: ProfileMessageAction.buttonKey,
      // Text only: an icon beside the label overflows a half-width button on
      // a 360dp screen.
      label: l10n.messaging_dm_action_label,
      fullWidth: true,
      semanticLabel: blocked
          ? l10n.user_profile_cannot_message_blocked
          : l10n.messaging_dm_action_semantic,
      tone: DabblerButtonTone.outlined,
      loading: _busy,
      // Disabled while the block state loads, and when blocked.
      disabled: blocked || blockedAsync.isLoading,
      onPressed: () => _start(targetId),
    );
    if (!blocked) return button;
    return DabblerTooltip(
      message: l10n.user_profile_cannot_message_blocked,
      child: button,
    );
  }
}

/// The Follow + Message row on another user's profile (KAN-557). Side by side
/// with equal widths and a gap; stacked when the text scale is large enough
/// that two labelled buttons would not fit on one line (200% text).
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    super.key,
    required this.follow,
    required this.message,
    this.invite,
  });

  final Widget follow;

  /// Null when the Message action is gated off.
  final Widget? message;

  /// The icon-only Invite button (Profiles.dc.html OTHER_ACTIONS, third
  /// entry), drawn after Message. Null draws nothing.
  final Widget? invite;

  /// Above this text scale the two buttons stack.
  static const double stackAboveScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    final invite = this.invite;
    if (message == null && invite == null) return follow;
    final stacked =
        MediaQuery.textScalerOf(context).scale(10) / 10 > stackAboveScale;
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          follow,
          if (message != null) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            message,
          ],
          if (invite != null) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            invite,
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: follow),
        if (message != null) ...[
          const DabblerGap.h(DabblerSpacing.space3),
          Expanded(child: message),
        ],
        if (invite != null) ...[
          const DabblerGap.h(DabblerSpacing.space3),
          invite,
        ],
      ],
    );
  }
}

/// The icon-only "Invite" button on another user's profile (Profiles.dc.html
/// OTHER_ACTIONS: `calendar-add`, outlined, no label). The design names no
/// target flow and the codebase has no invite-a-person-to-a-game screen, so
/// it draws and announces itself but starts nothing (KAN-689, cxo ruling).
class ProfileInviteAction extends StatelessWidget {
  const ProfileInviteAction({super.key});

  static const buttonKey = ValueKey<String>('profile-invite-action');

  @override
  Widget build(BuildContext context) {
    return DabblerButton.icon(
      key: buttonKey,
      icon: 'calendar-add',
      semanticLabel: AppLocalizations.of(
        context,
      ).profile_invite_action_semantic,
      tone: DabblerButtonTone.outlined,
    );
  }
}
