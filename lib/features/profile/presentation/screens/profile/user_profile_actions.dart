import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/visited_profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_screen.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/helpers/share_links.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The write actions on another user's profile: follow / unfollow, block /
/// unblock, report, copy link and the More sheet. Moved out of the screen
/// unchanged in behaviour (KAN-688) so the screen stays under the size limit;
/// every id is resolved from the visited profile, never from the route slot
/// and never from the signed-in user's own controller.
mixin UserProfileActions on ConsumerState<UserProfileScreen> {
  /// The route identity of the profile on screen.
  VisitedProfileKey get visitedKey;

  /// Set while the copy-link pill shows its confirmed state.
  bool linkCopied = false;

  void toast(
    String message, {
    DabblerToastTone tone = DabblerToastTone.neutral,
  }) {
    if (!mounted) return;
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  /// The visited profile's `profiles.id`, once loaded.
  String? visitedProfileId() =>
      ref.read(visitedProfileControllerProvider(visitedKey)).profile?.id;

  /// The genuine `auth.users` id of the profile currently loaded on this
  /// screen. `widget.userId` is NOT reliably this — some entry points (e.g. a
  /// game creator card) only know a profile id and pass it in that slot. Any
  /// action that writes to a user-level (not profile-level) table — block,
  /// report, message — must resolve the real auth uid from the loaded
  /// profile instead, and no-op if it isn't loaded yet.
  String? targetAuthUserId() =>
      ref.read(visitedProfileControllerProvider(visitedKey)).profile?.userId;

  String? _myProfileId() => ref
      .read(myProfileIdProvider)
      .maybeWhen(data: (v) => v, orElse: () => null);

  Future<void> toggleFollow({
    required String myProfileId,
    required String targetProfileId,
    required bool currentlyFollowing,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      if (currentlyFollowing) {
        // User-level unfollow: removes every follow edge between the two
        // users' persona profiles, not just the active-profile pair —
        // otherwise followers-only content stays visible after unfollowing.
        await supabase.rpc(
          SupabaseConfig.rpcUnfollowUserFn,
          params: {'p_target_profile_id': targetProfileId},
        );
      } else {
        await supabase.from(SupabaseConfig.profileFollowsTable).insert({
          'follower_profile_id': myProfileId,
          'following_profile_id': targetProfileId,
        });
      }
      ref.invalidate(
        isFollowingProvider((
          currentProfileId: myProfileId,
          targetProfileId: targetProfileId,
        )),
      );
      ref.invalidate(followingListProvider(myProfileId));
      ref.invalidate(followingCountProvider(myProfileId));
      ref.invalidate(followersCountProvider(targetProfileId));
      ref.invalidate(visitedFollowersCountProvider(targetProfileId));
    } catch (_) {
      // The button keeps its previous state; it re-reads on the next refresh.
    }
  }

  void _invalidateBlockState(String targetUserId) {
    ref.invalidate(blockedUserIdsProvider);
    ref.invalidate(blockedUsersWithProfilesProvider);
    ref.invalidate(isUserBlockedProvider(targetUserId));
    final String? myProfileId = _myProfileId();
    if (myProfileId != null) {
      ref.invalidate(
        isBlockedProvider((
          currentProfileId: myProfileId,
          targetProfileId: visitedProfileId() ?? '',
        )),
      );
      ref.invalidate(followingListProvider(myProfileId));
      ref.invalidate(followersListProvider(myProfileId));
    }
  }

  Future<void> blockUser() async {
    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: AppLocalizations.of(ctx).user_profile_block_dialog_title,
        description: AppLocalizations.of(ctx).user_profile_block_dialog_body,
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: AppLocalizations.of(ctx).profile_btn_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: AppLocalizations.of(ctx).user_profile_block_btn_block,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (confirmed != true) return;
    final String? targetUserId = targetAuthUserId();
    if (targetUserId == null) return;
    final result = await ref
        .read(blockRepositoryProvider)
        .blockUser(targetUserId);
    result.fold(
      (err) => toast('Error: ${err.message}', tone: DabblerToastTone.error),
      (_) {
        _invalidateBlockState(targetUserId);
        if (mounted) {
          toast(AppLocalizations.of(context).user_profile_blocked_snack);
        }
      },
    );
  }

  Future<void> unblockUser() async {
    final String? targetUserId = targetAuthUserId();
    if (targetUserId == null) return;
    final result = await ref
        .read(blockRepositoryProvider)
        .unblockUser(targetUserId);
    result.fold(
      (err) => toast('Error: ${err.message}', tone: DabblerToastTone.error),
      (_) {
        _invalidateBlockState(targetUserId);
        if (mounted) {
          toast(AppLocalizations.of(context).user_profile_unblocked_snack);
        }
      },
    );
  }

  void reportUser() {
    final String? targetUserId = targetAuthUserId();
    if (targetUserId == null) return;
    showReportDialog(
      context,
      targetType: ReportTargetType.user,
      targetId: targetUserId,
      targetUserId: targetUserId,
    );
  }

  /// Copies the profile's public link; [confirmInPlace] flips the header pill
  /// to its "Link copied" state for a short toast interval instead of a toast.
  Future<void> copyProfileLink({bool confirmInPlace = false}) async {
    final String? profileId = visitedProfileId();
    if (profileId == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: ShareLinks.profile(
          profileId,
          sharerProfileId: ref.read(myProfileIdProvider).valueOrNull,
        ),
      ),
    );
    if (!mounted) return;
    if (!confirmInPlace) {
      toast(AppLocalizations.of(context).sfx_link_copied);
      return;
    }
    setState(() => linkCopied = true);
    await Future<void>.delayed(DabblerMotion.toastShort);
    if (mounted) setState(() => linkCopied = false);
  }

  void showMoreOptions() {
    final String? targetUserId = targetAuthUserId();
    final bool blocked = targetUserId == null
        ? false
        : ref.read(isUserBlockedProvider(targetUserId)).valueOrNull ?? false;
    final bool canCopy = visitedProfileId() != null;

    showAppSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return DabblerSheetBody(
          spacing: DabblerSpacing.space3,
          children: [
            // KAN-597: the full web link to this profile for the running environment.
            if (canCopy)
              DabblerButton(
                label: l10n.post_detail_copy_link,
                icon: 'copy',
                tone: DabblerButtonTone.neutral,
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  copyProfileLink();
                },
              ),
            DabblerButton(
              label: blocked
                  ? l10n.user_profile_menu_unblock_user
                  : l10n.user_profile_menu_block_user,
              icon: 'close-circle',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () async {
                Navigator.pop(sheetContext);
                await (blocked ? unblockUser() : blockUser());
              },
            ),
            DabblerButton(
              label: l10n.user_profile_menu_report_user,
              icon: 'warning-2',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                reportUser();
              },
            ),
          ],
        );
      },
    );
  }
}
