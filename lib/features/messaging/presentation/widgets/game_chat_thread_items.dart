import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/messaging/domain/gif_message.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_reason_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Maps the controller's rows to design-system thread rows (KAN-516):
/// messages in `seq` order, a date separator at each local day change, server
/// system lines, and a client-drawn "game finished" line at [gameEndAt] once
/// it has passed.
///
/// D8: the only delivery states passed are `sending` and `failed`; a sent
/// message carries none, so no tick is ever drawn (and the thread is a group
/// context, where the DS hides sent/delivered/read anyway).
List<DabblerThreadItem> gameChatThreadItems({
  required List<ChatItem> items,
  required AppLocalizations l10n,
  required String locale,
  required DateTime now,
  required void Function(String clientKey) onRetry,
  DateTime? gameEndAt,
  bool includeSystem = true,
}) {
  final out = <DabblerThreadItem>[];
  final today = _day(now.toLocal());
  DateTime? lastDay;
  final endLocal = gameEndAt?.toLocal();
  var finishedDrawn = endLocal == null || endLocal.isAfter(now.toLocal());

  void dateRow(DateTime local) {
    final day = _day(local);
    if (lastDay == day) return;
    lastDay = day;
    final diff = today.difference(day).inDays;
    out.add(
      DabblerThreadDate(
        diff == 0
            ? l10n.messaging_chat_today
            : diff == 1
            ? l10n.messaging_chat_yesterday
            : DateFormat.yMMMd(locale).format(local),
      ),
    );
  }

  void finishedRow() {
    dateRow(endLocal!);
    out.add(
      DabblerThreadSystem(
        text: l10n.messaging_chat_game_finished,
        icon: 'flag',
        timestamp: DateFormat.jm(locale).format(endLocal),
      ),
    );
    finishedDrawn = true;
  }

  for (final item in items) {
    final m = item.message;
    // A DM (KAN-556) draws no system lines.
    if (!includeSystem && m != null && m.kind == MessageKind.system) continue;
    final at = (m?.createdAt ?? now).toLocal();
    if (!finishedDrawn && at.isAfter(endLocal!)) finishedRow();
    dateRow(at);
    final time = DateFormat.jm(locale).format(at);
    if (m != null && m.kind == MessageKind.system) {
      out.add(DabblerThreadSystem(text: m.body, timestamp: time));
      continue;
    }
    // Own: a pending send, or a server message carrying our idempotency key.
    final own = m == null || item.clientKey != null || m.clientKey != null;
    final key = item.clientKey;
    // KAN-582: a body that is one GIPHY media URL is drawn as a GIF.
    final gifUrl = gifUrlOfBody(item.body);
    out.add(
      DabblerThreadMessage(
        id: m?.id ?? key,
        direction: own
            ? DabblerMessageDirection.outgoing
            : DabblerMessageDirection.incoming,
        sender: own ? null : m.senderUserId,
        avatarSeed: own ? null : m.senderUserId,
        showSender: false,
        content: gifUrl == null ? item.body : null,
        attachment: gifUrl == null
            ? null
            : DabblerMessageAttachment.image(
                child: DabblerImage(
                  url: gifUrl,
                  width: DabblerMessage.imageSize.width,
                  height: DabblerMessage.imageSize.height,
                  radius: DabblerRadius.lgAll,
                  semanticLabel: l10n.messaging_gif_semantic,
                  overlay: DabblerBadge(label: l10n.messaging_gif_badge),
                ),
              ),
        timestamp: time,
        deliveryState: switch (item.state) {
          OutgoingState.sending => DabblerDeliveryState.sending,
          OutgoingState.failed => DabblerDeliveryState.failed,
          OutgoingState.sent => null,
        },
        retryLabel: l10n.messaging_chat_retry,
        onRetry: item.state == OutgoingState.failed && key != null
            ? () => onRetry(key)
            : null,
      ),
    );
    // A rejected send says why, with the existing line for its typed reason.
    final why = item.state == OutgoingState.failed && item.failureReason != null
        ? gameChatReasonText(l10n, item.failureReason!)
        : null;
    if (why != null) {
      out.add(
        DabblerThreadNotice(tone: DabblerNoticeTone.error, description: why),
      );
    }
  }
  if (!finishedDrawn) finishedRow();
  return out;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
