import 'package:dabbler_design_system/dabbler_design_system.dart' show DabblerSpacing;
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/showup_rate/data/showup_rate_repository.dart';
import 'package:dabbler/features/showup_rate/domain/showup_rate.dart';
import 'package:dabbler/features/showup_rate/presentation/widgets/showup_rate_section.dart';
import 'package:dabbler/features/showup_rate/providers/showup_rate_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _normal = <String, dynamic>{
  'user_id': 'u1',
  'confirmed': 14,
  'attended': 12,
  'no_shows': 2,
  'rate': 86,
  'enough': true,
};

const _few = <String, dynamic>{
  'user_id': 'u1',
  'confirmed': 2,
  'attended': 2,
  'no_shows': 0,
  'rate': null,
  'enough': false,
};

class _Repo implements ShowUpRateRepository {
  _Repo(this.result);
  final Result<ShowUpRate, Failure> result;
  String? asked;

  @override
  Future<Result<ShowUpRate, Failure>> rateFor(String userId) async {
    asked = userId;
    return result;
  }
}

Widget _host(_Repo repo, {bool own = false, String locale = 'en'}) =>
    ProviderScope(
      overrides: [showUpRateRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        home: Scaffold(
          body: ShowUpRateSection(userId: 'u1', own: own),
        ),
      ),
    );

Future<void> _pump(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  await t.pump();
  await t.pump();
}

void main() {
  group('ShowUpRate.fromJson', () {
    test('maps the RPC jsonb as the server sent it', () {
      final r = ShowUpRate.fromJson(_normal);
      expect(r.confirmed, 14);
      expect(r.attended, 12);
      expect(r.noShows, 2);
      expect(r.rate, 86);
      expect(r.enough, isTrue);
    });

    test('below the threshold: no rate', () {
      final r = ShowUpRate.fromJson(_few);
      expect(r.enough, isFalse);
      expect(r.rate, isNull);
      expect(r.confirmed, 2);
    });

    test('a rate without enough is dropped; missing counts read as zero', () {
      final r = ShowUpRate.fromJson(const {'rate': 50, 'enough': false});
      expect(r.rate, isNull);
      expect(r.confirmed, 0);
      expect(ShowUpRate.fromJson(const {'enough': true}).enough, isFalse);
    });
  });

  for (final locale in ['en', 'ar']) {
    final ar = locale == 'ar';
    group('ShowUpRateSection ($locale)', () {
      testWidgets('not enough games yet, own and public', (t) async {
        for (final own in [true, false]) {
          await _pump(
            t,
            _host(
              _Repo(Ok(ShowUpRate.fromJson(_few))),
              own: own,
              locale: locale,
            ),
          );
          expect(
            find.text(
              ar ? 'لا توجد مباريات كافية بعد' : 'Not enough games yet',
            ),
            findsOneWidget,
          );
          expect(find.textContaining(ar ? '%' : '%'), findsNothing);
        }
      });

      testWidgets('normal, own: server value, basis and the rule', (t) async {
        final repo = _Repo(Ok(ShowUpRate.fromJson(_normal)));
        await _pump(t, _host(repo, own: true, locale: locale));
        expect(repo.asked, 'u1');
        expect(find.text(ar ? '86%' : '86%'), findsOneWidget);
        expect(
          find.text(ar ? 'من 14 مباراة مؤكدة' : 'from 14 confirmed games'),
          findsOneWidget,
        );
        final how = ar ? 'كيف تُحتسب' : "How it's counted";
        expect(find.text(how), findsOneWidget);
        await t.tap(find.text(how));
        await t.pump();
        expect(
          find.textContaining(
            ar ? 'لا تُحتسب الفعاليات الملغاة' : 'Cancelled events',
          ),
          findsOneWidget,
        );
        if (ar) {
          expect(
            Directionality.of(t.element(find.text(ar ? '86%' : '86%'))),
            TextDirection.rtl,
          );
        }
      });

      testWidgets('normal, public: percentage and basis only', (t) async {
        await _pump(
          t,
          _host(_Repo(Ok(ShowUpRate.fromJson(_normal))), locale: locale),
        );
        expect(find.text(ar ? '86%' : '86%'), findsOneWidget);
        expect(
          find.text(ar ? 'من 14 مباراة مؤكدة' : 'from 14 confirmed games'),
          findsOneWidget,
        );
        expect(find.text(ar ? 'كيف تُحتسب' : "How it's counted"), findsNothing);
      });
    });
  }

  testWidgets('padded like the neighbouring profile sections', (t) async {
    for (final own in [true, false]) {
      await _pump(t, _host(_Repo(Ok(ShowUpRate.fromJson(_few))), own: own));
      final title = t.getTopLeft(find.text('Show-up rate'));
      expect(title.dx, DabblerSpacing.space6);
    }
  });

  testWidgets('a failed read renders nothing', (t) async {
    await _pump(t, _host(_Repo(const Err(Failure()))));
    expect(find.text('Show-up rate'), findsNothing);
  });
}
