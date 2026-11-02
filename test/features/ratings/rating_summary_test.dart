import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/ratings/data/rating_aggregate_repository.dart';
import 'package:dabbler/features/ratings/domain/rating_aggregate.dart';
import 'package:dabbler/features/ratings/presentation/widgets/rating_summary.dart';
import 'package:dabbler/features/ratings/providers/rating_aggregate_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = {
  'sportsmanship': RatingTag(
    key: 'sportsmanship',
    labelEn: 'Sportsmanship',
    labelAr: 'الروح الرياضية',
  ),
  'reliability': RatingTag(
    key: 'reliability',
    labelEn: 'Reliability',
    labelAr: 'الالتزام',
  ),
  'skill': RatingTag(key: 'skill', labelEn: 'Skill', labelAr: 'المهارة'),
  'teamwork': RatingTag(key: 'teamwork', labelEn: 'Teamwork', labelAr: 'الفريق'),
};

Map<String, dynamic> _row({int? count = 12}) => {
  'user_id': 'u1',
  'composite_score': 4.26,
  'event_count': count,
  'dimension_means': {
    'sportsmanship': 4.8,
    'reliability': 4.5,
    'skill': 4.1,
    'teamwork': 3.9,
    'unlabelled': 5.0,
  },
};

class _Repo implements RatingAggregateRepository {
  _Repo(this.result);
  final Result<RatingAggregate?, Failure> result;
  String? asked;

  @override
  Future<Result<RatingAggregate?, Failure>> aggregateFor(String userId) async {
    asked = userId;
    return result;
  }
}

Widget _host(_Repo repo, {String? userId = 'u1', Locale? locale}) =>
    ProviderScope(
      overrides: [ratingAggregateRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: locale ?? const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('shot'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('above'),
                RatingSummary(userId: userId),
                const Text('below'),
              ],
            ),
          ),
        ),
      ),
    );

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(390, 400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
  await t.pump();
  await t.pump();
}

void main() {
  group('RatingAggregate.fromRow', () {
    test('average, count and the three best labelled tags', () {
      final a = RatingAggregate.fromRow(_row(), _labels);
      expect(a.average, 4.26);
      expect(a.count, 12);
      expect(a.topTags.map((t) => t.key), [
        'sportsmanship',
        'reliability',
        'skill',
      ]);
    });

    test('no count unless the server returns one', () {
      expect(RatingAggregate.fromRow(_row(count: null), _labels).count, isNull);
    });
  });

  testWidgets('no aggregate renders nothing and takes no space', (t) async {
    await _pump(t, _host(_Repo(const Ok(null))));
    expect(find.byType(DabblerIcon), findsNothing);
    expect(find.byType(DabblerChip), findsNothing);
    expect(find.textContaining('rating'), findsNothing);
    final gap =
        t.getTopLeft(find.text('below')).dy - t.getBottomLeft(find.text('above')).dy;
    expect(gap, lessThan(2));
  });

  testWidgets('a failed read renders nothing', (t) async {
    await _pump(t, _host(_Repo(Err(Failure.from('boom')))));
    expect(find.byType(DabblerChip), findsNothing);
  });

  testWidgets('no user id renders nothing and asks nobody', (t) async {
    final repo = _Repo(Ok(RatingAggregate.fromRow(_row(), _labels)));
    await _pump(t, _host(repo, userId: null));
    expect(find.byType(DabblerChip), findsNothing);
    expect(repo.asked, isNull);
  });

  testWidgets('aggregate renders star, average, count and tag chips', (t) async {
    final repo = _Repo(Ok(RatingAggregate.fromRow(_row(), _labels)));
    await _pump(t, _host(repo));
    expect(repo.asked, 'u1');
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('from 12 ratings'), findsOneWidget);
    expect(find.byType(DabblerChip), findsNWidgets(3));
    expect(find.text('Sportsmanship'), findsOneWidget);
    expect(find.text('Teamwork'), findsNothing);
  });

  testWidgets('no count text when the server gave none', (t) async {
    final repo = _Repo(Ok(RatingAggregate.fromRow(_row(count: null), _labels)));
    await _pump(t, _host(repo));
    expect(find.text('4.3'), findsOneWidget);
    expect(find.textContaining('from'), findsNothing);
  });

  testWidgets('shows no rater: no avatar, no id, nothing tappable', (t) async {
    final repo = _Repo(Ok(RatingAggregate.fromRow(_row(), _labels)));
    await _pump(t, _host(repo));
    expect(find.byType(DabblerAvatar), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data);
    expect(texts.any((s) => s != null && s.contains('u1')), isFalse);
    await t.tap(find.text('Sportsmanship'), warnIfMissed: false);
    await t.tap(find.text('4.3'), warnIfMissed: false);
    await t.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('golden $lang', (t) async {
      final repo = _Repo(Ok(RatingAggregate.fromRow(_row(), _labels)));
      await _pump(t, _host(repo, locale: Locale(lang)));
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/summary_$lang.png'),
      );
    });
  }
}
