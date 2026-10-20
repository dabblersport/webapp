import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/messaging/domain/gif_message.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_reason_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Maps the controller's rows to design-system thread rows (KAN-516):
/// messages in `seq` order, a date separator at each local day change, server
/// system lines, and a client-drawn "game finished" line at [gameEndAt] once
/// it has passed.
///
/// KAN-580 delivery metadata, outgoing messages only. A pending send is
/// `sending`, a manual Retry in flight `retrying`, a rejected one `failed`.
/// Once the server has it: in a direct chat ([isDm]) it is `sent`, `delivered`
/// or `seen` from [receipts] (the newest outgoing message also spells the
/// word); in a group it carries a [DabblerReceipt] tally ("Seen by 4 of 9")
/// and the DS draws the count. Without [receipts] (an old Worker, the fake
/// backend) a sent message is just `sent`. Incoming messages carry none.
List<DabblerThreadItem> gameChatThreadItems({
  required List<ChatItem> items,
  required AppLocalizations l10n,
  required String locale,
  required DateTime now,
  required void Function(String clientKey) onRetry,
  DateTime? gameEndAt,
  bool includeSystem = true,
  bool isDm = false,
  Map<int, ReceiptCounts> receipts = const <int, ReceiptCounts>{},
  Set<String> freshIds = const <String>{},
}) {
  final out = <DabblerThreadItem>[];
  final today = _day(now.toLocal());
  DateTime? lastDay;
  final endLocal = gameEndAt?.toLocal();
  // The newest outgoing message that the server has: the one that spells the
  // delivery word in a direct chat.
  final newestOwnId = items
      .where(
        (i) =>
            i.message != null &&
            i.message!.kind != MessageKind.system &&
            (i.clientKey != null || i.message!.clientKey != null),
      )
      .lastOrNull
      ?.message
      ?.id;
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
    final counts = m == null ? null : receipts[m.seq];
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
        deliveryState: !own
            ? null
            : switch (item.state) {
                OutgoingState.sending => DabblerDeliveryState.sending,
                OutgoingState.retrying => DabblerDeliveryState.retrying,
                OutgoingState.failed => DabblerDeliveryState.failed,
                OutgoingState.sent => switch (counts?.level) {
                  ReceiptLevel.seen => DabblerDeliveryState.seen,
                  ReceiptLevel.delivered => DabblerDeliveryState.delivered,
                  _ => DabblerDeliveryState.sent,
                },
              },
        receipt:
            own &&
                !isDm &&
                item.state == OutgoingState.sent &&
                counts != null &&
                counts.total > 0
            ? DabblerReceipt(
                seen: counts.seen,
                delivered: counts.delivered,
                total: counts.total,
              )
            : null,
        showDeliveryLabel: own && isDm && m != null && m.id == newestOwnId,
        fresh: !own && freshIds.contains(m.id),
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
