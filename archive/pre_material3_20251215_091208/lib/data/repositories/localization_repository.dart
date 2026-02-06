import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/localized_error.dart';

abstract class LocalizationRepository {
  /// Fetch a single error, with fallback locales (first hit wins).
  Future<Result<LocalizedError?, Failure>> getError(
    String code, {
    String locale = 'en',
    List<String> fallbackLocales = const ['en'],
  });

  /// Batch fetch; returns map by code (missing codes omitted).
  Future<Result<Map<String, LocalizedError>, Failure>> getErrors(
    List<String> codes, {
    String locale = 'en',
    List<String> fallbackLocales = const ['en'],
  });

  /// Prime the in-memory cache.
  void primeCache(List<LocalizedError> items);

  /// Clear cache; if [locale] provided, only that locale is cleared.
  void clearCache({String? locale});
}
