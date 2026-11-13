import 'package:uuid/uuid.dart';

/// Holds the one client request id of a create attempt (KAN-618).
///
/// A composer calls [begin] when the user taps Create: the first call makes a
/// uuid v4, later calls (a retry after a failure) return the same id. The
/// composer calls [clear] on success, when the form is edited after a failure
/// and when it is discarded, so the next attempt gets a new id.
///
/// KAN-612: the composers send the id to the create calls (`create_post`,
/// `rpc_create_game`, `rpc_create_meetup`), so a retry never makes a second row.
/// KAN-612: the message of the failure a composer returns when Create is
/// tapped offline. Nothing is sent and the form is kept; the screen shows
/// `offline_create_refused` for it.
const String kCreateOfflineRefused = 'create-offline-refused';

class CreateRequestId {
  CreateRequestId({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  String? _current;

  /// The id of the attempt in progress; null until the first [begin].
  String? get current => _current;

  /// The id of this attempt: the existing one, or a new uuid v4.
  String begin() => _current ??= _uuid.v4();

  /// Ends the attempt; the next [begin] makes a new id.
  void clear() => _current = null;
}
