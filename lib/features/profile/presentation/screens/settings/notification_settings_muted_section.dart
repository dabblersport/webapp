// KAN-991 (G-12, H.2): the muted list. Kinds muted with "Turn off
// notifications like this" and conversations muted with "Mute this
// conversation", each with Unmute; the last unmute can be undone. Empty:
// "Nothing muted".

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The label of a muted kind: its settings group's name.
String notifMutedKindLabel(AppLocalizations l10n, String kindKey) =>
    switch (NotificationKinds.of(kindKey)?.settingsGroup) {
      NotificationSettingsGroup.gameInvites =>
        l10n.notif_settings_kind_game_invites,
      NotificationSettingsGroup.gameReminders =>
        l10n.notif_settings_kind_game_reminders,
      NotificationSettingsGroup.gameUpdates ||
      NotificationSettingsGroup.waitlist =>
        l10n.notif_settings_kind_game_updates,
      NotificationSettingsGroup.likes => l10n.notif_settings_kind_likes,
      NotificationSettingsGroup.comments => l10n.notif_settings_kind_comments,
      NotificationSettingsGroup.mentions => l10n.notif_settings_kind_mentions,
      // F-17: follows, never "friends".
      NotificationSettingsGroup.followers ||
      NotificationSettingsGroup.friends => l10n.notif_settings_kind_followers,
      NotificationSettingsGroup.squads => l10n.notif_settings_kind_squads,
      NotificationSettingsGroup.meetups => l10n.notif_settings_kind_meetups,
      NotificationSettingsGroup.meetupRsvps =>
        l10n.notif_settings_kind_meetup_rsvps,
      NotificationSettingsGroup.meetupRequests =>
        l10n.notif_settings_kind_meetup_requests,
      NotificationSettingsGroup.meetupApproved =>
        l10n.notif_settings_kind_meetup_approved,
      NotificationSettingsGroup.meetupDeclined =>
        l10n.notif_settings_kind_meetup_declined,
      NotificationSettingsGroup.meetupCancelled =>
        l10n.notif_settings_kind_meetup_cancelled,
      NotificationSettingsGroup.messages => l10n.notif_settings_cat_messages,
      NotificationSettingsGroup.system => l10n.notif_settings_cat_system,
      _ => l10n.notif_settings_muted_kind_other,
    };

/// The name of a muted conversation.
String notifMutedConversationLabel(AppLocalizations l10n, MyConversation c) {
  final String? name = c.isDm ? c.counterpartName : c.title;
  return (name == null || name.trim().isEmpty)
      ? l10n.notif_settings_muted_conversation_fallback
      : name.trim();
}

typedef _Undo = ({String label, Future<void> Function() run});

class NotificationSettingsMutedSection extends ConsumerStatefulWidget {
  const NotificationSettingsMutedSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final NotificationSettings settings;
  final NotificationSettingsController controller;

  @override
  ConsumerState<NotificationSettingsMutedSection> createState() =>
      _NotificationSettingsMutedSectionState();
}

class _NotificationSettingsMutedSectionState
    extends ConsumerState<NotificationSettingsMutedSection> {
  _Undo? _undo;

  Future<void> _unmuteKind(String key, String label) async {
    final bool ok = await widget.controller.setKindsMuted([key], false);
    if (!mounted || !ok) return;
    setState(
      () => _undo = (
        label: label,
        run: () => widget.controller.setKindsMuted([key], true),
      ),
    );
  }

  Future<void> _unmuteConversation(String id, String label) async {
    final setMuted = ref.read(notificationSetConversationMutedProvider);
    if (!await setMuted(id, false) || !mounted) return;
    setState(() => _undo = (label: label, run: () => setMuted(id, true)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> kinds = widget.settings.mutedKinds;
    final List<MyConversation> chats =
        ref.watch(notificationMutedConversationsProvider).valueOrNull ??
        const <MyConversation>[];
    final _Undo? undo = _undo;
    final bool empty = kinds.isEmpty && chats.isEmpty;

    return DabblerRowGroup(
      header: l10n.notif_settings_muted_header,
      children: [
        if (empty)
          DabblerEmptyState(
            key: const ValueKey<String>('notif-muted-empty'),
            icon: 'notification',
            title: l10n.notif_settings_muted_empty_title,
            text: l10n.notif_settings_muted_empty_body,
            size: DabblerEmptyStateSize.inline,
          ),
        if (kinds.isNotEmpty) ...[
          _caption(l10n.notif_settings_muted_kinds),
          for (final String k in kinds)
            _row(
              key: 'kind-$k',
              icon: NotificationKinds.of(k)?.icon ?? 'notification',
              title: notifMutedKindLabel(l10n, k),
              subtitle: l10n.notif_settings_muted_kind_sub,
              onUnmute: () =>
                  unawaited(_unmuteKind(k, notifMutedKindLabel(l10n, k))),
            ),
        ],
        if (chats.isNotEmpty) ...[
          _caption(l10n.notif_settings_muted_conversations),
          for (final MyConversation c in chats)
            _row(
              key: 'chat-${c.conversationId}',
              icon: 'message-text',
              title: notifMutedConversationLabel(l10n, c),
              onUnmute: () => unawaited(
                _unmuteConversation(
                  c.conversationId,
                  notifMutedConversationLabel(l10n, c),
                ),
              ),
            ),
        ],
        if (undo != null)
          DabblerBanner(
            key: const ValueKey<String>('notif-muted-undo'),
            tone: DabblerBannerTone.info,
            message: l10n.notif_settings_unmuted(undo.label),
            action: DabblerBannerAction(
              label: l10n.notif_settings_undo,
              onPressed: () {
                setState(() => _undo = null);
                unawaited(undo.run());
              },
            ),
          ),
      ],
    );
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space2,
      vertical: DabblerSpacing.space1,
    ),
    child: DabblerText(
      text,
      style: DabblerType.caption1,
      tone: DabblerTextTone.secondary,
    ),
  );

  Widget _row({
    required String key,
    required String icon,
    required String title,
    String? subtitle,
    required VoidCallback onUnmute,
  }) {
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerInputRow(
      key: ValueKey<String>('notif-muted-$key'),
      flat: true,
      showDivider: false,
      dense: true,
      title: title,
      subtitle: subtitle,
      leading: DabblerIcon(
        icon,
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      trailing: DabblerButton(
        label: AppLocalizations.of(context).notif_settings_unmute,
        size: DabblerButtonSize.small,
        tone: DabblerButtonTone.neutral,
        onPressed: onUnmute,
      ),
    );
  }
}
