import 'package:equatable/equatable.dart';

import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/view_boundary.dart';

/// Which side of the cursor to page.
enum MessageDirection {
  older('older'),
  newer('newer');

  const MessageDirection(this.wireName);
  final String wireName;
}

/// Page-size and field limits of the contract (`docs/messaging/openapi.yaml`).
/// The size limits are proposals to be confirmed with the Worker owner.
abstract final class MessagingLimits {
  const MessagingLimits._();

  static const int defaultPageSize = 30;
  static const int maxPageSize = 50;
  static const int maxBodyLength = 2000;
}

/// One page of messages, ascending by `seq` (`components.schemas.MessagePage`).
class MessagePage extends Equatable {
  const MessagePage({
    required this.messages,
    required this.hasOlder,
    required this.hasNewer,
    required this.pageSize,
    this.olderCursor,
    this.newerCursor,
    this.boundary,
  });

  final List<Message> messages;

  /// Pass as the cursor with [MessageDirection.older]; null when [hasOlder] is false.
  final int? olderCursor;

  /// Pass as the cursor with [MessageDirection.newer]; null when [hasNewer] is false.
  final int? newerCursor;

  final bool hasOlder;
  final bool hasNewer;
  final int pageSize;

  /// Present when the caller's view is limited (a member who left); every
  /// message in the page is at or below `boundary.seq`.
  final ViewBoundary? boundary;

  /// Throws [FormatException] on a malformed payload.
  factory MessagePage.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'];
    final hasOlder = json['has_older'];
    final hasNewer = json['has_newer'];
    final pageSize = json['page_size'];
    if (messages is! List ||
        hasOlder is! bool ||
        hasNewer is! bool ||
        pageSize is! int) {
      throw const FormatException('Malformed message page payload');
    }
    return MessagePage(
      messages: [
        for (final m in messages)
          Message.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      olderCursor: json['older_cursor'] as int?,
      newerCursor: json['newer_cursor'] as int?,
      hasOlder: hasOlder,
      hasNewer: hasNewer,
      pageSize: pageSize,
      boundary: ViewBoundary.tryFromJson(json['boundary']),
    );
  }

  Map<String, dynamic> toJson() => {
    'messages': [for (final m in messages) m.toJson()],
    'older_cursor': olderCursor,
    'newer_cursor': newerCursor,
    'has_older': hasOlder,
    'has_newer': hasNewer,
    'page_size': pageSize,
    'boundary': boundary?.toJson(),
  };

  @override
  List<Object?> get props => [
    messages,
    olderCursor,
    newerCursor,
    hasOlder,
    hasNewer,
    pageSize,
    boundary,
  ];
}
