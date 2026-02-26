import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import '../models/search/search_result_bundle.dart';

abstract class SearchRepository {
  /// Execute a unified search via the `rpc_unified_search_sectioned` RPC.
  ///
  /// [query] is the clean search term (prefix already stripped by
  /// [SearchQueryParser]).
  /// [mode] controls which entity types are returned.
  Future<Result<SearchResultBundle, Failure>> unifiedSearch({
    required String query,
    required SearchMode mode,
    int limit = 20,
  });
}
