// KAN-1012: Going (button or the sheet's Yes) or an invite accept on a
// request-policy meetup comes back `pending`; the detail screen then says the
// request was sent and the CTA reads the pending state, never Going.
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/presentation/rsvp_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('going or invite accept answered pending is a request', () {
    for (final a in RsvpAction.values.where((a) => a != RsvpAction.request)) {
      expect(rsvpBecameRequest(a, RsvpStatus.pending), isTrue, reason: '$a');
      expect(rsvpBecameRequest(a, RsvpStatus.going), isFalse, reason: '$a');
    }
  });

  test('the request flow itself expects pending: no extra notice', () {
    expect(rsvpBecameRequest(RsvpAction.request, RsvpStatus.pending), isFalse);
  });
}
