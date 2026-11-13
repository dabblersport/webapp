import 'dart:convert';

import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/render_mode.dart';

/// KAN-582: the app's one GIF picker (GIPHY) and its states: trending,
/// search, selection, empty, offline, unavailable and retry. The fake client
/// answers for GIPHY; nothing real is called.
const _original = 'https://media1.giphy.com/media/abc/giphy.gif';

String _page({int count = 2, int total = 2}) => jsonEncode({
  'data': [
    for (var i = 0; i < count; i++)
      {
        'images': {
          'original': {'url': '$_original?i=$i'},
          'fixed_width': {
            'url': 'https://media1.giphy.com/media/abc/$i/200w.gif',
          },
        },
      },
  ],
  'pagination': {'total_count': total},
});

typedef _Variant = ({String name, Locale locale, Brightness brightness});
const _variants = <_Variant>[
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

Widget _app(_Variant v, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: v.locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: DabblerDesignSystemTheme.withFonts(
    DabblerDesignSystemTheme.withTokens(
      v.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
    ),
    locale: v.locale,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final v in _variants) {
    group('[${v.name}]', () {
      late AppLocalizations l10n;
      late List<Uri> requests;
      late List<String> picked;

      setUp(() {
        l10n = lookupAppLocalizations(v.locale);
        requests = [];
        picked = [];
      });

      Widget picker(http.Client client, {String apiKey = 'test-key'}) => _app(
        v,
        GifPickerSheet(client: client, apiKey: apiKey, onSelected: picked.add),
      );

      testWidgets('TC1: trending loads with the existing GIPHY request shape '
          'and the provider credit shows', (tester) async {
        final client = MockClient((request) async {
          requests.add(request.url);
          return http.Response(_page(), 200);
        });
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(requests.single.path, '/v1/gifs/trending');
        expect(requests.single.host, 'api.giphy.com');
        expect(requests.single.queryParameters['rating'], 'pg-13');
        expect(
          requests.single.queryParameters['bundle'],
          'messaging_non_clips',
        );
        expect(find.byType(DabblerImage), findsNWidgets(2));
        expect(find.text(l10n.composer_gif_attribution), findsOneWidget);
        expect(find.text(l10n.composer_gif_empty), findsNothing);
      });

      testWidgets('TC2: a search sends q, and picking returns the full-size '
          'GIF url', (tester) async {
        final client = MockClient((request) async {
          requests.add(request.url);
          return http.Response(_page(), 200);
        });
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        await tester.enterText(find.byType(EditableText), 'cats');
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(requests.last.path, '/v1/gifs/search');
        expect(requests.last.queryParameters['q'], 'cats');
        await tester.tap(find.byType(DabblerImage).first);
        await tester.pump();
        expect(picked, ['$_original?i=0']);
      });

      testWidgets('TC3: no results shows the empty state', (tester) async {
        final client = MockClient(
          (request) async => http.Response(_page(count: 0, total: 0), 200),
        );
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(find.text(l10n.composer_gif_empty), findsOneWidget);
        expect(find.byType(DabblerImage), findsNothing);
      });

      testWidgets('TC4: offline shows the offline banner with Try again; '
          'Try again after reconnecting loads results', (tester) async {
        var online = false;
        final client = MockClient((request) async {
          if (!online) throw http.ClientException('no route');
          return http.Response(_page(), 200);
        });
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(find.byKey(GifPickerKeys.offline), findsOneWidget);
        expect(find.text(l10n.composer_gif_offline_title), findsOneWidget);
        expect(find.text(l10n.composer_gif_retry), findsOneWidget);

        online = true;
        await tester.tap(find.text(l10n.composer_gif_retry));
        await _settle(tester);
        expect(find.byKey(GifPickerKeys.offline), findsNothing);
        expect(find.byType(DabblerImage), findsNWidgets(2));
      });

      testWidgets('TC5: a provider error shows the unavailable banner, with '
          'Try again', (tester) async {
        var healthy = false;
        final client = MockClient(
          (request) async => healthy
              ? http.Response(_page(), 200)
              : http.Response('nope', 503),
        );
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(find.byKey(GifPickerKeys.unavailable), findsOneWidget);
        expect(find.text(l10n.composer_gif_unavailable_title), findsOneWidget);
        expect(find.text(l10n.composer_gif_unavailable_text), findsOneWidget);
        healthy = true;
        await tester.tap(find.text(l10n.composer_gif_retry));
        await _settle(tester);
        expect(find.byType(DabblerImage), findsNWidgets(2));
      });

      testWidgets('TC5b: a malformed answer is "unavailable", not a crash', (
        tester,
      ) async {
        final client = MockClient(
          (request) async => http.Response('{"data": 7}', 200),
        );
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(find.byKey(GifPickerKeys.unavailable), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('no key configured: unavailable at once, nothing is '
          'requested', (tester) async {
        final client = MockClient((request) async {
          requests.add(request.url);
          return http.Response(_page(), 200);
        });
        await tester.pumpWidget(picker(client, apiKey: ''));
        await _settle(tester);
        // The environment key is empty in tests, so this is the real default.
        expect(find.byKey(GifPickerKeys.unavailable), findsOneWidget);
        expect(requests, isEmpty);
      });

      testWidgets('the search field and credit are localized (no English '
          'literals in Arabic)', (tester) async {
        final client = MockClient(
          (request) async => http.Response(_page(), 200),
        );
        await tester.pumpWidget(picker(client));
        await _settle(tester);
        expect(find.text(l10n.composer_gif_search_placeholder), findsOneWidget);
        if (v.locale.languageCode == 'ar') {
          expect(find.text('Powered by GIPHY'), findsNothing);
          expect(find.text('No GIFs found'), findsNothing);
        }
      });
    });
  }
}
