/// A hook that lets the data layer's guarded calls tell the app how a request
/// ended, without the data layer knowing who listens (KAN-603). The
/// connectivity notifier registers itself; [Result.guard] reports every
/// failure and success through it, so a real request failing with no-internet
/// or a timeout while the OS says connected turns the connection state to poor.
abstract final class RequestOutcome {
  const RequestOutcome._();

  /// Called with the error of every guarded call that failed.
  static void Function(Object error)? onFailure;

  /// Called when a guarded call succeeded.
  static void Function()? onSuccess;

  static void failure(Object error) {
    try {
      onFailure?.call(error);
    } catch (_) {}
  }

  static void success() {
    try {
      onSuccess?.call();
    } catch (_) {}
  }
}
