import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-640: the cities of a country and the areas of a city for the manual
/// location flow. Read only, from the tables the app already has:
/// `ref_countries` / `ref_cities` for the cities, `areas` for the areas.

/// The ISO alpha-2 code of each service country, for the map-service
/// `country` filter.
const Map<String, String> kCountryIsoCodes = <String, String>{
  'Egypt': 'EG',
  'Morocco': 'MA',
  'Qatar': 'QA',
  'Saudi Arabia': 'SA',
  'United Arab Emirates': 'AE',
};

/// A city of a country (`ref_cities`).
class CatalogCity {
  const CatalogCity({
    required this.code,
    required this.nameEn,
    required this.nameAr,
  });

  final String code;
  final String nameEn;
  final String nameAr;

  String name(bool arabic) => arabic && nameAr.isNotEmpty ? nameAr : nameEn;

  @override
  bool operator ==(Object other) => other is CatalogCity && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// An area of a city (`areas`).
class CatalogArea {
  const CatalogArea({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;
}

abstract class ManualLocationCatalog {
  /// The cities of [countryName] (the canonical English service-region name),
  /// by name. Empty when the country has none; throws when unreachable.
  Future<List<CatalogCity>> citiesOf(String countryName);

  /// The active areas of [city], by name.
  Future<List<CatalogArea>> areasOf(CatalogCity city);
}

class SupabaseManualLocationCatalog implements ManualLocationCatalog {
  const SupabaseManualLocationCatalog(this._db);

  final SupabaseClient _db;

  @override
  Future<List<CatalogCity>> citiesOf(String countryName) async {
    final List<dynamic> country = await _db
        .from(SupabaseConfig.refCountriesTable)
        .select('code')
        .eq('name_en', countryName)
        .limit(1);
    if (country.isEmpty) return const <CatalogCity>[];
    final String code = (country.first as Map)['code'] as String;
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.refCitiesTable)
        .select('code, name_en, name_ar')
        .eq('country_code', code)
        .order('name_en');
    return <CatalogCity>[
      for (final Map r in rows.cast<Map>())
        CatalogCity(
          code: r['code'] as String,
          nameEn: r['name_en'] as String? ?? '',
          nameAr: r['name_ar'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<List<CatalogArea>> areasOf(CatalogCity city) async {
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.areasTable)
        .select('name, center_lat, center_lng')
        .eq('city_code', city.code)
        .eq('is_active', true)
        .order('name');
    return <CatalogArea>[
      for (final Map r in rows.cast<Map>())
        CatalogArea(
          name: r['name'] as String,
          lat: (r['center_lat'] as num).toDouble(),
          lng: (r['center_lng'] as num).toDouble(),
        ),
    ];
  }
}

final manualLocationCatalogProvider = Provider<ManualLocationCatalog>(
  (ref) =>
      SupabaseManualLocationCatalog(ref.read(supabaseServiceProvider).client),
);

final catalogCitiesProvider = FutureProvider.autoDispose
    .family<List<CatalogCity>, String>(
      (ref, country) =>
          ref.read(manualLocationCatalogProvider).citiesOf(country),
    );

final catalogAreasProvider = FutureProvider.autoDispose
    .family<List<CatalogArea>, CatalogCity>(
      (ref, city) => ref.read(manualLocationCatalogProvider).areasOf(city),
    );
