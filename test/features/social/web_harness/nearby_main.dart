// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui' as ui;

import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:flutter/material.dart';

/// KAN-594 review harness (localhost only). It runs the REAL ranking and
/// paging code (`NearbyFeedLoader`) over fixture posts for two Cities and draws
/// the result, so TC1-TC7 can be seen in a browser without a backend.
///
///   ?case=city|area|lastknown|expired|nocity   ?city=Dubai|Doha   ?lang=ar  ?dark=1
void main() {
  final q = Uri.base.queryParameters;
  runApp(_Harness(q));
}

final _now = DateTime.now();
const _dubaiOrigin = (25.0, 55.0);

double _north(double m) => 25.0 + m / 111195.0;

NearbyCandidate _c(String id, double ageH, {double? meters}) => NearbyCandidate(
  id: id,
  createdAt: _now.subtract(Duration(minutes: (ageH * 60).round())),
  lat: meters == null ? null : _north(meters),
  lng: meters == null ? null : 55.0,
);

// The documented five-post table, plus a post with no coordinates (TC4).
final _byCity = <String, List<NearbyCandidate>>{
  'Dubai': [
    _c('A newer, farther (1h, 12km)', 1, meters: 12000),
    _c('B older, closer (30h, 0.8km)', 30, meters: 800),
    _c('C (6h, 4km)', 6, meters: 4000),
    _c('D (3h, 25km)', 3, meters: 25000),
    _c('E old, very close (72h, 0.3km)', 72, meters: 300),
    _c('F no coordinates (2h)', 2),
  ],
  'Doha': [
    _c('Q1 Doha (1h)', 1, meters: 900),
    _c('Q2 Doha (5h)', 5, meters: 3000),
    _c('Q3 Doha no coordinates (8h)', 8),
  ],
};

class _Harness extends StatefulWidget {
  const _Harness(this.q);
  final Map<String, String> q;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String _city = widget.q['city'] ?? 'Dubai';
  late final String _case = widget.q['case'] ?? 'area';
  final List<String> _shown = [];
  int _queries = 0;

  NearbyScope get _scope {
    switch (_case) {
      case 'nocity':
        return const NearbyScope();
      case 'city':
        return NearbyScope(city: _city);
      case 'lastknown':
        return NearbyScope(
          city: _city,
          lat: _dubaiOrigin.$1,
          lng: _dubaiOrigin.$2,
          lastKnown: true,
          fixedAt: _now.subtract(const Duration(hours: 3)),
        );
      case 'expired':
        return NearbyScope(
          city: _city,
          lat: _dubaiOrigin.$1,
          lng: _dubaiOrigin.$2,
          lastKnown: true,
          fixedAt: _now.subtract(const Duration(hours: 25)),
        );
      default:
        return NearbyScope(
          city: _city,
          lat: _dubaiOrigin.$1,
          lng: _dubaiOrigin.$2,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _shown.clear();
    final scope = _scope;
    final city = scope.city;
    if (city == null) {
      setState(() {});
      return;
    }
    _queries++;
    final asOf = _now;
    final origin = resolveNearbyOrigin(scope, asOf);
    final ranked = rankNearby(
      _byCity[city] ?? const [],
      origin: origin,
      asOf: asOf,
    );
    // Page through the real cursor, three rows at a time.
    NearbyCursor? cursor;
    while (true) {
      final page = afterNearbyCursor(ranked, cursor).take(3).toList();
      if (page.isEmpty) break;
      for (final r in page) {
        _shown.add('${r.candidate.id}   score ${r.score.toStringAsFixed(4)}');
      }
      cursor = page.last.cursor;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.q['lang'] == 'ar';
    final dark = widget.q['dark'] == '1';
    final scope = _scope;
    final origin = resolveNearbyOrigin(scope, _now);
    final label = scope.city == null
        ? (ar ? 'اختر المدينة' : 'Choose city')
        : origin == null
        ? (ar ? 'الأحدث أولاً' : 'Newest first (city only)')
        : scope.lastKnown
        ? (ar ? 'آخر موقع معروف' : 'Last known location')
        : (ar ? 'الأقرب والأحدث' : 'Nearest and newest');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(ar ? 'ar' : 'en'),
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
      ),
      builder: (c, w) => Directionality(
        textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: w!,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text(ar ? 'القريب' : 'Nearby')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final c in _byCity.keys)
                  ChoiceChip(
                    label: Text(c),
                    selected: c == _city,
                    onSelected: (_) {
                      _city = c;
                      _reset();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'case=$_case  city=${scope.city ?? "none"}  queries=$_queries',
            ),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            if (scope.city == null)
              Text(
                ar
                    ? 'لا استعلام. افتح تحديد الموقع.'
                    : 'No query. Opens Set location.',
              )
            else
              for (var i = 0; i < _shown.length; i++)
                ListTile(leading: Text('${i + 1}'), title: Text(_shown[i])),
          ],
        ),
      ),
    );
  }
}
