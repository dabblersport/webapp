// KAN-1029: a venue card with no photo shows the design system's placeholder
// glyph in the photo slot; a venue with a photo loads it.
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_cards.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
    home: Scaffold(body: Center(child: card)),
  ),
);

DabblerImage _photo(WidgetTester tester) => tester.widget<DabblerImage>(
  find.byKey(const ValueKey<String>('sport-venue-photo')),
);

void main() {
  const SportVenue bare = SportVenue(
    id: 'v1',
    nameEn: 'Ajman City Centre Roof Sports',
  );
  const SportVenue withPhoto = SportVenue(
    id: 'v2',
    nameEn: 'Padel Hub',
    coverUrl: 'https://example.com/venue.jpg',
  );

  testWidgets('rail card with no photo shows the placeholder glyph', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SportRailVenueCard(venue: bare));
    expect(_photo(tester).url, isNull);
    expect(_photo(tester).placeholderGlyph, isTrue);
    expect(find.byType(Image), findsNothing);
    final Finder glyph = find.descendant(
      of: find.byType(DabblerImage),
      matching: find.byType(DabblerIcon),
    );
    expect(glyph, findsOneWidget);
    expect(
      tester.getSize(find.byType(DabblerImage)).height,
      kSportRailVenuePhoto,
    );
    expect(find.text('Ajman City Centre Roof Sports'), findsOneWidget);
  });

  testWidgets('full venue card with no photo shows the placeholder glyph', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SportVenueCard(venue: bare));
    expect(
      find.descendant(
        of: find.byType(DabblerImage),
        matching: find.byType(DabblerIcon),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(DabblerImage)).height, kSportVenuePhoto);
  });

  testWidgets('card with a photo loads it', (WidgetTester tester) async {
    await _pump(tester, const SportRailVenueCard(venue: withPhoto));
    expect(_photo(tester).url, 'https://example.com/venue.jpg');
    final Image image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://example.com/venue.jpg');
  });
}
