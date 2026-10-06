/// The venue Facilities chips: a glyph before a human label, centred in the
/// pill, EN and AR, RTL mirrored (`Details.dc.html:441-449`).
///
/// Optional defines: `AMENITY_SHOTS_DIR=<dir>` writes the renders (2x, 393
/// wide); `AMENITY_PHASE=before` renders the previous call shape (raw keys, a
/// bare glyph) for the before image.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/features/venues/presentation/widgets/venue_amenity_chips.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

const String _shotsDir = String.fromEnvironment('AMENITY_SHOTS_DIR');
const String _phase = String.fromEnvironment(
  'AMENITY_PHASE',
  defaultValue: 'after',
);
const Key _key = Key('amenity-shot');

const List<String> _keys = <String>[
  'outdoor',
  'indoor',
  'parking',
  'washrooms',
  'changing_rooms',
  'showers',
  'lighting',
  'cafeteria',
  'wifi',
  'first_aid',
  'accessibility',
  'gym',
];

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  List<String> amenities, {
  double scale = 1,
  bool before = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(393, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: locale,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => ColoredBox(
          color: DabblerColors.of(context).bgPrimary,
          child: RepaintBoundary(
            key: _key,
            child: Padding(
              padding: const EdgeInsets.all(DabblerSpacing.space6),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: before
                    ? Wrap(
                        spacing: DabblerSpacing.space3,
                        runSpacing: DabblerSpacing.space3,
                        children: [
                          for (final a in amenities)
                            DabblerChip(
                              label: a,
                              compact: true,
                              leadingIcon: const DabblerIcon('tick-circle'),
                            ),
                        ],
                      )
                    : VenueAmenityChips(amenities: amenities),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _shoot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary b =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await b.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadRenderFonts);

  for (final Locale locale in const [Locale('en'), Locale('ar')]) {
    final bool rtl = locale.languageCode == 'ar';

    testWidgets(
      'amenity chips: human labels, glyph before label (${locale.languageCode})',
      (tester) async {
        await _pump(tester, locale, _keys, before: _phase == 'before');
        await _shoot(tester, 'venue-amenities-$_phase-${rtl ? 'rtl' : 'ltr'}');
        if (_phase == 'before') return;

        final l10n = await AppLocalizations.delegate.load(locale);
        expect(find.byType(DabblerChip), findsNWidgets(_keys.length));
        for (final String k in _keys) {
          final String label = amenityLabel(l10n, k);
          expect(label, isNot(contains('_')), reason: k);
          expect(find.text(label), findsOneWidget, reason: k);
          // A localised name, not the raw key.
          expect(label, isNot(equals(k)), reason: k);
        }
        for (final String k in _keys) {
          expect(find.text(k), findsNothing, reason: 'raw key $k');
        }

        final double height = DabblerChip.compactVerticalPadding * 2 + 18;
        for (final Element e in find.byType(DabblerChip).evaluate()) {
          final Rect pill = tester.getRect(find.byWidget(e.widget));
          final Rect icon = tester.getRect(
            find.descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(DabblerIcon),
            ),
          );
          final Rect text = tester.getRect(
            find.descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(Text),
            ),
          );
          if (rtl) {
            expect(icon.left, greaterThanOrEqualTo(text.right));
          } else {
            expect(icon.right, lessThanOrEqualTo(text.left));
          }
          expect(icon.center.dy, closeTo(pill.center.dy, 0.5));
          expect(pill.height, height);
        }
      },
    );
  }

  test('unknown keys are humanised, never raw', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(amenityLabel(l10n, 'some_new_thing'), 'Some new thing');
    expect(amenityLabel(l10n, 'Changing rooms'), 'Changing rooms');
    expect(amenityLabel(l10n, 'first-aid'), 'First aid');
    expect(amenityIconName('changing_rooms'), 'lock');
    expect(amenityIconName('lighting'), 'flash');
    expect(amenityIconName('cafeteria'), 'cup');
    expect(amenityIconName('unheard_of'), 'tick-circle');
  });

  testWidgets('wraps and does not overlap at 2x text', (tester) async {
    await _pump(tester, const Locale('ar'), _keys, scale: 2);
    final rects = [
      for (final e in find.byType(DabblerChip).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i vs $j');
      }
    }
    expect(tester.takeException(), isNull);
  });
}
