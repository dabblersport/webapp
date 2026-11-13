import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/connectivity_overrides.dart';
import '../../support/render_mode.dart';

/// KAN-592: the composer's "Posted from" pill and the city prompt that opens
/// from Post when no city is known, with the typed draft kept.
class _Device extends ActiveLocationNotifier {
  _Device(this._value);
  final ActiveLocationState _value;

  @override
  Future<ActiveLocationState> build() async => _value;
}

const Area _marina = Area(
  id: 'a1',
  name: 'Dubai Marina',
  district: 'Dubai',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  ActiveLocationState device, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => []),
        activeLocationProvider.overrideWith(() => _Device(device)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: DabblerPage(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: const PostComposerScreen(),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    final l = lookupAppLocalizations(locale);
    final pill = find.byKey(const Key('composer-posted-from-pill'));

    testWidgets('[$tag] TC1 device city fills the pill', (tester) async {
      await _pump(
        tester,
        locale,
        ActiveLocationReady(
          const ActiveLocation(
            lat: 25.08,
            lng: 55.14,
            area: _marina,
            source: ActiveLocationSource.gps,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(pill, findsOneWidget);
      expect(find.text(l.composer_posted_from_pill('Dubai')), findsOneWidget);
    });

    testWidgets('[$tag] TC2 denied: Post asks for a city, the draft is kept, '
        'the choice shows on the pill', (tester) async {
      await _pump(tester, locale, ActiveLocationDenied());
      expect(find.text(l.composer_posted_from_choose), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'Padel tonight');
      await tester.pump();
      await tester.tap(find.text(l.composer_post_cta));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.byKey(const Key('composer-posted-from-prompt')),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      );
      expect(container.read(postComposerProvider).body, 'Padel tonight');

      await tester.tap(
        find.byKey(const ValueKey('composer-posted-from-Abu Dhabi')),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(const Key('composer-posted-from-prompt')),
        findsNothing,
      );
      expect(
        find.text(l.composer_posted_from_pill('Abu Dhabi')),
        findsOneWidget,
      );
      expect(container.read(postComposerProvider).body, 'Padel tonight');
      expect(tester.takeException(), isNull);
    });

    testWidgets('[$tag] KAN-612 offline: Post is refused with a localized '
        'message, the draft is kept, nothing is posted', (tester) async {
      await _pump(
        tester,
        locale,
        ActiveLocationReady(
          const ActiveLocation(
            lat: 25.08,
            lng: 55.14,
            area: _marina,
            source: ActiveLocationSource.gps,
          ),
        ),
        extraOverrides: [offlineConnectivity()],
      );
      await tester.enterText(find.byType(EditableText).first, 'Padel tonight');
      await tester.pump();
      await tester.tap(find.text(l.composer_post_cta));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(l.offline_create_refused), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      );
      expect(container.read(postComposerProvider).body, 'Padel tonight');
      expect(container.read(postComposerProvider).isSubmitting, isFalse);
      expect(container.read(postComposerProvider.notifier).requestId, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
