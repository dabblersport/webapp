import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/features/venues/experiment/places_details_route.dart';

void main() {
  test('disabled source never returns data', () async {
    expect(await const PlacesDetailsSource.disabled().fetch('x'), isNull);
  });

  test('field mask asks for no field beyond the card needs', () {
    expect(kPlacesDetailsFieldMask, contains('rating'));
    expect(kPlacesDetailsFieldMask, isNot(contains('reviews')));
    expect(kPlacesDetailsFieldMask, isNot(contains('editorialSummary')));
  });

  test('cost model: nine venues stay free inside the monthly allowance', () {
    expect(PlacesRoute2Cost.zeroCostDailyQuota, 33);
    expect(PlacesRoute2Cost.monthlyUsd(venues: 9, views: 100), 0);
    expect(PlacesRoute2Cost.monthlyUsd(venues: 9, views: 1000) > 0, isTrue);
  });
}
