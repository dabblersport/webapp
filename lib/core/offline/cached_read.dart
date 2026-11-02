import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// A value read through the on-device cache (KAN-655). [isStale] is true when
/// the value is the cached copy rather than a fresh fetch; [cachedAt] is when
/// that copy was fetched (null for a fresh value).
class CachedRead<T> {
  const CachedRead({required this.value, this.isStale = false, this.cachedAt});

  final T value;
  final bool isStale;
  final DateTime? cachedAt;
}

/// The failure code for "offline and nothing cached", so callers can tell it
/// from any other failure.
const String kOfflineCacheMiss = 'offline_cache_miss';

/// Fetch, then write through; offline, or when the fetch fails on the network,
/// serve the cached copy marked stale. Never throws.
///
/// - Signed out ([accountId] null): just fetches, nothing is cached.
/// - Online success: the value is written under [key] (after [cap], the
///   first-page cap) and returned fresh.
/// - [isOffline] true, or a network / no-internet / timeout failure: the cached
///   copy is returned with `isStale: true` and its `cachedAt`; with no usable
///   copy the result is `Err` with code [kOfflineCacheMiss].
/// - Any other failure passes through unchanged.
Future<Result<CachedRead<T>, Failure>> readThrough<T>({
  required OfflineCache cache,
  required String? accountId,
  required String key,
  required bool Function() isOffline,
  required Future<Result<T, Failure>> Function() fetch,
  required Object? Function(T value) encode,
  required T Function(Object? json) decode,
  T Function(T value)? cap,
}) async {
  final account = accountId;
  if (account == null) {
    final r = await fetch();
    return r.fold(
      (f) => Err<CachedRead<T>, Failure>(f),
      (v) => Ok<CachedRead<T>, Failure>(CachedRead<T>(value: v)),
    );
  }

  Future<Result<CachedRead<T>, Failure>> fromCache(Failure cause) async {
    final hit = await cache.read(account, key);
    if (hit != null) {
      try {
        return Ok(
          CachedRead<T>(
            value: decode(hit.payload),
            isStale: true,
            cachedAt: hit.fetchedAt,
          ),
        );
      } catch (_) {
        // A shape that no longer parses counts as a miss.
      }
    }
    return Err(
      Failure(
        category: FailureCode.noInternet,
        message: 'You are offline and nothing is saved on this device yet.',
        code: kOfflineCacheMiss,
        cause: cause,
      ),
    );
  }

  if (isOffline()) {
    return fromCache(const Failure(category: FailureCode.noInternet));
  }

  final started = DateTime.now();
  final Result<T, Failure> result;
  try {
    result = await fetch();
  } catch (e, st) {
    return Err(Failure.from(e, st));
  }
  if (result is Ok<T, Failure>) {
    final value = result.value;
    try {
      await cache.write(
        account,
        key,
        encode(cap == null ? value : cap(value)),
        requestStartedAt: started,
      );
    } catch (_) {
      // An unencodable value is simply not cached.
    }
    return Ok(CachedRead<T>(value: value));
  }
  final failure = result.requireError;
  if (failure.isNetwork || failure.isTimeout) return fromCache(failure);
  return Err(failure);
}
