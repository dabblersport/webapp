import 'dart:async';
import 'dart:convert';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';

import 'package:dabbler/core/services/theme_categories.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'features/venues/experiment/places_ui_kit_experiment.dart';
import 'features/venues/experiment/places_ui_kit_ios_host.dart';

/// KAN-629 experiment harness. Development only; never part of a release.
///
///   flutter run -t lib/experiment_places_main.dart \
///     --dart-define=PLACES_UI_KIT_EXPERIMENT=true \
///     --dart-define=PLACES_IOS_KEY=$KEY_FROM_KEYCHAIN \
///     --dart-define=PLACES_MODE=match, nine or tier (plus the options below)
///
/// It renders the real [DabblerCardVenue] with the real cover injection
/// ([experimentCover]) for the nine allowlisted venues and prints `PLX` lines
/// (markers, counters) for the evidence script. It makes no Supabase call.
const String _mode = String.fromEnvironment(
  'PLACES_MODE',
  defaultValue: 'nine',
);
const bool _dark = bool.fromEnvironment('PLACES_DARK');
const bool _rtl = bool.fromEnvironment('PLACES_RTL');
const bool _horizontal = bool.fromEnvironment('PLACES_HORIZONTAL');
const bool _photoOnly = bool.fromEnvironment('PLACES_PHOTO_ONLY');
const int _tier = int.fromEnvironment('PLACES_TIER', defaultValue: 10);
const String _scaleRaw = String.fromEnvironment(
  'PLACES_SCALE',
  defaultValue: '1.0',
);
const String _width = String.fromEnvironment('PLACES_WIDTH');

void plx(String line) => debugPrint('PLX $line');

class _V {
  const _V(
    this.id,
    this.name,
    this.area,
    this.query,
    this.lat,
    this.lng, {
    this.radius = 400,
    this.max = 1,
  });
  final String id, name, area, query;
  final double lat, lng, radius;
  final int max;
}

