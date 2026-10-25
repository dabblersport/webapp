import 'dart:io';

import 'package:dabbler/features/sports/presentation/widgets/sport_artwork.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-591: the supplied sport artwork. File names are case-sensitive and
/// carry the supplier's misspellings; the tests read the real folder, so a
/// rename or a wrong case fails here before it fails on a case-sensitive host.
void main() {
  final Directory folder = Directory(kSportArtworkFolder);
  final Set<String> onDisk = folder
      .listSync()
      .whereType<File>()
      .map((File f) => f.uri.pathSegments.last)
      .toSet();

  test('all 17 supplied files are in the folder, names untouched', () {
    expect(onDisk, <String>{
      'Badmition.svg',
      'Basketball.svg',
      'Bowloing.svg',
      'Cricket.svg',
      'Cycling.svg',
      'Football.svg',
      'Frame 5.svg',
      'Golf.svg',
      'GYM.svg',
      'Padel.svg',
      'Ping-Pong.svg',
      'Pool.svg',
      'Rakby.svg',
      'Running.svg',
      'Swimming.svg',
      'Tennis.svg',
      'Volyball.svg',
    });
  });

  test('every mapped key points at a file that exists, case for case', () {
    for (final MapEntry<String, String> e in kSportArtworkFiles.entries) {
      expect(onDisk, contains(e.value), reason: '${e.key} -> ${e.value}');
      expect(
        File('$kSportArtworkFolder/${e.value}').existsSync(),
        isTrue,
        reason: e.key,
      );
      expect(sportArtworkAsset(e.key), '$kSportArtworkFolder/${e.value}');
    }
  });

  test('the sports the data names resolve to their own file', () {
    const Map<String, String> expected = <String, String>{
      'football': 'Football.svg',
      'basketball': 'Basketball.svg',
      'swimming': 'Swimming.svg',
      'running': 'Running.svg',
      'cricket': 'Cricket.svg',
      'gym_training': 'GYM.svg',
      'tennis': 'Tennis.svg',
      'padel': 'Padel.svg',
      'table_tennis': 'Ping-Pong.svg',
      'pool_billiards': 'Pool.svg',
      'badminton': 'Badmition.svg',
      'volleyball': 'Volyball.svg',
      'rugby_union': 'Rakby.svg',
    };
    for (final MapEntry<String, String> e in expected.entries) {
      expect(kSportArtworkFiles[e.key], e.value, reason: e.key);
    }
  });

  test('a sport the supplied set does not draw has no artwork', () {
    expect(sportArtworkAsset('quidditch'), isNull);
    expect(sportArtworkAsset('beach_volleyball'), isNull);
    expect(sportArtworkAsset(null), isNull);
    expect(sportArtworkAsset(''), isNull);
    // Keys are the data's, exact: no case folding that would guess.
    expect(sportArtworkAsset('Football'), isNull);
  });

  test('Frame 5.svg is baseball (CEO ruling, KAN-591 R2)', () {
    expect(kSportArtworkFiles['baseball'], 'Frame 5.svg');
    expect(sportArtworkAsset('baseball'), '$kSportArtworkFolder/Frame 5.svg');
  });

  test('every shipped file is registered by the folder entry in pubspec', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- $kSportArtworkFolder/'));
  });

  testWidgets('a mapped sport draws its SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SportArtwork(sportKey: 'football', size: 60)),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('an unknown sport falls back to the design system icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SportArtwork(sportKey: 'quidditch', size: 60)),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(DabblerSportIcon), findsOneWidget);
  });

  testWidgets('every mapped SVG parses and draws without an exception', (
    tester,
  ) async {
    final List<String> keys = kSportArtworkFiles.keys.toList();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: <Widget>[
              for (final String k in keys) SportArtwork(sportKey: k, size: 48),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SvgPicture), findsNWidgets(keys.length));
    expect(tester.takeException(), isNull);
  });
}
