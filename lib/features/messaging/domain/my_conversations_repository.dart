import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';

/// The Messages list's one read (KAN-549), over `msg_my_conversations`
/// (KAN-547).
///
/// It lives beside `MessagingRepository` rather than on it because that
/// interface is pinned, method for method, to `docs/messaging/openapi.yaml`
/// (`contract_agreement_test.dart`), and this operation is not in that
/// contract yet. The fake implements both.
abstract class MyConversationsRepository {
  /// The signed-in user's game chats, newest activity first (the order is the
  /// server's; callers keep it). At most [limit] rows (server default 50,
  /// max 100). Never throws: a malformed payload or a failed call is a
  /// `Failure`.
  Future<Result<List<MyConversation>, Failure>> listMyConversations({
    int? limit,
  });
}
