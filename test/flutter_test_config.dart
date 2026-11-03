import 'dart:async';

import 'package:dabbler/features/explore/presentation/widgets/listing_refresh.dart';

/// KAN-755: widget tests render the listings against a real client; keep the
/// Realtime feed off by default so no socket retry timer outlives a test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  listingRealtimeDisabled = true;
  await testMain();
}
