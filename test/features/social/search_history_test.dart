import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/features/social/presentation/providers/search_history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentSearchHistoryNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'persists ordered searches and restores them for a new notifier',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final history = RecentSearchHistoryNotifier(preferences: preferences);
        await history.initialized;

        await history.add('padel courts dubai');
        await history.add('#football');

        expect(history.state, ['#football', 'padel courts dubai']);

        final restored = RecentSearchHistoryNotifier(preferences: preferences);
        await restored.initialized;

        expect(restored.state, ['#football', 'padel courts dubai']);
      },
    );

    test(
      'removes one requested item and clears all remaining history',
      () async {
        SharedPreferences.setMockInitialValues({
          'social_search_recent_queries': [
            '#football',
            '@ahmed_fc',
            'padel courts dubai',
          ],
        });
        final preferences = await SharedPreferences.getInstance();
        final history = RecentSearchHistoryNotifier(preferences: preferences);
        await history.initialized;

        await history.remove('@ahmed_fc');

        expect(history.state, ['#football', 'padel courts dubai']);
        expect(preferences.getStringList('social_search_recent_queries'), [
          '#football',
          'padel courts dubai',
        ]);

        await history.clear();

        expect(history.state, isEmpty);
        expect(
          preferences.getStringList('social_search_recent_queries'),
          isEmpty,
        );
      },
    );
  });
}