// Supabase facts (read-only, 2026-10-23). The query is what Text Search gets.
const List<_V> _venues = [
  _V(
    'b53aea46-f61e-4d81-9de7-9ca515f0b9f9',
    'All Star Sport',
    'Al Barsha, Dubai',
    'All Star Sport Umm Suqeim Road Al Barsha',
    25.1090448,
    55.2192127,
  ),
  _V(
    '608c44d5-0d3e-4f9f-ace3-a9e7bf565dc4',
    'Champs Sports Club (Al Quoz)',
    'Al Quoz, Dubai',
    'Champs Sports Club Al Quoz Industrial Area 3',
    25.1308,
    55.2328,
    max: 3,
  ),
  _V(
    '85de82d7-9470-408c-ba3d-3559ea9248b6',
    'Aktiv Nation',
    'Al Quoz, Dubai',
    'Aktiv Nation Al Quoz Industrial Area 4',
    25.1164,
    55.22691,
  ),
  _V(
    'c68d6c80-54a4-4d17-ac93-395be1fa8ba4',
    'Ahdaaf Sports Club',
    'Al Quoz, Dubai',
    'Ahdaaf Sports Club Al Quoz Industrial Area 2',
    25.12832,
    55.24163,
  ),
  _V(
    '387f6a70-760b-47d5-a991-495d07aa869f',
    'ISD Dubai Sports City',
    'Dubai Sports City',
    'ISD Padel Dubai Sports City',
    25.03867,
    55.22442,
  ),
  _V(
    'c5aefd96-474d-4171-b7e6-64155a1d6fa3',
    'United Pro Sports',
    'Al Quoz, Dubai',
    'United Pro Sports Al Quoz Dubai',
    25.15,
    55.19,
    radius: 6000,
    max: 3,
  ),
  _V(
    '069a13d4-8994-462c-9226-0024d1d4006c',
    '365 Open Sports',
    'Dubailand, Dubai',
    '365 Open Sports Falcon City of Wonders',
    25.1015,
    55.3374,
  ),
  _V(
    'e91d8b43-360f-4da6-ad0b-d89b5402db85',
    'Jebel Ali Recreation Club',
    'Jebel Ali, Dubai',
    'Jebel Ali Recreation Club',
    25.0349392,
    55.1177546,
  ),
  _V(
    'cbcb52c5-9ffd-42e3-bec3-a3447a18cf3f',
    'Danube Sports World',
    'Al Habtoor City, Dubai',
    'Danube Sports World Al Habtoor City',
    25.1791,
    55.253,
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final started = await IosPlacesUiKitHost.start();
  plx('configured ${jsonEncode(started)}');
  PlacesExperiment.host = IosPlacesUiKitHost(
    horizontal: _horizontal,
    photoOnly: _photoOnly,
  );
  PlacesExperiment.manifest = {
    ...kPlacesManifest,
    // A development-only override, e.g. to verify an alternate candidate.
    ...Map<String, String>.from(
      jsonDecode(
            const String.fromEnvironment('PLACES_OVERRIDE', defaultValue: '{}'),
          )
          as Map,
    ),
  };
  runApp(const _Harness());
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _counters(String tag) async {
    final c = await kPlacesChannel.invokeMapMethod<String, Object?>('counters');
    plx('counters $tag ${jsonEncode(c)}');
    plx(
      'intrinsic $tag ${placesIntrinsics.value.entries.map((e) => '${e.key}=${e.value.width.toStringAsFixed(1)}x${e.value.height.toStringAsFixed(1)}').join(' ')}',
    );
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _run() async {
    await _wait(1500);
    await kPlacesChannel.invokeMethod('resetSession');
    if (_mode == 'match') return _match();
    if (_mode == 'tier') return _tierRun();
    return _ninePass();
  }

  Future<void> _match() async {
    for (final v in _venues) {
      final r = await kPlacesChannel.invokeMapMethod<String, Object?>('match', {
        'query': v.query,
        'lat': v.lat,
        'lng': v.lng,
        'radius': v.radius,
        'max': v.max,
      });
      plx('match ${v.id} ${v.name} -> ${jsonEncode(r)}');
    }
    // Identity research for the Champs duplicate: the Area 4 record's point.
    final r = await kPlacesChannel.invokeMapMethod<String, Object?>('match', {
      'query': 'Champs Sports Club Al Quoz Industrial Area 4',
      'lat': 25.1250,
      'lng': 55.2290,
      'radius': 400.0,
      'max': 3,
    });
    plx('match champs-uae-point -> ${jsonEncode(r)}');
    await _counters('after-match');
    plx('DONE');
  }

  // One card per scroll step so each venue is on screen once; PLX SHOT lines
  // tell the evidence script when to take a screenshot.
  Future<void> _ninePass() async {
    await _wait(9000);
    for (var i = 0; i < _venues.length; i++) {
      final pos = i * _cardExtent;
      _scroll.jumpTo(pos.clamp(0.0, _scroll.position.maxScrollExtent));
      await _wait(9000);
      plx('SHOT ${_venues[i].id} ${_venues[i].name}');
      await _wait(2500);
    }
    await _counters('nine-pass');
    plx('DONE');
  }

  double get _cardExtent => 520;

  Future<void> _tierRun() async {
    Future<void> sweep(String name) async {
      _scroll.jumpTo(0);
      await _wait(1500);
      final max = _scroll.position.maxScrollExtent;
      var y = 0.0;
      while (y < max) {
        y = (y + _cardExtent).clamp(0.0, max);
        _scroll.jumpTo(y);
        await _wait(1800);
      }
      await _counters('$name-end');
    }

    await _counters('tier$_tier-start');
    await sweep('tier$_tier-cold');
    await sweep('tier$_tier-revisit');
    plx('DONE');
  }

  @override
  Widget build(BuildContext context) {
    final scale = double.tryParse(_scaleRaw) ?? 1.0;
    final theme = DabblerDesignSystemTheme.withTokens(
      ThemeData(brightness: _dark ? Brightness.dark : Brightness.light),
      theme: ThemeCategories.dabblerThemeFor('main'),
    );
    final count = _mode == 'tier' ? _tier : _venues.length;
    final cardWidth = double.tryParse(_width);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListView.builder(
            controller: _scroll,
            cacheExtent: 0, // ignore: deprecated_member_use
            padding: const EdgeInsets.all(16),
            itemCount: count,
            itemBuilder: (context, i) {
              final v = _venues[i % _venues.length];
              return SizedBox(
                height: _cardExtent,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: cardWidth,
                    child: DabblerCardVenue(
                      name: v.name,
                      cover: experimentCover(
                        venueId: v.id,
                        height: DabblerCardVenue.coverHeight,
                        enabled: true,
                        baseline: DabblerImage(
                          url: null,
                          height: DabblerCardVenue.coverHeight,
                          radius: BorderRadius.zero,
                          placeholderGlyph: true,
                        ),
                      ),
                      area: v.area,
                      price: 'AED 120',
                      priceCaption: 'Starting from',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
