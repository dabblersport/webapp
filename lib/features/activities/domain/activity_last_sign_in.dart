import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-990 hook for the Activity log security card.
///
/// The card shows real sign-in data only (F-16, G.9): never "No unusual
/// activity" without data. The sign-in ledger (KAN-985) and its read RPC are
/// not built yet, so [activityLastSignInProvider] answers null and the card
/// renders nothing.
///
/// KAN-985 / KAN-1003: override [activityLastSignInProvider] with the ledger
/// read, and fill `ActivitySecurityFooter` with "Last sign-in · time ·
/// device · city" and a "Review sign-ins" link to the sign-in list.
class ActivityLastSignIn {
  const ActivityLastSignIn({
    required this.at,
    this.device,
    this.city,
    this.isNewDevice = false,
  });

  /// When the latest sign-in happened.
  final DateTime at;

  /// The device as the ledger names it ("iPhone", "Chrome on macOS").
  final String? device;

  /// The city the sign-in came from, when the ledger knows it.
  final String? city;

  /// True when the sign-in came from a device not seen before.
  final bool isNewDevice;
}

/// The latest sign-in of the viewer; null until the KAN-985 ledger exists.
final activityLastSignInProvider = FutureProvider<ActivityLastSignIn?>(
  (ref) async => null,
);
