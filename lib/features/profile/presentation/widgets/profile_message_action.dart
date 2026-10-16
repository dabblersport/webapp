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

    final button = DabblerButton.icon(
      key: ProfileMessageAction.buttonKey,
      icon: 'sms',
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
