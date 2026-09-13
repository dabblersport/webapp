import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/features/social/presentation/providers/search_history_provider.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';

class _RecordingSearchRepository implements SearchRepository {
  final queries = <String>[];

  @override
  Future<Result<SearchResultBundle, Failure>> unifiedSearch({
    required String query,
    required SearchMode mode,
    int limit = 20,
  }) async {
    queries.add(query);
    return const Ok(SearchResultBundle.empty);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recent item actions search, remove one, and clear all', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'social_search_recent_queries': ['#football', '@ahmed_fc'],
    });
    final repository = _RecordingSearchRepository();
    final container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SocialSearchScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('#football'), findsOneWidget);
    expect(find.text('@ahmed_fc'), findsOneWidget);

    final ahmedRecentChip = find.ancestor(
      of: find.text('@ahmed_fc'),
      matching: find.byType(Container),
    );
    await tester.tap(
      find.descendant(
        of: ahmedRecentChip,
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();

    expect(find.text('@ahmed_fc'), findsNothing);
    expect(find.text('#football'), findsOneWidget);
    expect(repository.queries, isEmpty);

    await tester.tap(find.text('#football'));
    await tester.pump();

    expect(repository.queries, ['football']);

    container.read(searchProvider.notifier).clear();
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('Recent'), findsNothing);
    expect(container.read(recentSearchHistoryProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
