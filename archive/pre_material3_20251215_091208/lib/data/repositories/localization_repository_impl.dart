import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import 'base_repository.dart';
import '../models/localized_error.dart';
import 'localization_repository.dart';

@immutable
class LocalizationRepositoryImpl extends BaseRepository
    implements LocalizationRepository {
  static const _table = 'localized_errors';

  /// Cache key is locale::code
  final Map<String, LocalizedError> _cache = {};

  LocalizationRepositoryImpl(super.svc);

  String _k(String locale, String code) => '$locale::$code';

  @override
  void primeCache(List<LocalizedError> items) {
    for (final e in items) {
      _cache[_k(e.locale, e.code)] = e;
    }
  }

  @override
  void clearCache({String? locale}) {
    if (locale == null) {
      _cache.clear();
      return;
    }
    _cache.removeWhere((k, _) => k.startsWith('$locale::'));
  }

  @override
  Future<Result<LocalizedError?, Failure>> getError(
    String code, {
    String locale = 'en',
    List<String> fallbackLocales = const ['en'],
  }) {
    return guard<LocalizedError?>(() async {
      // 1) Cache
      final ck = _k(locale, code);
      if (_cache.containsKey(ck)) return _cache[ck];

      // 2) Primary locale
      final primary = await _fetchSingle(code, locale);
      if (primary != null) return primary;

      // 3) Fallbacks (in order)
      for (final fb in fallbackLocales) {
        final fk = _k(fb, code);
        if (_cache.containsKey(fk)) return _cache[fk];
        final hit = await _fetchSingle(code, fb);
        if (hit != null) return hit;
      }
      return null;
    });
  }

  @override
  Future<Result<Map<String, LocalizedError>, Failure>> getErrors(
    List<String> codes, {
    String locale = 'en',
    List<String> fallbackLocales = const ['en'],
  }) {
    return guard<Map<String, LocalizedError>>(() async {
      final out = <String, LocalizedError>{};
      final missing = <String>[];

      // 1) Cache for primary locale
      for (final code in codes) {
        final ck = _k(locale, code);
        final cached = _cache[ck];
        if (cached != null) {
          out[code] = cached;
        } else {
          missing.add(code);
        }
      }

      // 2) Fetch missing for primary
      if (missing.isNotEmpty) {
        final prim = await _fetchMany(missing, locale);
        out.addAll(prim);
        // Compute still missing
        missing
          ..clear()
          ..addAll(codes.where((c) => !out.containsKey(c)));
      }

      // 3) Fallbacks in order
      for (final fb in fallbackLocales) {
        if (missing.isEmpty) break;
        final fromCache = <String>[];
        for (final code in List<String>.from(missing)) {
          final fk = _k(fb, code);
          final cached = _cache[fk];
          if (cached != null) {
            out[code] = cached;
            fromCache.add(code);
          }
        }
        if (fromCache.isNotEmpty) {
          missing.removeWhere(fromCache.contains);
        }
        if (missing.isEmpty) break;

        final hits = await _fetchMany(missing, fb);
        out.addAll(hits);
        missing
          ..clear()
          ..addAll(codes.where((c) => !out.containsKey(c)));
      }

      return out;
    });
  }

  Future<LocalizedError?> _fetchSingle(String code, String locale) async {
    final row = await svc.client
        .from(_table)
        .select()
        .eq('code', code)
        .eq('locale', locale)
        .maybeSingle();

    if (row == null) return null;
    final e = LocalizedError.fromMap(asMap(row));
    _cache[_k(locale, code)] = e;
    return e;
  }

  Future<Map<String, LocalizedError>> _fetchMany(
    List<String> codes,
    String locale,
  ) async {
    if (codes.isEmpty) return {};
    final rows = await svc.client
        .from(_table)
        .select()
        .eq('locale', locale)
        .inFilter('code', codes);

    final map = <String, LocalizedError>{};
    for (final r in rows) {
      final e = LocalizedError.fromMap(asMap(r));
      map[e.code] = e;
      _cache[_k(locale, e.code)] = e;
    }
    return map;
  }
}
